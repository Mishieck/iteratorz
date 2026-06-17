const std = @import("std");
const testing = std.testing;

pub fn Readable(Item: type) type {
    return struct {
        const Self = @This();

        slice: []const Item,
        index: usize = 0,

        pub fn next(self: *Self) !?Item {
            if (self.index >= self.slice.len) return null;
            const item = self.slice[self.index];
            self.index += 1;
            return item;
        }

        pub fn previous(self: *Self) !?Item {
            if (self.index == 0) return null;
            self.index -= 1;
            const item = self.slice[self.index];
            return item;
        }

        pub inline fn to(self: *Self, Iterator: type) *Iterator {
            return Iterator.from(self);
        }
    };
}

test Readable {
    const slice = "hello";
    var b = Readable(u8){ .slice = slice };
    var iterated: [slice.len]u8 = undefined;

    var i: usize = 0;
    while (try b.next()) |char| {
        iterated[i] = char;
        i += 1;
    }

    try testing.expectEqualStrings(slice, &iterated);
}

pub fn Writable(Item: type) type {
    return struct {
        const Self = @This();

        slice: []Item,
        index: usize = 0,

        pub fn next(self: *Self, item: Item) !?*Self {
            if (self.index >= self.slice.len) return null;
            self.slice[self.index] = item;
            self.index += 1;
            return self;
        }

        pub fn previous(self: *Self, item: Item) !?*Self {
            if (self.index == 0) return null;
            self.index -= 1;
            self.slice[self.index] = item;
            return self;
        }

        pub inline fn to(self: *Self, Iterator: type) *Iterator {
            return Iterator.from(self);
        }
    };
}

test Writable {
    const slice = "hello";
    var buffer: [slice.len]u8 = undefined;
    var b = Writable(u8){ .slice = &buffer };

    for (slice) |char| _ = try b.next(char);
    try testing.expectEqualStrings(slice, b.slice);
}
