const std = @import("std");
const mockery = @import("mockery/mock.zig");
const argsMod = @import("mockery/arguments.zig");
const captorMod = @import("mockery/captor.zig");
const inOrderMod = @import("mockery/inOrder.zig");

fn printTestHeader(name: []const u8) void {
    std.debug.print("\n--- Test: {s} ---\n", .{name});
}

fn printTestFooter(name: []const u8) void {
    std.debug.print("--- End Test: {s} ---\n", .{name});
}

test "1. Basic Mocking: Return a Stubbed Value and Verify Call Count" {
    const testName = "1. Basic Mocking";
    printTestHeader(testName);
    const doSomethingArgs = struct { value: i32 };
    const doSomethingReturn = bool;

    var mockDoSomething = mockery.mock(doSomethingArgs, doSomethingReturn).init(std.testing.allocator);
    defer mockDoSomething.deinit();
    std.debug.print("  Mock initialized.\n", .{});

    _ = mockery.when(doSomethingArgs, doSomethingReturn, &mockDoSomething).thenReturn(true);
    mockDoSomething.setExhaustedBehavior(.repeatLast);
    std.debug.print("  Stubbed: .thenReturn(true), .repeatLast\n", .{});

    std.debug.print("  Calling: mockDoSomething.call(.{{ .value = 42 }})...\n", .{});
    const result = mockDoSomething.call(.{ .value = 42 });
    std.debug.print("  Result: {any}\n", .{result});
    try std.testing.expect(result);

    std.debug.print("  Verifying: .verifyCalled(1)...\n", .{});
    try mockDoSomething.verifyCalled(1);
    std.debug.print("  Verification successful.\n", .{});

    _ = mockery.when(doSomethingArgs, doSomethingReturn, &mockDoSomething).thenReturn(false);
    mockDoSomething.setExhaustedBehavior(.repeatLast);
    std.debug.print("  Re-stubbed: .thenReturn(false), .repeatLast\n", .{});

    std.debug.print("  Calling: mockDoSomething.call(.{{ .value = 99 }})...\n", .{});
    const result2 = mockDoSomething.call(.{ .value = 99 });
    std.debug.print("  Result: {any}\n", .{result2});
    try std.testing.expect(!result2);

    std.debug.print("  Verifying: .verifyCalled(2)...\n", .{});
    try mockDoSomething.verifyCalled(2);
    std.debug.print("  Verification successful.\n", .{});
    printTestFooter(testName);
}

test "2. Argument Verification: Checking Calls With Specific Arguments (verifyCalledWith)" {
    const testName = "2. Argument Verification (verifyCalledWith)";
    printTestHeader(testName);
    const test2Args = struct { x: i32, y: []const u8 };
    var m = mockery.mock(test2Args, bool).init(std.testing.allocator);
    defer m.deinit();
    std.debug.print("  Mock initialized.\n", .{});

    _ = mockery.when(test2Args, bool, &m).thenReturn(true);
    m.setExhaustedBehavior(.repeatLast);
    std.debug.print("  Stubbed: .thenReturn(true), .repeatLast\n", .{});

    const callArgs1 = test2Args{ .x = 123, .y = "test_string" };
    const callArgs2 = test2Args{ .x = 456, .y = "another_string" };
    const callArgs3 = test2Args{ .x = 123, .y = "test_string" };

    std.debug.print("  Calling: m.call(.{{ .x = {d}, .y = \"{s}\" }})...\n", .{callArgs1.x, callArgs1.y});
    _ = m.call(callArgs1);
    std.debug.print("  Calling: m.call(.{{ .x = {d}, .y = \"{s}\" }})...\n", .{callArgs2.x, callArgs2.y});
    _ = m.call(callArgs2);
    std.debug.print("  Calling: m.call(.{{ .x = {d}, .y = \"{s}\" }})...\n", .{callArgs3.x, callArgs3.y});
    _ = m.call(callArgs3);

    std.debug.print("  Verifying: .verifyCalled(3)...\n", .{});
    try m.verifyCalled(3);
    std.debug.print("  Verification successful.\n", .{});

    std.debug.print("  Verifying: .verifyCalledWith(.{{ .x = 123, .y = \"test_string\" }}, 2)...\n", .{});
    try m.verifyCalledWith(test2Args{ .x = 123, .y = "test_string" }, 2);
    std.debug.print("  Verification successful.\n", .{});

    std.debug.print("  Verifying: .verifyCalledWith(.{{ .x = 456, .y = \"another_string\" }}, 1)...\n", .{});
    try m.verifyCalledWith(test2Args{ .x = 456, .y = "another_string" }, 1);
    std.debug.print("  Verification successful.\n", .{});

    std.debug.print("  Verifying: .verifyCalledWith(.{{ .x = 789, .y = \"not_called_string\" }}, 0)...\n", .{});
    try m.verifyCalledWith(test2Args{ .x = 789, .y = "not_called_string" }, 0);
    std.debug.print("  Verification successful.\n", .{});
    printTestFooter(testName);
}

