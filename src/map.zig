//! A higher-order iterator that maps values of an iterator to other values
//! It users a map function where its input is a value from the base iterator
//! and its output is a value of the map iterator.

const std = @import("std");
const testing = std.testing;
const mem = std.mem;

const vec = @import("vector.zig");
const ib = @import("iterable.zig");
const it = @import("iterator.zig");
const Mode = @import("mode.zig").Mode;

pub fn This(BaseIterator: type, map: anytype) type {
    return struct {
        const ReturnType = @typeInfo(@TypeOf(map)).@"fn".return_type.?;
        pub const BaseValue = BaseIterator.ValueType;
        pub const ValueType = Value;
        pub const StateType = State;
        pub const Value = @typeInfo(ReturnType).error_union.payload;
        pub const State = BaseIterator.StateType;
        const BaIt = it.Iterator(BaseValue, State);
        pub const It = it.Iterator(Value, State);
        pub const Map = fn (value: BaseValue) ReturnType;
        const mapValue: Map = map;

        pub const Readable = create(.get);
        pub const Writable = create(.set);

        pub fn create(mode: Mode) type {
            return struct {
                const Self = @This();
                const Iterator = if (mode == .get) It.Readable else It.Writable;
                const Base = if (mode == .get) BaIt.Readable else BaIt.Writable;
                const Rm = ReadableMap(BaseIterator, map);
                const Wm = WritableMap(BaseIterator, map);
                const MapIterator = if (mode == .get) Rm else Wm;

                map_iterator: *MapIterator,

                pub fn init(gpa: mem.Allocator, base_iterator: *Base.Interface) !Self {
                    const map_iterator = try MapIterator.create(gpa, base_iterator);
                    return .{ .map_iterator = map_iterator };
                }

                pub fn deinit(self: *Self, gpa: mem.Allocator) void {
                    gpa.destroy(self.map_iterator);
                }

                pub fn iterator(self: *const Self) Iterator.This {
                    return .init(&self.map_iterator.interface);
                }
            };
        }
    };
}

pub fn ReadableMap(BaseIterator: type, map: anytype) type {
    return struct {
        const Self = @This();
        const ReturnType = @typeInfo(@TypeOf(map)).@"fn".return_type.?;
        pub const BaseValue = BaseIterator.ValueType;
        pub const ValueType = Value;
        pub const StateType = State;
        pub const Value = @typeInfo(ReturnType).error_union.payload;
        pub const State = BaseIterator.StateType;
        const BaIt = it.Iterator(BaseValue, State);
        pub const Iterator = it.Iterator(Value, State);
        pub const ReadableIterator = Iterator.Readable.Interface;
        pub const Map = fn (value: BaseValue) ReturnType;
        const mapValue: Map = map;

        interface: ReadableIterator,
        base_iterator: *BaIt.Readable.Interface,

        pub fn create(gpa: mem.Allocator, base_iterator: *BaIt.Readable.Interface) !*Self {
            const self = try gpa.create(Self);
            self.* = .init(base_iterator);
            return self;
        }

        pub fn init(base_iterator: *BaIt.Readable.Interface) Self {
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

test ReadableMap {
    const Value = u8;
    const capacity: u8 = 5;
    const VecIt = vec.This(Value, capacity);
    const State = VecIt.StateType;
    const It = it.Iterator(Value, State);
    const Map = This(It, toUppercase);

    const allocator = testing.allocator;
    const slice: []Value = @constCast("hello");
    const capitalized = "HELLO";
    var vector = try VecIt.Readable.init(allocator, slice);
    defer vector.deinit(allocator);
    var map = try Map.Readable.init(allocator, vector.iterator().interface);
    defer map.deinit(allocator);
    var iter = map.iterator();
    var iterated: [slice.len]u8 = undefined;

    var i: usize = 0;
    while (try iter.current()) |char| {
        iterated[i] = char;
        i += 1;
    }

    try testing.expectEqualStrings(capitalized, &iterated);
}

pub fn WritableMap(BaseIterator: type, map: anytype) type {
    return struct {
        const Self = @This();
        pub const BaseValue = BaseIterator.ValueType;
        pub const ValueType = Value;
        pub const StateType = State;
        pub const Value = @typeInfo(@TypeOf(map)).@"fn".params[0].type.?;
        pub const State = BaseIterator.StateType;
        const BaIt = it.Iterator(BaseValue, State);
        pub const Iterator = it.Iterator(Value, State);
        pub const WritableIterator = Iterator.Writable.Interface;
        pub const Map = fn (value: Value) anyerror!BaseValue;
        const mapValue: Map = map;

        interface: WritableIterator,
        base_iterator: *BaIt.Writable.Interface,

        pub fn create(gpa: mem.Allocator, base_iterator: *BaIt.Writable.Interface) !*Self {
            const self = try gpa.create(Self);
            self.* = .init(base_iterator);
            return self;
        }

        pub fn init(base_iterator: *BaIt.Writable.Interface) Self {
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

test WritableMap {
    const Value = u8;
    const capacity: u8 = 5;
    const VecIt = vec.This(Value, capacity);
    const State = VecIt.StateType;
    const It = it.Iterator(Value, State);
    const Map = This(It, toUppercase).Writable;

    const allocator = testing.allocator;
    const slice: []Value = @constCast("hello");
    const capitalized = "HELLO";
    var buffer: [slice.len]u8 = undefined;
    var vector = try VecIt.Writable.init(allocator, &buffer);
    defer vector.deinit(allocator);
    var map = try Map.init(allocator, vector.iterator().interface);
    defer map.deinit(allocator);
    var iter = map.iterator();

    for (slice) |char| _ = try iter.current(char);
    try testing.expectEqualStrings(capitalized, &buffer);
}

fn toUppercase(char: u8) anyerror!u8 {
    return std.ascii.toUpper(char);
}
