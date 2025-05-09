const std = @import("std");

pub fn matcher(comptime T: type) type {
    return union(enum) {
        any: void,
        eq: T,
        custom: *const fn (actualValue: T) bool,
        startsWith: []const u8,
        endsWith: []const u8,

        pub fn matches(self: @This(), actualValue: T) bool {
            return switch (self) {
                .any => true,
                .eq => |expectedValue| std.meta.eql(actualValue, expectedValue),
                .custom => |funcPtr| funcPtr(actualValue),
                .startsWith => |prefixValue| {
                    if (T == []const u8) {
                        return std.mem.startsWith(u8, actualValue, prefixValue);
                    } else {
                        return false;
                    }
                },
                .endsWith => |suffixValue| {
                    if (T == []const u8) {
                        return std.mem.endsWith(u8, actualValue, suffixValue);
                    } else {
                        return false;
                    }
                },
            };
        }
    };
}

pub fn any(comptime T: type) matcher(T) {
    return .{ .any = {} };
}

pub fn eq(comptime T: type, expectedValue: T) matcher(T) {
    return .{ .eq = expectedValue };
}

pub fn custom(comptime T: type, funcPtr: *const fn (actualValue: T) bool) matcher(T) {
    return .{ .custom = funcPtr };
}

pub fn startsWith(prefixValue: []const u8) matcher([]const u8) {
    return .{ .startsWith = prefixValue };
}

pub fn endsWith(suffixValue: []const u8) matcher([]const u8) {
    return .{ .endsWith = suffixValue };
}

pub fn argsMatch(comptime argsType: type, comptime matchersType: type, actualArgs: argsType, matchersStruct: matchersType) bool {
    if (@typeInfo(argsType) != .@"struct") {
        @compileError("argsType must be a struct for argsMatch.");
    }
    if (@typeInfo(matchersType) != .@"struct") {
        @compileError("matchersType must be a struct for argsMatch.");
    }

    inline for (std.meta.fields(argsType)) |argField| {
        const actualFieldValue = @field(actualArgs, argField.name);

        if (!@hasField(matchersType, argField.name)) {
            std.debug.print("Matcher field '{s}' not found in matchersType for argument field '{s}'.\n", .{ argField.name, argField.name });
            return false;
        }
        const matcherForField = @field(matchersStruct, argField.name);

        if (!matcherForField.matches(actualFieldValue)) {
            return false;
        }
    }
    return true;
}