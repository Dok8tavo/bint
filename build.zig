const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const mod = b.addModule("bint", .{
        .root_source_file = b.path("src/root.zig"),
        .optimize = optimize,
        .target = target,
    });

    const test_exe = b.addTest(.{ .root_module = mod });
    const test_run = b.addRunArtifact(test_exe);

    if (b.args) |args| test_run.addArgs(args);

    const doc = b.addInstallDirectory(.{
        .install_dir = .prefix,
        .install_subdir = "doc",
        .source_dir = test_exe.getEmittedDocs(),
    });

    const doc_step = b.step("doc", "Build & Emit the documentation.");
    const test_step = b.step("test", "Build & Run the unit tests.");
    const zls_step = b.step("zls", "A step for ZLS to use");

    doc_step.dependOn(&doc.step);
    test_step.dependOn(&test_run.step);
    zls_step.dependOn(&test_exe.step);
}
