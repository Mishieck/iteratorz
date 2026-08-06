pub const indexable = @import("indexable.zig");
pub const iterable = @import("iterable.zig");
pub const iterator = @import("iterator.zig");
pub const scalar = @import("scalar.zig");
pub const vector = @import("vector.zig");
pub const buffered = @import("buffered.zig");
pub const file = @import("file.zig");
// pub const filter = @import("filter.zig");
pub const map = @import("map.zig");

test {
    _ = indexable;
    _ = iterable;
    _ = scalar;
    _ = vector;
    _ = file;
    _ = buffered;
    _ = iterator;
    // _ = filter;
    _ = map;
}
