const std = @import("std");
const testing = std.testing;

const ib = @import("iterable.zig");
const vector = @import("vector.zig");
const it = @import("iterator.zig");

pub fn Readable(BaseIterator: type, predicate: anytype) type {
    return struct {
        const Self = @This();
        pub const Iterator = it.Iterator(BaseIterator.ValueType, BaseIterator.StateType);
        pub const ValueType = Value;
        pub const StateType = State;
        pub const Value = Iterator.ValueType;
        pub const State = Iterator.StateType;
        pub const ReadableIterator = Iterator.Readable.Interface;
        pub const Predicate = fn (value: Value) anyerror!bool;
        const isMatch: Predicate = predicate;

        interface: ReadableIterator,
        base_iterator: *ReadableIterator,

        pub inline fn from(base_iterator: *ReadableIterator) *Iterator.Readable.This {
            var self: Self = .init(base_iterator);
            return @constCast(&Iterator.Readable.This.init(&self.interface));
        }

        pub fn init(base_iterator: *ReadableIterator) Self {
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

        fn previous(iterator: *ReadableIterator) anyerror!?Value {
            var self: *Self = @fieldParentPtr("interface", iterator);
            return while (try self.base_iterator.previous(self.base_iterator)) |value| {
                if (try isMatch(value)) break value;
            } else null;
        }

        fn current(iterator: *ReadableIterator) anyerror!?Value {
            var self: *Self = @fieldParentPtr("interface", iterator);
            return while (try self.base_iterator.current(self.base_iterator)) |value| {
                if (try isMatch(value)) break value;
            } else null;
        }

        fn next(iterator: *ReadableIterator) anyerror!?Value {
            var self: *Self = @fieldParentPtr("interface", iterator);
            return while (try self.base_iterator.next(self.base_iterator)) |value| {
                if (try isMatch(value)) break value;
            } else null;
        }

        fn at(iterator: *ReadableIterator, state: State) anyerror!?Value {
            var self: *Self = @fieldParentPtr("interface", iterator);
            if (try self.base_iterator.at(self.base_iterator, state)) |value| {
                if (try isMatch(value)) return value;
            } else return null;

            return while (try self.base_iterator.current(self.base_iterator)) |v| {
                if (try isMatch(v)) break v;
            } else null;
        }

        pub fn getState(iterator: *ReadableIterator) anyerror!State {
            const self: *Self = @fieldParentPtr("interface", iterator);
            return self.base_iterator.getState(self.base_iterator);
        }

        pub fn setState(iterator: *ReadableIterator, state: State) anyerror!*ReadableIterator {
            const self: *Self = @fieldParentPtr("interface", iterator);
            _ = try self.base_iterator.setState(self.base_iterator, state);
            return iterator;
        }

        pub fn setInitialState(iterator: *ReadableIterator) anyerror!*ReadableIterator {
            const self: *Self = @fieldParentPtr("interface", iterator);
            _ = try self.base_iterator.setInitialState(self.base_iterator);
            return iterator;
        }

        pub fn setFinalState(iterator: *ReadableIterator) anyerror!*ReadableIterator {
            const self: *Self = @fieldParentPtr("interface", iterator);
            _ = try self.base_iterator.setFinalState(self.base_iterator);
            return iterator;
        }

        pub inline fn to(self: *Self, Other: type) it.Infer(Other).Readable {
            return Other.from(self.interface);
        }
    };
}

test Readable {
    const Value = u8;
    const State = vector.State;
    const Vec = vector.Vector(Value);
    const Ib = ib.Iterable(Value, State);
    const It = it.Iterator(Value, State);

    const slice: []Vec.ValueType = @constCast("hello");
    const vowels = "eo";
    var vec = Vec.init(slice);
    var vec_ib = Ib.init(&vec.interface);
    var int = It.Readable.Default.init(&vec_ib);
    var iter = It.Readable.This.init(&int.interface);
    var f = iter.to(Readable(It, isVowel));
    var iterated: [slice.len]u8 = undefined;

    var i: usize = 0;
    while (try f.current()) |char| {
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

pub fn Writable(BaseIterator: type, predicate: anytype) type {
    return struct {
        const Self = @This();
        pub const Iterator = it.Iterator(BaseIterator.ValueType, BaseIterator.StateType);
        pub const ValueType = Value;
        pub const StateType = State;
        pub const Value = Iterator.ValueType;
        pub const State = Iterator.StateType;
        pub const WritableIterator = Iterator.Writable.Interface;
        pub const Predicate = fn (value: Value) anyerror!bool;
        const isMatch: Predicate = predicate;

        interface: WritableIterator,
        base_iterator: *WritableIterator,

        pub inline fn from(base_iterator: *WritableIterator) *Iterator.Writable.This {
            var self: Self = .init(base_iterator);
            return @constCast(&Iterator.Writable.This.init(&self.interface));
        }

        pub fn init(base_iterator: *WritableIterator) Self {
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

        fn previous(iterator: *WritableIterator, value: Value) anyerror!?*WritableIterator {
            const self: *Self = @fieldParentPtr("interface", iterator);
            return if (try isMatch(value)) set: {
                const base_iterator = try self.base_iterator.previous(self.base_iterator, value);
                break :set if (base_iterator) |_| iterator else null;
            } else null;
        }

        fn current(iterator: *WritableIterator, value: Value) anyerror!?*WritableIterator {
            const self: *Self = @fieldParentPtr("interface", iterator);
            return if (try isMatch(value)) set: {
                const base_iterator = try self.base_iterator.current(self.base_iterator, value);
                break :set if (base_iterator) |_| iterator else null;
            } else null;
        }

        fn next(iterator: *WritableIterator, value: Value) anyerror!?*WritableIterator {
            const self: *Self = @fieldParentPtr("interface", iterator);
            return if (try isMatch(value)) set: {
                const base_iterator = try self.base_iterator.next(self.base_iterator, value);
                break :set if (base_iterator) |_| iterator else null;
            } else null;
        }

        fn at(iterator: *WritableIterator, state: State, value: Value) anyerror!?*WritableIterator {
            const self: *Self = @fieldParentPtr("interface", iterator);
            return if (try isMatch(value)) set: {
                const base_iterator = try self.base_iterator.at(self.base_iterator, state, value);
                break :set if (base_iterator) |_| iterator else null;
            } else null;
        }

        fn getState(iterator: *WritableIterator) anyerror!State {
            const self: *Self = @fieldParentPtr("interface", iterator);
            return self.base_iterator.getState(self.base_iterator);
        }

        fn setState(iterator: *WritableIterator, state: State) anyerror!*WritableIterator {
            const self: *Self = @fieldParentPtr("interface", iterator);
            _ = try self.base_iterator.setState(self.base_iterator, state);
            return iterator;
        }

        fn setInitialState(iterator: *WritableIterator) anyerror!*WritableIterator {
            const self: *Self = @fieldParentPtr("interface", iterator);
            _ = try self.base_iterator.setInitialState(self.base_iterator);
            return iterator;
        }

        fn setFinalState(iterator: *WritableIterator) anyerror!*WritableIterator {
            const self: *Self = @fieldParentPtr("interface", iterator);
            _ = try self.base_iterator.setFinalState(self.base_iterator);
            return iterator;
        }

        pub inline fn to(self: *Self, Other: type) it.Infer(Other).Writable {
            return Other.from(self.interface);
        }
    };
}

test Writable {
    const Value = u8;
    const State = vector.State;
    const Vec = vector.Vector(Value);
    const Ib = ib.Iterable(Value, State);
    const It = it.Iterator(Value, State);

    const slice: []Value = @constCast("hello");
    const vowels = "eo";
    var buffer: [slice.len]u8 = undefined;
    var vec = Vec.init(&buffer);
    var vec_ib = Ib.init(&vec.interface);
    var int = It.Writable.Default.init(&vec_ib);
    var iter = It.Writable.This.init(&int.interface);
    var f = iter.to(Writable(It, isVowel));

    for (slice) |char| _ = try f.current(char);
    try testing.expectEqualStrings(vowels, buffer[0..vowels.len]);
}
