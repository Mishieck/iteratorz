const std = @import("std");
const debug = std.debug;
const mem = std.mem;
const testing = std.testing;

const iteratorz = @import("iteratorz");

const Char = u8;
const capacity: u3 = 5;
const Text = iteratorz.vector.Iterator(Char, capacity);
const Uppercase = iteratorz.map.Readable(Text, toUppercase);

pub fn main() !void {
    const slice: []Char = @constCast("hello");
    var text = Text.Readable.init(slice);
    var uppercase = text.to(Uppercase);
    var iterated: [slice.len]Char = undefined;

    var i: usize = 0;
    while (try uppercase.current()) |char| {
        iterated[i] = char;
        i += 1;
    }

    const expected = "HELLO";
    try testing.expectEqualStrings(expected, &iterated);
}

fn toUppercase(char: u8) anyerror!u8 {
    return std.ascii.toUpper(char);
}
