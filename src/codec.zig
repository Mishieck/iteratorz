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
const scalar = @import("scalar.zig");

pub fn This(
    BaseIterator: type,
    encode: anytype,
    decode: anytype,
    getLength: *const GetLength(BaseIterator),
) type {
    return struct {
        pub const Getter = Encoder(BaseIterator, encode, getLength);
        pub const Setter = Decoder(BaseIterator, decode, getLength);
    };
}

pub fn Encoder(
    BaseIterator: type,
    encode: anytype,
    getLength: *const GetLength(BaseIterator),
) type {
    return struct {
        const Self = @This();
        pub const ValueType = Value;
        pub const StateType = BaseIterator.StateType;
        const State = StateType;
        pub const Value = @typeInfo(@TypeOf(encode)).@"fn".params[1].type.?;
        pub const Iterator = it.Iterator(Value, State);
        pub const BaIt = it.Iterator(BaseIterator.ValueType, BaseIterator.StateType);
        pub const Interface = Iterator.Setter.Interface;
        const encodeValue: Encode(BaIt, Value) = encode;

        interface: Interface,
        setter: BaIt.Setter.This,
        getter: BaIt.Getter.This,
        iterable: ib.Iterable(BaIt.ValueType, BaIt.StateType),
        state: State = .initial,

        pub fn init(setter: *BaIt.Setter.Interface, getter: *BaIt.Getter.Interface) Self {
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
                .getter = .init(getter),
                .iterable = setter_default.iterable,
            };
        }

        fn previous(iterator: *Interface, value: Value) anyerror!?*Interface {
            const self: *Self = @fieldParentPtr("interface", iterator);
            var state = try self.iterable.getState();
            state = state.getPrevious();

            while (self.iterable.setState(state)) |_| {
                const length = try getLength(&self.getter);
                if (length > 0) {
                    _ = try self.iterable.setState(state);
                    _ = try encodeValue(&self.setter, value);
                    self.state = self.state.getPrevious();
                    return iterator;
                }
                state = state.getPrevious();
            } else |err| return err;

            return iterator;
        }

        fn current(iterator: *Interface, value: Value) anyerror!?*Interface {
            const self: *Self = @fieldParentPtr("interface", iterator);
            _ = try encodeValue(&self.setter, value);
            self.state = self.state.getNext();
            return iterator;
        }

        fn next(iterator: *Interface, value: Value) anyerror!?*Interface {
            const self: *Self = @fieldParentPtr("interface", iterator);
            var state = try self.iterable.getState();
            state = state.getNext();

            while (self.iterable.setState(state)) |_| {
                const length = try getLength(&self.getter);
                if (length > 0) {
                    _ = try self.iterable.setState(state);
                    _ = try encodeValue(&self.setter, value);
                    self.state = self.state.getNext();
                    return iterator;
                }
                state = state.getNext();
            } else |err| return err;

            return iterator;
        }

        fn at(iterator: *Interface, state: State, value: Value) anyerror!?*Interface {
            const self: *Self = @fieldParentPtr("interface", iterator);
            _ = try self.iterable.setInitialState();
            var iterable_state = try self.iterable.getState();
            self.state = .initial;

            while (getLength(&self.getter)) |length| {
                if (length > 0) {
                    if (iterable_state.valid == state.valid) {
                        _ = try encodeValue(&self.setter, value);
                        _ = try self.iterable.setState(iterable_state);
                        return iterator;
                    }
                    iterable_state = .{ .valid = iterable_state.valid + length };
                    self.state = self.state.getNext();
                }
            } else |err| return err;

            return iterator;
        }

        fn getState(iterator: *Interface) anyerror!State {
            const self: *Self = @fieldParentPtr("interface", iterator);
            return self.state;
        }

        fn setState(iterator: *Interface, state: State) anyerror!*Interface {
            const self: *Self = @fieldParentPtr("interface", iterator);
            self.state = state;
            var i: usize = 0;
            var iterable_state = State.initial;

            while (getLength(&self.getter)) |length| {
                if (length > 0) {
                    if (i == self.state.valid) _ = try self.iterable.setState(iterable_state);
                    iterable_state = .{ .valid = iterable_state.valid + length };
                    i += 1;
                }
            } else |err| return err;

            return iterator;
        }

        fn setInitialState(iterator: *Interface) anyerror!*Interface {
            const self: *Self = @fieldParentPtr("interface", iterator);
            _ = try self.iterable.setInitialState();
            self.state = .initial;
            return iterator;
        }

        fn setFinalState(iterator: *Interface) anyerror!*Interface {
            const self: *Self = @fieldParentPtr("interface", iterator);
            _ = try self.iterable.setFinalState();
            self.state = .final;
            return iterator;
        }
    };
}

