const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const m = b.addModule("llvm", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    m.addSystemIncludePath(.{ .cwd_relative = "/usr/lib/llvm-18/include/" });
    m.addLibraryPath(.{ .cwd_relative = "/usr/lib/llvm-18/lib/" });
    m.linkSystemLibrary("LLVM-18", .{});

    const lib_test = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib_test.addSystemIncludePath(.{ .cwd_relative = "/usr/lib/llvm-18/include/" });
    lib_test.addLibraryPath(.{ .cwd_relative = "/usr/lib/llvm-18/lib/" });
    lib_test.linkLibC();
    lib_test.linkSystemLibrary("LLVM-18");
    const run_lib_unit_tests = b.addRunArtifact(lib_test);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
