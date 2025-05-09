# Mockery — Mockito‑Style Mocking for Zig
**Extended Tutorial (Zig 0.14‑compatible): Real‑World Tests That Match the Stories**

---

## 1 Basic Mocking — Payment Gateway Happy Path

| Story | “Our checkout service calls **`charge()`** once. We only care that it returns *success* and that it happened exactly once.” |
|-------|-----------------------------------------------------------------------------------------------------------------------------|

```zig
const std = @import("std");
const mockery = @import("mockery/mock.zig");

test "payment gateway charge() called once" {
const PaymentArgs = struct { amount: u32 };
var gateway = mockery
.mock(PaymentArgs, bool)
.init(std.testing.allocator);
defer gateway.deinit();

    // Stub one success result; repeat it if called more (so test panics if >1)
    _ = mockery.when(PaymentArgs, bool, &gateway)
        .thenReturn(true);
    gateway.setExhaustedBehavior(.repeatLast);

    // Code‑under‑test would call gateway. We simulate it here:
    try std.testing.expect(gateway.call(.{ .amount = 5_000 }));

    // Assert exactly one invocation.
    try gateway.verifyCalled(1);
}
```

---

## 2 Argument Verification — Audit Logger

| Story | “Logger must record two events for **user 123** and one for **user 456**.”          |
|-------|-------------------------------------------------------------------------------------|
```zig
const std = @import("std");
const mockery = @import("mockery/mock.zig");

test "audit logger argument counts" {
const LogArgs = struct { user_id: u32, event: []const u8 };
var logger = mockery.mock(LogArgs, void).init(std.testing.allocator);
defer logger.deinit();

    _ = mockery.when(LogArgs, void, &logger).thenReturn(void{});
    logger.setExhaustedBehavior(.repeatLast);

    // Simulated code‑under‑test
    logger.call(.{ .user_id = 123, .event = "login"     });
    logger.call(.{ .user_id = 456, .event = "purchase"  });
    logger.call(.{ .user_id = 123, .event = "logout"    });

    try logger.verifyCalledWith(.{ .user_id = 123, .event = "login"  }, 1);
    try logger.verifyCalledWith(.{ .user_id = 123, .event = "logout" }, 1);
    try logger.verifyCalledWith(.{ .user_id = 456, .event = "purchase" }, 1);
}
```

---

## 2b Matchers — Notification Service

| Story | “`sendEmail()` should be invoked **three times** where the *subject* ends with `_ALERT` and the *statusCode* is negative.” |
|-------|----------------------------------------------------------------------------------------------------------------------------|
```zig
const std = @import("std");
const mockery = @import("mockery/mock.zig");
const m = @import("mockery/arguments.zig");

test "email notifications with matchers" {
const EmailArgs = struct { subject: []const u8, status_code: i32 };
var notifier = mockery.mock(EmailArgs, void).init(std.testing.allocator);
defer notifier.deinit();

    _ = mockery.when(EmailArgs, void, &notifier).thenReturn(void{});
    notifier.setExhaustedBehavior(.repeatLast);

    // Simulated calls
    notifier.call(.{ .subject = "CPU_ALERT",    .status_code = -1 });
    notifier.call(.{ .subject = "RAM_ALERT",    .status_code = -2 });
    notifier.call(.{ .subject = "DISK_ALERT",   .status_code = -3 });

    const match = struct {
        subject: m.endsWith("_ALERT"),
        status_code: m.custom(i32, struct {
            fn neg(v: i32) bool { return v < 0; }
        }.neg),
    };

    try notifier.verifyCalledWithMatchers(match, 3);
}
```

---

## 3 Custom Stubbing (`thenCall`) — Cart × Quantity

| Story | “Cache should return **`unit_price * qty`** on demand.”        |
|-------|----------------------------------------------------------------|
```zig
const std = @import("std");
const mockery = @import("mockery/mock.zig");

test "dynamic price calculation" {
const PriceArgs = struct { qty: u32, unit_price: f64 };

    fn calc(_: *anyopaque, p: PriceArgs) f64 {
        return p.unit_price * @as(f64, p.qty);
    }

    var cache = mockery.mock(PriceArgs, f64).init(std.testing.allocator);
    defer cache.deinit();

    _ = mockery.when(PriceArgs, f64, &cache).thenCall(&calc);

    try std.testing.expectApproxEqAbs(19.5, cache.call(.{ .qty = 3, .unit_price = 6.5 }), 1e-9);
}
```

---

## 4 Capturing Arguments — Telemetry Batch

