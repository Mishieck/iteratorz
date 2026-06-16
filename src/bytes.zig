const std = @import("std");
const testing = std.testing;

pub const bytes = @import("bytes.zig");

const Byte = u8;

pub const Readable = struct {
    const Self = @This();

    slice: []const u8,
    index: usize = 0,

    pub fn next(self: *Self) !?Byte {
        if (self.index >= self.slice.len) return null;
        const byte = self.slice[self.index];
        self.index += 1;
        return byte;
    }

    pub fn previous(self: *Self) !?Byte {
        if (self.index == 0) return null;
        self.index -= 1;
        const byte = self.slice[self.index];
        return byte;
    }

    pub inline fn to(self: *Self, Iterator: type) *Iterator {
        return Iterator.from(self);
    }
};

test Readable {
    const slice = "hello";
    var b = Readable{ .slice = slice };
    var iterated: [slice.len]u8 = undefined;

    var i: usize = 0;
    while (try b.next()) |char| {
        iterated[i] = char;
        i += 1;
    }

    try testing.expectEqualStrings(slice, &iterated);
}
