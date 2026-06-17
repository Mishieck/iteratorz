const std = @import("std");
const testing = std.testing;

pub const vector = @import("vector.zig");

pub fn Readable(OriginalIterator: type, function: anytype) type {
    return struct {
        const Self = @This();
        const Item = @typeInfo(@TypeOf(function)).@"fn".params[0].type.?;

        iterator: *OriginalIterator,

        pub inline fn from(original_iterator: anytype) *Self {
            var iterator: Self = .{ .iterator = original_iterator };
            return &iterator;
        }

        fn next(self: *Self) !?Item {
            return while (try self.iterator.next()) |value| {
                if (function(value)) break value;
            } else null;
        }

        fn previous(self: *Self) !?Item {
            return while (try self.iterator.previous()) |value| {
                if (function(value)) break value;
            } else null;
        }

        pub inline fn to(self: *Self, Iterator: type) *Iterator {
            return Iterator.from(self);
        }
    };
}

test Readable {
    const slice = "hello";
    const vowels = "eo";
    var b = vector.Readable(u8){ .slice = slice };
    var f = b.to(Readable(vector.Readable(u8), isVowel));
    var iterated: [slice.len]u8 = undefined;

    var i: usize = 0;
    while (try f.next()) |char| {
        iterated[i] = char;
        i += 1;
    }

    try testing.expectEqualStrings(vowels, iterated[0..i]);
}

fn isVowel(char: u8) bool {
    return for ("aeiou") |c| {
        if (c == char) break true;
    } else false;
}

pub fn Writable(OriginalIterator: type, function: anytype) type {
    return struct {
        const Self = @This();
        const Item = @typeInfo(@TypeOf(function)).@"fn".params[0].type.?;

        iterator: *OriginalIterator,

        pub inline fn from(original_iterator: anytype) *Self {
            var iterator: Self = .{ .iterator = original_iterator };
            return &iterator;
        }

        fn next(self: *Self, item: Item) !?*Self {
            return if (function(item)) set: {
                break :set if (try self.iterator.next(item)) |_| self else null;
            } else null;
        }

        fn previous(self: *Self, item: Item) !?*Self {
            return if (function(item)) set: {
                break :set if (try self.iterator.previous(item)) |_| self else null;
            } else null;
        }

        pub inline fn to(self: *Self, Iterator: type) *Iterator {
            return Iterator.from(self);
        }
    };
}

test Writable {
    const slice = "hello";
    const vowels = "eo";
    var buffer: [slice.len]u8 = undefined;
    var b = vector.Writable(u8){ .slice = &buffer };
    var f = b.to(Writable(vector.Writable(u8), isVowel));

    for (slice) |char| _ = try f.next(char);
    try testing.expectEqualStrings(vowels, buffer[0..vowels.len]);
}