| Story | “Ensure the *third* event captured has `count == -5`.” |
|-------|--------------------------------------------------------|
```zig
const std = @import("std");
const mockery = @import("mockery/mock.zig");
const captorMod = @import("mockery/captor.zig");

test "telemetry event capture" {
const Event = struct { name: []const u8, count: i32 };

    var telemetry = mockery.mock(Event, void).init(std.testing.allocator);
    defer telemetry.deinit();

    var captor = captorMod.captor(Event).init(std.testing.allocator);
    defer captor.deinit();

    _ = mockery.when(Event, void, &telemetry)
        .thenReturn(void{})
        .captureArgs(&captor);
    telemetry.setExhaustedBehavior(.repeatLast);

    telemetry.call(.{ .name = "first",  .count = 10 });
    telemetry.call(.{ .name = "second", .count = 25 });
    telemetry.call(.{ .name = "third",  .count = -5 });

    try std.testing.expectEqual(@as(i32, -5), (try captor.getLastValue()).count);
}
```

---

## 5 Flexible Invocation Counts — HTTP Retries

| Story | “`send()` may retry up to **3×**; must call at least once but never more than three.” |
|-------|---------------------------------------------------------------------------------------|
```zig
const std = @import("std");
const mockery = @import("mockery/mock.zig");

test "http retry count bounds" {
const UrlArgs = struct { url: []const u8 };

    var client = mockery.mock(UrlArgs, i32).init(std.testing.allocator);
    defer client.deinit();
    _ = mockery.when(UrlArgs, i32, &client).thenReturn(200);

    // Pretend retry loop
    client.call(.{ .url = "/health" });
    client.call(.{ .url = "/health" });
    client.call(.{ .url = "/health" });

    try client.verifyCalledAtLeast(1);
    try client.verifyCalledAtMost(3);
}
```

---

## 6 Sequential Stubbing & `repeatLast` — Build Server Polling

| Story | “Poll returns **QUEUED → RUNNING → SUCCESS**, then stays at *SUCCESS*.”   |
|-------|---------------------------------------------------------------------------|
```zig
const std = @import("std");
const mockery = @import("mockery/mock.zig");

test "build status progression" {
const PollArgs  = struct { build_id: []const u8 };
const PollReply = []const u8;

    var build = mockery.mock(PollArgs, PollReply).init(std.testing.allocator);
    defer build.deinit();

    _ = mockery.when(PollArgs, PollReply, &build)
        .thenReturn("QUEUED")
        .thenReturn("RUNNING")
        .thenReturn("SUCCESS");

    build.setExhaustedBehavior(.repeatLast);

    try std.testing.expectEqualSlices(u8, "QUEUED",  build.call(.{ .build_id = "A" }));
    try std.testing.expectEqualSlices(u8, "RUNNING", build.call(.{ .build_id = "A" }));
    try std.testing.expectEqualSlices(u8, "SUCCESS", build.call(.{ .build_id = "A" }));
    try std.testing.expectEqualSlices(u8, "SUCCESS", build.call(.{ .build_id = "A" })); // repeats
}
```

---

## 7 In‑Order Verification — File Exporter

| Story | “Exporter must call **open → writeHeader → writeRows → close** in that order.” |
|-------|--------------------------------------------------------------------------------|
```zig
const std = @import("std");
const mockery = @import("mockery/mock.zig");
const orderMod = @import("mockery/inOrder.zig");

test "file exporter order" {
// Mock open/close & writer separately
var file = mockery.mock(struct { }, void).init(std.testing.allocator);
var writer = mockery.mock(struct { section: []const u8 }, void).init(std.testing.allocator);
defer {
file.deinit();
writer.deinit();
}

    _ = mockery.when(struct { }, void, &file).thenReturn(void{});
    _ = mockery.when(struct { section: []const u8 }, void, &writer).thenReturn(void{});

    // --- execution sequence ---
    file.call(.{ });                            // open
    writer.call(.{ .section = "header" });      // writeHeader
    writer.call(.{ .section = "rows"   });      // writeRows
    file.call(.{ });                            // close

    var in_order = orderMod.inOrder();

    try in_order.verify(struct { }, void, &file, .{ });                       // open
    try in_order.verify(struct { section: []const u8 }, void,
        &writer, .{ .section = "header" });                                   // header
    try in_order.verify(struct { section: []const u8 }, void,
        &writer, .{ .section = "rows" });                                     // rows
    try in_order.verify(struct { }, void, &file, .{ });                       // close
}
```

---