const std = @import("std");
const debug = std.debug;
const mem = std.mem;

const iteratorz = @import("iteratorz");
const ib = iteratorz.iterable;
const vec = iteratorz.vector;
const it = iteratorz.iterator;
const filter = iteratorz.filter;
const map = iteratorz.map;

const Value = u8;
const State = vec.State;
const Vector = vec.Vector(Value);
const Iterable = ib.Iterable(Value, State);
const Iterator = it.Iterator(Value, State);
const ToUppercase = map.Readable(Iterator, toUppercase);
const IsVowel = filter.Readable(Iterator, isVowel);

pub fn main() !void {
    const text: []Value = @constCast("hello");

    var vector = Vector.init(text);
    var iterable = Iterable.init(&vector.interface);
    var default = Iterator.Readable.Default.init(&iterable);
    var iterator = Iterator.Readable.This.init(&default.interface);
    var uppercase_vowels = iterator.to(ToUppercase).to(IsVowel);
    var result: [text.len]u8 = undefined;

    var i: usize = 0;
    while (try uppercase_vowels.current()) |char| {
        result[i] = char;
        i += 1;
    }

    const expected = "EO";
    debug.assert(expected.len == i);
    debug.assert(mem.eql(u8, expected, result[0..i]));
}

fn toUppercase(char: u8) anyerror!u8 {
    return std.ascii.toUpper(char);
}

fn isVowel(char: u8) anyerror!bool {
    return for ("aeiouAEIOU") |c| {
        if (c == char) break true;
    } else false;
}
