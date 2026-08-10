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

pub fn This(BaseIterator: type, comptime delimiter: usize) type {
    return struct {
        pub const Getter = DelimitedGetter(BaseIterator, delimiter);
        pub const Setter = DelimitedSetter(BaseIterator, delimiter);
    };
}

pub fn DelimitedSetter(BaseIterator: type, comptime delimiter: BaseIterator.ValueType) type {
    return struct {
        const Self = @This();
        pub const ValueType = Value;
        pub const StateType = State;
        pub const Value = *BaIt.Getter.This;
        pub const State = BaseIterator.StateType;
        const BaIt = it.Infer(BaseIterator);
        pub const Iterator = it.Iterator(Value, State);
        pub const Interface = Iterator.Setter.Interface;
        pub const Iterable = ib.Iterable(Iterator.ValueType, State);

        interface: Interface,
        setter: BaIt.Setter.This,

        pub fn init(setter: *BaIt.Setter.Interface) Self {
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
            };
        }

        // TODO: Implement
        fn previous(iterator: *Interface, value: Value) anyerror!?*Interface {
            _ = value;
            // const self: *Self = @fieldParentPtr("interface", iterator);
            return iterator;
        }

        fn current(iterator: *Interface, value: Value) anyerror!?*Interface {
            const self: *Self = @fieldParentPtr("interface", iterator);
            while (try value.current()) |item| _ = try self.setter.current(item);
            _ = try self.setter.current(delimiter);
            return iterator;
        }

        // TODO: Implement
        fn next(iterator: *Interface, value: Value) anyerror!?*Interface {
            _ = value;
            // const self: *Self = @fieldParentPtr("interface", iterator);
            return iterator;
        }

        fn at(iterator: *Interface, state: State, value: Value) anyerror!?*Interface {
            const self: *Self = @fieldParentPtr("interface", iterator);
            _ = try self.setter.setState(state);
            return iterator.current(iterator, value);
        }

        fn getState(iterator: *Interface) anyerror!State {
            const self: *Self = @fieldParentPtr("interface", iterator);
            return self.setter.getState();
        }

        fn setState(iterator: *Interface, state: State) anyerror!*Interface {
            const self: *Self = @fieldParentPtr("interface", iterator);
            _ = try self.setter.setState(state);
            return iterator;
        }

        fn setInitialState(iterator: *Interface) anyerror!*Interface {
            const self: *Self = @fieldParentPtr("interface", iterator);
            _ = try self.setter.setInitialState();
            return iterator;
        }

        fn setFinalState(iterator: *Interface) anyerror!*Interface {
            const self: *Self = @fieldParentPtr("interface", iterator);
            _ = try self.setter.setFinalState();
            return iterator;
        }
    };
}

pub fn DelimitedGetter(BaseIterator: type, delimiter: usize) type {
    return struct {
        const Self = @This();
        pub const ValueType = Value;
        pub const StateType = State;
        pub const State = BaseIterator.StateType;
        pub const Value = *BaIt.Getter.This;
        pub const BaIt = it.Infer(BaseIterator);
        pub const Iterator = it.Iterator(Value, State);
        pub const Interface = Iterator.Getter.Interface;
        pub const Content = ContentGetter(BaIt, delimiter);

        interface: Interface,
        getter: BaIt.Getter.This,
        allocator: mem.Allocator,

        pub fn init(allocator: mem.Allocator, getter: *BaIt.Getter.Interface) Self {
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
                .allocator = allocator,
            };
        }

        pub fn deinitContent(self: *Self, iterator: *BaIt.Getter.This) void {
            const content: *Content = @fieldParentPtr("interface", iterator.interface);
            self.allocator.destroy(content);
            self.allocator.destroy(iterator);
        }

        fn previous(iterator: *Interface) anyerror!?Value {
            var self: *Self = @fieldParentPtr("interface", iterator);
            _ = try self.getter.previous(); // Go beyond previous delimiter.
            while (try self.getter.previous()) |value| {
                // delimiter of previous content
                if (value == delimiter) {
                    _ = try self.getter.next();
                    return current(iterator);
                }
            } else return null;
        }

        fn current(iterator: *Interface) anyerror!?Value {
            var self: *Self = @fieldParentPtr("interface", iterator);
            const content = try self.allocator.create(Content);
            content.* = Content.init(self.getter.interface);
            const i = try self.allocator.create(BaIt.Getter.This);
            i.* = .init(&content.interface);
            return i;
        }

        fn next(iterator: *Interface) anyerror!?Value {
            var self: *Self = @fieldParentPtr("interface", iterator);
            while (try self.getter.next()) |value| {
                if (value == delimiter) {
                    _ = try self.getter.next();
                    return current(iterator);
                }
            } else return null;
        }

        fn at(iterator: *Interface, state: State) anyerror!?Value {
            var self: *Self = @fieldParentPtr("interface", iterator);
            _ = try self.getter.at(state);
            return current(iterator);
        }

        fn getState(iterator: *Interface) anyerror!State {
            const self: *Self = @fieldParentPtr("interface", iterator);
            return self.getter.getState();
        }

        fn setState(iterator: *Interface, state: State) anyerror!*Interface {
            const self: *Self = @fieldParentPtr("interface", iterator);
            _ = try self.getter.setState(state);
            return iterator;
        }

        fn setInitialState(iterator: *Interface) anyerror!*Interface {
            const self: *Self = @fieldParentPtr("interface", iterator);
            _ = try self.getter.setInitialState();
            return iterator;
        }

        fn setFinalState(iterator: *Interface) anyerror!*Interface {
            const self: *Self = @fieldParentPtr("interface", iterator);
            _ = try self.getter.setFinalState();
            return iterator;
        }
    };
}

