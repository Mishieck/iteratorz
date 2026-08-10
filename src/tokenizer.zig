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

pub fn This(BaseIterator: type) type {
    return struct {
        pub const Getter = Tokenizer(BaseIterator);
        pub const Setter = Detokenizer(BaseIterator);
    };
}

test This {
    const Vector = vec.This(u8, bytes.u64_capacity);
    const It = it.Iterator(Vector.ValueType, Vector.StateType);
    const T = This(It);
    _ = T.Getter;
    _ = T.Setter;
}

pub fn Detokenizer(BaseIterator: type) type {
    return struct {
        const Self = @This();
        pub const ValueType = Value;
        pub const StateType = BaseIterator.StateType;
        const Value = []const BaseIterator.ValueType;
        const State = StateType;
        const BaIt = it.Infer(BaseIterator);
        pub const Iterator = it.Iterator(Value, State);
        pub const Interface = Iterator.Setter.Interface;
        pub const Iterable = ib.Iterable(Value, State);

        interface: Interface,
        setter: BaIt.Setter.This,
        getter: BaIt.Getter.This,

        pub fn init(setter: *BaIt.Setter.Interface, getter: *BaIt.Getter.Interface) Self {
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
            };
        }

        fn previous(iterator: *Interface, value: Value) anyerror!?*Interface {
            _ = value;
            return iterator;
        }

        fn current(iterator: *Interface, value: Value) anyerror!?*Interface {
            const self: *Self = @fieldParentPtr("interface", iterator);
            for (value) |val| _ = try self.setter.current(val);
            return iterator;
        }

        fn next(iterator: *Interface, value: Value) anyerror!?*Interface {
            _ = value;
            return iterator;
        }

        fn at(iterator: *Interface, state: State, value: Value) anyerror!?*Interface {
            _ = state;
            _ = value;
            return iterator;
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

test Detokenizer {
    const Vector = vec.This(u8, bytes.u64_capacity);
    const It = it.Iterator(Vector.ValueType, Vector.StateType);
    const Dt = Detokenizer(It);

    const allocator = testing.allocator;
    var buffer: [1024]u8 = undefined;
    var vector_setter = try Vector.Setter.init(allocator, &buffer);
    defer vector_setter.deinit(allocator);
    const setter = vector_setter.iterator();
    var vector_getter = try Vector.Getter.init(allocator, &buffer);
    defer vector_getter.deinit(allocator);
    const getter = vector_getter.iterator();
    var detokenizer = Dt.init(setter.interface, getter.interface);
    var detokenizer_iterator = Dt.Iterator.Setter.This.init(&detokenizer.interface);
    const values = [_]bytes.Bytes{ "Hello", ", ", "world", "!" };
    var length: usize = 0;
    for (values) |value| {
        _ = try detokenizer_iterator.current(value);
        length += value.len;
    }
    try testing.expectEqualStrings("Hello, world!", buffer[0..length]);
}

pub fn Tokenizer(BaseIterator: type) type {
    return struct {
        const Self = @This();
        pub const ValueType = Value;
        pub const StateType = BaseIterator.StateType;
        pub const Value = []const BaseIterator.ValueType;
        const State = StateType;
        const BaIt = it.Infer(BaseIterator);
        pub const Iterator = it.Iterator(Value, State);
        pub const Interface = Iterator.Getter.Interface;
        const Tok = Tokenize(BaseIterator);

        interface: Interface,
        getter: BaIt.Getter.This,
        allocator: mem.Allocator,
        tokenize: *Tok,

        pub fn init(allocator: mem.Allocator, getter: *BaIt.Getter.Interface, tokenize: *Tok) Self {
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
                .tokenize = tokenize,
            };
        }

        fn previous(iterator: *Interface) anyerror!?Value {
            _ = iterator;
            // var self: *Self = @fieldParentPtr("interface", iterator);
            return null;
        }

        fn current(iterator: *Interface) anyerror!?Value {
            const self: *Self = @fieldParentPtr("interface", iterator);
            const slice = try self.tokenize.call(self.tokenize, self.allocator, &self.getter);
            _ = try self.getter.previous();
            return slice;
        }

        fn next(iterator: *Interface) anyerror!?Value {
            _ = iterator;
            // var self: *Self = @fieldParentPtr("interface", iterator);
            return null;
        }

        fn at(iterator: *Interface, state: State) anyerror!?Value {
            _ = iterator;
            _ = state;
            // var self: *Self = @fieldParentPtr("interface", iterator);
            return null;
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

test Tokenizer {
    const Vector = vec.This(u8, bytes.u64_capacity);
    const It = it.Iterator(Vector.ValueType, Vector.StateType);
    const Tk = Tokenizer(It);

    const allocator = testing.allocator;
    var buffer: [1024]u8 = undefined;
    const values = [_]bytes.Bytes{ "Hello", ", ", "world", "!" };
    var vector_setter = try Vector.Setter.init(allocator, &buffer);
    defer vector_setter.deinit(allocator);
    var setter = vector_setter.iterator();
    var length: usize = 0;
    for (values) |slice| {
        for (slice) |char| _ = try setter.current(char);
        length += slice.len;
    }

    var vector_getter = try Vector.Getter.init(allocator, buffer[0..length]);
    defer vector_getter.deinit(allocator);
    const getter = vector_getter.iterator();
    var tokenizer = Tk.init(allocator, getter.interface, @constCast(&word_tokenizer));
    var tokenizer_iterator = Tk.Iterator.Getter.This.init(&tokenizer.interface);
    for (0..values.len) |i| {
        const tokenized = (try tokenizer_iterator.current()).?;
        defer allocator.free(tokenized);
        try testing.expectEqualStrings(values[i], tokenized);
    }
}

const TestIterator = it.Iterator(bytes.Byte, scalar.State(u64, bytes.u64_capacity));
const TestGetter = TestIterator.Getter;
const TestSetter = TestIterator.Setter;

pub const WordTokenizer = Tokenize(TestIterator);
pub const word_tokenizer = WordTokenizer{ .call = getWord };

pub fn getWord(
    tokenizer: *WordTokenizer,
    allocator: mem.Allocator,
    getter: *TestGetter.This,
) anyerror!?[]const bytes.Byte {
    _ = tokenizer;
    if (try getter.current()) |first_char| {
        var list = std.array_list.Managed(bytes.Byte).init(allocator);
        defer list.deinit();
        try list.append(first_char);

        if (std.ascii.isAlphanumeric(first_char)) {
            while (try getter.current()) |char| {
                if (std.ascii.isAlphanumeric(char)) try list.append(char) else break;
            }
        } else {
            while (try getter.current()) |char| {
                if (std.ascii.isAlphanumeric(char)) break else try list.append(char);
            }
        }

        return try allocator.dupe(bytes.Byte, list.items);
    } else return null;
}

/// A closure for tokenizing.
pub fn Tokenize(Iterator: type) type {
    return struct {
        const Self = @This();

        call: *const fn (
            self: *Self,
            allocator: mem.Allocator,
            iterator: *Iterator.Getter.This,
        ) anyerror!?[]const Iterator.ValueType,
    };
}
