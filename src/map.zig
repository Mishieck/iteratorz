const std = @import("std");
const testing = std.testing;

const vector = @import("vector.zig");
const ib = @import("iterable.zig");
const it = @import("iterator.zig");

pub fn Readable(BaseIterator: type, map: anytype) type {
    return struct {
        const Self = @This();
        const ReturnType = @typeInfo(@TypeOf(map)).@"fn".return_type.?;
        pub const BaseValue = BaseIterator.ValueType;
        pub const ValueType = Value;
        pub const StateType = State;
        pub const Value = @typeInfo(ReturnType).error_union.payload;
        pub const State = BaseIterator.StateType;
        pub const Iterator = it.Iterator(Value, State);
        pub const ReadableIterator = Iterator.Readable.Interface;
        pub const Map = fn (value: BaseValue) ReturnType;
        const mapValue: Map = map;

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
            const value = try self.base_iterator.previous(self.base_iterator);
            return if (value) |v| try mapValue(v) else null;
        }

        fn current(iterator: *ReadableIterator) anyerror!?Value {
            var self: *Self = @fieldParentPtr("interface", iterator);
            const value = try self.base_iterator.current(self.base_iterator);
            return if (value) |v| try mapValue(v) else null;
        }

        fn next(iterator: *ReadableIterator) anyerror!?Value {
            var self: *Self = @fieldParentPtr("interface", iterator);
            const value = try self.base_iterator.next(self.base_iterator);
            return if (value) |v| try mapValue(v) else null;
        }

        fn at(iterator: *ReadableIterator, state: State) anyerror!?Value {
            var self: *Self = @fieldParentPtr("interface", iterator);
            const value = try self.base_iterator.at(self.base_iterator, state);
            return if (value) |v| try mapValue(v) else null;
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
    };
}

test Readable {
    const Value = u8;
    const State = vector.State;
    const Vec = vector.Vector(Value);
    const Ib = ib.Iterable(Value, State);
    const It = it.Iterator(Value, State);

    const slice: []Vec.ValueType = @constCast("hello");
    const capitalized = "HELLO";
    var vec = Vec.init(slice);
    var vec_ib = Ib.init(&vec.interface);
    var int = It.Readable.Default.init(&vec_ib);
    var iter = It.Readable.This.init(&int.interface);
    var m = iter.to(Readable(It, capitalize));
    var iterated: [slice.len]u8 = undefined;

    var i: usize = 0;
    while (try m.current()) |char| {
        iterated[i] = char;
        i += 1;
    }

    try testing.expectEqualStrings(capitalized, &iterated);
}

pub fn Writable(BaseIterator: type, map: anytype) type {
    return struct {
        const Self = @This();
        pub const BaseValue = BaseIterator.ValueType;
        pub const ValueType = Value;
        pub const StateType = State;
        pub const Value = @typeInfo(@TypeOf(map)).@"fn".params[0].type.?;
        pub const State = BaseIterator.StateType;
        pub const Iterator = it.Iterator(Value, State);
        pub const WritableIterator = Iterator.Writable.Interface;
        pub const Map = fn (value: Value) anyerror!BaseValue;
        const mapValue: Map = map;

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
            const result = try self.base_iterator.previous(self.base_iterator, try mapValue(value));
            return if (result) |_| iterator else null;
        }

        fn current(iterator: *WritableIterator, value: Value) anyerror!?*WritableIterator {
            const self: *Self = @fieldParentPtr("interface", iterator);
            const result = try self.base_iterator.current(self.base_iterator, try mapValue(value));
            return if (result) |_| iterator else null;
        }

        fn next(iterator: *WritableIterator, value: Value) anyerror!?*WritableIterator {
            const self: *Self = @fieldParentPtr("interface", iterator);
            const result = try self.base_iterator.next(self.base_iterator, try mapValue(value));
            return if (result) |_| iterator else null;
        }

        fn at(iterator: *WritableIterator, state: State, value: Value) anyerror!?*WritableIterator {
            const self: *Self = @fieldParentPtr("interface", iterator);
            const result = try self.base_iterator.at(self.base_iterator, state, try mapValue(value));
            return if (result) |_| iterator else null;
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
    };
}

test Writable {
    const Value = u8;
    const State = vector.State;
    const Vec = vector.Vector(Value);
    const Ib = ib.Iterable(Value, State);
    const It = it.Iterator(Value, State);

    const slice: []Value = @constCast("hello");
    const capitalized = "HELLO";
    var buffer: [slice.len]u8 = undefined;
    var vec = Vec.init(&buffer);
    var vec_ib = Ib.init(&vec.interface);
    var int = It.Writable.Default.init(&vec_ib);
    var iter = It.Writable.This.init(&int.interface);
    var m = iter.to(Writable(It, capitalize));

    for (slice) |char| _ = try m.current(char);
    try testing.expectEqualStrings(capitalized, &buffer);
}

fn capitalize(char: u8) anyerror!u8 {
    return std.ascii.toUpper(char);
}
