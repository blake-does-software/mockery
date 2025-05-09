const std = @import("std");
const arguments = @import("arguments.zig");
const captorMod = @import("captor.zig");

var gCallSequence: usize = 0;

pub fn resetGlobalCallSequence() void {
    gCallSequence = 0;
}

pub fn mock(comptime argsType: type, comptime returnType: type) type {
    return struct {
        const Self = @This();
        const callRecord = struct { args: argsType, seq: usize };
        const stubAction = union(enum) {
            returnValue: returnType,
            callFunction: *const fn (selfPtr: *Self, args: argsType) returnType,
        };
        const exhaustedBehavior = enum { panic, repeatLast };

        allocator: std.mem.Allocator,
        callCount: usize = 0,
        allArgsAndSeq: std.ArrayList(callRecord),

        stubQueue: std.ArrayList(stubAction),
        stubIndex: usize = 0,
        behaviorOnExhaustion: exhaustedBehavior = .panic,

        captureFn: ?*const fn (payload: ?*anyopaque, args: argsType) void = null,
        capturePayload: ?*anyopaque = null,

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .allocator = allocator,
                .allArgsAndSeq = std.ArrayList(callRecord).init(allocator),
                .stubQueue = std.ArrayList(stubAction).init(allocator),
                .behaviorOnExhaustion = .panic,
            };
        }

        pub fn deinit(self: *Self) void {
            self.allArgsAndSeq.deinit();
            self.stubQueue.deinit();
        }

        fn clearStubsAndCaptures(self: *Self) void {
            self.stubQueue.clearRetainingCapacity();
            self.stubIndex = 0;
            self.captureFn = null;
            self.capturePayload = null;
        }

        pub fn setExhaustedBehavior(self: *Self, behavior: exhaustedBehavior) void {
            self.behaviorOnExhaustion = behavior;
        }

        pub fn call(self: *Self, args: argsType) returnType {
            self.callCount += 1;
            gCallSequence += 1;
            const currentSeq = gCallSequence;

            self.allArgsAndSeq.append(.{ .args = args, .seq = currentSeq }) catch |err| {
                std.debug.print("Failed to append args/seq to mock history: {any}\n", .{err});
                @panic("mock.call: failed to record arguments");
            };

            if (self.captureFn) |cFn| {
                cFn(self.capturePayload, args);
            }

            if (self.stubQueue.items.len == 0) {
                @panic("mock.call: no stub provided (stub queue is empty)");
            }

            const stubIdxToUse: usize = if (self.stubIndex >= self.stubQueue.items.len) blk: {
                switch (self.behaviorOnExhaustion) {
                    .panic => @panic("mock.call: stub queue exhausted"),
                    .repeatLast => break :blk self.stubQueue.items.len - 1,
                }
            } else blk: {
                break :blk self.stubIndex;
            };

            const currentStub = self.stubQueue.items[stubIdxToUse];

            if (self.stubIndex < self.stubQueue.items.len) {
                self.stubIndex += 1;
            }

            return switch (currentStub) {
                .returnValue => |value| value,
                .callFunction => |funcPtr| @call(.auto, funcPtr, .{ self, args }),
            };
        }

        pub fn verifyCalled(self: *const Self, expectedTotalCalls: usize) !void {
            if (self.callCount != expectedTotalCalls) {
                std.debug.print("verifyCalled failed: expected exactly {d} total calls, got {d} calls.\n", .{ expectedTotalCalls, self.callCount });
                return error.verificationFailed;
            }
        }
        pub fn verifyCalledAtLeast(self: *const Self, expectedMinCalls: usize) !void {
            if (self.callCount < expectedMinCalls) {
                std.debug.print("verifyCalledAtLeast failed: expected at least {d} total calls, got {d} calls.\n", .{ expectedMinCalls, self.callCount });
                return error.verificationFailed;
            }
        }
        pub fn verifyCalledAtMost(self: *const Self, expectedMaxCalls: usize) !void {
            if (self.callCount > expectedMaxCalls) {
                std.debug.print("verifyCalledAtMost failed: expected at most {d} total calls, got {d} calls.\n", .{ expectedMaxCalls, self.callCount });
                return error.verificationFailed;
            }
        }

        pub fn verifyCalledWith(self: *const Self, expectedArgs: argsType, expectedCount: usize) !void {
            const matchCount = self.countExactMatches(expectedArgs);
            if (matchCount != expectedCount) {
                std.debug.print("verifyCalledWith failed: expected exactly {d} calls with specified args, found {d}.\n", .{ expectedCount, matchCount });
                self.printExactFailureDetails(expectedArgs);
                return error.verificationFailed;
            }
        }

        pub fn verifyCalledWithMatchers(self: *const Self, expectedArgMatchers: anytype, expectedCount: usize) !void {
            const matchCount = self.countMatcherMatches(expectedArgMatchers);
            if (matchCount != expectedCount) {
                std.debug.print("verifyCalledWithMatchers failed: expected exactly {d} calls with matching args, found {d}.\n", .{ expectedCount, matchCount });
                self.printMatcherFailureDetails(expectedArgMatchers);
                return error.verificationFailed;
            }
        }

        pub fn verifyCalledWithMatchersAtLeast(self: *const Self, expectedArgMatchers: anytype, expectedMinCount: usize) !void {
            const matchCount = self.countMatcherMatches(expectedArgMatchers);
            if (matchCount < expectedMinCount) {
                std.debug.print("verifyCalledWithMatchersAtLeast failed: expected at least {d} calls with matching args, found {d}.\n", .{ expectedMinCount, matchCount });
                self.printMatcherFailureDetails(expectedArgMatchers);
                return error.verificationFailed;
            }
        }

        pub fn verifyCalledWithMatchersAtMost(self: *const Self, expectedArgMatchers: anytype, expectedMaxCount: usize) !void {
            const matchCount = self.countMatcherMatches(expectedArgMatchers);
            if (matchCount > expectedMaxCount) {
                std.debug.print("verifyCalledWithMatchersAtMost failed: expected at most {d} calls with matching args, found {d}.\n", .{ expectedMaxCount, matchCount });
                self.printMatcherFailureDetails(expectedArgMatchers);
                return error.verificationFailed;
            }
        }

        fn countExactMatches(self: *const Self, expectedArgs: argsType) usize {
            var matchCount: usize = 0;
            for (self.allArgsAndSeq.items) |record| {
                if (std.meta.eql(record.args, expectedArgs)) {
                    matchCount += 1;
                }
            }
            return matchCount;
        }

        fn countMatcherMatches(self: *const Self, expectedArgMatchers: anytype) usize {
            const matchersType = @TypeOf(expectedArgMatchers);
            if (@typeInfo(matchersType) != .@"struct") {
                @compileError("Internal error: expectedArgMatchers should be a struct here.");
            }
            var matchCount: usize = 0;
            for (self.allArgsAndSeq.items) |record| {
                if (arguments.argsMatch(argsType, matchersType, record.args, expectedArgMatchers)) {
                    matchCount += 1;
                }
            }
            return matchCount;
        }

        fn printExactFailureDetails(self: *const Self, expectedArgs: argsType) void {
            std.debug.print("Expected args: {any}\n", .{expectedArgs});
            self.printRecordedArgsHistory();
        }

        fn printMatcherFailureDetails(self: *const Self, expectedArgMatchers: anytype) void {
            std.debug.print("Matchers used: {any}\n", .{expectedArgMatchers});
            self.printRecordedArgsHistory();
        }

        fn printRecordedArgsHistory(self: *const Self) void {
            std.debug.print("Recorded args history ({d} total calls):\n", .{self.callCount});
            for (self.allArgsAndSeq.items, 0..) |record, i| {
                std.debug.print("  Call Index [{d}] (Seq #{d}): {any}\n", .{ i, record.seq, record.args });
            }
        }
    };
}