const test2bActualArgs = struct { id: u32, category: []const u8, value: i32, code: []const u8 };
const test2bMatchers = struct {
    id: argsMod.matcher(u32),
    category: argsMod.matcher([]const u8),
    value: argsMod.matcher(i32),
    code: argsMod.matcher([]const u8),
};

fn valueIsNegative(val: i32) bool {
    return val < 0;
}

fn idIsEven(idVal: u32) bool {
    return idVal % 2 == 0;
}

test "2b. Argument Verification with All Matchers (verifyCalledWithMatchers)" {
    const testName = "2b. Argument Verification with All Matchers";
    printTestHeader(testName);
    var m = mockery.mock(test2bActualArgs, void).init(std.testing.allocator);
    defer m.deinit();
    std.debug.print("  Mock initialized.\n", .{});

    _ = mockery.when(test2bActualArgs, void, &m).thenReturn(void{});
    m.setExhaustedBehavior(.repeatLast);
    std.debug.print("  Stubbed: .thenReturn(void{{}}), .repeatLast\n", .{});

    const call1Args = test2bActualArgs{ .id = 1, .category = "books", .value = 100, .code = "PREFIX_CODE_SUFFIX" };
    std.debug.print("  Calling: m.call(.{{ .id = {d}, .category = \"{s}\", .value = {d}, .code = \"{s}\" }})...\n", .{call1Args.id, call1Args.category, call1Args.value, call1Args.code});
    m.call(call1Args);

    const call2Args = test2bActualArgs{ .id = 2, .category = "electronics", .value = -50, .code = "PREFIX_XYZ" };
    std.debug.print("  Calling: m.call(.{{ .id = {d}, .category = \"{s}\", .value = {d}, .code = \"{s}\" }})...\n", .{call2Args.id, call2Args.category, call2Args.value, call2Args.code});
    m.call(call2Args);

    const call3Args = test2bActualArgs{ .id = 3, .category = "books", .value = 200, .code = "ZYX_SUFFIX" };
    std.debug.print("  Calling: m.call(.{{ .id = {d}, .category = \"{s}\", .value = {d}, .code = \"{s}\" }})...\n", .{call3Args.id, call3Args.category, call3Args.value, call3Args.code});
    m.call(call3Args);

    const call4Args = test2bActualArgs{ .id = 4, .category = "food", .value = 100, .code = "RANDOM_CODE" };
    std.debug.print("  Calling: m.call(.{{ .id = {d}, .category = \"{s}\", .value = {d}, .code = \"{s}\" }})...\n", .{call4Args.id, call4Args.category, call4Args.value, call4Args.code});
    m.call(call4Args);

    const call5Args = test2bActualArgs{ .id = 5, .category = "books", .value = -20, .code = "PREFIX_123_SUFFIX" };
    std.debug.print("  Calling: m.call(.{{ .id = {d}, .category = \"{s}\", .value = {d}, .code = \"{s}\" }})...\n", .{call5Args.id, call5Args.category, call5Args.value, call5Args.code});
    m.call(call5Args);

    var matchers: test2bMatchers = undefined;

    matchers = test2bMatchers{ .id = argsMod.eq(u32, 1), .category = argsMod.any([]const u8), .value = argsMod.eq(i32, 100), .code = argsMod.any([]const u8) };
    std.debug.print("  Verifying with matchers (id=eq(1), cat=any, val=eq(100), code=any) for 1 call...\n", .{});
    try m.verifyCalledWithMatchers(matchers, 1);
    std.debug.print("  Verification successful.\n", .{});

    matchers = test2bMatchers{ .id = argsMod.any(u32), .category = argsMod.eq([]const u8, "books"), .value = argsMod.any(i32), .code = argsMod.any([]const u8) };
    std.debug.print("  Verifying with matchers (id=any, cat=eq(\"books\"), val=any, code=any) for 3 calls...\n", .{});
    try m.verifyCalledWithMatchers(matchers, 3);
    std.debug.print("  Verification successful.\n", .{});

    matchers = test2bMatchers{ .id = argsMod.any(u32), .category = argsMod.any([]const u8), .value = argsMod.custom(i32, &valueIsNegative), .code = argsMod.any([]const u8) };
    std.debug.print("  Verifying with matchers (val=custom(valueIsNegative)) for 2 calls...\n", .{});
    try m.verifyCalledWithMatchers(matchers, 2);
    std.debug.print("  Verification successful.\n", .{});

    matchers = test2bMatchers{ .id = argsMod.custom(u32, &idIsEven), .category = argsMod.any([]const u8), .value = argsMod.any(i32), .code = argsMod.any([]const u8) };
    std.debug.print("  Verifying with matchers (id=custom(idIsEven)) for 2 calls...\n", .{});
    try m.verifyCalledWithMatchers(matchers, 2);
    std.debug.print("  Verification successful.\n", .{});

    matchers = test2bMatchers{ .id = argsMod.any(u32), .category = argsMod.any([]const u8), .value = argsMod.any(i32), .code = argsMod.startsWith("PREFIX_") };
    std.debug.print("  Verifying with matchers (code=startsWith(\"PREFIX_\")) for 3 calls...\n", .{});
    try m.verifyCalledWithMatchers(matchers, 3);
    std.debug.print("  Verification successful.\n", .{});

    matchers = test2bMatchers{ .id = argsMod.any(u32), .category = argsMod.any([]const u8), .value = argsMod.any(i32), .code = argsMod.endsWith("_SUFFIX") };
    std.debug.print("  Verifying with matchers (code=endsWith(\"_SUFFIX\")) for 3 calls...\n", .{});
    try m.verifyCalledWithMatchers(matchers, 3);
    std.debug.print("  Verification successful.\n", .{});

    matchers = test2bMatchers{ .id = argsMod.eq(u32, 5), .category = argsMod.eq([]const u8, "books"), .value = argsMod.custom(i32, &valueIsNegative), .code = argsMod.startsWith("PREFIX_") };
    std.debug.print("  Verifying with matchers (id=eq(5), cat=eq(\"books\"), val=custom(valueIsNegative), code=startsWith(\"PREFIX_\")) for 1 call...\n", .{});
    try m.verifyCalledWithMatchers(matchers, 1);
    std.debug.print("  Verification successful.\n", .{});

    matchers = test2bMatchers{ .id = argsMod.eq(u32, 1), .category = argsMod.eq([]const u8, "books"), .value = argsMod.eq(i32, 100), .code = argsMod.endsWith("_SUFFIX") };
    std.debug.print("  Verifying with matchers (id=eq(1), cat=eq(\"books\"), val=eq(100), code=endsWith(\"_SUFFIX\")) for 1 call...\n", .{});
    try m.verifyCalledWithMatchers(matchers, 1);
    std.debug.print("  Verification successful.\n", .{});
    printTestFooter(testName);
}

