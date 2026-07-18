//! Iterates over text characters.

const std = @import("std");
const debug = std.debug;
const mem = std.mem;
const testing = std.testing;

const iteratorz = @import("iteratorz");

const Char = u8;
const capacity: u3 = 5;
const Text = iteratorz.vector.Iterator(Char, capacity);

pub fn main() !void {
    const slice: []Char = @constCast("hello");
    var text = Text.Readable.init(slice);
    var iterated: [slice.len]Char = undefined;

    var i: usize = 0;
    while (try text.current()) |char| {
        iterated[i] = char;
        i += 1;
    }

    try testing.expectEqualStrings(slice, &iterated);

    var buffer: [slice.len]Char = undefined;
    var writable_bytes = Text.Writable.init(&buffer);
    for (slice) |char| _ = try writable_bytes.current(char);
    try testing.expectEqualStrings(slice, &buffer);
}
