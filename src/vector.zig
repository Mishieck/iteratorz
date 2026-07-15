const std = @import("std");
const testing = std.testing;
const ib = @import("iterable.zig");
const it = @import("iterator.zig");
const in = @import("indexable.zig");

pub fn Iterator(Value: type, comptime capacity: anytype) type {
    return struct {
        pub const ValueType = Value;
        pub const StateType = State;
        const State = InIt.StateType;
        pub const Slice = []Value;

        const It = it.Iterator(Value, State);
        const InIt = in.Iterator(Value, capacity);
        const In = Indexable(Value, capacity);
        const VecIb = Iterable(Value, capacity);

        pub const Readable = struct {
            pub inline fn init(slice: In.Slice) It.Readable.This {
                return It.Readable.This.init(
                    @constCast(
                        &It.Readable.Default.init(VecIb.init(slice, .get).interface).interface,
                    ),
                );
            }
        };

        pub const Writable = struct {
            pub inline fn init(slice: In.Slice) It.Writable.This {
                return It.Writable.This.init(
                    @constCast(
                        &It.Writable.Default.init(@constCast(&VecIb.init(slice, .set))).interface,
                    ),
                );
            }
        };
    };
}

test Iterator {
    const Bytes = Iterator(u8, @as(u8, 5));

    const slice: []u8 = @constCast("hello");
    var readable_bytes = Bytes.Readable.init(slice);
    var iterated: [slice.len]u8 = undefined;

    var i: usize = 0;
    while (try readable_bytes.current()) |char| {
        iterated[i] = char;
        i += 1;
    }

    try testing.expectEqualStrings(slice, &iterated);

    var buffer: [slice.len]u8 = undefined;
    var writable_bytes = Bytes.Writable.init(&buffer);
    for (slice) |char| _ = try writable_bytes.current(char);
    try testing.expectEqualStrings(slice, &buffer);
}

pub fn Iterable(Value: type, comptime capacity: anytype) type {
    return struct {
        const Self = @This();
        pub const ValueType = Value;
        pub const StateType = InIb.StateType;
        pub const InIb = in.Iterable(Value, capacity);
        pub const Ib = ib.Iterable(Value, StateType);
        const VecIn = Indexable(Value, capacity);

        pub inline fn init(slice: VecIn.Slice, mode: in.Mode) Ib {
            return .init(
                @constCast(&InIb.init(@constCast(&VecIn.init(slice, mode).interface)).interface),
            );
        }
    };
}

pub fn Indexable(Value: type, comptime capacity: anytype) type {
    return struct {
        const Self = @This();
        pub const Capacity = @TypeOf(capacity);
        pub const In = in.Collection(Value, capacity);
        pub const Interface = In.Interface;
        pub const Slice = []Value;

        interface: Interface,
        slice: Slice,

        pub fn init(slice: Slice, mode: in.Mode) Self {
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
