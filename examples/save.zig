//! Performs read/write operations on a file. It performs the following
//! operations:
//!
//! 1. Writes text to a file.
//! 2. Reads the written text from a file.

const std = @import("std");
const debug = std.debug;
const mem = std.mem;
const testing = std.testing;

const iteratorz = @import("iteratorz");

const Char = u8;
const capacity: u3 = 5;
const Text = iteratorz.file.Iterator(capacity);

pub fn main() !void {
    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();
    var file = try tmp_dir.dir.createFile("hello", .{ .read = true });
    defer file.close();

    const text: []Char = @constCast("hello");

    var buffer: [text.len]Char = undefined;
    var writable_file = Text.Writable.init(file, &buffer, .streaming);
    var buffered_indexable = Text.Writable.buffered_indexable(&writable_file);

    for (text) |char| _ = try writable_file.current(char);
    try testing.expectEqualStrings(text, &buffer);

    _ = try buffered_indexable.flush();

    const stat = try file.stat();
    try testing.expectEqual(text.len, stat.size);

    var readable_file = Text.Readable.init(file, &buffer, .streaming);
    var iterated: [text.len]u8 = undefined;

    var i: usize = 0;
    while (try readable_file.current()) |char| {
        iterated[i] = char;
        i += 1;
    }

    try testing.expectEqualStrings(text, &iterated);
}
