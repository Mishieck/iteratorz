const std = @import("std");
const testing = std.testing;
const ib = @import("iterable.zig");
const it = @import("iterator.zig");

pub fn IterableIterator(Value: type, State: type) type {
    return struct {
        const Iterator = it.Iterator(Value, State);
        const Iterable = ib.Iterable(Value, State);

        pub const Readable = struct {
            const Self = @This();
            const ReadableIterator = Iterator.Readable.Interface;

            interface: ReadableIterator,
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

            fn previous(iterator: *ReadableIterator) anyerror!?Value {
                var self: *Self = @fieldParentPtr("interface", iterator);
                _ = self.iterable.setPreviousState() catch |err| {
                    return if (err == error.InvalidState) null else err;
                };
                return try self.iterable.getValue();
            }

            fn current(iterator: *ReadableIterator) anyerror!?Value {
                var self: *Self = @fieldParentPtr("interface", iterator);
                if (!try self.iterable.isStateValid()) return null;
                const value = try self.iterable.getValue();
                _ = self.iterable.setNextState() catch |err| {
                    if (err != error.InvalidState) return err;
                };
                return value;
            }

            fn next(iterator: *ReadableIterator) anyerror!?Value {
                var self: *Self = @fieldParentPtr("interface", iterator);
                _ = self.iterable.setNextState() catch |err| {
                    return if (err == error.InvalidState) null else err;
                };
                const value = try self.iterable.getValue();
                return value;
            }

            fn at(iterator: *ReadableIterator, state: State) anyerror!?Value {
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

            fn getState(iterator: *ReadableIterator) anyerror!State {
                var self: *Self = @fieldParentPtr("interface", iterator);
                return self.iterable.getState();
            }

            fn setState(iterator: *ReadableIterator, state: State) anyerror!*ReadableIterator {
                var self: *Self = @fieldParentPtr("interface", iterator);
                _ = try self.iterable.setState(state);
                return iterator;
            }

            fn setInitialState(iterator: *ReadableIterator) anyerror!*ReadableIterator {
                var self: *Self = @fieldParentPtr("interface", iterator);
                _ = try self.iterable.setInitialState();
                return iterator;
            }

            fn setFinalState(iterator: *ReadableIterator) anyerror!*ReadableIterator {
                var self: *Self = @fieldParentPtr("interface", iterator);
                _ = try self.iterable.setFinalState();
                return iterator;
            }
        };

        pub const Writable = struct {
            const Self = @This();
            const WritableIterator = Iterator.Writable.Interface;

            interface: WritableIterator,
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

            fn previous(iterator: *WritableIterator, value: Value) anyerror!?*WritableIterator {
                var self: *Self = @fieldParentPtr("interface", iterator);
                _ = self.iterable.setPreviousState() catch |err| {
                    return if (err == error.InvalidState) null else err;
                };
                _ = try self.iterable.setValue(value);
                return iterator;
            }

            fn current(iterator: *WritableIterator, value: Value) anyerror!?*WritableIterator {
                var self: *Self = @fieldParentPtr("interface", iterator);
                if (!try self.iterable.isStateValid()) return null;
                _ = try self.iterable.setValue(value);
                _ = self.iterable.setNextState() catch |err| {
                    if (err != error.InvalidState) return err;
                };
                return iterator;
            }

            fn next(iterator: *WritableIterator, value: Value) anyerror!?*WritableIterator {
                var self: *Self = @fieldParentPtr("interface", iterator);
                _ = self.iterable.setNextState() catch |err| {
                    return if (err == error.InvalidState) null else err;
                };
                _ = try self.iterable.setValue(value);
                return iterator;
            }

            fn at(iterator: *WritableIterator, state: State, value: Value) anyerror!?*WritableIterator {
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

            fn getState(iterator: *WritableIterator) anyerror!State {
                var self: *Self = @fieldParentPtr("interface", iterator);
                return self.iterable.getState();
            }

            fn setState(iterator: *WritableIterator, state: State) anyerror!*WritableIterator {
                var self: *Self = @fieldParentPtr("interface", iterator);
                _ = try self.iterable.setState(state);
                return iterator;
            }

            fn setInitialState(iterator: *WritableIterator) anyerror!*WritableIterator {
                var self: *Self = @fieldParentPtr("interface", iterator);
                _ = try self.iterable.setInitialState();
                return iterator;
            }

            fn setFinalState(iterator: *WritableIterator) anyerror!*WritableIterator {
                var self: *Self = @fieldParentPtr("interface", iterator);
                _ = try self.iterable.setFinalState();
                return iterator;
            }
        };
    };
}

test IterableIterator {
    _ = IterableIterator(u8, usize);
}
