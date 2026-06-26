const std = @import("std");
const testing = std.testing;

pub fn Iterable(Value: type, State: type) type {
    return struct {
        const Self = @This();
        pub const ValueType = Value;

        /// The state of the iterable. The state value must have valid and
        /// invalid variants the state.
        pub const StateType = State;

        pub const Interface = struct {
            const It = @This();

            /// Gets a `value`. It is called when the state is valid. If the state
            /// is not valid, it panics or has incorrect behavior.
            getValue: *const fn (iterable: *It) anyerror!Value,

            /// Sets a `value`. It is called when the state is valid. If the state
            /// is not valid, it panics or has incorrect behavior.
            setValue: *const fn (iterable: *It, value: Value) anyerror!*It,

            /// Gets the `state`. The `state` may be invalid.
            getState: *const fn (iterable: *It) anyerror!State,

            /// Sets the `state`. The `state` may be invalid. If the `state` is
            /// invalid, it returns `error.InvalidState`.
            setState: *const fn (iterable: *It, state: State) anyerror!*It,

            /// Sets the next state. If the `state` is invalid, it returns
            /// error.InvalidState`.
            setNextState: *const fn (iterable: *It) anyerror!*It,

            /// Sets the previous state. If the `state` is invalid, it returns
            /// error.InvalidState`.
            setPreviousState: *const fn (iterable: *It) anyerror!*It,

            /// Sets the state to the initial value. The initial value must be
            /// a valid state.
            setInitialState: *const fn (iterable: *It) anyerror!*It,

            /// Sets the state to the final value. The final value must be a
            /// valid state. It
            setFinalState: *const fn (iterable: *It) anyerror!*It,

            /// Checks whether the state is valid or not.
            isStateValid: *const fn (iterable: *It) anyerror!bool,
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
    };
}

test Iterable {
    _ = Iterable(u8, usize);
}
