//! Data structures for iterating over an array.

const std = @import("std");
const mem = std.mem;
const testing = std.testing;
const ib = @import("iterable.zig");
const it = @import("iterator.zig");
const in = @import("indexable.zig");
const Mode = @import("mode.zig").Mode;

pub fn This(Value: type, comptime capacity: anytype) type {
    return struct {
        pub const ValueType = Value;
        pub const StateType = State;
        const State = InIb.StateType;
        pub const Slice = []Value;

        const It = it.Iterator(Value, State);
        const Ib = ib.Iterable(Value, State);
        const InIb = in.Iterable(Value, capacity);
        const In = in.Indexable(Value, capacity);
        const VecIn = Indexable(Value, capacity);

        pub const Getter = create(.get);
        pub const Setter = create(.set);

        fn create(comptime mode: Mode) type {
            return struct {
                const Self = @This();
                const Iterator = if (mode == .get) It.Getter else It.Setter;

                default_iterator: *Iterator.Default,
                indexable_iterable: *InIb,
                vector_indexable: *VecIn,

                /// Creates utilities for a vector. Free memory using `deinit`.
                pub fn init(gpa: mem.Allocator, slice: VecIn.Slice) !Self {
                    const vector_indexable = try VecIn.create(gpa, slice, .get);
                    const indexable_iterable = try InIb.create(gpa, &vector_indexable.interface);
                    const default_iterator = try Iterator.Default.create(
                        gpa,
                        &indexable_iterable.interface,
                    );

                    return .{
                        .default_iterator = default_iterator,
                        .indexable_iterable = indexable_iterable,
                        .vector_indexable = vector_indexable,
                    };
                }

                pub fn deinit(self: *Self, gpa: mem.Allocator) void {
                    gpa.destroy(self.default_iterator);
                    gpa.destroy(self.indexable_iterable);
                    gpa.destroy(self.vector_indexable);
                }

                pub fn iterator(self: *const Self) Iterator.This {
                    return .init(&self.default_iterator.interface);
                }

                pub fn iterable(self: *const Self) Ib {
                    return .init(&self.indexable_iterable.interface);
                }

                pub fn indexable(self: *const Self) In {
                    return .init(&self.vector_indexable.interface);
                }
            };
        }
    };
}

test This {
    const Bytes = This(u8, @as(u8, 5));
    const allocator = testing.allocator;

    const slice: []u8 = @constCast("hello");
    var getter_bytes = try Bytes.Getter.init(allocator, slice);
    defer getter_bytes.deinit(allocator);
    var getter_iterator = getter_bytes.iterator();
    var iterated: [slice.len]u8 = undefined;

    var i: usize = 0;
    while (try getter_iterator.current()) |char| {
        iterated[i] = char;
        i += 1;
    }

    try testing.expectEqualStrings(slice, &iterated);

    var buffer: [slice.len]u8 = undefined;
    var setter_bytes = try Bytes.Setter.init(allocator, &buffer);
    defer setter_bytes.deinit(allocator);
    var setter_iterator = setter_bytes.iterator();
    for (slice) |char| _ = try setter_iterator.current(char);
    try testing.expectEqualStrings(slice, &buffer);
}

pub fn Indexable(Value: type, comptime capacity: anytype) type {
    return struct {
        const Self = @This();
        pub const Capacity = @TypeOf(capacity);
        pub const In = in.Indexable(Value, capacity);
        pub const Interface = In.Interface;
        pub const Slice = []Value;

        interface: Interface,
        slice: Slice,

        pub fn create(gpa: mem.Allocator, slice: Slice, mode: Mode) !*Self {
            const self = try gpa.create(Self);
            self.* = .init(slice, mode);
            return self;
        }

        pub fn init(slice: Slice, mode: Mode) Self {
            return .{
                .interface = .{
                    .mode = mode,
                    .get = get,
                    .set = set,
                    .size = size,
                },
                .slice = slice,
            };
        }

        pub fn get(indexable: *Interface, index: Capacity) anyerror!Value {
            const self: *Self = @fieldParentPtr("interface", indexable);
            return self.slice[index];
        }

        pub fn set(indexable: *Interface, index: Capacity, value: Value) anyerror!*Interface {
            var self: *Self = @fieldParentPtr("interface", indexable);
            self.slice[index] = value;
            return indexable;
        }

        pub fn size(indexable: *Interface) anyerror!Capacity {
            const self: *Self = @fieldParentPtr("interface", indexable);
            return @truncate(self.slice.len);
        }
    };
}
