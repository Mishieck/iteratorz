//! Performs read/write operations on a file. It performs the following
//! operations:
//!
//! 1. Writes text to a file.
//! 2. Reads the written text from a file.

const std = @import("std");
const debug = std.debug;
const mem = std.mem;
const heap = std.heap;
const testing = std.testing;

const iteratorz = @import("iteratorz");

const Char = u8;
const capacity: u3 = 5;
const Text = iteratorz.file.This(capacity);

pub fn main() !void {
    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();
    var file = try tmp_dir.dir.createFile("hello", .{ .read = true });
    defer file.close();

    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const text: []Char = @constCast("hello");

    var buffer: [text.len]Char = undefined;
    var file_setter = try Text.Setter.init(allocator, file, &buffer, .streaming);
    defer file_setter.deinit(allocator);
    var setter_iterator = file_setter.iterator();
    var buffered_indexable = file_setter.buffered_indexable;

    for (text) |char| _ = try setter_iterator.current(char);
    try testing.expectEqualStrings(text, &buffer);

    _ = try buffered_indexable.flush();

    const stat = try file.stat();
    try testing.expectEqual(text.len, stat.size);

    var file_getter = try Text.Getter.init(allocator, file, &buffer, .streaming);
    defer file_getter.deinit(allocator);
    var getter_iterator = file_getter.iterator();
    var iterated: [text.len]u8 = undefined;

    var i: usize = 0;
    while (try getter_iterator.current()) |char| {
        iterated[i] = char;
        i += 1;
    }

    try testing.expectEqualStrings(text, &iterated);
}
