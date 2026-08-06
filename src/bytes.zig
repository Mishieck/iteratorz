const std = @import("std");
const testing = std.testing;
const debug = std.debug;
const math = std.math;
const mem = std.mem;
const builtin = std.builtin;
const ArrayList = std.array_list.Managed;

const arrayz = @import("arrayz");
const scalar = @import("scalar.zig");
const it = @import("iterator.zig");
const vec = @import("vector.zig");

pub const Byte = u8;
pub const Bytes = []const u8;
pub const Array = arrayz.Array(Byte);
pub const Size = u8;
pub const u64_capacity = ~@as(u64, 0);

pub fn This(State: type) type {
    return struct {
        pub const Getter = ByteGetter(State);
        pub const Setter = ByteSetter(State);
    };
}

pub fn ByteGetter(State: type) type {
    return struct {
        const Self = @This();
        pub const ByteIterator = it.Iterator(Byte, State);
        pub const Iterator = ByteIterator.Getter;

        iterator: Iterator.This,
        endianness: builtin.Endian,
        size: Size,

        pub fn init(iterator: *Iterator.Interface, endianness: builtin.Endian, size: Size) Self {
            return .{
                .iterator = .init(iterator),
                .endianness = endianness,
                .size = size,
            };
        }

        pub fn default(iterator: *Iterator.Interface) Self {
            return .{
                .iterator = .init(iterator),
                .endianness = .little,
                .size = 4,
            };
        }

        /// Reads bytes from `iterator` and converts them to `Value`. If memory has been
        /// allocated, it is freed depending on `Value`:
        ///
        /// - Single-item pointer: memory should be freed using `gpa.destroy`.
        /// - Slice and many-item pointer: memory should be freed using `gpa.free`.
        /// - Otherwise: No memory is allocated.
        pub fn get(self: *Self, gpa: mem.Allocator, Value: type) !Value {
            const type_info = @typeInfo(Value);
            const type_size = @sizeOf(Value);

            if (Value == usize) {
                var buffer: [type_size]u8 = undefined;
                for (0..self.size) |i| if (try self.iterator.current()) |byte| {
                    buffer[i] = byte;
                } else return error.OutOfBounds;
                return mem.readVarInt(usize, buffer[0..self.size], self.endianness);
            }

            return switch (type_info) {
                .int => |_| int: {
                    var buffer: [type_size]u8 = undefined;
                    for (0..type_size) |i| if (try self.iterator.current()) |byte| {
                        buffer[i] = byte;
                    } else return error.OutOfBounds;
                    break :int mem.readInt(Value, &buffer, self.endianness);
                },
                .@"enum" => |info| en: {
                    const Int = ByteInt(info.tag_type);
                    const int = try self.get(gpa, Int);
                    break :en @enumFromInt(@as(info.tag_type, @truncate(int)));
                },
                .bool => (try self.get(gpa, u8)) == 1,
                .array => |info| array: {
                    const len = try self.get(gpa, usize);
                    var array: [info.len]info.child = undefined;
                    if (info.child == u8) {
                        for (0..len) |i| array[i] = if (try self.iterator.current()) |value| value else return error.OutOfBounds;
                    } else {
                        for (0..len) |i| array[i] = try self.get(gpa, info.child);
                    }
                    break :array array;
                },
                .pointer => |info| pointer: {
                    const pointer = switch (info.size) {
                        .one, .c => one: {
                            const p = try gpa.create(info.child);
                            p.* = try self.get(gpa, info.child);
                            break :one p;
                        },
                        .slice, .many => many: {
                            const len = try self.get(gpa, usize);
                            const p = try gpa.alloc(info.child, len);
                            if (info.child == u8) {
                                for (0..len) |i| p[i] = if (try self.iterator.current()) |value| value else return error.OutOfBounds;
                            } else {
                                for (0..len) |i| p[i] = try self.get(gpa, info.child);
                            }
                            break :many p;
                        },
                    };

                    break :pointer pointer;
                },
                .@"union" => |info| un: {
                    const Tag = info.tag_type.?;
                    const tag = try self.get(gpa, Tag);
                    inline for (info.fields) |field| {
                        const field_tag = comptime std.meta.stringToEnum(Tag, field.name).?;
                        if (field_tag == tag) {
                            const Payload = std.meta.TagPayload(Value, field_tag);
                            const value = try self.get(gpa, Payload);
                            break :un @unionInit(Value, field.name, value);
                        }
                    } else unreachable;
                },
                .void => {},
                else => error.UnhandledType,
            };
        }
    };
}

