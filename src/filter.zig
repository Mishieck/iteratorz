//! ERROR: This module does not work yet due to a comptime error.
//!
//! A higher-order iterator which filters values of another iterator. The
//! filter uses a predicate to filter values from another iterator.

const std = @import("std");
const testing = std.testing;
const mem = std.mem;

const ib = @import("iterable.zig");
const vec = @import("vector.zig");
const it = @import("iterator.zig");
const Mode = @import("mode.zig").Mode;

pub fn This(BaseIterator: type, predicate: anytype) type {
    return struct {
        pub const It = it.Iterator(Value, State);
        pub const Value = BaseIterator.ValueType;
        pub const State = BaseIterator.StateType;
        pub const ValueType = Value;
        pub const StateType = State;
        pub const GetterIterator = It.Getter.Interface;
        pub const Predicate = fn (value: Value) anyerror!bool;
        const isMatch: Predicate = predicate;

        pub const Getter = create(.get);
        pub const Setter = create(.set);

        pub fn create(mode: Mode) type {
            return struct {
                const Self = @This();
                const Iterator = if (mode == .get) It.Getter else It.Setter;
                const Base = if (mode == .get) It.Getter else It.Setter;
                const Rm = GetterFilter(BaseIterator, isMatch);
                const Wm = SetterFilter(BaseIterator, isMatch);
                const FilterIterator = if (mode == .get) Rm else Wm;

                filter_iterator: *FilterIterator,

                pub fn init(gpa: mem.Allocator, base_iterator: *Base.Interface) !Self {
                    const filter_iterator = try FilterIterator.create(gpa, base_iterator);
                    return .{ .filter_iterator = filter_iterator };
                }

                pub fn deinit(self: *Self, gpa: mem.Allocator) void {
                    gpa.destroy(self.filter_iterator);
                }

                pub fn iterator(self: *const Self) Iterator.This {
                    return .init(&self.filter_iterator.interface);
                }
            };
        }
    };
}

pub fn GetterFilter(BaseIterator: type, predicate: anytype) type {
    return struct {
        const Self = @This();
        pub const Iterator = it.Iterator(Value, State);
        pub const Value = BaseIterator.ValueType;
        pub const State = BaseIterator.StateType;
        pub const ValueType = Value;
        pub const StateType = State;
        pub const GetterIterator = Iterator.Getter.Interface;
        pub const Predicate = fn (value: Value) anyerror!bool;
        const isMatch: Predicate = predicate;

        interface: GetterIterator,
        base_iterator: *GetterIterator,

        pub fn init(base_iterator: *GetterIterator) Self {
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
                .base_iterator = base_iterator,
            };
        }

        fn previous(iterator: *GetterIterator) anyerror!?Value {
            var self: *Self = @fieldParentPtr("interface", iterator);
            return while (try self.base_iterator.previous(self.base_iterator)) |value| {
                if (try isMatch(value)) break value;
            } else null;
        }

        fn current(iterator: *GetterIterator) anyerror!?Value {
            var self: *Self = @fieldParentPtr("interface", iterator);
            return while (try self.base_iterator.current(self.base_iterator)) |value| {
                if (try isMatch(value)) break value;
            } else null;
        }

        fn next(iterator: *GetterIterator) anyerror!?Value {
            var self: *Self = @fieldParentPtr("interface", iterator);
            return while (try self.base_iterator.next(self.base_iterator)) |value| {
                if (try isMatch(value)) break value;
            } else null;
        }

        fn at(iterator: *GetterIterator, state: State) anyerror!?Value {
            var self: *Self = @fieldParentPtr("interface", iterator);
            if (try self.base_iterator.at(self.base_iterator, state)) |value| {
                if (try isMatch(value)) return value;
            } else return null;

            return while (try self.base_iterator.current(self.base_iterator)) |v| {
                if (try isMatch(v)) break v;
            } else null;
        }

        pub fn getState(iterator: *GetterIterator) anyerror!State {
            const self: *Self = @fieldParentPtr("interface", iterator);
            return self.base_iterator.getState(self.base_iterator);
        }

        pub fn setState(iterator: *GetterIterator, state: State) anyerror!*GetterIterator {
            const self: *Self = @fieldParentPtr("interface", iterator);
            _ = try self.base_iterator.setState(self.base_iterator, state);
            return iterator;
        }

        pub fn setInitialState(iterator: *GetterIterator) anyerror!*GetterIterator {
            const self: *Self = @fieldParentPtr("interface", iterator);
            _ = try self.base_iterator.setInitialState(self.base_iterator);
            return iterator;
        }

        pub fn setFinalState(iterator: *GetterIterator) anyerror!*GetterIterator {
            const self: *Self = @fieldParentPtr("interface", iterator);
            _ = try self.base_iterator.setFinalState(self.base_iterator);
            return iterator;
        }
    };
}

