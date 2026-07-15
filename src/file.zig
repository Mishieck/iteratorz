const std = @import("std");

const builtin = @import("builtin");
const native_os = builtin.os.tag;
const is_windows = native_os == .windows;
const debug = std.debug;

const posix = std.posix;
const windows = std.os.windows;
const fs = std.fs;
const testing = std.testing;

const ib = @import("iterable.zig");
const vec = @import("vector.zig");
const it = @import("iterator.zig");
const in = @import("indexable.zig");
const buf = @import("buffered.zig");

pub const Capacity = u64;
pub const capacity = ~@as(Capacity, 0);
pub const Slice = []Value;
pub const Value = u8;

pub fn Iterator(buffer_capacity: anytype) type {
    return struct {
        const In = in.Collection(Value, capacity);
        const FiIb = Iterable(buffer_capacity);
        const It = it.Iterator(Value, State);
        const Ib = ib.Iterable(Value, State);
        const InIb = in.Iterable(Value, capacity);
        const VecIn = vec.Indexable(Value, capacity);
        const State = FiIb.StateType;
        pub const StateType = State;
        const BufIn = buf.Indexable(Value, capacity, buffer_capacity);

        pub const Readable = struct {
            pub inline fn init(file: fs.File, buffer: Slice, operation: Mode.Operation) It.Readable.This {
                return It.Readable.This.init(
                    @constCast(
                        &It.Readable.Default.init(
                            FiIb.init(file, buffer, .{ .read = operation }).interface,
                        ).interface,
                    ),
                );
            }

            pub fn default_iterator(iterator: *It.Readable.This) *It.Readable.Default {
                return @fieldParentPtr("interface", iterator.interface);
            }

            pub fn indexable_iterable(iterator: *It.Readable.This) *InIb {
                return @fieldParentPtr("interface", default_iterator(iterator).iterable.interface);
            }

            pub fn buffered_indexable(iterator: *It.Readable.This) *BufIn {
                return @fieldParentPtr("interface", indexable_iterable(iterator).collection.interface);
            }
        };

        pub const Writable = struct {
            pub inline fn init(file: fs.File, buffer: Slice, operation: Mode.Operation) It.Writable.This {
                return It.Writable.This.init(
                    @constCast(
                        &It.Writable.Default.init(
                            @constCast(&FiIb.init(file, buffer, .{ .write = operation })),
                        ).interface,
                    ),
                );
            }

            pub fn default_iterator(iterator: *It.Writable.This) *It.Writable.Default {
                return @fieldParentPtr("interface", iterator.interface);
            }

            pub fn indexable_iterable(iterator: *It.Writable.This) *InIb {
                return @fieldParentPtr("interface", default_iterator(iterator).iterable.interface);
            }

            pub fn buffered_indexable(iterator: *It.Writable.This) *BufIn {
                return @fieldParentPtr("interface", indexable_iterable(iterator).collection.interface);
            }
        };
    };
}

test Iterator {
    const Operation = Mode.Operation;
    const operations = [2]Mode.Operation{ Operation.streaming, Operation.positional };
    for (operations) |op| try testIterator(op);
}

pub fn Iterable(buffer_capacity: anytype) type {
    return struct {
        const BufIb = buf.Iterable(Value, capacity, buffer_capacity);
        const BufIn = buf.Indexable(Value, capacity, buffer_capacity);
        const Ib = ib.Iterable(Value, State);
        const InIb = in.Iterable(Value, capacity);
        const VecIn = vec.Indexable(Value, capacity);
        const FiIn = Indexable(buffer_capacity);
        const State = BufIb.StateType;
        pub const StateType = State;

        pub inline fn init(file: fs.File, buffer: Slice, mode: Mode) Ib {
            return .init(
                @constCast(&InIb.init(FiIn.init(file, buffer, mode).interface).interface),
            );
        }

        pub fn indexable_iterable(iterable: *Ib) *InIb {
            return @fieldParentPtr("interface", iterable.interface);
        }

        pub fn buffered_indexable(iterable: *Ib) *BufIn {
            return @fieldParentPtr("interface", indexable_iterable(iterable).collection.interface);
        }
    };
}

pub fn Indexable(buffer_capacity: anytype) type {
    return struct {
        const BufIn = buf.Indexable(Value, capacity, buffer_capacity);
        const In = in.Collection(Value, capacity);
        const SlIn = in.Collection(Slice, capacity);
        const VecIn = vec.Indexable(Value, buffer_capacity);

        pub inline fn init(file: fs.File, buffer: Slice, mode: Mode) In {
            return In.init(
                @constCast(
                    &BufIn.init(
                        @constCast(
                            &SlIn.init(
                                @constCast(&SliceIndexable.init(file, buffer, mode).interface),
                            ),
                        ),
                        @constCast(&VecIn.init(buffer, mode.toBuffered()).interface),
                        mode.toBuffered(),
                    ).interface,
                ),
            );
        }

        pub fn buffered_indexable(indexable: *In) *BufIn {
            return @fieldParentPtr("interface", indexable.interface);
        }

        pub const SliceIndexable = struct {
            const Self = @This();
            pub const Interface = in.Collection(Slice, capacity).Interface;

            interface: Interface,
            file: fs.File,
            buffer: Slice,
            mode: Mode,

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
    const buffer_capacity: u16 = 5;
    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();
    var file = try tmp_dir.dir.createFile("hello", .{ .read = true });
    defer file.close();

    const slice = "hello";

    var buffer: [slice.len]u8 = undefined;
    const FiIt = Iterator(buffer_capacity);
    var writable_file = FiIt.Writable.init(file, &buffer, operation);
    var buffered_indexable = FiIt.Writable.buffered_indexable(&writable_file);

    for (slice) |char| _ = try writable_file.current(char);
    try testing.expectEqualStrings(slice, &buffer);

    _ = try buffered_indexable.flush();

    const stat = try file.stat();
    try testing.expectEqual(slice.len, stat.size);

    var readable_file = FiIt.Readable.init(file, &buffer, operation);
    var iterated: [slice.len]u8 = undefined;

    var i: usize = 0;
    while (try readable_file.current()) |char| {
        iterated[i] = char;
        i += 1;
    }

    try testing.expectEqualStrings(slice, &iterated);
}
