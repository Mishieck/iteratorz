const std = @import("std");
const testing = std.testing;

pub const bytes = @import("bytes.zig");

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
    var b = bytes.Readable{ .slice = slice };
    var m = b.to(Readable(bytes.Readable, isVowel));
    var iterated: [slice.len]u8 = undefined;

    var i: usize = 0;
    while (try m.next()) |char| {
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