test Encoder {
    const Vector = vec.This(u8, bytes.u64_capacity);
    const It = it.Iterator(Vector.ValueType, Vector.StateType);
    const Enc = Encoder(It, enc, getU32Length);

    const allocator = testing.allocator;
    var buffer: [1024]u8 = undefined;
    var vector_setter = try Vector.Setter.init(allocator, &buffer);
    defer vector_setter.deinit(allocator);
    const setter = vector_setter.iterator();
    var vector_getter = try Vector.Getter.init(allocator, &buffer);
    defer vector_getter.deinit(allocator);
    const getter = vector_getter.iterator();
    var encoder = Enc.init(setter.interface, getter.interface);
    var encoder_iterator = Enc.Iterator.Setter.This.init(&encoder.interface);
    const values = [_]u32{ 1, 128 };
    for (values) |value| _ = try encoder_iterator.current(value);
    try testing.expectEqualSlices(u8, &.{ 0b10000000, 1, 0b11000000, 0, 1 }, buffer[0..5]);
}

pub fn Encode(Iterator: type, Value: type) type {
    return fn (setter: *Iterator.Setter.This, value: Value) anyerror!*Iterator.Setter.This;
}

pub fn enc(setter: *TestSetter.This, value: u32) anyerror!*TestSetter.This {
    const length: usize = switch (value) {
        0...~@as(u7, 0) => 1,
        128...~@as(u14, 0) => 2,
        @as(u15, ~@as(u14, 0)) + 1...~@as(u21, 0) => 3,
        else => 4,
    };

    const length_indicator = ~@as(u8, 0) << @truncate(8 - length);
    _ = try setter.current(length_indicator);
    for (0..length) |i| _ = try setter.current(
        @truncate((value >> (7 * @as(u5, @truncate(i)))) & 0b01111111),
    );

    return setter;
}

pub fn Decoder(BaseIterator: type, decode: anytype, getLength: GetLength(BaseIterator)) type {
    return struct {
        const Self = @This();
        pub const ValueType = Value;
        pub const StateType = BaseIterator.StateType;
        const State = StateType;
        const ReturnType = @typeInfo(@TypeOf(decode)).@"fn".return_type.?;
        pub const Value = @typeInfo(ReturnType).error_union.payload;
        pub const Iterator = it.Iterator(Value, State).Getter;
        pub const BaIt = it.Iterator(BaseIterator.ValueType, BaseIterator.StateType);
        pub const Interface = Iterator.Interface;
        const decodeValue: Decode(BaIt, Value) = decode;

        interface: Interface,
        getter: BaIt.Getter.This,
        iterable: ib.Iterable(BaseIterator.ValueType, BaseIterator.StateType),
        state: State = .initial,

        pub fn init(getter: *BaIt.Getter.Interface) Self {
            const setter_default: *BaIt.Getter.Default = @fieldParentPtr("interface", getter);

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
            var iterable_state = try self.iterable.getState();
            iterable_state = iterable_state.getPrevious();
            _ = try self.iterable.setNextState();

            while (getLength(&self.getter)) |length| {
                if (length > 0) {
                    _ = try self.iterable.setState(iterable_state);
                    self.state = self.state.getPrevious();
                    const value = try decodeValue(&self.getter);
                    return value;
                }
                iterable_state = iterable_state.getPrevious();
            } else |err| return err;

            return null;
        }

        fn current(iterator: *Interface) anyerror!?Value {
            const self: *Self = @fieldParentPtr("interface", iterator);
            const value = try decodeValue(&self.getter);
            return value;
        }

        fn next(iterator: *Interface) anyerror!?Value {
            var self: *Self = @fieldParentPtr("interface", iterator);
            var iterable_state = try self.iterable.getState();
            iterable_state = iterable_state.getNext();
            _ = try self.iterable.setNextState();

            while (getLength(&self.getter)) |length| {
                if (length > 0) {
                    _ = try self.iterable.setState(iterable_state);
                    self.state = self.state.getNext();
                    const value = try decodeValue(&self.getter);
                    return value;
                }
                iterable_state = iterable_state.getNext();
            } else |err| return err;

            return null;
        }

        fn at(iterator: *Interface, state: State) anyerror!?Value {
            var self: *Self = @fieldParentPtr("interface", iterator);
            const i = state.valid;
            var j = State.initial;
            _ = try self.iterable.setInitialState();
            var iterable_state = State.initial;

            while (getLength(&self.getter)) |length| {
                if (length > 0) {
                    if (i == j.valid) {
                        self.state = j;
                        _ = try self.iterable.setState(iterable_state);
                        const value = try decodeValue(&self.getter);
                        return value;
                    }
                    j = j.getNext();
                }

                iterable_state = iterable_state.getNext();
            } else |err| return err;

            return null;
        }

        fn getState(iterator: *Interface) anyerror!State {
            const self: *Self = @fieldParentPtr("interface", iterator);
            return self.state;
        }

        fn setState(iterator: *Interface, state: State) anyerror!*Interface {
            const self: *Self = @fieldParentPtr("interface", iterator);
            self.state = state;
            var i: usize = 0;
            var iterable_state = State.initial;

            while (getLength(&self.getter)) |length| {
                if (length > 0) {
                    if (i == self.state.valid) _ = try self.iterable.setState(iterable_state);
                    iterable_state = .{ .valid = iterable_state.valid + length };
                    i += 1;
                }
            } else |err| return err;

            return iterator;
        }

        fn setInitialState(iterator: *Interface) anyerror!*Interface {
            const self: *Self = @fieldParentPtr("interface", iterator);
            _ = try self.iterable.setInitialState();
            self.state = .initial;
            return iterator;
        }

        fn setFinalState(iterator: *Interface) anyerror!*Interface {
            const self: *Self = @fieldParentPtr("interface", iterator);
            _ = try self.iterable.setFinalState();
            self.state = .final;
            return iterator;
        }
    };
}