const test3Args = struct { a: i32, b: i32 };
const test3Return = i32;

fn customSum(mockInstance: *mockery.mock(test3Args, test3Return), argsReceived: test3Args) test3Return {
    std.debug.print("    [customSum] Called with args: .{{ .a = {d}, .b = {d} }}\n", .{ argsReceived.a, argsReceived.b });
    _ = mockInstance;
    const sumResult = argsReceived.a + argsReceived.b;
    std.debug.print("    [customSum] Returning: {d}\n", .{sumResult});
    return sumResult;
}

test "3. Stubbing with a Custom Function (thenCall)" {
    const testName = "3. Stubbing with a Custom Function (thenCall)";
    printTestHeader(testName);
    var m = mockery.mock(test3Args, test3Return).init(std.testing.allocator);
    defer m.deinit();
    std.debug.print("  Mock initialized.\n", .{});

    _ = mockery.when(test3Args, test3Return, &m).thenCall(&customSum);
    m.setExhaustedBehavior(.repeatLast);
    std.debug.print("  Stubbed: .thenCall(&customSum), .repeatLast\n", .{});

    const call1Args = test3Args{ .a = 10, .b = 5 };
    std.debug.print("  Calling: m.call(.{{ .a = {d}, .b = {d} }})...\n", .{call1Args.a, call1Args.b});
    const result1 = m.call(call1Args);
    std.debug.print("  Result1: {d}\n", .{result1});
    try std.testing.expectEqual(@as(test3Return, 15), result1);

    const call2Args = test3Args{ .a = -3, .b = 8 };
    std.debug.print("  Calling: m.call(.{{ .a = {d}, .b = {d} }})...\n", .{call2Args.a, call2Args.b});
    const result2 = m.call(call2Args);
    std.debug.print("  Result2: {d}\n", .{result2});
    try std.testing.expectEqual(@as(test3Return, 5), result2);

    std.debug.print("  Verifying: .verifyCalled(2)...\n", .{});
    try m.verifyCalled(2);
    std.debug.print("  Verification successful.\n", .{});
    printTestFooter(testName);
}

