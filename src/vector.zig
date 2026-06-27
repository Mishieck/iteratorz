const std = @import("std");
const testing = std.testing;
const ib = @import("iterable.zig");
const it = @import("iterator.zig");

pub fn Vector(Value: type) type {
    return struct {
        const Self = @This();
        pub const ValueType = Value;
        pub const StateType = State;

        pub const Interface = ib.Iterable(Value, State).Interface;
        pub const Vec = []Value;

        interface: Interface,
        vector: Vec,
        index: State = .{ .valid = 0 },

        pub fn init(vector: Vec) Self {
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
                .vector = vector,
            };
        }

        pub fn getValue(iterable: *Interface) anyerror!Value {
            const self: *Self = @fieldParentPtr("interface", iterable);
            return self.vector[self.index.valid];
        }

        pub fn setValue(iterable: *Interface, value: Value) anyerror!*Interface {
            var self: *Self = @fieldParentPtr("interface", iterable);
            self.vector[self.index.valid] = value;
            return iterable;
        }

        pub fn getState(iterable: *Interface) anyerror!State {
            const self: *Self = @fieldParentPtr("interface", iterable);
            return self.index;
        }

        pub fn setState(iterable: *Interface, index: State) anyerror!*Interface {
            var self: *Self = @fieldParentPtr("interface", iterable);
            self.index = switch (index) {
                .valid => |v| if (v < self.vector.len) index else return error.InvalidState,
                else => index,
            };
            return iterable;
        }

        pub fn setNextState(iterable: *Interface) anyerror!*Interface {
            const self: *Self = @fieldParentPtr("interface", iterable);
            self.index = switch (self.index) {
                .underflow => .{ .valid = 0 },
                .valid => |index| valid: {
                    const value, const overflow = @addWithOverflow(index, 1);
                    const has_overflowed = overflow == 1 or value == self.vector.len;
                    break :valid if (has_overflowed) .overflow else .{ .valid = value };
                },
                .overflow => .overflow,
            };
            return iterable;
        }

        pub fn setPreviousState(iterable: *Interface) anyerror!*Interface {
            var self: *Self = @fieldParentPtr("interface", iterable);
            self.index = switch (self.index) {
                .underflow => .underflow,
                .valid => |index| if (index == 0) .underflow else .{ .valid = index - 1 },
                .overflow => if (self.vector.len == 0) .overflow else .{ .valid = self.vector.len - 1 },
            };
            return iterable;
        }

        pub fn setInitialState(iterable: *Interface) anyerror!*Interface {
            var self: *Self = @fieldParentPtr("interface", iterable);
            self.index = if (self.vector.len > 0) .{ .valid = 0 } else .overflow;
            return iterable;
        }

        pub fn setFinalState(iterable: *Interface) anyerror!*Interface {
            var self: *Self = @fieldParentPtr("interface", iterable);
            self.index = if (self.vector.len > 0) .{ .valid = self.vector.len - 1 } else .overflow;
            return iterable;
        }

        pub fn isStateValid(iterable: *Interface) anyerror!bool {
            const self: *Self = @fieldParentPtr("interface", iterable);
            return switch (self.index) {
                .valid => |_| true,
                else => false,
            };
        }

        pub fn written(self: *const Self) []const u8 {
            return self.vector[0..self.index.valid];
        }
    };
}

test Vector {
    const Bytes = Vector(u8);
    const Iterable = ib.Iterable(u8, State);
    const Iterator = it.Iterator(Bytes.ValueType, Bytes.StateType);

    const slice: []u8 = @constCast("hello");

    var readable_bytes = Bytes.init(slice);
    var readable_ib = Iterable.init(&readable_bytes.interface);
    var readable_interface = Iterator.Readable.Default.init(&readable_ib);
    var readable_iter = Iterator.Readable.This.init(&readable_interface.interface);
    var iterated: [slice.len]u8 = undefined;

    var i: usize = 0;
    while (try readable_iter.current()) |char| {
        iterated[i] = char;
        i += 1;
    }

    try testing.expectEqualStrings(slice, &iterated);

    var buffer: [slice.len]u8 = undefined;
    var writable_bytes = Bytes.init(&buffer);
    var writable_ib = Iterable.init(&writable_bytes.interface);
    var writable_interface = Iterator.Writable.Default.init(&writable_ib);
    var writable_iter = Iterator.Writable.This.init(&writable_interface.interface);

    for (slice) |char| _ = try writable_iter.current(char);
    try testing.expectEqualStrings(slice, &buffer);
}

pub const State = union(enum) {
    underflow,
    valid: usize,
    overflow,
};
