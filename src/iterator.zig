const std = @import("std");
const testing = std.testing;

pub fn Iterator(Value: type, State: type) type {
    return struct {
        pub const ValueType = Value;

        /// The state of the iterator. The state value must have valid and
        /// invalid variants the state.
        pub const StateType = State;

        pub const Readable = struct {
            const Self = @This();

            pub const Interface = struct {
                const It = @This();

                /// Gets the value at the previous state. It sets the state to
                /// the previous value before getting the `Value`, If the new
                /// state is invalid, it returns `null`.
                previous: *const fn (iterator: *It) anyerror!?Value,

                /// Gets the value at the current state. It sets the state to
                /// the next value after getting the `Value`. If the current
                /// state is invalid, it returns `null`.
                current: *const fn (iterator: *It) anyerror!?Value,

                /// Gets the value at the next state. It sets the state to the
                /// next value before getting the `Value`, If the new state is
                /// invalid, it returns `null`.
                next: *const fn (iterator: *It) anyerror!?Value,

                /// Gets the value at the given `state`. It sets the state to
                /// the next value after getting the `Value`. If the `state` is
                /// invalid, it returns null after setting the state.
                at: *const fn (iterator: *It, state: State) anyerror!?Value,

                /// Gets the current state. The returned `State` may be invalid.
                getState: *const fn (iterator: *It) anyerror!State,

                /// Sets the current state. If the `state` is invalid, it
                /// returns `error.InvalidState` after setting the state.
                setState: *const fn (iterator: *It, state: State) anyerror!*It,

                /// Sets the value of the state to the initial value.
                setInitialState: *const fn (iterator: *It) anyerror!*It,

                /// Sets the value of the state to the final value.
                setFinalState: *const fn (iterator: *It) anyerror!*It,
            };

            interface: *Interface,

            /// Creates an iterator from the interface of another iterator.
            pub inline fn from(int: *Interface) *Self {
                return @constCast(&Self.init(int));
            }

            pub fn init(interface: *Interface) Self {
                return .{ .interface = interface };
            }

            pub fn previous(self: *Self) anyerror!?Value {
                return self.interface.previous(self.interface);
            }

            pub fn current(self: *Self) anyerror!?Value {
                return self.interface.current(self.interface);
            }

            pub fn next(self: *Self) anyerror!?Value {
                return self.interface.next(self.interface);
            }

            pub fn at(self: *Self) anyerror!?Value {
                return self.interface.next(self.interface);
            }

            pub fn getState(self: *Self) anyerror!State {
                return self.interface.getState(self.interface);
            }

            pub fn setState(self: *Self, state: State) anyerror!State {
                return self.interface.setState(self.interface, state);
            }

            pub fn setInitialState(self: *Self) anyerror!*Self {
                _ = try self.interface.setInitialState(self.interface);
                return self;
            }

            pub fn setFinalState(self: *Self) anyerror!*Self {
                _ = try self.interface.setFinalState(self.interface);
                return self;
            }

            pub inline fn to(self: *Self, Other: type) *Infer(Other).Readable {
                return Other.from(self.interface);
            }
        };

        pub const Writable = struct {
            const Self = @This();

            pub const Interface = struct {
                const It = @This();

                /// Sets the value at the previous state. It sets the state to
                /// the previous value before setting the `Value`, If the new
                /// state is invalid, it returns `null`.
                previous: *const fn (iterator: *It, value: Value) anyerror!?*It,

                /// Sets the value at the current state. It sets the state to
                /// the next value after setting the `Value`. If the current
                /// state is invalid, it returns `null`.
                current: *const fn (iterator: *It, value: Value) anyerror!?*It,

                /// Sets the value at the next state. It sets the state to the
                /// next value before setting the `Value`, If the new state is
                /// invalid, it returns `null`.
                next: *const fn (iterator: *It, value: Value) anyerror!?*It,

                /// Sets the value at the given `state`. It sets the state to
                /// the next value after setting the `Value`. If the `state` is
                /// invalid, it returns null after setting the state.
                at: *const fn (iterator: *It, state: State, value: Value) anyerror!?*It,

                /// Gets the current state. The returned `State` may be invalid.
                getState: *const fn (iterator: *It) anyerror!State,

                /// Sets the current state. If the `state` is invalid, it
                /// returns `error.InvalidState` after setting the state.
                setState: *const fn (iterator: *It, state: State) anyerror!*It,

                /// Sets the value of the state to the initial value.
                setInitialState: *const fn (iterator: *It) anyerror!*It,

                /// Sets the value of the state to the final value.
                setFinalState: *const fn (iterator: *It) anyerror!*It,
            };

            interface: *Interface,

            pub inline fn from(int: *Interface) *Self {
                return @constCast(&Self.init(int));
            }

            pub fn init(interface: *Interface) Self {
                return .{ .interface = interface };
            }

            pub fn previous(self: *Self, value: Value) anyerror!?*Self {
                return if (try self.interface.previous(self.interface, value)) |_| self else null;
            }

            pub fn current(self: *Self, value: Value) anyerror!?*Self {
                return if (try self.interface.current(self.interface, value)) |_| self else null;
            }

            pub fn next(self: *Self, value: Value) anyerror!?*Self {
                return if (try self.interface.next(self.interface, value)) |_| self else null;
            }

            pub fn at(self: *Self, state: State, value: Value) anyerror!?*Self {
                return if (try self.interface.at(self.interface, state, value)) |_| self else null;
            }

            pub fn getState(self: *Self) anyerror!State {
                return self.interface.getState(self.interface);
            }

            pub fn setState(self: *Self, state: State) anyerror!State {
                return self.interface.setState(self.interface, state);
            }

            pub fn setInitialState(self: *Self) anyerror!*Self {
                _ = try self.interface.setInitialState(self.interface);
                return self;
            }

            pub fn setFinalState(self: *Self) anyerror!*Self {
                _ = try self.interface.setFinalState(self.interface);
                return self;
            }

            pub inline fn to(self: *Self, Other: type) *Infer(Other).Writable {
                return Other.from(self.interface);
            }
        };
    };
}

pub fn Infer(It: type) type {
    return Iterator(It.ValueType, It.StateType);
}

test Iterator {
    _ = Iterator(u8, usize);
}
