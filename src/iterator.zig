const std = @import("std");
const testing = std.testing;
const ib = @import("iterable.zig");
const it = @import("iterator.zig");

pub fn Iterator(Value: type, State: type) type {
    return struct {
        pub const ValueType = Value;
        pub const StateType = State;
        pub const Readable = ReadableIterator(Value, State);
        pub const Writable = WritableIterator(Value, State);
    };
}

test Iterator {
    _ = Iterator(u8, usize);
}

pub fn Infer(It: type) type {
    return Iterator(It.ValueType, It.StateType);
}

pub fn ReadableIterator(Value: type, State: type) type {
    return struct {
        const Iterable = ib.Iterable(Value, State);

        pub const Interface = struct {
            /// Gets the value at the previous state. It sets the state to
            /// the previous value before getting the `Value`, If the new
            /// state is invalid, it returns `null`.
            previous: *const fn (iterator: *Interface) anyerror!?Value,

            /// Gets the value at the current state. It sets the state to
            /// the next value after getting the `Value`. If the current
            /// state is invalid, it returns `null`.
            current: *const fn (iterator: *Interface) anyerror!?Value,

            /// Gets the value at the next state. It sets the state to the
            /// next value before getting the `Value`, If the new state is
            /// invalid, it returns `null`.
            next: *const fn (iterator: *Interface) anyerror!?Value,

            /// Gets the value at the given `state`. It sets the state to
            /// the next value after getting the `Value`. If the `state` is
            /// invalid, it returns null after setting the state.
            at: *const fn (iterator: *Interface, state: State) anyerror!?Value,

            /// Gets the current state. The returned `State` may be invalid.
            getState: *const fn (iterator: *Interface) anyerror!State,

            /// Sets the current state. If the `state` is invalid, it
            /// returns `error.InvalidState` after setting the state.
            setState: *const fn (iterator: *Interface, state: State) anyerror!*Interface,

            /// Sets the value of the state to the initial value.
            setInitialState: *const fn (iterator: *Interface) anyerror!*Interface,

            /// Sets the value of the state to the final value.
            setFinalState: *const fn (iterator: *Interface) anyerror!*Interface,
        };

        pub const Default = struct {
            const Self = @This();

            interface: Interface,
            iterable: *Iterable,

            pub fn init(iterable: *Iterable) Self {
                return .{
                    .interface = .{
                        .previous = previous,
                        .current = current,
                        .next = next,
                        .at = at,
                        .getState = getState,
                        .setState = setState,
                        .setInitialState = setInitialState,
                        .setFinalState = setFinalState,
                    },
                    .iterable = iterable,
                };
            }

            fn previous(iterator: *Interface) anyerror!?Value {
                var self: *Self = @fieldParentPtr("interface", iterator);
                _ = self.iterable.setPreviousState() catch |err| {
                    return if (err == error.InvalidState) null else err;
                };
                return try self.iterable.getValue();
            }

            fn current(iterator: *Interface) anyerror!?Value {
                var self: *Self = @fieldParentPtr("interface", iterator);
                if (!try self.iterable.isStateValid()) return null;
                const value = try self.iterable.getValue();
                _ = self.iterable.setNextState() catch |err| {
                    if (err != error.InvalidState) return err;
                };
                return value;
            }

            fn next(iterator: *Interface) anyerror!?Value {
                var self: *Self = @fieldParentPtr("interface", iterator);
                _ = self.iterable.setNextState() catch |err| {
                    return if (err == error.InvalidState) null else err;
                };
                const value = try self.iterable.getValue();
                return value;
            }

            fn at(iterator: *Interface, state: State) anyerror!?Value {
                var self: *Self = @fieldParentPtr("interface", iterator);
                _ = self.iterable.setState(state) catch |err| {
                    return if (err == error.InvalidState) null else err;
                };
                const value = try self.iterable.getValue();
                _ = self.iterable.setNextState() catch |err| {
                    if (err != error.InvalidState) return err;
                };
                return value;
            }

            fn getState(iterator: *Interface) anyerror!State {
                var self: *Self = @fieldParentPtr("interface", iterator);
                return self.iterable.getState();
            }

            fn setState(iterator: *Interface, state: State) anyerror!*Interface {
                var self: *Self = @fieldParentPtr("interface", iterator);
                _ = try self.iterable.setState(state);
                return iterator;
            }

            fn setInitialState(iterator: *Interface) anyerror!*Interface {
                var self: *Self = @fieldParentPtr("interface", iterator);
                _ = try self.iterable.setInitialState();
                return iterator;
            }

            fn setFinalState(iterator: *Interface) anyerror!*Interface {
                var self: *Self = @fieldParentPtr("interface", iterator);
                _ = try self.iterable.setFinalState();
                return iterator;
            }
        };

        pub const This = struct {
            const Self = @This();

            interface: *Interface,

            pub fn init(interface: *Interface) Self {
                return .{ .interface = interface };
            }

            pub fn previous(self: *Self) anyerror!?Value {
                return try self.interface.previous(self.interface);
            }

            pub fn current(self: *Self) anyerror!?Value {
                return self.interface.current(self.interface);
            }

            pub fn next(self: *Self) anyerror!?Value {
                return self.interface.next(self.interface);
            }

            pub fn at(self: *Self, state: State) anyerror!?Value {
                return self.interface.at(self.interface, state);
            }

            pub fn getState(self: *Self) anyerror!State {
                return self.interface.getState();
            }

            pub fn setState(self: *Self, state: State) anyerror!State {
                return self.interface.setState(self, state);
            }

            pub fn setInitialState(self: *Self) anyerror!*Self {
                _ = try self.interface.setInitialState(self);
                return self;
            }

            pub fn setFinalState(self: *Self) anyerror!*Self {
                _ = try self.interface.setFinalState(self);
                return self;
            }

            pub inline fn to(self: *Self, Other: type) *Infer(Other).Readable.This {
                return Other.from(self.interface);
            }
        };
    };
}