pub fn ContentGetter(BaseIterator: type, delimiter: BaseIterator.ValueType) type {
    return struct {
        const Self = @This();
        pub const ValueType = Value;
        pub const StateType = State;
        pub const State = BaseIterator.StateType;
        pub const Value = BaseIterator.ValueType;
        pub const Iterator = it.Infer(BaseIterator).Getter;
        pub const Interface = Iterator.Interface;

        interface: Interface,
        getter: Iterator.This,

        pub fn init(getter: *Iterator.Interface) Self {
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
            };
        }

        fn previous(iterator: *Interface) anyerror!?Value {
            var self: *Self = @fieldParentPtr("interface", iterator);
            if (try self.getter.previous()) |value| {
                if (value == delimiter) {
                    _ = try self.getter.next();
                    return null;
                } else return value;
            } else return null;
        }

        fn current(iterator: *Interface) anyerror!?Value {
            var self: *Self = @fieldParentPtr("interface", iterator);
            if (try self.getter.current()) |value| {
                return if (value == delimiter) null else value;
            } else return null;
        }

        fn next(iterator: *Interface) anyerror!?Value {
            var self: *Self = @fieldParentPtr("interface", iterator);
            if (try self.getter.next()) |value| {
                if (value == delimiter) {
                    _ = try self.getter.previous();
                    return null;
                } else return value;
            } else return null;
        }

        fn at(iterator: *Interface, state: State) anyerror!?Value {
            var self: *Self = @fieldParentPtr("interface", iterator);
            if (try self.getter.at(state)) |value| {
                if (value == delimiter) {
                    _ = try self.getter.previous();
                    return null;
                } else return value;
            } else return null;
        }

        fn getState(iterator: *Interface) anyerror!State {
            const self: *Self = @fieldParentPtr("interface", iterator);
            return self.getter.getState();
        }

        fn setState(iterator: *Interface, state: State) anyerror!*Interface {
            const self: *Self = @fieldParentPtr("interface", iterator);
            _ = try self.getter.setState(state);
            return iterator;
        }

        fn setInitialState(iterator: *Interface) anyerror!*Interface {
            const self: *Self = @fieldParentPtr("interface", iterator);
            _ = try self.getter.setInitialState();
            return iterator;
        }

        fn setFinalState(iterator: *Interface) anyerror!*Interface {
            const self: *Self = @fieldParentPtr("interface", iterator);
            _ = try self.getter.setFinalState();
            return iterator;
        }
    };
}

test {
    const Vector = vec.This(bytes.Byte, bytes.u64_capacity);
    const It = it.Iterator(Vector.ValueType, Vector.StateType);

    const delimiter = ',';
    const Delimited = This(It, delimiter);
    const S = Delimited.Setter;
    const G = Delimited.Getter;

    const allocator = testing.allocator;
    var buffer: [1024]bytes.Byte = undefined;

    const first: []bytes.Byte = @constCast("first");
    const second: []bytes.Byte = @constCast("second");
    const third: []bytes.Byte = @constCast("third");
    const slices = [3][]u8{ first, second, third };

    var vector_setter = try Vector.Setter.init(allocator, &buffer);
    defer vector_setter.deinit(allocator);
    var setter = S.init(vector_setter.iterator().interface);
    var setter_iterator = S.Iterator.Setter.This.init(&setter.interface);

    for (slices) |slice| {
        var slice_vector = try Vector.Getter.init(allocator, slice);
        defer slice_vector.deinit(allocator);
        var slice_iterator = slice_vector.iterator();
        _ = try setter_iterator.current(&slice_iterator);
    }
    const delimited = first ++ "," ++ second ++ "," ++ third ++ ",";
    try testing.expectEqualStrings(delimited, buffer[0..delimited.len]);

    var vector_getter = try Vector.Getter.init(allocator, &buffer);
    defer vector_getter.deinit(allocator);
    var getter = G.init(allocator, vector_getter.iterator().interface);
    var getter_iterator = G.Iterator.Getter.This.init(&getter.interface);
    for (slices) |slice| {
        if (try getter_iterator.current()) |iter| {
            defer getter.deinitContent(iter);
            var slice_buffer: [16]u8 = undefined;
            var i: usize = 0;
            while (try iter.current()) |char| {
                slice_buffer[i] = char;
                i += 1;
            }
            try testing.expectEqualStrings(slice, slice_buffer[0..i]);
        } else return error.NullValue;
    }
}