test Decoder {
    const Vector = vec.This(u8, bytes.u64_capacity);
    const It = it.Iterator(Vector.ValueType, Vector.StateType);
    const Dec = Decoder(It, dec, getU32Length);

    const allocator = testing.allocator;
    var buffer: [1024]u8 = undefined;
    var vector_setter = try Vector.Setter.init(allocator, &buffer);
    defer vector_setter.deinit(allocator);
    var setter = vector_setter.iterator();
    const values = [_]u8{ 0b10000000, 1, 0b11000000, 0, 1 };
    for (values) |value| _ = try setter.current(value);

    var vector_getter = try Vector.Getter.init(allocator, &buffer);
    defer vector_getter.deinit(allocator);
    const getter = vector_getter.iterator();
    var decoder = Dec.init(getter.interface);
    var decoder_iterator = Dec.Iterator.This.init(&decoder.interface);
    var decoded: [2]u32 = undefined;
    for (0..decoded.len) |i| decoded[i] = (try decoder_iterator.current()).?;
    try testing.expectEqualSlices(u32, &.{ 1, 128 }, &decoded);
}

const TestIterator = it.Iterator(bytes.Byte, scalar.State(u64, bytes.u64_capacity));
const TestGetter = TestIterator.Getter;
const TestSetter = TestIterator.Setter;

pub fn Decode(Iterator: type, Value: type) type {
    return fn (iterator: *Iterator.Getter.This) anyerror!Value;
}

pub fn dec(getter: *TestGetter.This) anyerror!u32 {
    const length: usize = if (try getter.current()) |byte| switch (byte) {
        0b10000000 => 1,
        0b11000000 => 2,
        0b11100000 => 3,
        0b11110000 => 4,
        else => return error.InvalidValue,
    } else return error.InvalidState;

    var value: u32 = 0;
    for (0..length) |i| if (try getter.current()) |byte| {
        value |= byte << @truncate(i * 7);
    } else return error.InvalidState;
    return value;
}

pub fn getU32Length(iterator: *TestGetter.This) anyerror!usize {
    return if (try iterator.current()) |byte| switch (byte) {
        0b10000000 => 1,
        0b11000000 => 2,
        0b11100000 => 3,
        0b11110000 => 4,
        else => 0,
    } else error.InvalidState;
}

/// Gets the length of an encoded value. A length of `0` means that the byte at
/// the current state of the `iterator` is not the start of a value. If the
/// current value of the iterator is `null`, it returns `error.InvalidState`.
pub fn GetLength(Iterator: type) type {
    return fn (iterator: *Iterator.Getter.This) anyerror!usize;
}
