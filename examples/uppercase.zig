//! Converts text to uppercase using a pipeline. It does the following:
//!
//! 1. Iterate over text characters.
//! 2. Map each character to uppercase.

const std = @import("std");
const debug = std.debug;
const mem = std.mem;
const heap = std.heap;
const testing = std.testing;

const iteratorz = @import("iteratorz");

const Char = u8;
const capacity: u3 = 5;
const Text = iteratorz.vector.This(Char, capacity);
const Uppercase = iteratorz.map.This(Text, toUppercase);

pub fn main() !void {
    const slice: []Char = @constCast("hello");

    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var text = try Text.Getter.init(allocator, slice);
    defer text.deinit(allocator);
    const text_iterator = text.iterator();
    var uppercase = try Uppercase.Getter.init(allocator, text_iterator.interface);
    defer uppercase.deinit(allocator);
    var uppercase_iterator = uppercase.iterator();
    var iterated: [slice.len]Char = undefined;

    var i: usize = 0;
    while (try uppercase_iterator.current()) |char| {
        iterated[i] = char;
        i += 1;
    }

    const expected = "HELLO";
    try testing.expectEqualStrings(expected, &iterated);
}

fn toUppercase(char: u8) anyerror!u8 {
    return std.ascii.toUpper(char);
}