pub fn WritableIterator(Value: type, State: type) type {
    return struct {
        const Iterable = ib.Iterable(Value, State);

        pub const Interface = struct {
            /// Sets the value at the previous state. It sets the state to
            /// the previous value before setting the `Value`, If the new
            /// state is invalid, it returns `null`.
            previous: *const fn (iterator: *Interface, value: Value) anyerror!?*Interface,

            /// Sets the value at the current state. It sets the state to
            /// the next value after setting the `Value`. If the current
            /// state is invalid, it returns `null`.
            current: *const fn (iterator: *Interface, value: Value) anyerror!?*Interface,

            /// Sets the value at the next state. It sets the state to the
            /// next value before setting the `Value`, If the new state is
            /// invalid, it returns `null`.
            next: *const fn (iterator: *Interface, value: Value) anyerror!?*Interface,

            /// Sets the value at the given `state`. It sets the state to
            /// the next value after setting the `Value`. If the `state` is
            /// invalid, it returns null after setting the state.
            at: *const fn (iterator: *Interface, state: State, value: Value) anyerror!?*Interface,

            /// Gets the current state. The returned `State` may be invalid.
            getState: *const fn (iterator: *Interface) anyerror!State,

            /// Sets the current state. If the `state` is invalid, it
            /// returns `error.InvalidState` after setting the state.
            setState: *const fn (iterator: *Interface, state: State) anyerror!*Interface,

            /// Sets the value of the state to the initial value.
            setInitialState: *const fn (iterator: *Interface) anyerror!*Interface,

            /// Sets the value of the state to the final value.
            setFinalState: *const fn (iterator: *Interface) anyerror!*Interface,
        };

        pub const Default = struct {
            const Self = @This();

            interface: Interface,
            iterable: *Iterable,

            pub fn init(iterable: *Iterable) Self {
                return .{
                    .interface = .{
                        .previous = previous,
                        .current = current,
                        .next = next,
                        .at = at,
                        .getState = getState,
                        .setState = setState,
                        .setInitialState = setInitialState,
                        .setFinalState = setFinalState,
                    },
                    .iterable = iterable,
                };
            }

            fn previous(iterator: *Interface, value: Value) anyerror!?*Interface {
                var self: *Self = @fieldParentPtr("interface", iterator);
                _ = self.iterable.setPreviousState() catch |err| {
                    return if (err == error.InvalidState) null else err;
                };
                _ = try self.iterable.setValue(value);
                return iterator;
            }

            fn current(iterator: *Interface, value: Value) anyerror!?*Interface {
                var self: *Self = @fieldParentPtr("interface", iterator);
                if (!try self.iterable.isStateValid()) return null;
                _ = try self.iterable.setValue(value);
                _ = self.iterable.setNextState() catch |err| {
                    if (err != error.InvalidState) return err;
                };
                return iterator;
            }

            fn next(iterator: *Interface, value: Value) anyerror!?*Interface {
                var self: *Self = @fieldParentPtr("interface", iterator);
                _ = self.iterable.setNextState() catch |err| {
                    return if (err == error.InvalidState) null else err;
                };
                _ = try self.iterable.setValue(value);
                return iterator;
            }

            fn at(iterator: *Interface, state: State, value: Value) anyerror!?*Interface {
                var self: *Self = @fieldParentPtr("interface", iterator);
                _ = self.iterable.setState(state) catch |err| {
                    return if (err == error.InvalidState) null else err;
                };
                _ = try self.iterable.setValue(value);
                _ = self.iterable.setNextState() catch |err| {
                    if (err != error.InvalidState) return err;
                };
                return iterator;
            }

            fn getState(iterator: *Interface) anyerror!State {
                var self: *Self = @fieldParentPtr("interface", iterator);
                return self.iterable.getState();
            }

            fn setState(iterator: *Interface, state: State) anyerror!*Interface {
                var self: *Self = @fieldParentPtr("interface", iterator);
                _ = try self.iterable.setState(state);
                return iterator;
            }

            fn setInitialState(iterator: *Interface) anyerror!*Interface {
                var self: *Self = @fieldParentPtr("interface", iterator);
                _ = try self.iterable.setInitialState();
                return iterator;
            }

            fn setFinalState(iterator: *Interface) anyerror!*Interface {
                var self: *Self = @fieldParentPtr("interface", iterator);
                _ = try self.iterable.setFinalState();
                return iterator;
            }
        };

        pub const This = struct {
            const Self = @This();

            interface: *Interface,

            pub fn init(interface: *Interface) Self {
                return .{ .interface = interface };
            }

            pub fn previous(self: *Self, value: Value) anyerror!?*Self {
                _ = try self.interface.previous(self.interface, value);
                return self;
            }

            pub fn current(self: *Self, value: Value) anyerror!?*Self {
                _ = try self.interface.current(self.interface, value);
                return self;
            }

            pub fn next(self: *Self, value: Value) anyerror!?*Self {
                _ = try self.interface.next(self.interface, value);
                return self;
            }

            pub fn at(self: *Self, state: State, value: Value) anyerror!?*Self {
                _ = try self.interface.at(self.interface, state, value);
                return self;
            }

            pub fn getState(self: *Self) anyerror!State {
                return self.interface.getState(self);
            }

            pub fn setState(self: *Self, state: State) anyerror!State {
                return self.interface.setState(self, state);
            }

            pub fn setInitialState(self: *Self) anyerror!*Self {
                _ = try self.interface.setInitialState(self);
                return self;
            }

            pub fn setFinalState(self: *Self) anyerror!*Self {
                _ = try self.interface.setFinalState(self);
                return self;
            }

            pub inline fn to(self: *Self, Other: type) *Infer(Other).Writable.This {
                return Other.from(self.interface);
            }
        };
    };
}
