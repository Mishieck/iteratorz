//! Iterates over text characters.

const std = @import("std");
const debug = std.debug;
const mem = std.mem;
const heap = std.heap;
const testing = std.testing;

const iteratorz = @import("iteratorz");

const Char = u8;
const capacity: u3 = 5;
const Text = iteratorz.vector.This(Char, capacity);

pub fn main() !void {
    const slice: []Char = @constCast("hello");

    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var text = try Text.Getter.init(allocator, slice);
    defer text.deinit(allocator);
    var text_iterator = text.iterator();
    var iterated: [slice.len]Char = undefined;

    var i: usize = 0;
    while (try text_iterator.current()) |char| {
        iterated[i] = char;
        i += 1;
    }

    try testing.expectEqualStrings(slice, &iterated);

    var buffer: [slice.len]Char = undefined;
    var bytes_setter = try Text.Setter.init(allocator, &buffer);
    defer bytes_setter.deinit(allocator);
    var setter_iterator = bytes_setter.iterator();
    for (slice) |char| _ = try setter_iterator.current(char);
    try testing.expectEqualStrings(slice, &buffer);
}