pub fn whenReturnConfig(comptime argsType: type, comptime returnType: type) type {
    const mockType = mock(argsType, returnType);
    const argsCaptorType = captorMod.captor(argsType); // This line is corrected

    return struct {
        const ThisWhen = @This();
        instance: *mockType,

        fn captureWrapper(payload: ?*anyopaque, args: argsType) void {
            if (payload) |p| {
                const captorPtr: *argsCaptorType = @ptrCast(@alignCast(p));
                captorPtr.capture(args);
            } else {
                std.debug.print("Capture payload was null!\n", .{});
            }
        }

        pub fn init(inst: *mockType) ThisWhen {
            inst.clearStubsAndCaptures();
            return ThisWhen{ .instance = inst };
        }

        pub fn thenReturn(self: *const ThisWhen, value: returnType) *const ThisWhen {
            self.instance.stubQueue.append(.{ .returnValue = value }) catch @panic("thenReturn failed");
            return self;
        }

        pub fn thenCall(self: *const ThisWhen, fnPtr: *const fn (*mockType, argsType) returnType) *const ThisWhen {
            self.instance.stubQueue.append(.{ .callFunction = fnPtr }) catch @panic("thenCall failed");
            return self;
        }

        pub fn captureArgs(self: *const ThisWhen, captor: *argsCaptorType) *const ThisWhen {
            self.instance.captureFn = &captureWrapper;
            self.instance.capturePayload = captor;
            return self;
        }
    };
}

pub fn when(comptime argsType: type, comptime returnType: type, instance: *mock(argsType, returnType))
whenReturnConfig(argsType, returnType) {
    return whenReturnConfig(argsType, returnType).init(instance);
}