test "4. Argument Capturing" {
    const testName = "4. Argument Capturing";
    printTestHeader(testName);
    const captureArgsType = struct { name: []const u8, count: i32 };
    const captureReturnType = void;

    var m = mockery.mock(captureArgsType, captureReturnType).init(std.testing.allocator);
    defer m.deinit();
    std.debug.print("  Mock initialized.\n", .{});

    var captor = captorMod.captor(captureArgsType).init(std.testing.allocator);
    defer captor.deinit();
    std.debug.print("  Captor initialized.\n", .{});

    _ = mockery.when(captureArgsType, captureReturnType, &m)
    .thenReturn(void{})
    .captureArgs(&captor);
    m.setExhaustedBehavior(.repeatLast);
    std.debug.print("  Stubbed: .thenReturn(void{{}}), .captureArgs(&captor), .repeatLast\n", .{});

    const call1Args = captureArgsType{ .name = "first", .count = 10 };
    std.debug.print("  Calling: m.call(.{{ .name = \"{s}\", .count = {d} }})...\n", .{call1Args.name, call1Args.count});
    m.call(call1Args);

    const call2Args = captureArgsType{ .name = "second", .count = 25 };
    std.debug.print("  Calling: m.call(.{{ .name = \"{s}\", .count = {d} }})...\n", .{call2Args.name, call2Args.count});
    m.call(call2Args);

    const call3Args = captureArgsType{ .name = "third", .count = -5 };
    std.debug.print("  Calling: m.call(.{{ .name = \"{s}\", .count = {d} }})...\n", .{call3Args.name, call3Args.count});
    m.call(call3Args);

    std.debug.print("  Verifying: .verifyCalled(3)...\n", .{});
    try m.verifyCalled(3);
    std.debug.print("  Verification successful.\n", .{});

    std.debug.print("  Getting all captured values...\n", .{});
    const allCaptured = captor.getAllValues();
    std.debug.print("  All captured values (count: {d}):\n", .{allCaptured.len});
    for (allCaptured, 0..) |val, i| {
        std.debug.print("    [{d}]: .{{ .name = \"{s}\", .count = {d} }}\n", .{i, val.name, val.count});
    }
    try std.testing.expectEqual(@as(usize, 3), allCaptured.len);

    std.debug.print("  Getting last captured value...\n", .{});
    const lastValue = try captor.getLastValue();
    std.debug.print("  Last captured value: .{{ .name = \"{s}\", .count = {d} }}\n", .{lastValue.name, lastValue.count});
    try std.testing.expectEqualSlices(u8, "third", lastValue.name);
    try std.testing.expectEqual(@as(i32, -5), lastValue.count);

    std.debug.print("  Verifying specific captured values by index...\n", .{});
    try std.testing.expectEqualSlices(u8, "first", allCaptured[0].name);
    try std.testing.expectEqual(@as(i32, 10), allCaptured[0].count);
    try std.testing.expectEqualSlices(u8, "second", allCaptured[1].name);
    try std.testing.expectEqual(@as(i32, 25), allCaptured[1].count);
    try std.testing.expectEqualSlices(u8, "third", allCaptured[2].name);
    try std.testing.expectEqual(@as(i32, -5), allCaptured[2].count);
    std.debug.print("  Specific captured values assertion successful.\n", .{});
    printTestFooter(testName);
}

