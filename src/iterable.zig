const std = @import("std");
const testing = std.testing;

pub fn Iterable(Value: type, State: type) type {
    return struct {
        const Self = @This();

        pub const Interface = struct {
            const It = @This();

            getValue: *const fn (iterable: *It) anyerror!Value,
            setValue: *const fn (iterable: *It, value: Value) anyerror!*It,
            getState: *const fn (iterable: *It) anyerror!State,
            setState: *const fn (iterable: *It, state: State) anyerror!*It,
            setNextState: *const fn (iterable: *It) anyerror!*It,
            setPreviousState: *const fn (iterable: *It) anyerror!*It,
            setInitialState: *const fn (iterable: *It) anyerror!*It,
            setFinalState: *const fn (iterable: *It) anyerror!*It,
            isStateValid: *const fn (iterable: *It) anyerror!bool,
            commit: *const fn (iterable: *It) anyerror!*It,
        };

        interface: *Interface,

        pub fn init(interface: *Interface) Self {
            return .{ .interface = interface };
        }

        pub fn getValue(self: *Self) anyerror!Value {
            return self.interface.getValue(self.interface);
        }

        pub fn setValue(self: *Self, value: Value) anyerror!*Self {
            _ = try self.interface.setValue(self.interface, value);
            return self;
        }

        pub fn getState(self: *Self) anyerror!State {
            return self.interface.getState(self.interface);
        }

        pub fn setState(self: *Self, state: State) anyerror!*Self {
            _ = try self.interface.setState(self.interface, state);
            return self;
        }

        pub fn setNextState(self: *Self) anyerror!*Self {
            _ = try self.interface.setNextState(self.interface);
            return self;
        }

        pub fn setPreviousState(self: *Self) anyerror!*Self {
            _ = try self.interface.setPreviousState(self.interface);
            return self;
        }

        pub fn setInitialState(self: *Self) anyerror!*Self {
            _ = try self.interface.setInitialState(self.interface);
            return self;
        }

        pub fn setFinalState(self: *Self) anyerror!*Self {
            _ = try self.interface.setFinalState(self.interface);
            return self;
        }

        pub fn isStateValid(self: *Self) anyerror!bool {
            return self.interface.isStateValid(self.interface);
        }

        pub fn commit(self: *Self) anyerror!*Self {
            _ = try self.interface.commit(self.interface);
            return self;
        }
    };
}

test Iterable {
    _ = Iterable(u8, usize);
}
