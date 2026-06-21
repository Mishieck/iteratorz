const std = @import("std");
const testing = std.testing;

pub fn Iterator(Value: type, State: type) type {
    return struct {
        pub const ValueType = Value;
        pub const StateType = State;

        pub const Readable = struct {
            const Self = @This();

            pub const Interface = struct {
                const It = @This();

                previous: *const fn (iterator: *It) anyerror!?Value,
                current: *const fn (iterator: *It) anyerror!?Value,
                next: *const fn (iterator: *It) anyerror!?Value,
                at: *const fn (iterator: *It, state: State) anyerror!?Value,
                getState: *const fn (iterator: *It) anyerror!State,
                setState: *const fn (iterator: *It, state: State) anyerror!*It,
                setInitialState: *const fn (iterator: *It) anyerror!*It,
                setFinalState: *const fn (iterator: *It) anyerror!*It,
            };

            interface: *Interface,

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

            pub inline fn to(self: *Self, Other: type) @typeInfo(@TypeOf(Other.from)).@"fn".return_type.? {
                return Other.from(self.interface);
            }
        };

        pub const Writable = struct {
            const Self = @This();

            pub const Interface = struct {
                const It = @This();

                previous: *const fn (iterator: *It, value: Value) anyerror!?*It,
                current: *const fn (iterator: *It, value: Value) anyerror!?*It,
                next: *const fn (iterator: *It, value: Value) anyerror!?*It,
                at: *const fn (iterator: *It, state: State, value: Value) anyerror!?*It,
                getState: *const fn (iterator: *It) anyerror!State,
                setState: *const fn (iterator: *It, state: State) anyerror!*It,
                setInitialState: *const fn (iterator: *It) anyerror!*It,
                setFinalState: *const fn (iterator: *It) anyerror!*It,
                commit: *const fn (iterator: *It) anyerror!*It,
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

            pub fn commit(self: *Self) anyerror!*Self {
                _ = try self.interface.commit(self.interface);
                return self;
            }

            pub inline fn to(self: *Self, Other: type) @typeInfo(@TypeOf(Other.from)).@"fn".return_type.? {
                return Other.from(self.interface);
            }
        };
    };
}

test Iterator {
    _ = Iterator(u8, usize);
}
