//! ERROR: This example does not run yet. It fails due to a comptime error in
//! [filter](../src/filter.zig).
//!
//! Uses a pipeline to filter vowels from text and convert them to uppercase.

const std = @import("std");
const debug = std.debug;
const mem = std.mem;
const testing = std.testing;

const iteratorz = @import("iteratorz");
const vec = iteratorz.vector;

const Char = u8;
const capacity: u3 = 5;
const Text = vec.Iterator(Char, capacity);
const Uppercase = iteratorz.map.Readable(Text, toUppercase);
const Vowels = iteratorz.filter.Readable(Text, isVowel);

pub fn main() !void {
    const slice: []Char = @constCast("hello");
    var readable_bytes = Text.Readable.init(slice);
    var uppercase = readable_bytes.to(Vowels).to(Uppercase);
    var iterated: [slice.len]Char = undefined;

    var i: usize = 0;
    while (try uppercase.current()) |char| {
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
