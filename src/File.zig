const std = @import("std");

const builtin = @import("builtin");
const Os = std.builtin.Os;
const native_os = builtin.os.tag;
const is_windows = native_os == .windows;
const debug = std.debug;

const File = @This();
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

const Self = @This();
pub const Value = u8;

pub const Iterable = ib.Iterable(Value, State);
pub const Interface = Iterable.Interface;
pub const Vector = vec.Vector(Value);
pub const State = vec.State;

const max_buffers_len = 16;

interface: Iterable.Interface,
file: fs.File,
file_size: ?u64 = null,
buffer: Iterable,
buffered_size: u64 = 0,
mode: Mode = Mode.default,
index: State = .{ .valid = 0 },

pub fn init(file: fs.File, buffer: *Interface, mode: Mode) Self {
    return .{
        .interface = .{
            .getValue = getValue,
            .setValue = setValue,
            .getState = getState,
            .setState = setState,
            .setNextState = setNextState,
            .setPreviousState = setPreviousState,
            .setInitialState = setInitialState,
            .setFinalState = setFinalState,
            .isStateValid = isStateValid,
        },
        .file = file,
        .mode = mode,
        .buffer = .init(buffer),
    };
}

pub fn getValue(iterable: *Interface) anyerror!Value {
    const self: *Self = @fieldParentPtr("interface", iterable);
    if (self.buffered_size == 0) _ = try self.read();
    return self.buffer.getValue();
}

pub fn setValue(iterable: *Interface, value: Value) anyerror!*Interface {
    var self: *Self = @fieldParentPtr("interface", iterable);
    _ = try self.buffer.setValue(value);
    return iterable;
}

pub fn getState(iterable: *Interface) anyerror!State {
    const self: *Self = @fieldParentPtr("interface", iterable);
    return switch (self.index) {
        .valid => |index| .{ .valid = index + self.vector().index.valid },
        else => self.index,
    };
}

pub fn setState(iterable: *Interface, index: State) anyerror!*Interface {
    var self: *Self = @fieldParentPtr("interface", iterable);
    switch (index) {
        .valid => |i| {
            switch (self.mode) {
                .read => |_| {
                    const file_size = try self.getSize();

                    if (i < file_size) {
                        self.index = index;
                        _ = try self.read();
                    } else return error.InvalidState;
                },
                .write => |_| {
                    _ = try self.write();
                    self.index = index;
                },
            }
        },
        else => {
            self.index = index;
            return error.InvalidState;
        },
    }

    return iterable;
}

pub fn setPreviousState(iterable: *Interface) anyerror!*Interface {
    var self: *Self = @fieldParentPtr("interface", iterable);

    switch (self.index) {
        .underflow => self.index = .underflow,
        .valid => |index| {
            const new_index, const underflow = @subWithOverflow(index, 1);
            const underflowed = underflow == 1;

            switch (self.mode) {
                .read => |_| {
                    if (underflowed) {
                        _ = try self.buffer.setInitialState();
                        self.index = .underflow;
                    } else if (self.buffered_size > 0) {
                        _ = self.buffer.setPreviousState() catch |err| switch (err) {
                            error.InvalidState => _ = try iterable.setState(
                                iterable,
                                .{ .valid = new_index },
                            ),
                            else => return err,
                        };
                    } else {
                        self.index = .{ .valid = new_index };
                        _ = try self.read();
                    }
                },
                .write => |_| {
                    if (underflowed) {
                        _ = try self.write();
                        self.index = .underflow;
                    } else if (self.buffered_size > 0) {
                        _ = self.buffer.setPreviousState() catch |err| switch (err) {
                            error.InvalidState => _ = try iterable.setState(
                                iterable,
                                .{ .valid = new_index },
                            ),
                            else => return err,
                        };
                    } else {
                        self.index = .{ .valid = new_index };
                    }
                },
            }
        },
        .overflow => _ = try iterable.setState(iterable, .{ .valid = self.index.valid - 1 }),
    }

    return iterable;
}

