//! Data structures for iterating over an array.

const std = @import("std");
const mem = std.mem;
const debug = std.debug;
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
        const MemIn = Indexable(Value, capacity);

        pub const Getter = create(.get);
        pub const Setter = create(.set);

        fn create(comptime mode: Mode) type {
            return struct {
                const Self = @This();
                const Iterator = if (mode == .get) It.Getter else It.Setter;

                default_iterator: *Iterator.Default,
                indexable_iterable: *InIb,
                memory_indexable: *MemIn,

                /// Creates utilities for a memory. Free memory using `deinit`.
                pub fn init(gpa: mem.Allocator) !Self {
                    const memory_indexable = try MemIn.create(gpa, mode);
                    const indexable_iterable = try InIb.create(gpa, &memory_indexable.interface);
                    const default_iterator = try Iterator.Default.create(
                        gpa,
                        &indexable_iterable.interface,
                    );

                    return .{
                        .default_iterator = default_iterator,
                        .indexable_iterable = indexable_iterable,
                        .memory_indexable = memory_indexable,
                    };
                }

                pub fn toggleMode(self: *const Self, gpa: mem.Allocator) !create(mode.toggle()) {
                    const New = create(mode.toggle());
                    var new = try New.init(gpa);
                    var old_memory_indexable = new.memory_indexable;
                    old_memory_indexable.deinit();
                    gpa.destroy(old_memory_indexable);
                    const new_memory_indexable = try gpa.create(MemIn);
                    new_memory_indexable.* = self.memory_indexable.toggleMode();
                    new.memory_indexable = new_memory_indexable;
                    new.indexable_iterable.indexable = .init(&new_memory_indexable.interface);
                    return new;
                }

                pub fn deinit(self: *Self, gpa: mem.Allocator) void {
                    gpa.destroy(self.default_iterator);
                    gpa.destroy(self.indexable_iterable);
                    self.memory_indexable.deinit();
                    gpa.destroy(self.memory_indexable);
                }

                pub fn iterator(self: *const Self) Iterator.This {
                    return .init(&self.default_iterator.interface);
                }

                pub fn iterable(self: *const Self) Ib {
                    return .init(&self.indexable_iterable.interface);
                }

                pub fn indexable(self: *const Self) In {
                    return .init(&self.memory_indexable.interface);
                }
            };
        }
    };
}

test This {
    const Bytes = This(u8, @as(u8, 5));
    const allocator = testing.allocator;

    const slice = "hello";

    var bytes_setter = try Bytes.Setter.init(allocator);
    defer bytes_setter.deinit(allocator);
    var setter_iterator = bytes_setter.iterator();
    for (slice) |char| _ = try setter_iterator.current(char);

    var bytes_getter = try bytes_setter.toggleMode(allocator);
    defer bytes_getter.deinit(allocator);
    var getter_iterator = bytes_getter.iterator();
    var iterated: [slice.len]u8 = undefined;

    var i: usize = 0;
    while (try getter_iterator.current()) |char| {
        iterated[i] = char;
        i += 1;
    }

    try testing.expectEqual(bytes_setter.memory_indexable.list, bytes_getter.memory_indexable.list);
    try testing.expectEqualStrings(slice, &iterated);
}

pub fn Indexable(Value: type, comptime capacity: anytype) type {
    return struct {
        const Self = @This();
        pub const Capacity = @TypeOf(capacity);
        pub const In = in.Indexable(Value, capacity);
        pub const Interface = In.Interface;
        pub const List = std.array_list.Managed(Value);

        interface: Interface,
        list: *List,
        has_adopted_list: bool = false,

        pub fn create(gpa: mem.Allocator, mode: Mode) !*Self {
            const self = try gpa.create(Self);
            self.* = try .init(gpa, mode);
            return self;
        }

        pub fn init(gpa: mem.Allocator, mode: Mode) !Self {
            const list = try gpa.create(List);
            list.* = .init(gpa);

            return .{
                .interface = .{
                    .mode = mode,
                    .get = get,
                    .set = set,
                    .size = size,
                },
                .list = list,
                .has_adopted_list = false,
            };
        }

        pub fn toggleMode(self: *const Self) Self {
            return .{
                .interface = .{
                    .mode = self.interface.mode.toggle(),
                    .get = get,
                    .set = set,
                    .size = size,
                },
                .list = self.list,
                .has_adopted_list = true,
            };
        }

        pub fn deinit(self: *Self) void {
            if (self.has_adopted_list) return;
            self.list.deinit();
            self.list.allocator.destroy(self.list);
        }

        pub fn get(indexable: *Interface, index: Capacity) anyerror!Value {
            const self: *Self = @fieldParentPtr("interface", indexable);
            return self.list.items[index];
        }

        pub fn set(indexable: *Interface, index: Capacity, value: Value) anyerror!*Interface {
            var self: *Self = @fieldParentPtr("interface", indexable);

            if (index < self.list.items.len) {
                _ = self.list.orderedRemove(index);
                try self.list.insert(index, value);
            } else if (index == self.list.items.len) {
                try self.list.append(value);
            } else {
                try self.list.resize(index + 1);
                try self.list.insert(index, value);
            }

            return indexable;
        }

        pub fn size(indexable: *Interface) anyerror!Capacity {
            const self: *Self = @fieldParentPtr("interface", indexable);
            return @truncate(self.list.items.len);
        }
    };
}
