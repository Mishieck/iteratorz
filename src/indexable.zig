const std = @import("std");
const debug = std.debug;
const testing = std.testing;

const scalar = @import("scalar.zig");
const ib = @import("iterable.zig");
const it = @import("iterator.zig");

pub fn Iterator(Value: type, comptime capacity: anytype) type {
    return struct {
        const Capacity = @TypeOf(capacity);
        pub const ValueType = Value;
        pub const StateType = State;
        const State = InIb.StateType;

        const Co = Collection(Value, capacity);
        const InIb = Iterable(Value, capacity);
        const Ib = ib.Iterable(Value, StateType);

        pub const Readable = struct {
            const It = it.Iterator(Value, State).Readable;

            pub inline fn init(collection: *Co.Interface) It.This {
                var default = It.Default.init(
                    @constCast(&Ib.init(@constCast(&InIb.init(collection).interface))),
                );
                return It.This.init(&default.interface);
            }
        };

        pub const Writable = struct {
            const It = it.Iterator(Value, State).Writable;

            pub inline fn init(collection: *Co.Interface) It.This {
                var default = It.Default.init(
                    @constCast(&Ib.init(@constCast(&InIb.init(collection).interface))),
                );
                return It.This.init(&default.interface);
            }
        };
    };
}

test Iterator {
    const It = Iterator(u8, 16);
    _ = It.Readable;
    _ = It.Writable;
}

pub fn Iterable(Value: type, comptime capacity: anytype) type {
    return struct {
        const Self = @This();
        const Capacity = @TypeOf(capacity);
        pub const ValueType = Value;
        pub const StateType = State;
        const State = scalar.State(Capacity, capacity);

        const Ib = ib.Iterable(Value, State);
        pub const Interface = Ib.Interface;
        pub const Vec = []Value;
        const CollectionType = Collection(Value, capacity);

        interface: Interface,
        collection: CollectionType,
        index: State = .initial,

        pub fn init(collection: *CollectionType.Interface) Self {
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
                .collection = .init(collection),
            };
        }

        pub fn getValue(iterable: *Interface) anyerror!Value {
            const self: *Self = @fieldParentPtr("interface", iterable);
            return self.collection.get(self.index.valid);
        }

        pub fn setValue(iterable: *Interface, value: Value) anyerror!*Interface {
            var self: *Self = @fieldParentPtr("interface", iterable);
            _ = try self.collection.set(self.index.valid, value);
            return iterable;
        }

        pub fn getState(iterable: *Interface) anyerror!State {
            const self: *Self = @fieldParentPtr("interface", iterable);
            return self.index;
        }

        pub fn setState(iterable: *Interface, index: State) anyerror!*Interface {
            var self: *Self = @fieldParentPtr("interface", iterable);
            self.index = switch (index) {
                .valid => |v| if (v < try self.collection.size()) index else .overflow,
                else => index,
            };
            return switch (self.index) {
                .valid => |_| iterable,
                else => error.InvalidState,
            };
        }

        pub fn setNextState(iterable: *Interface) anyerror!*Interface {
            const self: *Self = @fieldParentPtr("interface", iterable);
            self.index = self.index.getNext();
            return switch (self.index) {
                .valid => |index| if (index == try self.collection.size()) error.InvalidState else iterable,
                else => error.InvalidState,
            };
        }

        pub fn setPreviousState(iterable: *Interface) anyerror!*Interface {
            var self: *Self = @fieldParentPtr("interface", iterable);
            self.index = self.index.getPrevious();
            return switch (self.index) {
                .valid => |_| iterable,
                else => error.InvalidState,
            };
        }

        pub fn setInitialState(iterable: *Interface) anyerror!*Interface {
            var self: *Self = @fieldParentPtr("interface", iterable);
            self.index = .initial;
            return iterable;
        }

        pub fn setFinalState(iterable: *Interface) anyerror!*Interface {
            var self: *Self = @fieldParentPtr("interface", iterable);
            self.index = .final;
            return iterable;
        }

        pub fn isStateValid(iterable: *Interface) anyerror!bool {
            const self: *Self = @fieldParentPtr("interface", iterable);
            return self.index.isValid() and self.index.valid < try self.collection.size();
        }
    };
}

test Iterable {
    _ = Iterable(u8, @as(usize, 16));
}

pub fn Collection(Value: type, comptime capacity: anytype) type {
    return struct {
        const Self = @This();
        pub const Capacity = @TypeOf(capacity);
        pub const cap = capacity;

        pub const Interface = struct {
            mode: Mode,
            get: *const fn (indexable: *Interface, index: Capacity) anyerror!Value,
            set: *const fn (indexable: *Interface, index: Capacity, value: Value) anyerror!*Interface,
            size: *const fn (indexable: *Interface) anyerror!Capacity,
        };

        interface: *Interface,

        pub fn init(interface: *Interface) Self {
            return .{ .interface = interface };
        }

        pub fn get(self: *Self, index: Capacity) anyerror!Value {
            return self.interface.get(self.interface, index);
        }

        pub fn set(self: *Self, index: Capacity, value: Value) anyerror!*Self {
            _ = try self.interface.set(self.interface, index, value);
            return self;
        }

        pub fn size(self: *Self) anyerror!Capacity {
            return if (self.interface.mode == .get) self.interface.size(self.interface) else capacity;
        }
    };
}

pub const Mode = enum { get, set };