pub fn setNextState(iterable: *Interface) anyerror!*Interface {
    const self: *Self = @fieldParentPtr("interface", iterable);

    switch (self.index) {
        .underflow => _ = try iterable.setState(iterable, .{ .valid = 0 }),
        .valid => |index| {
            const new_index, const overflow = @addWithOverflow(index + self.vector().index.valid, 1);
            var overflowed = overflow == 1;

            switch (self.mode) {
                .read => |_| {
                    const file_size = try self.getSize();
                    overflowed = overflowed or new_index == file_size;

                    if (overflowed) {
                        _ = try self.buffer.setInitialState();
                        self.index = .overflow;
                        return error.InvalidState;
                    } else if (self.buffered_size > 0) {
                        switch (new_index < index + self.buffered_size) {
                            true => _ = try self.buffer.setNextState(),
                            false => {
                                self.index = .{ .valid = new_index };
                                _ = try self.read();
                            },
                        }
                    } else {
                        _ = try self.read();
                    }
                },
                .write => |_| {
                    if (overflowed) {
                        _ = try self.write();
                        self.index = .overflow;
                        return error.InvalidState;
                    } else {
                        _ = self.buffer.setNextState() catch |err| switch (err) {
                            error.InvalidState => _ = try self.write(),
                            else => return err,
                        };
                    }
                },
            }
        },
        .overflow => self.index = .overflow,
    }

    return iterable;
}

pub fn setInitialState(iterable: *Interface) anyerror!*Interface {
    return iterable.setState(iterable, .{ .valid = 0 });
}

pub fn setFinalState(iterable: *Interface) anyerror!*Interface {
    var self: *Self = @fieldParentPtr("interface", iterable);
    const file_size = try self.getSize();
    return iterable.setState(iterable, .{ .valid = file_size -| 1 });
}

pub fn isStateValid(iterable: *Interface) anyerror!bool {
    const self: *Self = @fieldParentPtr("interface", iterable);
    return switch (self.index) {
        .valid => |_| true,
        else => false,
    };
}

pub fn read(self: *Self) std.Io.Reader.Error!*Self {
    return switch (self.mode) {
        .read => |operation| switch (operation) {
            .positional => |_| readPositional(self) catch return error.ReadFailed,
            .streaming => |_| readStreaming(self) catch return error.ReadFailed,
            .failure => error.ReadFailed,
        },
        else => unreachable,
    };
}

pub fn readPositional(self: *Self) std.Io.Reader.Error!*Self {
    const index = self.index.valid;
    const size: usize = self.file.pread(self.vector().vector, index) catch |err| switch (err) {
        error.Unseekable => {
            self.mode = self.mode.toStreaming();

            if (index != 0) {
                self.index = .{ .valid = 0 };
                _ = self.seekBy(@intCast(index)) catch {
                    self.mode = self.mode.toFailure();
                    return error.ReadFailed;
                };
            }
            return self;
        },
        else => return error.ReadFailed,
    };

    if (size == 0) {
        self.file_size = self.index.valid;
        return error.EndOfStream;
    }
    self.buffered_size = size;
    return self;
}

pub fn readStreaming(self: *Self) anyerror!*Self {
    _ = try self.seekTo(self.index.valid);
    const size = self.file.read(self.vector().vector) catch return error.ReadFailed;
    if (size == 0) {
        self.file_size = self.index.valid;
        return error.EndOfStream;
    }
    self.buffered_size = size;
    return self;
}

pub fn write(self: *Self) anyerror!*Self {
    const buffered = self.vector().vector;

    return switch (self.mode) {
        .write => |operation| switch (operation) {
            .positional => |_| if (buffered.len != 0) try self.writePositional(buffered) else self,
            .streaming => |_| if (buffered.len != 0) try self.writeStreaming(buffered) else self,
            .failure => return error.WriteFailed,
        },
        else => unreachable,
    };
}

pub fn vector(self: *Self) Vector {
    const v: *Vector = @fieldParentPtr("interface", self.buffer.interface);
    return v.*;
}

pub fn writePositional(self: *Self, buffered: []const u8) anyerror!*Self {
    if (buffered.len == 0) return self;
    const handle = self.file.handle;

    if (is_windows) {
        const size = windows.WriteFile(handle, buffered, self.index.valid) catch {
            return error.CommitFailed;
        };
        self.index = .{ .valid = self.index.valid + size - 1 };
        _ = try self.buffer.setInitialState();
        return self;
    }

    const size = std.posix.pwrite(handle, buffered, self.index.valid) catch |err| switch (err) {
        error.Unseekable => {
            self.mode = self.mode.toStreaming();
            const index = self.index.valid;
            if (index != 0) {
                self.index = .{ .valid = 0 };
                _ = self.seekTo(@intCast(index)) catch {
                    self.mode = self.mode.toFailure();
                    return error.CommitFailed;
                };
            }
            return self;
        },
        else => return error.CommitFailed,
    };
    self.index = .{ .valid = self.index.valid + size - 1 };
    _ = try self.buffer.setInitialState();
    return self;
}

