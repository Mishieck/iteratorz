pub const indexable = @import("indexable.zig");
pub const iterable = @import("iterable.zig");
pub const iterator = @import("iterator.zig");
pub const scalar = @import("scalar.zig");
pub const vector = @import("vector.zig");
pub const memory = @import("memory.zig");
pub const buffered = @import("buffered.zig");
pub const file = @import("file.zig");
// pub const filter = @import("filter.zig");
pub const map = @import("map.zig");
pub const bytes = @import("bytes.zig");
pub const codec = @import("codec.zig");
pub const partition = @import("partition.zig");

test {
    _ = indexable;
    _ = iterable;
    _ = scalar;
    _ = vector;
    _ = memory;
    _ = file;
    _ = buffered;
    _ = iterator;
    // _ = filter;
    _ = map;
    _ = bytes;
    _ = codec;
    _ = partition;
}
