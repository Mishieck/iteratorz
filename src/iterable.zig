const std = @import("std");
const testing = std.testing;

pub fn Iterable(Value: type, State: type) type {
    return struct {
        const It = @This();

        getValue: *const fn (iterable: *It) anyerror!Value,
        setValue: *const fn (iterable: *It, value: Value) anyerror!*It,
        getState: *const fn (iterable: *It) anyerror!State,
        setState: *const fn (iterable: *It, state: State) anyerror!*It,
        setNextState: *const fn (iterable: *It) anyerror!*It,
        setPreviousState: *const fn (iterable: *It) anyerror!*It,
        setInitialState: *const fn (iterable: *It) anyerror!*It,
        setFinalState: *const fn (iterable: *It) anyerror!*It,
        isStateValid: *const fn (iterable: *It) anyerror!bool,
    };
}

test Iterable {
    _ = Iterable(u8, usize);
}
