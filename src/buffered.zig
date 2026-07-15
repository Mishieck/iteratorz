const std = @import("std");

const debug = std.debug;
const testing = std.testing;

const in = @import("indexable.zig");
const ib = @import("iterable.zig");
const it = @import("iterator.zig");
const vec = @import("vector.zig");
const scalar = @import("scalar.zig");

pub const Mode = in.Mode;

pub fn Iterator(Value: type, comptime capacity: anytype, comptime buffer_capacity: anytype) type {
    return struct {
        pub const BufIn = Indexable(Value, capacity, buffer_capacity);
        const InIt = in.Iterator(Value, capacity);
        const Ib = ib.Iterable(Value, State);
        const It = it.Iterator(Value, State);
        const In = in.Collection(Value, buffer_capacity);
        const State = InIt.StateType;
        pub const StateType = State;

        pub const Readable = struct {
            pub inline fn init(collection: *BufIn.Collection, buffer: *In.Interface) It.Readable.This {
                var buf_in = BufIn.init(collection, buffer, .get);
                return InIt.Readable.init(&buf_in.interface);
            }
        };

        pub const Writable = struct {
            pub inline fn init(collection: *BufIn.Collection, buffer: *In.Interface) It.Writable.This {
                var buf_in = BufIn.init(collection, buffer, .set);
                return InIt.Writable.init(&buf_in.interface);
            }
        };
    };
}

test Iterator {
    _ = Iterator(u8, 16, 4);
}

pub fn Iterable(Value: type, comptime capacity: anytype, comptime buffer_capacity: anytype) type {
    return struct {
        const In = in.Collection(Value, capacity);
        pub const BufIn = Indexable(Value, capacity, buffer_capacity);
        const InIb = in.Iterable(Value, capacity);
        const Ib = ib.Iterable(Value, State);
        const State = InIb.StateType;
        pub const StateType = State;

        pub inline fn init(collection: *BufIn.Collection, buffer: *In.Interface, mode: Mode) Ib {
            var buf_in = BufIn.init(collection, buffer, mode);
            var in_ib = InIb.init(&buf_in.interface);
            return Ib.init(&in_ib.interface);
        }
    };
}

test Iterable {
    _ = Iterable(u8, 16, 4);
}

pub fn Indexable(Value: type, comptime capacity: anytype, comptime buffer_capacity: anytype) type {
    return struct {
        const Self = @This();
        const In = in.Collection(Value, capacity);
        pub const Interface = In.Interface;
        const Ib = ib.Iterable(Value, State);
        pub const Collection = in.Collection(Vector.Slice, capacity);
        pub const BufferCapacity = @TypeOf(buffer_capacity);
        pub const Capacity = @TypeOf(capacity);
        pub const Vector = vec.Indexable(Value, buffer_capacity);
        const State = scalar.State(Value, capacity);
        pub const StateType = State;
        pub const Buffer = in.Collection(Value, buffer_capacity);

        interface: Interface,
        collection: *Collection,
        collection_size: ?Capacity = null,

        /// A `Vector` indexable.
        buffer: Buffer,
        buffered_size: BufferCapacity = 0,

        /// The index of the buffer in the collection.
        buffer_index: Capacity,
        mode: Mode,

        pub fn init(
            collection: *Collection,
            /// An `Indexable` interface for ``vector.Indexable`.
            buffer: *Buffer.Interface,
            mode: Mode,
        ) Self {
            return .{
                .interface = .{
                    .mode = mode,
                    .get = get,
                    .set = set,
                    .size = size,
                },
                .collection = collection,
                .buffer = .init(buffer),
                .buffer_index = 0,
                .mode = mode,
            };
        }

        fn get(indexable: *Interface, index: Capacity) anyerror!Value {
            const self: *Self = @fieldParentPtr("interface", indexable);

            return try if (self.isInsideBuffer(index)) get_from_buffer: {
                const relative_index = index - self.buffer_index;
                break :get_from_buffer self.buffer.get(@truncate(relative_index));
            } else refill_buffer: {
                const buffer_slice = try self.collection.get(index);
                self.buffered_size = @truncate(buffer_slice.len);
                break :refill_buffer self.buffer.get(0);
            };
        }

        fn set(indexable: *Interface, index: Capacity, value: Value) anyerror!*Interface {
            var self: *Self = @fieldParentPtr("interface", indexable);

            if (self.isInsideBuffer(index)) {
                const relative_index = self.getRelativeIndex(index);
                self.buffered_size = @max(self.buffered_size, @as(BufferCapacity, @truncate(relative_index + 1)));
                _ = try self.buffer.set(@truncate(relative_index), value);
            } else {
                _ = try self.flush();
                _ = try self.buffer.set(0, value);
                self.buffered_size = 1;
            }

            self.collection_size = @max(index + 1, self.collection_size orelse 0);
            return indexable;
        }

        fn size(indexable: *Interface) anyerror!Capacity {
            const self: *Self = @fieldParentPtr("interface", indexable);
            if (self.collection_size == null) self.collection_size = try self.collection.size();
            return self.collection_size.?;
        }

        pub fn isInsideBuffer(self: *const Self, index: Capacity) bool {
            const buffer_end_index = switch (self.mode) {
                .get => self.buffered_size,
                .set => buffer_capacity,
            };
            const end_index = self.buffer_index + buffer_end_index;
            return index >= self.buffer_index and index < end_index;
        }

        /// Gets an index in buffer from an index in collection.
        pub fn getRelativeIndex(self: *const Self, index: Capacity) Capacity {
            return index - self.buffer_index;
        }

        pub fn flush(self: *Self) anyerror!*Self {
            _ = try self.collection.set(self.buffer_index, self.buffered());
            self.buffer_index += self.buffered_size;
            self.buffered_size = 0;
            return self;
        }

        pub fn buffered(self: *const Self) Vector.Slice {
            const vector: *Vector = @fieldParentPtr("interface", self.buffer.interface);
            return vector.slice[0..self.buffered_size];
        }
    };
}

test Indexable {
    _ = Indexable(u8, 16, 4);
}
