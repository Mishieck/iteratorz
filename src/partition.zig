const std = @import("std");
const testing = std.testing;
const debug = std.debug;
const math = std.math;
const mem = std.mem;
const builtin = std.builtin;
const ArrayList = std.array_list.Managed;

const arrayz = @import("arrayz");
const it = @import("iterator.zig");
const ib = @import("iterable.zig");
const vec = @import("vector.zig");
const bytes = @import("bytes.zig");

pub fn This(BaseIterator: type, comptime partition_size: usize) type {
    return struct {
        pub const Getter = PartitionGetter(BaseIterator, partition_size);
        pub const Setter = PartitionSetter(BaseIterator, partition_size);
    };
}

pub fn PartitionSetter(BaseIterator: type, comptime partition_size: usize) type {
    return struct {
        const Self = @This();
        pub const ValueType = Value;
        pub const StateType = State;
        pub const Value = Part;
        pub const State = BaseIterator.StateType;
        pub const BaIt = it.Iterator(BaseIterator.ValueType, BaseIterator.StateType);
        pub const Iterator = it.Iterator(Value, State).Setter;
        pub const Interface = Iterator.Interface;
        pub const Iterable = ib.Iterable(BaIt.ValueType, State);
        pub const size = partition_size;
        pub const Part = [partition_size]BaIt.ValueType;

        interface: Interface,
        setter: BaIt.Setter.This,
        iterable: Iterable,

        pub fn init(setter: *BaIt.Setter.Interface) Self {
            const setter_default: *BaIt.Setter.Default = @fieldParentPtr("interface", setter);

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
                .setter = .init(setter),
                .iterable = setter_default.iterable,
            };
        }

        fn previous(iterator: *Interface, value: Value) anyerror!?*Interface {
            const self: *Self = @fieldParentPtr("interface", iterator);
            for (0..value.len) |i| _ = try self.setter.previous(value[value.len - i - 1]);
            return iterator;
        }

        fn current(iterator: *Interface, value: Value) anyerror!?*Interface {
            const self: *Self = @fieldParentPtr("interface", iterator);
            for (value) |byte| _ = try self.setter.current(byte);
            return iterator;
        }

        fn next(iterator: *Interface, value: Value) anyerror!?*Interface {
            const self: *Self = @fieldParentPtr("interface", iterator);
            for (value) |byte| _ = try self.setter.next(byte);
            return iterator;
        }

        fn at(iterator: *Interface, state: State, value: Value) anyerror!?*Interface {
            const self: *Self = @fieldParentPtr("interface", iterator);
            if (!state.isValid()) return null;
            _ = try self.iterable.setState(.{ .valid = state.valid * partition_size });
            for (value) |byte| _ = try self.setter.current(byte);
            return iterator;
        }

        fn getState(iterator: *Interface) anyerror!State {
            const self: *Self = @fieldParentPtr("interface", iterator);
            const state = try self.iterable.getState();
            return switch (state) {
                .valid => |index| .{ .valid = @divFloor(index, partition_size) },
                else => state,
            };
        }

        fn setState(iterator: *Interface, state: State) anyerror!*Interface {
            const self: *Self = @fieldParentPtr("interface", iterator);
            _ = try self.iterable.setState(switch (state) {
                .valid => |index| .{ .valid = index * partition_size },
                else => state,
            });
            return iterator;
        }

        fn setInitialState(iterator: *Interface) anyerror!*Interface {
            const self: *Self = @fieldParentPtr("interface", iterator);
            _ = try self.iterable.setInitialState();
            return iterator;
        }

        fn setFinalState(iterator: *Interface) anyerror!*Interface {
            const self: *Self = @fieldParentPtr("interface", iterator);
            _ = try self.iterable.setFinalState();
            return iterator;
        }
    };
}

