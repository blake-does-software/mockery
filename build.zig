const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exeMod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "mockery",
        .root_module = exeMod,
    });
    b.installArtifact(exe);

    const runExe = b.addRunArtifact(exe);
    runExe.step.dependOn(b.getInstallStep());
    if (b.args) |args| runExe.addArgs(args);

    const runStep = b.step("run", "Run the app");
    runStep.dependOn(&runExe.step);
    const testMod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const tests = b.addTest(.{
        .name = "mockeryTests",
        .root_module = testMod,
    });

    const runTests = b.addRunArtifact(tests);
    const testStep = b.step("test", "Run unit tests");
    testStep.dependOn(&runTests.step);
}
