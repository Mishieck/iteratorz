const std = @import("std");

const debug = std.debug;
const mem = std.mem;
const testing = std.testing;

const in = @import("indexable.zig");
const ib = @import("iterable.zig");
const it = @import("iterator.zig");
const vec = @import("vector.zig");
const scalar = @import("scalar.zig");
pub const Mode = @import("mode.zig").Mode;

pub fn This(Value: type, comptime capacity: anytype, comptime buffer_capacity: anytype) type {
    return struct {
        pub const BufIn = Indexable(Value, capacity, buffer_capacity);
        const Ib = ib.Iterable(Value, State);
        const It = it.Iterator(Value, State);
        const In = in.Indexable(Value, buffer_capacity);
        const InIb = in.Iterable(Value, capacity);
        const State = InIb.StateType;
        pub const StateType = State;

        pub const Readable = create(.get);
        pub const Writable = create(.set);

        pub fn create(mode: Mode) type {
            return struct {
                const Self = @This();
                const Iterator = if (mode == .get) It.Readable else It.Writable;

                default_iterator: *Iterator.Default,
                indexable_iterable: *BufIn,
                buffered_indexable: *BufIn,

                pub fn init(
                    gpa: mem.Allocator,
                    slice_indexable: *BufIn.SlIn,
                    buffer: *BufIn.VecIn,
                ) !Self {
                    var buffered_indexable = try BufIn.create(gpa, slice_indexable, buffer, .get);
                    const indexable_iterable = try InIb.create(gpa, &buffered_indexable.interface);
                    const default_iterator = try Iterator.Default.create(
                        gpa,
                        &indexable_iterable.indexable,
                    );

                    return .{
                        .default_iterator = default_iterator,
                        .indexable_iterable = indexable_iterable,
                        .buffered_indexable = buffered_indexable,
                    };
                }

                pub fn deinit(self: *Self, gpa: mem.Allocator) void {
                    gpa.destroy(self.default_iterator);
                    gpa.destroy(self.indexable_iterable);
                    gpa.destroy(self.buffered_indexable);
                }

                pub fn iterator(self: *const Self) Iterator.This {
                    return .init(&self.default_iterator.interface);
                }

                pub fn iterable(self: *const Self) Ib {
                    return .init(&self.indexable_iterable.interface);
                }

                pub fn indexable(self: *const Self) In {
                    return .init(&self.buffered_indexable.interface);
                }
            };
        }
    };
}

test This {
    _ = This(u8, 16, 4);
}

pub fn Indexable(Value: type, comptime capacity: anytype, comptime buffer_capacity: anytype) type {
    return struct {
        const Self = @This();
        const In = in.Indexable(Value, capacity);
        pub const Interface = In.Interface;
        const Ib = ib.Iterable(Value, State);
        pub const SlIn = in.Indexable(Vector.Slice, capacity);
        pub const BufferCapacity = @TypeOf(buffer_capacity);
        pub const Capacity = @TypeOf(capacity);
        pub const Vector = vec.Indexable(Value, buffer_capacity);
        const State = scalar.State(Value, capacity);
        pub const StateType = State;
        pub const Buffer = in.Indexable(Value, buffer_capacity);
        pub const VecIn = vec.Indexable(Value, buffer_capacity);

        interface: Interface,
        slice_indexable: SlIn,
        slice_indexable_size: ?Capacity = null,
        vector_indexable: *VecIn,

        /// A `Vector` indexable.
        buffer: Buffer,
        buffered_size: BufferCapacity = 0,

        /// The index of the buffer in the slice_indexable.
        buffer_index: Capacity,
        mode: Mode,

        pub fn create(
            gpa: mem.Allocator,
            slice_indexable: *SlIn.Interface,
            buffer: *VecIn,
            mode: Mode,
        ) !*Self {
            const self = try gpa.create(Self);
            self.* = .init(slice_indexable, buffer, mode);
            return self;
        }

        pub fn init(slice_indexable: *SlIn.Interface, buffer: *VecIn, mode: Mode) Self {
            return .{
                .interface = .{
                    .mode = mode,
                    .get = get,
                    .set = set,
                    .size = size,
                },
                .slice_indexable = .init(slice_indexable),
                .buffer = .init(&buffer.interface),
                .vector_indexable = buffer,
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
                const buffer_slice = try self.slice_indexable.get(index);
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

            self.slice_indexable_size = @max(index + 1, self.slice_indexable_size orelse 0);
            return indexable;
        }

        fn size(indexable: *Interface) anyerror!Capacity {
            const self: *Self = @fieldParentPtr("interface", indexable);
            if (self.slice_indexable_size == null) self.slice_indexable_size = try self.slice_indexable.size();
            return self.slice_indexable_size.?;
        }

        pub fn isInsideBuffer(self: *const Self, index: Capacity) bool {
            const buffer_end_index = switch (self.mode) {
                .get => self.buffered_size,
                .set => buffer_capacity,
            };
            const end_index = self.buffer_index + buffer_end_index;
            return index >= self.buffer_index and index < end_index;
        }

        /// Gets an index in buffer from an index in slice_indexable.
        pub fn getRelativeIndex(self: *const Self, index: Capacity) Capacity {
            return index - self.buffer_index;
        }

        pub fn flush(self: *Self) anyerror!*Self {
            _ = try self.slice_indexable.set(self.buffer_index, self.buffered());
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
