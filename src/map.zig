const std = @import("std");
const testing = std.testing;

pub const bytes = @import("bytes.zig");

pub fn Readable(OriginalIterator: type, function: anytype) type {
    return struct {
        const Self = @This();
        const Item = @typeInfo(@TypeOf(function)).@"fn".return_type.?;

        iterator: *OriginalIterator,

        pub inline fn from(original_iterator: anytype) *Self {
            var iterator: Self = .{ .iterator = original_iterator };
            return &iterator;
        }

        fn next(self: *Self) !?Item {
            return if (try self.iterator.next()) |value| function(value) else null;
        }

        fn previous(self: *Self) !?Item {
            return if (try self.iterator.previous()) |value| function(value) else null;
        }

        pub inline fn to(self: *Self, Iterator: type) *Iterator {
            return Iterator.from(self);
        }
    };
}

test Readable {
    const slice = "hello";
    const capitalized_slice = "HELLO";
    var b = bytes.Readable{ .slice = slice };
    var m = b.to(Readable(bytes.Readable, capitalize));
    var iterated: [slice.len]u8 = undefined;

    var i: usize = 0;
    while (try m.next()) |char| {
        iterated[i] = char;
        i += 1;
    }

    try testing.expectEqualStrings(capitalized_slice, &iterated);
}

fn capitalize(char: u8) u8 {
    return std.ascii.toUpper(char);
}