test GetterFilter {
    const Value = u8;
    const capacity = 5;
    const VecIt = vec.This(Value, capacity);
    const State = VecIt.StateType;
    const It = it.Iterator(Value, State);
    const Filter = This(It, isVowel).Getter;

    const allocator = testing.allocator;
    const slice: []Value = @constCast("hello");
    const vowels = "eo";
    var vector = try VecIt.Getter.init(allocator, slice);
    var filter = try Filter.init(allocator, vector.iterator().interface);
    var iter = filter.iterator();
    var iterated: [slice.len]u8 = undefined;

    var i: usize = 0;
    while (try iter.current()) |char| {
        iterated[i] = char;
        i += 1;
    }

    try testing.expectEqualStrings(vowels, iterated[0..i]);
}

fn isVowel(char: u8) anyerror!bool {
    return for ("aeiou") |c| {
        if (c == char) break true;
    } else false;
}

pub fn SetterFilter(BaseIterator: type, predicate: anytype) type {
    return struct {
        const Self = @This();
        pub const Iterator = it.Iterator(BaseIterator.ValueType, BaseIterator.StateType);
        pub const ValueType = Value;
        pub const StateType = State;
        pub const Value = Iterator.ValueType;
        pub const State = Iterator.StateType;
        pub const SetterIterator = Iterator.Setter.Interface;
        pub const Predicate = fn (value: Value) anyerror!bool;
        const isMatch: Predicate = predicate;

        interface: SetterIterator,
        base_iterator: *SetterIterator,

        pub fn init(base_iterator: *SetterIterator) Self {
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
                .base_iterator = base_iterator,
            };
        }

        fn previous(iterator: *SetterIterator, value: Value) anyerror!?*SetterIterator {
            const self: *Self = @fieldParentPtr("interface", iterator);
            return if (try isMatch(value)) set: {
                const base_iterator = try self.base_iterator.previous(self.base_iterator, value);
                break :set if (base_iterator) |_| iterator else null;
            } else null;
        }

        fn current(iterator: *SetterIterator, value: Value) anyerror!?*SetterIterator {
            const self: *Self = @fieldParentPtr("interface", iterator);
            return if (try isMatch(value)) set: {
                const base_iterator = try self.base_iterator.current(self.base_iterator, value);
                break :set if (base_iterator) |_| iterator else null;
            } else null;
        }

        fn next(iterator: *SetterIterator, value: Value) anyerror!?*SetterIterator {
            const self: *Self = @fieldParentPtr("interface", iterator);
            return if (try isMatch(value)) set: {
                const base_iterator = try self.base_iterator.next(self.base_iterator, value);
                break :set if (base_iterator) |_| iterator else null;
            } else null;
        }

        fn at(iterator: *SetterIterator, state: State, value: Value) anyerror!?*SetterIterator {
            const self: *Self = @fieldParentPtr("interface", iterator);
            return if (try isMatch(value)) set: {
                const base_iterator = try self.base_iterator.at(self.base_iterator, state, value);
                break :set if (base_iterator) |_| iterator else null;
            } else null;
        }

        fn getState(iterator: *SetterIterator) anyerror!State {
            const self: *Self = @fieldParentPtr("interface", iterator);
            return self.base_iterator.getState(self.base_iterator);
        }

        fn setState(iterator: *SetterIterator, state: State) anyerror!*SetterIterator {
            const self: *Self = @fieldParentPtr("interface", iterator);
            _ = try self.base_iterator.setState(self.base_iterator, state);
            return iterator;
        }

        fn setInitialState(iterator: *SetterIterator) anyerror!*SetterIterator {
            const self: *Self = @fieldParentPtr("interface", iterator);
            _ = try self.base_iterator.setInitialState(self.base_iterator);
            return iterator;
        }

        fn setFinalState(iterator: *SetterIterator) anyerror!*SetterIterator {
            const self: *Self = @fieldParentPtr("interface", iterator);
            _ = try self.base_iterator.setFinalState(self.base_iterator);
            return iterator;
        }
    };
}

test SetterFilter {
    const Value = u8;
    const capacity = 5;
    const VecIt = vec.This(Value, capacity);
    const State = VecIt.StateType;
    const It = it.Iterator(Value, State);
    const Filter = This(It, isVowel).Setter;

    const allocator = testing.allocator;
    const slice: []Value = @constCast("hello");
    const vowels = "eo";
    var buffer: [slice.len]u8 = undefined;
    var vector = try VecIt.Setter.init(allocator, slice);
    var filter = try Filter.init(allocator, vector.iterator().interface);
    var iter = filter.iterator();

    for (slice) |char| _ = try iter.current(char);
    try testing.expectEqualStrings(vowels, buffer[0..vowels.len]);
}