test "5. Flexible Invocation Counts" {
    const testName = "5. Flexible Invocation Counts";
    printTestHeader(testName);
    const flexArgs = struct { value: u16 };
    const flexReturn = void;
    const flexMatchers = struct { value: argsMod.matcher(u16) };

    var m = mockery.mock(flexArgs, flexReturn).init(std.testing.allocator);
    defer m.deinit();
    std.debug.print("  Mock initialized.\n", .{});

    _ = mockery.when(flexArgs, flexReturn, &m).thenReturn(void{});
    m.setExhaustedBehavior(.repeatLast);
    std.debug.print("  Stubbed: .thenReturn(void{{}}), .repeatLast\n", .{});

    std.debug.print("  Calling: m.call(.{{ .value = 10 }})...\n", .{});
    m.call(.{ .value = 10 });
    std.debug.print("  Calling: m.call(.{{ .value = 20 }})...\n", .{});
    m.call(.{ .value = 20 });
    std.debug.print("  Calling: m.call(.{{ .value = 10 }})...\n", .{});
    m.call(.{ .value = 10 });
    std.debug.print("  Calling: m.call(.{{ .value = 30 }})...\n", .{});
    m.call(.{ .value = 30 });
    std.debug.print("  Calling: m.call(.{{ .value = 10 }})...\n", .{});
    m.call(.{ .value = 10 });

    std.debug.print("  Verifying: .verifyCalledAtLeast(5)...\n", .{});
    try m.verifyCalledAtLeast(5);
    std.debug.print("  Verifying: .verifyCalledAtLeast(1)...\n", .{});
    try m.verifyCalledAtLeast(1);
    std.debug.print("  Verifying: .verifyCalledAtMost(5)...\n", .{});
    try m.verifyCalledAtMost(5);
    std.debug.print("  Verifying: .verifyCalledAtMost(10)...\n", .{});
    try m.verifyCalledAtMost(10);
    std.debug.print("  Verifying: .verifyCalled(5)...\n", .{});
    try m.verifyCalled(5);
    std.debug.print("  General call count verifications successful.\n", .{});

    std.debug.print("  Verifying: .verifyCalledWith(.{{ .value = 10 }}, 3)...\n", .{});
    try m.verifyCalledWith(.{ .value = 10 }, 3);
    std.debug.print("  Verification successful.\n", .{});

    const matchers10 = flexMatchers{ .value = argsMod.eq(u16, 10) };
    std.debug.print("  Verifying with matchers (value=eq(10)) .atLeast(3)...\n", .{});
    try m.verifyCalledWithMatchersAtLeast(matchers10, 3);
    std.debug.print("  Verifying with matchers (value=eq(10)) .atLeast(2)...\n", .{});
    try m.verifyCalledWithMatchersAtLeast(matchers10, 2);
    std.debug.print("  Verifying with matchers (value=eq(10)) .atMost(3)...\n", .{});
    try m.verifyCalledWithMatchersAtMost(matchers10, 3);
    std.debug.print("  Verifying with matchers (value=eq(10)) .atMost(5)...\n", .{});
    try m.verifyCalledWithMatchersAtMost(matchers10, 5);
    std.debug.print("  Matchers for value=eq(10) verifications successful.\n", .{});

    const matchersAny = flexMatchers{ .value = argsMod.any(u16) };
    std.debug.print("  Verifying with matchers (value=any) .atLeast(5)...\n", .{});
    try m.verifyCalledWithMatchersAtLeast(matchersAny, 5);
    std.debug.print("  Verifying with matchers (value=any) .atMost(5)...\n", .{});
    try m.verifyCalledWithMatchersAtMost(matchersAny, 5);
    std.debug.print("  Matchers for value=any verifications successful.\n", .{});

    const matchers99 = flexMatchers{ .value = argsMod.eq(u16, 99) };
    std.debug.print("  Verifying with matchers (value=eq(99)) count 0...\n", .{});
    try m.verifyCalledWithMatchers(matchers99, 0);
    std.debug.print("  Verifying with matchers (value=eq(99)) .atMost(0)...\n", .{});
    try m.verifyCalledWithMatchersAtMost(matchers99, 0);
    std.debug.print("  Verifying with matchers (value=eq(99)) .atLeast(0)...\n", .{});
    try m.verifyCalledWithMatchersAtLeast(matchers99, 0);
    std.debug.print("  Matchers for value=eq(99) (not called) verifications successful.\n", .{});
    printTestFooter(testName);
}

