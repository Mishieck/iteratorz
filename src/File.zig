const std = @import("std");

const builtin = @import("builtin");
const Os = std.builtin.Os;
const native_os = builtin.os.tag;
const is_windows = native_os == .windows;
const debug = std.debug;

const Allocator = std.mem.Allocator;
const posix = std.posix;
const io = std.io;
const math = std.math;
const assert = std.debug.assert;
const linux = std.os.linux;
const windows = std.os.windows;
const maxInt = std.math.maxInt;
const Alignment = std.mem.Alignment;
const fs = std.fs;
const testing = std.testing;

const ib = @import("iterable.zig");
const vec = @import("vector.zig");
const it = @import("iterator.zig");
const buf = @import("buffered.zig");

const Self = @This();
pub const Value = u8;

pub const Iterable = ib.Iterable(Value, State);
pub const Vector = vec.Vector(Value);
pub const State = vec.State;
pub const Buffered = buf.Buffered(Value);
pub const Collection = Buffered.Collection;
const max_buffers_len = 16;

interface: Collection,
file: fs.File,
mode: Mode = Mode.default,

pub fn init(file: fs.File, mode: Mode) Self {
    return .{
        .interface = .{ .read = read, .write = write, .size = size },
        .file = file,
        .mode = mode,
    };
}

pub fn read(collection: *Collection, index: usize, buffer: Vector.Vec) anyerror!usize {
    const self: *Self = @fieldParentPtr("interface", collection);
    return switch (self.mode) {
        .read => |operation| switch (operation) {
            .positional => |_| self.readPositional(index, buffer) catch return error.ReadFailed,
            .streaming => |_| self.readStreaming(index, buffer) catch return error.ReadFailed,
            .failure => error.ReadFailed,
        },
        else => unreachable,
    };
}

pub fn readPositional(self: *Self, index: usize, buffer: Vector.Vec) anyerror!usize {
    const buffered: usize = self.file.pread(buffer, index) catch |err| switch (err) {
        error.Unseekable => {
            self.mode = self.mode.toStreaming();

            if (index != 0) {
                _ = self.seekTo(@intCast(index)) catch {
                    self.mode = self.mode.toFailure();
                    return error.ReadFailed;
                };
            }
            return 0;
        },
        else => return error.ReadFailed,
    };

    if (buffered == 0) return error.EndOfStream;
    return buffered;
}

pub fn readStreaming(self: *Self, index: usize, buffer: Vector.Vec) anyerror!usize {
    _ = try self.seekTo(index);
    const buffered = self.file.read(buffer) catch return error.ReadFailed;
    if (buffered == 0) return error.EndOfStream;
    return buffered;
}

pub fn write(collection: *Collection, index: usize, buffer: Vector.Vec) anyerror!*Collection {
    const self: *Self = @fieldParentPtr("interface", collection);

    switch (self.mode) {
        .write => |operation| switch (operation) {
            .positional => |_| if (buffer.len != 0) {
                _ = try self.writePositional(index, buffer);
            },
            .streaming => |_| if (buffer.len != 0) {
                _ = try self.writeStreaming(index, buffer);
            },
            .failure => return error.WriteFailed,
        },
        else => unreachable,
    }

    return collection;
}

pub fn writePositional(self: *Self, index: usize, buffer: []const u8) anyerror!*Self {
    if (buffer.len == 0) return self;
    const handle = self.file.handle;

    if (is_windows) {
        _ = windows.WriteFile(handle, buffer, index) catch return error.CommitFailed;
        return self;
    }

    _ = std.posix.pwrite(handle, buffer, index) catch |err| switch (err) {
        error.Unseekable => {
            self.mode = self.mode.toStreaming();
            if (index != 0) return error.CommitFailed;
            return self;
        },
        else => return error.CommitFailed,
    };

    return self;
}

pub fn writeStreaming(self: *Self, index: usize, buffer: []const u8) anyerror!*Self {
    _ = try self.seekTo(@bitCast(index));
    if (buffer.len == 0) return self;
    const handle = self.file.handle;

    if (is_windows) {
        _ = windows.WriteFile(handle, buffer, null) catch return error.WriteFailed;
    } else _ = std.posix.write(handle, buffer) catch return error.CommitFailed;

    return self;
}

pub fn seekTo(self: *Self, index: usize) anyerror!*Self {
    return switch (self.mode) {
        .read, .write => |operation| switch (operation) {
            .positional => unreachable,
            .streaming => |_| s: {
                try posix.lseek_SET(self.file.handle, @bitCast(index));
                break :s self;
            },
            .failure => posix.SeekError.Unseekable,
        },
    };
}

pub fn getSize(self: *Self) anyerror!usize {
    var collection = &self.interface;
    return @bitCast(try collection.size(&self.interface));
}

pub fn size(collection: *Collection) anyerror!usize {
    const self: *Self = @fieldParentPtr("interface", collection);
    if (is_windows) return if (windows.GetFileSizeEx(self.file.handle)) |s| @truncate(s) else |err| err;
    if (posix.Stat == void) return error.Streaming;

    if (self.file.stat()) |stat| {
        if (stat.kind == .file) return stat.size else {
            self.mode = self.mode.toStreaming();
            return error.Streaming;
        }
    } else |err| return err;
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

test Self {
    const Operation = Mode.Operation;
    const operations = [2]Mode.Operation{ Operation.streaming, Operation.positional };
    for (operations) |op| try testFile(op);
}

fn testFile(operation: Mode.Operation) !void {
    const Iterator = it.Iterator(Value, State);

    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();
    var file = try tmp_dir.dir.createFile("hello", .{ .read = true });
    defer file.close();

    const slice = "hello";

    var buffer: [slice.len]u8 = undefined;
    var writable_vector = Vector.init(&buffer);
    var collection = init(file, .{ .write = operation });
    var writable_file = Buffered.init(&collection.interface, &writable_vector.interface, .write);
    var writable_file_ib = Iterable.init(&writable_file.interface);
    var writable_file_interface = Iterator.Writable.Default.init(&writable_file_ib);
    var writable_iter = Iterator.Writable.This.init(&writable_file_interface.interface);

    for (slice) |char| _ = try writable_iter.current(char);
    try testing.expectEqualStrings(slice, &buffer);

    _ = try writable_file.write();

    const stat = try file.stat();
    try testing.expectEqual(slice.len, stat.size);

    var readable_vector = Vector.init(&buffer);
    collection = init(file, .{ .read = operation });
    var readable_file = Buffered.init(&collection.interface, &readable_vector.interface, .read);
    var readable_file_ib = Iterable.init(&readable_file.interface);
    var readable_file_interface = Iterator.Readable.Default.init(&readable_file_ib);
    var readable_iter = Iterator.Readable.This.init(&readable_file_interface.interface);

    var iterated: [slice.len]u8 = undefined;

    var i: usize = 0;
    while (try readable_iter.current()) |char| {
        iterated[i] = char;
        i += 1;
    }

    try testing.expectEqualStrings(slice, &iterated);
}
