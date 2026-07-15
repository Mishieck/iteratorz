const std = @import("std");
const debug = std.debug;
const testing = std.testing;

const ib = @import("iterable.zig");
const it = @import("iterator.zig");
const vec = @import("vector.zig");

pub fn Iterator(Value: type, comptime size: anytype) type {
    return struct {
        const Size = @TypeOf(size);
        pub const ValueType = Value;
        pub const StateType = ScIb.StateType;

        const ScIb = Iterable(Value, size);
        const Ib = ib.Iterable(Value, StateType);

        pub const Readable = struct {
            const It = it.Iterator(Value, StateType).Readable;

            pub inline fn init() It.This {
                return It.This.init(
                    @constCast(&It.Default.init(@constCast(&ScIb.init().interface)).interface),
                );
            }
        };

        pub const Writable = struct {
            const It = it.Iterator(Value, StateType).Writable;

            pub inline fn init() It.This {
                var iterable = Ib.init(@constCast(&ScIb.init().interface));
                var default = It.Default.init(&iterable);
                return It.This.init(&default.interface);
            }
        };
    };
}

test Iterator {
    const U2 = Iterator(u2, 4);
    const S = U2.StateType;
    var scalar = U2.Readable.init();

    for (0..4) |i| {
        const value = try scalar.current();
        try testing.expect(value != null);
        try testing.expectEqual(i, value.?);
    }

    try testing.expectEqualDeep(S.overflow, try scalar.getState());
    _ = try scalar.setInitialState();
    try testing.expectEqual(null, try scalar.previous());
    try testing.expectEqual(S.underflow, scalar.getState());
}

pub fn Iterable(Value: type, comptime size: u16) type {
    return struct {
        const Self = @This();
        pub const ValueType = Value;
        pub const StateType = State(Value, size);

        pub const Interface = ib.Iterable(Value, StateType).Interface;

        interface: Interface,
        state: StateType = .initial,

        pub fn init() Self {
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
            };
        }

        pub fn getValue(iterable: *Interface) anyerror!Value {
            const self: *Self = @fieldParentPtr("interface", iterable);
            return self.state.valid;
        }

        pub fn setValue(iterable: *Interface, value: Value) anyerror!*Interface {
            var self: *Self = @fieldParentPtr("interface", iterable);
            self.state = .{ .valid = value };
            return iterable;
        }

        pub fn getState(iterable: *Interface) anyerror!StateType {
            const self: *Self = @fieldParentPtr("interface", iterable);
            return self.state;
        }

        pub fn setState(iterable: *Interface, state: StateType) anyerror!*Interface {
            var self: *Self = @fieldParentPtr("interface", iterable);
            self.state = state;
            switch (state) {
                .valid => |_| {},
                else => return error.InvalidState,
            }
            return iterable;
        }

        pub fn setNextState(iterable: *Interface) anyerror!*Interface {
            var self: *Self = @fieldParentPtr("interface", iterable);
            self.state = self.state.getNext();
            if (self.state == StateType.overflow) return error.InvalidState;
            return iterable;
        }

        pub fn setPreviousState(iterable: *Interface) anyerror!*Interface {
            var self: *Self = @fieldParentPtr("interface", iterable);
            self.state = self.state.getPrevious();
            if (self.state == StateType.underflow) return error.InvalidState;
            return iterable;
        }

        pub fn setInitialState(iterable: *Interface) anyerror!*Interface {
            var self: *Self = @fieldParentPtr("interface", iterable);
            self.state = StateType.initial;
            return iterable;
        }

        pub fn setFinalState(iterable: *Interface) anyerror!*Interface {
            var self: *Self = @fieldParentPtr("interface", iterable);
            self.state = StateType.final;
            return iterable;
        }

        pub fn isStateValid(iterable: *Interface) anyerror!bool {
            const self: *Self = @fieldParentPtr("interface", iterable);
            return switch (self.state) {
                .valid => |_| true,
                else => false,
            };
        }
    };
}

