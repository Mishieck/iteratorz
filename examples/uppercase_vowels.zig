//! ERROR: This example does not run yet. It fails due to a comptime error in
//! [filter](../src/filter.zig).
//!
//! Uses a pipeline to filter vowels from text and convert them to uppercase.

const std = @import("std");
const debug = std.debug;
const mem = std.mem;
const heap = std.heap;
const testing = std.testing;

const iteratorz = @import("iteratorz");
const vec = iteratorz.vector;

const Char = u8;
const capacity: u3 = 5;
const Text = vec.This(Char, capacity);
const Uppercase = iteratorz.map.This(Text, toUppercase);
const Vowels = iteratorz.filter.This(Text, isVowel);

pub fn main() !void {
    const slice: []Char = @constCast("hello");

    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var readable_bytes = try Text.Readable.init(allocator, slice);
    defer readable_bytes.deinit(allocator);
    const readable_iterator = readable_bytes.iterator();
    var uppercase = try Uppercase.Readable.init(allocator, readable_iterator.interface);
    defer uppercase.deinit(allocator);
    const uppercase_iterator = uppercase.iterator();
    var vowels = try Vowels.Readable.init(allocator, uppercase_iterator.interface);
    defer vowels.deinit(allocator);
    var vowels_iterator = vowels.iterator();
    var iterated: [slice.len]Char = undefined;

    var i: usize = 0;
    while (try vowels_iterator.current()) |char| {
        iterated[i] = char;
        i += 1;
    }

    const expected = "EO";
    try testing.expectEqualStrings(expected, iterated[0..i]);
}

fn toUppercase(char: u8) anyerror!u8 {
    return std.ascii.toUpper(char);
}

fn isVowel(char: u8) anyerror!bool {
    return for ("aeiou") |c| {
        if (c == char) break true;
    } else false;
}
