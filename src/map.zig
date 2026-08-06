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

        pub const Getter = create(.get);
        pub const Setter = create(.set);

        pub fn create(mode: Mode) type {
            return struct {
                const Self = @This();
                const Iterator = if (mode == .get) It.Getter else It.Setter;
                const Base = if (mode == .get) BaIt.Getter else BaIt.Setter;
                const Rm = GetterMap(BaseIterator, map);
                const Wm = SetterMap(BaseIterator, map);
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

pub fn GetterMap(BaseIterator: type, map: anytype) type {
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
        pub const GetterIterator = Iterator.Getter.Interface;
        pub const Map = fn (value: BaseValue) ReturnType;
        const mapValue: Map = map;

        interface: GetterIterator,
        base_iterator: *BaIt.Getter.Interface,

        pub fn create(gpa: mem.Allocator, base_iterator: *BaIt.Getter.Interface) !*Self {
            const self = try gpa.create(Self);
            self.* = .init(base_iterator);
            return self;
        }

        pub fn init(base_iterator: *BaIt.Getter.Interface) Self {
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
            const value = try self.base_iterator.previous(self.base_iterator);
            return if (value) |v| try mapValue(v) else null;
        }

        fn current(iterator: *GetterIterator) anyerror!?Value {
            var self: *Self = @fieldParentPtr("interface", iterator);
            const value = try self.base_iterator.current(self.base_iterator);
            return if (value) |v| try mapValue(v) else null;
        }

        fn next(iterator: *GetterIterator) anyerror!?Value {
            var self: *Self = @fieldParentPtr("interface", iterator);
            const value = try self.base_iterator.next(self.base_iterator);
            return if (value) |v| try mapValue(v) else null;
        }

        fn at(iterator: *GetterIterator, state: State) anyerror!?Value {
            var self: *Self = @fieldParentPtr("interface", iterator);
            const value = try self.base_iterator.at(self.base_iterator, state);
            return if (value) |v| try mapValue(v) else null;
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

test GetterMap {
    const Value = u8;
    const capacity: u8 = 5;
    const VecIt = vec.This(Value, capacity);
    const State = VecIt.StateType;
    const It = it.Iterator(Value, State);
    const Map = This(It, toUppercase);

    const allocator = testing.allocator;
    const slice: []Value = @constCast("hello");
    const capitalized = "HELLO";
    var vector = try VecIt.Getter.init(allocator, slice);
    defer vector.deinit(allocator);
    var map = try Map.Getter.init(allocator, vector.iterator().interface);
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

pub fn SetterMap(BaseIterator: type, map: anytype) type {
    return struct {
        const Self = @This();
        pub const BaseValue = BaseIterator.ValueType;
        pub const ValueType = Value;
        pub const StateType = State;
        pub const Value = @typeInfo(@TypeOf(map)).@"fn".params[0].type.?;
        pub const State = BaseIterator.StateType;
        const BaIt = it.Iterator(BaseValue, State);
        pub const Iterator = it.Iterator(Value, State);
        pub const SetterIterator = Iterator.Setter.Interface;
        pub const Map = fn (value: Value) anyerror!BaseValue;
        const mapValue: Map = map;

        interface: SetterIterator,
        base_iterator: *BaIt.Setter.Interface,

        pub fn create(gpa: mem.Allocator, base_iterator: *BaIt.Setter.Interface) !*Self {
            const self = try gpa.create(Self);
            self.* = .init(base_iterator);
            return self;
        }

        pub fn init(base_iterator: *BaIt.Setter.Interface) Self {
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
            const result = try self.base_iterator.previous(self.base_iterator, try mapValue(value));
            return if (result) |_| iterator else null;
        }

        fn current(iterator: *SetterIterator, value: Value) anyerror!?*SetterIterator {
            const self: *Self = @fieldParentPtr("interface", iterator);
            const result = try self.base_iterator.current(self.base_iterator, try mapValue(value));
            return if (result) |_| iterator else null;
        }

        fn next(iterator: *SetterIterator, value: Value) anyerror!?*SetterIterator {
            const self: *Self = @fieldParentPtr("interface", iterator);
            const result = try self.base_iterator.next(self.base_iterator, try mapValue(value));
            return if (result) |_| iterator else null;
        }

        fn at(iterator: *SetterIterator, state: State, value: Value) anyerror!?*SetterIterator {
            const self: *Self = @fieldParentPtr("interface", iterator);
            const result = try self.base_iterator.at(self.base_iterator, state, try mapValue(value));
            return if (result) |_| iterator else null;
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

test SetterMap {
    const Value = u8;
    const capacity: u8 = 5;
    const VecIt = vec.This(Value, capacity);
    const State = VecIt.StateType;
    const It = it.Iterator(Value, State);
    const Map = This(It, toUppercase).Setter;

    const allocator = testing.allocator;
    const slice: []Value = @constCast("hello");
    const capitalized = "HELLO";
    var buffer: [slice.len]u8 = undefined;
    var vector = try VecIt.Setter.init(allocator, &buffer);
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
