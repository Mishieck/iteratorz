pub const Mode = enum {
    const Self = @This();

    get,
    set,

    pub fn toggle(self: *const Self) Self {
        return switch (self.*) {
            .get => .set,
            .set => .get,
        };
    }
};