const test6SeqArgs = struct { key: []const u8 };
const test6SeqReturn = i32;

test "6. Sequential Stubbing" {
    const testName = "6. Sequential Stubbing";
    printTestHeader(testName);
    var m = mockery.mock(test6SeqArgs, test6SeqReturn).init(std.testing.allocator);
    defer m.deinit();
    std.debug.print("  Mock 'm' initialized (default .panic exhausted behavior).\n", .{});

    _ = mockery.when(test6SeqArgs, test6SeqReturn, &m)
    .thenReturn(10)
    .thenReturn(20)
    .thenReturn(30);
    std.debug.print("  Mock 'm' stubbed sequentially: .thenReturn(10).thenReturn(20).thenReturn(30).\n", .{});

    std.debug.print("  Calling: m.call(.{{ .key = \"A\" }})...\n", .{});
    const res1 = m.call(.{ .key = "A" });
    std.debug.print("  Result1: {d}\n", .{res1});
    try std.testing.expectEqual(@as(i32, 10), res1);

    std.debug.print("  Calling: m.call(.{{ .key = \"B\" }})...\n", .{});
    const res2 = m.call(.{ .key = "B" });
    std.debug.print("  Result2: {d}\n", .{res2});
    try std.testing.expectEqual(@as(i32, 20), res2);

    std.debug.print("  Calling: m.call(.{{ .key = \"C\" }})...\n", .{});
    const res3 = m.call(.{ .key = "C" });
    std.debug.print("  Result3: {d}\n", .{res3});
    try std.testing.expectEqual(@as(i32, 30), res3);

    std.debug.print("  Verifying: 'm' .verifyCalled(3)...\n", .{});
    try m.verifyCalled(3);
    std.debug.print("  Verification successful. (A 4th call would panic here).\n", .{});

    std.debug.print("\n  --- Part 2: Repeat Last Behavior ---\n", .{});
    var mRepeat = mockery.mock(test6SeqArgs, test6SeqReturn).init(std.testing.allocator);
    defer mRepeat.deinit();
    std.debug.print("  Mock 'mRepeat' initialized.\n", .{});

    mRepeat.setExhaustedBehavior(.repeatLast);
    std.debug.print("  Mock 'mRepeat' set to .repeatLast exhausted behavior.\n", .{});

    _ = mockery.when(test6SeqArgs, test6SeqReturn, &mRepeat)
    .thenReturn(100)
    .thenReturn(200);
    std.debug.print("  Mock 'mRepeat' stubbed sequentially: .thenReturn(100).thenReturn(200).\n", .{});

    std.debug.print("  Calling: mRepeat.call(.{{ .key = \"X\" }})...\n", .{});
    const repRes1 = mRepeat.call(.{ .key = "X" });
    std.debug.print("  Repeat Result1: {d}\n", .{repRes1});
    try std.testing.expectEqual(@as(i32, 100), repRes1);

    std.debug.print("  Calling: mRepeat.call(.{{ .key = \"Y\" }})...\n", .{});
    const repRes2 = mRepeat.call(.{ .key = "Y" });
    std.debug.print("  Repeat Result2: {d}\n", .{repRes2});
    try std.testing.expectEqual(@as(i32, 200), repRes2);

    std.debug.print("  Calling: mRepeat.call(.{{ .key = \"Z\" }}) (should repeat last: 200)...\n", .{});
    const repRes3 = mRepeat.call(.{ .key = "Z" });
    std.debug.print("  Repeat Result3: {d}\n", .{repRes3});
    try std.testing.expectEqual(@as(i32, 200), repRes3);

    std.debug.print("  Calling: mRepeat.call(.{{ .key = \"W\" }}) (should repeat last: 200)...\n", .{});
    const repRes4 = mRepeat.call(.{ .key = "W" });
    std.debug.print("  Repeat Result4: {d}\n", .{repRes4});
    try std.testing.expectEqual(@as(i32, 200), repRes4);

    std.debug.print("  Verifying: 'mRepeat' .verifyCalled(4)...\n", .{});
    try mRepeat.verifyCalled(4);
    std.debug.print("  Verification successful.\n", .{});
    printTestFooter(testName);
}

