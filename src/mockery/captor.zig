const std = @import("std");

pub fn captor(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        capturedValues: std.ArrayListUnmanaged(T) = .{},

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{ .allocator = allocator };
        }

        pub fn deinit(self: *Self) void {
            self.capturedValues.clearAndFree(self.allocator);
        }

        pub fn capture(self: *Self, value: T) void {
            self.capturedValues.append(self.allocator, value) catch |err| {
                std.debug.print("Captor failed to append value: {any}\n", .{err});
                @panic("Captor failed to capture value");
            };
        }

        pub fn getLastValue(self: *const Self) !T {
            if (self.capturedValues.items.len == 0) {
                return error.noValuesCaptured;
            }
            return self.capturedValues.items[self.capturedValues.items.len - 1];
        }

        pub fn getAllValues(self: *const Self) []const T {
            return self.capturedValues.items;
        }
    };
}
