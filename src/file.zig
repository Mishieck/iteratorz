//! Data structures for performing read/write operations on a file.

const std = @import("std");

const builtin = @import("builtin");
const native_os = builtin.os.tag;
const is_windows = native_os == .windows;
const debug = std.debug;
const mem = std.mem;

const posix = std.posix;
const windows = std.os.windows;
const fs = std.fs;
const testing = std.testing;

const ib = @import("iterable.zig");
const vec = @import("vector.zig");
const it = @import("iterator.zig");
const in = @import("indexable.zig");
const buf = @import("buffered.zig");
const mo = @import("mode.zig");

pub const Capacity = u64;
pub const capacity = ~@as(Capacity, 0);
pub const Slice = []Value;
pub const Value = u8;

pub fn This(buffer_capacity: anytype) type {
    return struct {
        const In = in.Collection(Value, capacity);
        const It = it.Iterator(Value, State);
        const Ib = ib.Iterable(Value, State);
        const InIb = in.Iterable(Value, capacity);
        const VecIn = vec.Indexable(Value, buffer_capacity);
        const State = InIb.StateType;
        pub const StateType = State;
        const BufIn = buf.Indexable(Value, capacity, buffer_capacity);
        const FiIn = Indexable(buffer_capacity);
        const Buf = buf.This(Value, capacity, buffer_capacity);

        pub const Getter = create(.get);
        pub const Setter = create(.set);

        pub fn create(mode: mo.Mode) type {
            return struct {
                const Self = @This();
                const Iterator = if (mode == .get) It.Getter else It.Setter;
                const Buffered = if (mode == .get) Buf.Getter else Buf.Setter;

                default_iterator: *Iterator.Default,
                indexable_iterable: *InIb,
                buffered_indexable: *BufIn,
                vector_indexable: *VecIn,
                file_indexable: *FiIn,

                pub fn init(
                    gpa: mem.Allocator,
                    file: fs.File,
                    buffer: Slice,
                    operation: Mode.Operation,
                ) !Self {
                    const read_mode = Mode{ .read = operation };
                    const write_mode = Mode{ .write = operation };
                    const file_mode = if (mode == .get) read_mode else write_mode;
                    const file_indexable = try FiIn.create(gpa, file, buffer, file_mode);
                    const vector_indexable = try VecIn.create(gpa, buffer, mode);
                    const buffered_indexable = try BufIn.create(
                        gpa,
                        &file_indexable.interface,
                        vector_indexable,
                        mode,
                    );
                    const indexable_iterable = try InIb.create(gpa, &buffered_indexable.interface);
                    const default_iterator = try Iterator.Default.create(
                        gpa,
                        &indexable_iterable.interface,
                    );

                    return .{
                        .default_iterator = default_iterator,
                        .indexable_iterable = indexable_iterable,
                        .buffered_indexable = buffered_indexable,
                        .file_indexable = file_indexable,
                        .vector_indexable = vector_indexable,
                    };
                }

                pub fn deinit(self: *Self, gpa: mem.Allocator) void {
                    gpa.destroy(self.default_iterator);
                    gpa.destroy(self.indexable_iterable);
                    gpa.destroy(self.buffered_indexable);
                    gpa.destroy(self.file_indexable);
                    gpa.destroy(self.vector_indexable);
                }

                pub fn iterator(self: *const Self) Iterator.This {
                    return .init(&self.default_iterator.interface);
                }

                pub fn iterable(self: *const Self) Ib {
                    return .init(&self.indexable_iterable.interface);
                }

                pub fn indexable(self: *const Self) In {
                    return .init(&self.buffered_indexable.interface);
                }
            };
        }
    };
}

test This {
    const Operation = Mode.Operation;
    const operations = [2]Mode.Operation{ Operation.streaming, Operation.positional };
    for (operations) |op| try testIterator(op);
}