test Iterable {
    const U2 = Iterable(u2, 4);
    const S = U2.StateType;
    var scalar = U2.init();

    try testing.expectEqual(0, scalar.interface.getValue(&scalar.interface));
    try testing.expectEqualDeep(S{ .valid = 0 }, try scalar.interface.getState(&scalar.interface));

    for (0..4) |i| {
        try testing.expect(try scalar.interface.isStateValid(&scalar.interface));
        try testing.expectEqualDeep(i, try scalar.interface.getValue(&scalar.interface));
        try testing.expectEqualDeep(
            S{ .valid = @truncate(i) },
            try scalar.interface.getState(&scalar.interface),
        );
        _ = scalar.interface.setNextState(&scalar.interface) catch |err| {
            if (err != error.InvalidState) return err;
        };
    }

    try testing.expectEqualDeep(S.overflow, try scalar.interface.getState(&scalar.interface));

    _ = try scalar.interface.setInitialState(&scalar.interface);
    _ = scalar.interface.setPreviousState(&scalar.interface) catch |err| {
        if (err != error.InvalidState) return err;
    };
    try testing.expectEqualDeep(S.underflow, try scalar.interface.getState(&scalar.interface));
}

pub fn typeToState(Type: type) type {
    return State(Type, @as(u16, ~@as(Type, 0)) + 1);
}

test typeToState {
    const S = typeToState(u2);
    try testing.expectEqual(3, S.maximum);
}

/// State of a scalar. The scalar has valid and invalid values. Valid values
/// range from the minimum value to the maximum value of the scalar. When the
/// value goes below the minimum value, the state becomes `underflow`. When
/// the value goes above the maximum value, the state becomes `overflow`.
pub fn State(Value: type, comptime size: anytype) type {
    return union(enum) {
        const Self = @This();

        underflow,
        valid: Value,
        overflow,

        pub const minimum = 0;
        pub const maximum = size - 1;
        pub const initial = Self{ .valid = minimum };
        pub const final = Self{ .valid = maximum };

        pub fn next(self: anytype) if (@TypeOf(self) == *Self) *Self else Self {
            return if (@TypeOf(self) == *Self) self.setNext() else self.getNext();
        }

        pub fn getNext(self: *const Self) Self {
            return switch (self.*) {
                .underflow => initial,
                .valid => |value| if (value == maximum) .overflow else .{ .valid = value + 1 },
                .overflow => .overflow,
            };
        }

        pub fn setNext(self: *Self) *Self {
            self.* = self.getNext();
            return self;
        }

        pub fn previous(self: anytype) if (@TypeOf(self) == *Self) *Self else Self {
            return if (@TypeOf(self) == *Self) self.setPrevious() else self.getPrevious();
        }

        pub fn getPrevious(self: *const Self) Self {
            return switch (self.*) {
                .underflow => .underflow,
                .valid => |value| if (value == minimum) .underflow else .{ .valid = value - 1 },
                .overflow => final,
            };
        }

        pub fn setPrevious(self: *Self) *Self {
            self.* = self.getPrevious();
            return self;
        }

        pub fn setInitial(self: *Self) *Self {
            self.* = initial;
            return self;
        }

        pub fn setFinal(self: *Self) *Self {
            self.* = final;
            return self;
        }

        pub fn isValid(self: *const Self) bool {
            return switch (self.*) {
                .valid => |_| true,
                else => false,
            };
        }
    };
}

test State {
    const U2 = State(u2, 4);
    var state: U2 = .underflow;

    var i: u2 = 0;
    while (i < 3) {
        _ = state.setNext();
        try testing.expect(state.isValid());
        try testing.expectEqualDeep(i, state.valid);
        i += 1;
    }

    try testing.expectEqualDeep(U2.final, state.setNext().*);
    try testing.expectEqualDeep(U2.overflow, state.setNext().*);

    while (i > 0) {
        _ = state.setPrevious();
        try testing.expect(state.isValid());
        try testing.expectEqualDeep(i, state.valid);
        i -= 1;
    }

    try testing.expectEqualDeep(U2.initial, state.setPrevious().*);
    try testing.expectEqualDeep(U2.underflow, state.setPrevious().*);

    const s = U2{ .valid = 1 };
    var sp = @constCast(&s);

    try testing.expectEqualDeep(U2{ .valid = 2 }, s.next());
    try testing.expectEqualDeep(U2{ .valid = 0 }, s.previous());
    try testing.expectEqualDeep(U2{ .valid = 2 }, sp.next().*);
    try testing.expectEqualDeep(U2{ .valid = 1 }, sp.previous().*);
}
