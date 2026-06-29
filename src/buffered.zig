const std = @import("std");

const debug = std.debug;
const testing = std.testing;

const ib = @import("iterable.zig");
const vec = @import("vector.zig");

pub const State = vec.State;

pub fn Buffered(Value: type) type {
    return struct {
        const Self = @This();
        const Iterable = ib.Iterable(Value, State);
        pub const Interface = Iterable.Interface;
        pub const Vector = vec.Vector(Value);

        interface: Interface,
        collection: *Collection,
        collection_size: ?usize = null,
        buffer: Iterable,
        buffered_size: u64 = 0,
        mode: Mode,
        index: State = .{ .valid = 0 },

        pub fn init(collection: *Collection, buffer: *Interface, mode: Mode) Self {
            return .{
                .interface = .{
                    .getValue = getValue,
                    .setValue = setValue,
                    .getState = getState,
                    .setState = setState,
                    .setNextState = setNextState,
                    .setPreviousState = setPreviousState,
                    .setInitialState = setInitialState,
                    .setFinalState = setFinalState,
                    .isStateValid = isStateValid,
                },
                .collection = collection,
                .mode = mode,
                .buffer = .init(buffer),
            };
        }

        pub fn getValue(iterable: *Interface) anyerror!Value {
            const self: *Self = @fieldParentPtr("interface", iterable);
            if (self.buffered_size == 0) _ = try self.read();
            return self.buffer.getValue();
        }

        pub fn setValue(iterable: *Interface, value: Value) anyerror!*Interface {
            var self: *Self = @fieldParentPtr("interface", iterable);
            _ = try self.buffer.setValue(value);
            return iterable;
        }

        pub fn getState(iterable: *Interface) anyerror!State {
            const self: *Self = @fieldParentPtr("interface", iterable);
            return switch (self.index) {
                .valid => |index| .{ .valid = index + self.vector().index.valid },
                else => self.index,
            };
        }

        pub fn setState(iterable: *Interface, index: State) anyerror!*Interface {
            var self: *Self = @fieldParentPtr("interface", iterable);
            switch (index) {
                .valid => |i| {
                    switch (self.mode) {
                        .read => {
                            const collection_size = try self.size();

                            if (i < collection_size) {
                                self.index = index;
                                _ = try self.read();
                            } else return error.InvalidState;
                        },
                        .write => {
                            _ = try self.write();
                            self.index = index;
                        },
                    }
                },
                else => {
                    self.index = index;
                    return error.InvalidState;
                },
            }

            return iterable;
        }

        pub fn setPreviousState(iterable: *Interface) anyerror!*Interface {
            var self: *Self = @fieldParentPtr("interface", iterable);

            switch (self.index) {
                .underflow => self.index = .underflow,
                .valid => |index| {
                    const new_index, const underflow = @subWithOverflow(index, 1);
                    const underflowed = underflow == 1;

                    switch (self.mode) {
                        .read => {
                            if (underflowed) {
                                _ = try self.buffer.setInitialState();
                                self.index = .underflow;
                            } else if (self.buffered_size > 0) {
                                _ = self.buffer.setPreviousState() catch |err| switch (err) {
                                    error.InvalidState => _ = try iterable.setState(
                                        iterable,
                                        .{ .valid = new_index },
                                    ),
                                    else => return err,
                                };
                            } else {
                                self.index = .{ .valid = new_index };
                                _ = try self.read();
                            }
                        },
                        .write => {
                            if (underflowed) {
                                _ = try self.write();
                                self.index = .underflow;
                            } else if (self.buffered_size > 0) {
                                _ = self.buffer.setPreviousState() catch |err| switch (err) {
                                    error.InvalidState => _ = try iterable.setState(
                                        iterable,
                                        .{ .valid = new_index },
                                    ),
                                    else => return err,
                                };
                            } else {
                                self.index = .{ .valid = new_index };
                            }
                        },
                    }
                },
                .overflow => _ = try iterable.setState(iterable, .{ .valid = self.index.valid - 1 }),
            }

            return iterable;
        }

        pub fn setNextState(iterable: *Interface) anyerror!*Interface {
            const self: *Self = @fieldParentPtr("interface", iterable);

            switch (self.index) {
                .underflow => _ = try iterable.setState(iterable, .{ .valid = 0 }),
                .valid => |index| {
                    const new_index, const overflow = @addWithOverflow(index + self.vector().index.valid, 1);
                    var overflowed = overflow == 1;

                    switch (self.mode) {
                        .read => {
                            const collection_size = try self.size();
                            overflowed = overflowed or new_index == collection_size;

                            if (overflowed) {
                                _ = try self.buffer.setInitialState();
                                self.index = .overflow;
                                return error.InvalidState;
                            } else if (self.buffered_size > 0) {
                                switch (new_index < index + self.buffered_size) {
                                    true => _ = try self.buffer.setNextState(),
                                    false => {
                                        self.index = .{ .valid = new_index };
                                        _ = try self.read();
                                    },
                                }
                            } else {
                                _ = try self.read();
                            }
                        },
                        .write => {
                            if (overflowed) {
                                _ = try self.write();
                                self.index = .overflow;
                                return error.InvalidState;
                            } else {
                                _ = self.buffer.setNextState() catch |err| switch (err) {
                                    error.InvalidState => _ = try self.write(),
                                    else => return err,
                                };
                            }
                        },
                    }
                },
                .overflow => self.index = .overflow,
            }

            return iterable;
        }

        pub fn setInitialState(iterable: *Interface) anyerror!*Interface {
            return iterable.setState(iterable, .{ .valid = 0 });
        }

        pub fn setFinalState(iterable: *Interface) anyerror!*Interface {
            var self: *Self = @fieldParentPtr("interface", iterable);
            const collection_size = try self.size();
            return iterable.setState(iterable, .{ .valid = collection_size -| 1 });
        }

        pub fn isStateValid(iterable: *Interface) anyerror!bool {
            const self: *Self = @fieldParentPtr("interface", iterable);
            return switch (self.index) {
                .valid => |_| true,
                else => false,
            };
        }

        pub fn vector(self: *Self) Vector {
            const v: *Vector = @fieldParentPtr("interface", self.buffer.interface);
            return v.*;
        }

        pub fn read(self: *Self) anyerror!*Self {
            const index = self.index.valid;
            const v = self.vector().vector;
            const s = try self.collection.read(self.collection, index, v);
            _ = try self.buffer.setInitialState();
            self.buffered_size = s;
            return self;
        }

        pub fn write(self: *Self) anyerror!*Self {
            const index = self.index.valid;
            _ = try self.collection.write(self.collection, index, self.vector().vector);
            _ = try self.buffer.setInitialState();
            self.index = .{ .valid = index + self.buffered_size -| 1 };
            self.buffered_size = 0;
            return self;
        }

        pub fn size(self: *Self) anyerror!usize {
            if (self.collection_size) |s| if (self.mode == .read) return s;
            return try self.collection.size(self.collection);
        }

        pub const Collection = struct {
            read: *const fn (collection: *@This(), index: usize, vector: Vector.Vec) anyerror!usize,
            write: *const fn (collection: *@This(), index: usize, vector: Vector.Vec) anyerror!*@This(),
            size: *const fn (collection: *@This()) anyerror!usize,
        };
    };
}

test Buffered {
    _ = Buffered(u8);
}

pub const Mode = enum { read, write };