pub fn Indexable(buffer_capacity: anytype) type {
    return struct {
        const BufIn = buf.Indexable(Value, capacity, buffer_capacity);
        const In = in.Collection(Value, capacity);
        const SlIn = in.Collection(Slice, capacity);
        const VecIn = vec.Indexable(Value, buffer_capacity);

        const Self = @This();
        pub const Interface = in.Indexable(Slice, capacity).Interface;

        interface: Interface,
        file: fs.File,
        buffer: Slice,
        mode: Mode,

        pub fn create(gpa: mem.Allocator, file: fs.File, buffer: Slice, mode: Mode) !*Self {
            const self = try gpa.create(Self);
            self.* = .init(file, buffer, mode);
            return self;
        }

        pub fn init(file: fs.File, buffer: Slice, mode: Mode) Self {
            return .{
                .interface = .{
                    .mode = mode.toBuffered(),
                    .get = get,
                    .set = set,
                    .size = size,
                },
                .file = file,
                .buffer = buffer,
                .mode = mode,
            };
        }

        fn get(indexable: *Interface, index: Capacity) anyerror!Slice {
            const self: *Self = @fieldParentPtr("interface", indexable);

            return switch (self.mode) {
                .read => |operation| switch (operation) {
                    .positional => |_| self.getPositional(index) catch return error.ReadFailed,
                    .streaming => |_| self.getStreaming(index) catch return error.ReadFailed,
                    .failure => error.ReadFailed,
                },
                else => unreachable,
            };
        }

        fn set(indexable: *Interface, index: Capacity, value: Slice) anyerror!*Interface {
            var self: *Self = @fieldParentPtr("interface", indexable);

            switch (self.mode) {
                .write => |operation| switch (operation) {
                    .positional => |_| if (value.len != 0) {
                        _ = try self.setPositional(index, value);
                    },
                    .streaming => |_| if (value.len != 0) {
                        _ = try self.setStreaming(index, value);
                    },
                    .failure => return error.WriteFailed,
                },
                else => unreachable,
            }

            return indexable;
        }

        fn size(indexable: *Interface) anyerror!Capacity {
            const self: *Self = @fieldParentPtr("interface", indexable);
            if (is_windows) return if (windows.GetFileSizeEx(self.file.handle)) |s| @truncate(s) else |err| err;
            if (posix.Stat == void) return error.Streaming;

            if (self.file.stat()) |stat| {
                if (stat.kind == .file) return stat.size else {
                    self.mode = self.mode.toStreaming();
                    return error.Streaming;
                }
            } else |err| return err;
        }

        pub fn getPositional(self: *Self, index: Capacity) anyerror!Slice {
            const buffered: usize = self.file.pread(self.buffer, index) catch |err| switch (err) {
                error.Unseekable => {
                    self.mode = self.mode.toStreaming();

                    if (index != 0) {
                        _ = self.seekTo(index) catch {
                            self.mode = self.mode.toFailure();
                            return error.ReadFailed;
                        };
                    }
                    return self.buffer[0..0];
                },
                else => return error.ReadFailed,
            };

            if (buffered == 0) return error.EndOfStream;
            return self.buffer[0..buffered];
        }

        pub fn getStreaming(self: *Self, index: Capacity) anyerror!Slice {
            _ = try self.seekTo(index);
            const value_size = self.file.read(self.buffer) catch return error.ReadFailed;
            if (value_size == 0) return error.EndOfStream;
            return self.buffer[0..value_size];
        }

        pub fn setPositional(self: *Self, index: Capacity, value: Slice) anyerror!*Self {
            if (value.len == 0) return self;
            const handle = self.file.handle;

            if (is_windows) {
                _ = windows.WriteFile(handle, value, index) catch return error.CommitFailed;
                return self;
            }

            _ = std.posix.pwrite(handle, value, index) catch |err| switch (err) {
                error.Unseekable => {
                    self.mode = self.mode.toStreaming();
                    if (index != 0) return error.CommitFailed;
                    return self;
                },
                else => return error.CommitFailed,
            };

            return self;
        }

        pub fn setStreaming(self: *Self, index: Capacity, value: Slice) anyerror!*Self {
            _ = try self.seekTo(index);
            if (value.len == 0) return self;
            const handle = self.file.handle;

            if (is_windows) {
                _ = windows.WriteFile(handle, value, null) catch return error.WriteFailed;
            } else _ = std.posix.write(handle, value) catch return error.CommitFailed;

            return self;
        }

        pub fn seekTo(self: *Self, index: Capacity) anyerror!*Self {
            return switch (self.mode) {
                .read, .write => |operation| switch (operation) {
                    .positional => unreachable,
                    .streaming => |_| s: {
                        try posix.lseek_SET(self.file.handle, index);
                        break :s self;
                    },
                    .failure => posix.SeekError.Unseekable,
                },
            };
        }

        pub fn fileSize(self: *Self) anyerror!usize {
            var collection = &self.interface;
            return @bitCast(try collection.size(&self.interface));
        }
    };
}

test Indexable {
    _ = Indexable(4);
}

pub const Mode = union(enum) {
    read: Operation,
    write: Operation,

    pub const default = Mode{ .read = Operation.default };

    pub fn toStreaming(self: @This()) @This() {
        const operation = switch (self) {
            .read, .write => |op| op.toStreaming(),
        };

        return switch (self) {
            .read => |_| @unionInit(Mode, "read", operation),
            .write => |_| @unionInit(Mode, "write", operation),
        };
    }

    pub fn toFailure(self: @This()) @This() {
        return switch (self) {
            .read => |_| @unionInit(Mode, "read", .failure),
            .write => |_| @unionInit(Mode, "write", .failure),
        };
    }

    pub fn toBuffered(self: *const @This()) buf.Mode {
        return switch (self.*) {
            .read => |_| .get,
            .write => |_| .set,
        };
    }

    pub const Operation = enum {
        streaming,
        positional,
        /// Indicates reading cannot continue because of a seek failure.
        failure,

        pub const default = Operation.streaming;

        pub fn toStreaming(self: @This()) @This() {
            return switch (self) {
                .positional, .streaming => .streaming,
                .failure => .failure,
            };
        }

        pub fn toFailure(self: @This()) @This() {
            return switch (self) {
                .positional, .streaming, .failure => .failure,
            };
        }
    };
};

fn testIterator(operation: Mode.Operation) !void {
    const allocator = testing.allocator;
    const buffer_capacity: u16 = 5;
    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();
    var file = try tmp_dir.dir.createFile("hello", .{ .read = true });
    defer file.close();

    const slice = "hello";

    var buffer: [slice.len]u8 = undefined;
    const File = This(buffer_capacity);
    var setter_file = try File.Setter.init(allocator, file, &buffer, operation);
    defer setter_file.deinit(allocator);
    var buffered_indexable = setter_file.buffered_indexable;
    var setter_iterator = setter_file.iterator();

    for (slice) |char| _ = try setter_iterator.current(char);
    try testing.expectEqualStrings(slice, &buffer);

    _ = try buffered_indexable.flush();

    const stat = try file.stat();
    try testing.expectEqual(slice.len, stat.size);

    var getter_file = try File.Getter.init(allocator, file, &buffer, operation);
    defer getter_file.deinit(allocator);
    var getter_iterator = getter_file.iterator();
    var iterated: [slice.len]u8 = undefined;

    var i: usize = 0;
    while (try getter_iterator.current()) |char| {
        iterated[i] = char;
        i += 1;
    }

    try testing.expectEqualStrings(slice, &iterated);
}