pub fn PartitionGetter(BaseIterator: type, partition_size: usize) type {
    return struct {
        const Self = @This();
        pub const ValueType = Value;
        pub const StateType = State;
        pub const State = BaseIterator.StateType;
        pub const Value = [partition_size]BaseIterator.ValueType;
        pub const BaIt = it.Iterator(BaseIterator.ValueType, BaseIterator.StateType).Getter;
        pub const Iterator = it.Iterator(Value, State).Getter;
        pub const Interface = Iterator.Interface;

        interface: Interface,
        getter: BaIt.This,
        iterable: ib.Iterable(BaseIterator.ValueType, State),

        pub fn init(getter: *BaIt.Interface) Self {
            const setter_default: *BaIt.Default = @fieldParentPtr("interface", getter);

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
                .getter = .init(getter),
                .iterable = setter_default.iterable,
            };
        }

        fn previous(iterator: *Interface) anyerror!?Value {
            var self: *Self = @fieldParentPtr("interface", iterator);
            var value: Value = undefined;
            for (0..partition_size) |i| if (try self.getter.previous()) |byte| {
                value[i] = byte;
            } else return null;
            mem.reverse(BaseIterator.ValueType, &value);
            return value;
        }

        fn current(iterator: *Interface) anyerror!?Value {
            var self: *Self = @fieldParentPtr("interface", iterator);
            var value: Value = undefined;
            for (0..partition_size) |i| if (try self.getter.current()) |byte| {
                value[i] = byte;
            } else return null;
            return value;
        }

        fn next(iterator: *Interface) anyerror!?Value {
            var self: *Self = @fieldParentPtr("interface", iterator);
            var value: Value = undefined;
            for (0..partition_size) |i| if (try self.getter.next()) |byte| {
                value[i] = byte;
            } else return null;
            return value;
        }

        fn at(iterator: *Interface, state: State) anyerror!?Value {
            var self: *Self = @fieldParentPtr("interface", iterator);
            if (!state.isValid()) return null;
            _ = try self.iterable.setState(.{ .valid = state.valid * partition_size });
            var value: Value = undefined;
            for (0..partition_size) |i| if (try self.getter.next()) |byte| {
                value[i] = byte;
            } else return null;
            return value;
        }

        fn getState(iterator: *Interface) anyerror!State {
            const self: *Self = @fieldParentPtr("interface", iterator);
            return self.iterable.getState();
        }

        fn setState(iterator: *Interface, state: State) anyerror!*Interface {
            const self: *Self = @fieldParentPtr("interface", iterator);
            _ = try self.iterable.setState(state);
            return iterator;
        }

        fn setInitialState(iterator: *Interface) anyerror!*Interface {
            const self: *Self = @fieldParentPtr("interface", iterator);
            _ = try self.iterable.setInitialState();
            return iterator;
        }

        fn setFinalState(iterator: *Interface) anyerror!*Interface {
            const self: *Self = @fieldParentPtr("interface", iterator);
            _ = try self.iterable.setFinalState();
            return iterator;
        }
    };
}

test {
    const Vector = vec.This(bytes.Byte, bytes.u64_capacity);
    const It = it.Iterator(Vector.ValueType, Vector.StateType);
    const size: usize = 2;
    const Partition = This(It, size);

    const allocator = testing.allocator;
    const S = Partition.Setter;
    const G = Partition.Getter;
    var buffer: [1024]bytes.Byte = undefined;
    var vector_setter = try Vector.Setter.init(allocator, &buffer);
    defer vector_setter.deinit(allocator);
    var setter = S.init(vector_setter.iterator().interface);
    var setter_iterator = S.Iterator.This.init(&setter.interface);
    const values = [_]bytes.Byte{ 0, 1, 2, 3 };
    for (0..2) |i| {
        var pair: [2]bytes.Byte = undefined;
        @memcpy(&pair, values[i * 2 .. i * 2 + 2]);
        _ = try setter_iterator.current(pair);
    }

    var vector_getter = try Vector.Getter.init(allocator, &buffer);
    defer vector_getter.deinit(allocator);
    var getter = G.init(vector_getter.iterator().interface);
    var getter_iterator = G.Iterator.This.init(&getter.interface);
    for (0..2) |i| {
        if (try getter_iterator.current()) |*pair| {
            try testing.expectEqualSlices(bytes.Byte, values[i * 2 .. i * 2 + 2], pair);
        } else return error.NullValue;
    }
}