pub fn writeStreaming(self: *Self, buffered: []const u8) anyerror!*Self {
    if (buffered.len == 0) return self;
    const handle = self.file.handle;

    if (is_windows) {
        const size = windows.WriteFile(handle, buffered, null) catch return error.WriteFailed;
        self.index = .{ .valid = self.index.valid + size - 1 };
        _ = try self.buffer.setInitialState();
        return self;
    }

    const size = std.posix.write(handle, buffered) catch return error.CommitFailed;
    self.index = .{ .valid = self.index.valid + size - 1 };
    _ = try self.buffer.setInitialState();
    return self;
}

pub fn seekBy(self: *Self, offset: i64) anyerror!*Self {
    var iterable = &self.interface;
    const index = self.index.valid;

    switch (self.mode) {
        .read, .write => |operation| switch (operation) {
            .positional => |_| {
                _ = try self.setPosAdjustingBuffer(
                    @intCast(@as(i64, @as(i64, @bitCast(index)) + offset)),
                );
            },
            .streaming => |_| {
                if (posix.SEEK == void) return error.Unseekable;

                const seek_err = e: {
                    if (posix.lseek_CUR(self.file.handle, offset)) |_| {
                        _ = try self.setPosAdjustingBuffer(
                            @intCast(@as(i64, @as(i64, @bitCast(index)) + offset)),
                        );
                        return self;
                    } else |err| break :e err;
                };
                var remaining = std.math.cast(u64, offset) orelse return seek_err;
                while (remaining > 0) {
                    remaining -= try self.discard(.limited64(remaining));
                }
                _ = try iterable.setInitialState(iterable);
            },
            .failure => return error.Unseekable,
        },
    }

    return self;
}

fn setPosAdjustingBuffer(self: *Self, offset: u64) anyerror!*Self {
    var iterable = &self.interface;
    const logical_pos = (try iterable.getState(iterable)).valid;
    if (offset < logical_pos or offset >= self.index.valid) {
        _ = try iterable.setInitialState(iterable);
        self.index = .{ .valid = offset };
    } else {
        const logical_delta: usize = @intCast(offset - logical_pos);
        _ = try iterable.setState(iterable, .{ .valid = self.index.valid + logical_delta });
    }

    return self;
}

pub fn seekTo(self: *Self, index: u64) anyerror!*Self {
    return switch (self.mode) {
        .read, .write => |operation| switch (operation) {
            .positional => |_| p: {
                self.index = .{ .valid = index };
                break :p self;
            },
            .streaming => |_| s: {
                try posix.lseek_SET(self.file.handle, index);
                self.index = .{ .valid = index };
                break :s self;
            },
            .failure => posix.SeekError.Unseekable,
        },
    };
}

fn discard(self: *Self, limit: std.Io.Limit) anyerror!usize {
    const file = self.file;
    const pos = self.index.valid;
    switch (self.mode) {
        .read, .write => |operation| switch (operation) {
            .positional => |_| {
                const size = self.getSize() catch {
                    self.mode = self.mode.toStreaming();
                    return 0;
                };
                const delta = @min(@intFromEnum(limit), size - pos);
                self.index = .{ .valid = pos + delta };
                return delta;
            },
            .streaming => |_| {
                const size = self.getSize() catch return 0;
                const n = @min(size - pos, maxInt(i64), @intFromEnum(limit));
                file.seekBy(n) catch return 0;
                self.index = .{ .valid = pos + n - 1 };
                return n;
            },
            .failure => return error.ReadFailed,
        },
    }
}

pub fn getSize(self: *Self) anyerror!u64 {
    if (self.file_size) |size| if (std.meta.activeTag(self.mode) == .read) return size;

    if (is_windows) {
        if (windows.GetFileSizeEx(self.file.handle)) |size| {
            self.file_size = size;
            return size;
        } else |err| return err;
    }

    if (posix.Stat == void) return error.Streaming;

    if (self.file.stat()) |stat| {
        if (stat.kind == .file) {
            self.file_size = stat.size;
            return stat.size;
        } else {
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
    var writable_file = init(file, &writable_vector.interface, .{ .write = operation });
    var writable_file_ib = Iterable.init(&writable_file.interface);
    var writable_file_interface = Iterator.Writable.Default.init(&writable_file_ib);
    var writable_iter = Iterator.Writable.This.init(&writable_file_interface.interface);

    for (slice) |char| _ = try writable_iter.current(char);
    try testing.expectEqualStrings(slice, &buffer);

    _ = try writable_file.write();

    const stat = try file.stat();
    try testing.expectEqual(slice.len, stat.size);

    var readable_vector = Vector.init(&buffer);
    var readable_file = init(file, &readable_vector.interface, .{ .read = operation });
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