const test7ArgsA = struct { id: i32 };
const test7ReturnA = u32;

const test7ArgsB = struct { name: []const u8 };
const test7ReturnB = bool;

const test7ArgsBMatchers = struct { name: argsMod.matcher([]const u8) };

test "7. In-Order Verification" {
    const testName = "7. In-Order Verification";
    printTestHeader(testName);
    var mockA = mockery.mock(test7ArgsA, test7ReturnA).init(std.testing.allocator);
    defer mockA.deinit();
    std.debug.print("  MockA initialized.\n", .{});

    var mockB = mockery.mock(test7ArgsB, test7ReturnB).init(std.testing.allocator);
    defer mockB.deinit();
    std.debug.print("  MockB initialized.\n", .{});

    _ = mockery.when(test7ArgsA, test7ReturnA, &mockA).thenReturn(1);
    mockA.setExhaustedBehavior(.repeatLast);
    std.debug.print("  MockA stubbed: .thenReturn(1), .repeatLast\n", .{});

    _ = mockery.when(test7ArgsB, test7ReturnB, &mockB).thenReturn(true);
    mockB.setExhaustedBehavior(.repeatLast);
    std.debug.print("  MockB stubbed: .thenReturn(true), .repeatLast\n", .{});

    std.debug.print("  Calls (Global Sequence #):\n", .{});
    std.debug.print("    1. mockA.call(.{{ .id = 10 }})...\n", .{});
    _ = mockA.call(.{ .id = 10 });
    std.debug.print("    2. mockB.call(.{{ .name = \"first\" }})...\n", .{});
    _ = mockB.call(.{ .name = "first" });
    std.debug.print("    3. mockA.call(.{{ .id = 20 }})...\n", .{});
    _ = mockA.call(.{ .id = 20 });
    std.debug.print("    4. mockB.call(.{{ .name = \"second\" }})...\n", .{});
    _ = mockB.call(.{ .name = "second" });
    std.debug.print("    5. mockA.call(.{{ .id = 30 }})...\n", .{});
    _ = mockA.call(.{ .id = 30 });

    var inOrderVerifier = inOrderMod.inOrder();
    std.debug.print("  InOrderVerifier initialized.\n", .{});

    std.debug.print("  Verifying in order (1): mockA with .{{ .id = 10 }}...\n", .{});
    try inOrderVerifier.verify(test7ArgsA, test7ReturnA, &mockA, .{ .id = 10 });
    std.debug.print("  Verification successful.\n", .{});

    std.debug.print("  Verifying in order (2): mockB with .{{ .name = \"first\" }}...\n", .{});
    try inOrderVerifier.verify(test7ArgsB, test7ReturnB, &mockB, .{ .name = "first" });
    std.debug.print("  Verification successful.\n", .{});

    std.debug.print("  Verifying in order (3): mockA with .{{ .id = 20 }}...\n", .{});
    try inOrderVerifier.verify(test7ArgsA, test7ReturnA, &mockA, .{ .id = 20 });
    std.debug.print("  Verification successful.\n", .{});

    const matchersBSecond = test7ArgsBMatchers{ .name = argsMod.endsWith("second") };
    std.debug.print("  Verifying in order (4): mockB with matchers (name=endsWith(\"second\"))...\n", .{});
    try inOrderVerifier.verifyWithMatchers( test7ArgsB, test7ReturnB, &mockB, matchersBSecond );
    std.debug.print("  Verification successful.\n", .{});

    std.debug.print("  Verifying in order (5): mockA with .{{ .id = 30 }}...\n", .{});
    try inOrderVerifier.verify(test7ArgsA, test7ReturnA, &mockA, .{ .id = 30 });
    std.debug.print("  Verification successful.\n", .{});

    printTestFooter(testName);
}