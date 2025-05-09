const std = @import("std");
const mockMod = @import("mock.zig");
const arguments = @import("arguments.zig");

pub const inOrderVerifier = struct {
    lastVerifiedGlobalSeq: usize,

    pub fn init() inOrderVerifier {
        return inOrderVerifier{ .lastVerifiedGlobalSeq = 0 };
    }

    pub fn deinit(_: *inOrderVerifier) void {}

    pub fn verify(
        self: *inOrderVerifier,
        comptime argsType: type,
        comptime returnType: type,
        mockInstance: *const mockMod.mock(argsType, returnType),
        expectedArgs: argsType,
    ) !void {
        for (mockInstance.allArgsAndSeq.items) |callRecord| {
            if (callRecord.seq > self.lastVerifiedGlobalSeq) {
                if (std.meta.eql(callRecord.args, expectedArgs)) {
                    self.lastVerifiedGlobalSeq = callRecord.seq;
                    return;
                } else {
                    std.debug.print(
                        \\inOrderVerifier.verify failed: Expected next call to mock @{any} with args {any},
                        \\ but found call #{d} with args {any}.
                        ++ "\n",
                        .{ mockInstance, expectedArgs, callRecord.seq, callRecord.args },
                    );
                    return error.verificationFailed;
                }
            }
        }
        std.debug.print(
            \\inOrderVerifier.verify failed: Expected call to mock @{any} with args {any}
            \\ was not found after call sequence #{d}.
            ++ "\n",
            .{ mockInstance, expectedArgs, self.lastVerifiedGlobalSeq },
        );
        return error.verificationFailed;
    }

    pub fn verifyWithMatchers(
        self: *inOrderVerifier,
        comptime argsType: type,
        comptime returnType: type,
        mockInstance: *const mockMod.mock(argsType, returnType),
        expectedArgMatchers: anytype,
    ) !void {
        const matchersType = @TypeOf(expectedArgMatchers);
        if (@typeInfo(matchersType) != .@"struct") {
            @compileError("expectedArgMatchers must be a struct");
        }

        for (mockInstance.allArgsAndSeq.items) |callRecord| {
            if (callRecord.seq > self.lastVerifiedGlobalSeq) {
                if (arguments.argsMatch(argsType, matchersType, callRecord.args, expectedArgMatchers)) {
                    self.lastVerifiedGlobalSeq = callRecord.seq;
                    return;
                } else {
                    std.debug.print(
                        \\inOrderVerifier.verifyWithMatchers failed: Expected next call to mock @{any} with matching args {any},
                        \\ but found call #{d} with args {any}.
                        ++ "\n",
                        .{ mockInstance, expectedArgMatchers, callRecord.seq, callRecord.args },
                    );
                    return error.verificationFailed;
                }
            }
        }
        std.debug.print(
            \\inOrderVerifier.verifyWithMatchers failed: Expected call to mock @{any} with matching args {any}
            \\ was not found after call sequence #{d}.
            ++ "\n",
            .{ mockInstance, expectedArgMatchers, self.lastVerifiedGlobalSeq },
        );
        return error.verificationFailed;
    }
};

pub fn inOrder() inOrderVerifier {
    return inOrderVerifier.init();
}
