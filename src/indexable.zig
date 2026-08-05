//! Indexable is an abstract collection where each value can be mapped to an
//! index. The index is used to get and set a value.

const std = @import("std");
const debug = std.debug;
const mem = std.mem;
const testing = std.testing;

const scalar = @import("scalar.zig");
const ib = @import("iterable.zig");
const it = @import("iterator.zig");
const Mode = @import("mode.zig").Mode;

pub fn This(Value: type, comptime capacity: anytype) type {
    return struct {
        const Capacity = @TypeOf(capacity);
        pub const ValueType = Value;
        pub const StateType = State;
        const State = InIb.StateType;

        const In = Indexable(Value, capacity);
        const InIb = Iterable(Value, capacity);
        const Ib = ib.Iterable(Value, StateType);
        const It = it.Iterator(Value, State);

        pub const Readable = create(.get);
        pub const Writable = create(.set);

        pub fn create(mode: Mode) type {
            return struct {
                const Self = @This();
                const Iterator = if (mode == .get) It.Readable else It.Writable;

                default_iterator: *Iterator.Default,
                indexable_iterable: *InIb,

                /// Creates utilities for an indexable. Free memory using `deinit`.
                pub fn init(gpa: mem.Allocator, in: *In.Interface) !Self {
                    const indexable_iterable = try InIb.create(gpa, in);
                    const default_iterator = try Iterator.Default.create(
                        &indexable_iterable.interface,
                    );

                    return .{
                        .default_iterator = default_iterator,
                        .indexable_iterable = indexable_iterable,
                    };
                }

                pub fn deinit(self: *Self, gpa: mem.Allocator) void {
                    gpa.destroy(self.default_iterator);
                    gpa.destroy(self.indexable_iterable);
                }

                pub fn iterator(self: *const Self) Iterator.This {
                    return .init(&self.default_iterator.interface);
                }

                pub fn iterable(self: *const Self) Ib {
                    return .init(&self.indexable_iterable.interface);
                }

                pub fn indexable(self: *const Self) In {
                    return self.indexable_iterable.indexable;
                }
            };
        }
    };
}

test This {
    const It = This(u8, 16);
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
        const IndexableType = Indexable(Value, capacity);

        interface: Interface,
        indexable: IndexableType,
        index: State = .initial,

        pub fn create(gpa: mem.Allocator, indexable: *IndexableType.Interface) !*Self {
            const self = try gpa.create(Self);
            self.* = .init(indexable);
            return self;
        }

        pub fn init(indexable: *IndexableType.Interface) Self {
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
                .indexable = .init(indexable),
            };
        }

        pub fn getValue(iterable: *Interface) anyerror!Value {
            const self: *Self = @fieldParentPtr("interface", iterable);
            return self.indexable.get(self.index.valid);
        }

        pub fn setValue(iterable: *Interface, value: Value) anyerror!*Interface {
            var self: *Self = @fieldParentPtr("interface", iterable);
            _ = try self.indexable.set(self.index.valid, value);
            return iterable;
        }

        pub fn getState(iterable: *Interface) anyerror!State {
            const self: *Self = @fieldParentPtr("interface", iterable);
            return self.index;
        }

        pub fn setState(iterable: *Interface, index: State) anyerror!*Interface {
            var self: *Self = @fieldParentPtr("interface", iterable);
            self.index = switch (index) {
                .valid => |v| if (v < try self.indexable.size()) index else .overflow,
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
                .valid => |index| if (index == try self.indexable.size()) error.InvalidState else iterable,
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
            return self.index.isValid() and self.index.valid < try self.indexable.size();
        }
    };
}

test Iterable {
    _ = Iterable(u8, @as(usize, 16));
}

pub fn Indexable(Value: type, comptime capacity: anytype) type {
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