pub fn ByteSetter(State: type) type {
    return struct {
        const Self = @This();
        pub const ByteIterator = it.Iterator(Byte, State);
        pub const Iterator = ByteIterator.Setter;

        iterator: Iterator.This,
        endianness: builtin.Endian,
        size: Size,

        pub fn init(iterator: *Iterator.Interface, endianness: builtin.Endian, size: Size) Self {
            return .{
                .iterator = .init(iterator),
                .endianness = endianness,
                .size = size,
            };
        }

        pub fn default(iterator: *Iterator.Interface) Self {
            return .{
                .iterator = .init(iterator),
                .endianness = .little,
                .size = 4,
            };
        }

        /// Writes `value` as bytes to `iterator`.
        pub fn set(self: *Self, value: anytype) !*Self {
            const Value = @TypeOf(value);
            const type_info = @typeInfo(Value);
            const type_size = @sizeOf(Value);

            if (Value == usize) {
                var buffer: [type_size]u8 = undefined;
                mem.writeInt(usize, &buffer, @truncate(value), self.endianness);
                const slice = if (self.endianness == .little) buffer[0..self.size] else buffer[type_size - self.size ..];
                for (slice) |byte| _ = try self.iterator.current(byte);
                return self;
            }

            return switch (type_info) {
                .int => |_| int: {
                    var buffer: [type_size]Byte = @bitCast(value);
                    mem.writeInt(Value, &buffer, value, self.endianness);
                    for (buffer) |byte| _ = try self.iterator.current(byte);
                    break :int self;
                },
                .@"enum" => |info| en: {
                    const int = @intFromEnum(value);
                    break :en try self.set(@as(ByteInt(info.tag_type), int));
                },
                .bool => try self.set(@as(u8, @intFromBool(value))),
                .array => |info| array: {
                    _ = try self.set(value.len);
                    if (info.child == u8) {
                        for (value) |byte| _ = try self.iterator.current(byte);
                    } else {
                        for (value) |item| _ = try self.set(item);
                    }
                    break :array self;
                },
                .pointer => |info| pointer: {
                    switch (info.size) {
                        .one, .c => _ = try self.set(value.*),
                        .slice, .many => {
                            _ = try self.set(value.len);
                            if (info.child == u8) {
                                for (value) |byte| _ = try self.iterator.current(byte);
                            } else {
                                for (value) |item| _ = try self.set(item);
                            }
                        },
                    }

                    break :pointer self;
                },
                .@"union" => |info| un: {
                    const Tag = info.tag_type.?;
                    const tag = std.meta.activeTag(value);
                    _ = try self.set(tag);
                    inline for (info.fields) |field| {
                        const field_tag = comptime std.meta.stringToEnum(Tag, field.name).?;
                        if (field_tag == tag) break :un try self.set(@field(value, field.name));
                    } else unreachable;
                },
                .void => self,
                else => error.UnhandledType,
            };
        }
    };
}

pub fn ByteInt(Int: type) type {
    const info = @typeInfo(Int).int;
    const is_evenly_divisible = info.bits % 8 == 0;
    return if (is_evenly_divisible) Int else @Type(
        .{
            .int = builtin.Type.Int{
                .bits = @divFloor(info.bits, 8) * 8 + 8,
                .signedness = info.signedness,
            },
        },
    );
}

test {
    const Vector = vec.This(u8, u64_capacity);
    const B = This(Vector.StateType);

    const allocator = testing.allocator;
    var buffer: [1024]u8 = undefined;
    const text: []const u8 = "hello";
    const Un = union(enum) { first, second: u8 };

    const values = .{
        @as(u8, 128),
        @as(u32, 1_000_000),
        false,
        @as(usize, 16),
        [2]u8{ 0, 1 },
        &@as(u8, 16),
        text,
        builtin.Endian.little,
        Un.first,
        Un{ .second = 0 },
    };
    const fields = @typeInfo(@TypeOf(values)).@"struct".fields;

    var vector_setter = try Vector.Setter.init(allocator, &buffer);
    defer vector_setter.deinit(allocator);
    var setter = B.Setter.default(vector_setter.iterator().interface);
    inline for (fields) |field| _ = try setter.set(@field(values, field.name));

    var vector_getter = try Vector.Getter.init(allocator, &buffer);
    defer vector_getter.deinit(allocator);
    var getter = B.Getter.default(vector_getter.iterator().interface);
    inline for (fields, 0..) |field, i| {
        const result = try getter.get(testing.allocator, field.type);
        try testing.expectEqualDeep(@field(values, field.name), result);
        if (i == 5) testing.allocator.destroy(result);
        if (i == 6) testing.allocator.free(result);
    }
}
