const std = @import("std");

const MaxInt = u65535;
const MinInt = i65535;

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseFast });
    const target = b.standardTargetOptions(.{});

    const mod = b.addModule("bint", .{
        .root_source_file = b.path("src/root.zig"),
        .optimize = optimize,
        .target = target,
    });

    const test_exe = b.addTest(.{ .root_module = mod });
    const test_run = b.addRunArtifact(test_exe);

    const suite_run = addSuite(b, mod, optimize, target);

    if (b.args) |args| {
        test_run.addArgs(args);
        suite_run.addArgs(args);
    }

    const doc = b.addInstallDirectory(.{
        .install_dir = .prefix,
        .install_subdir = "doc",
        .source_dir = test_exe.getEmittedDocs(),
    });

    const doc_step = b.step("doc", "Build & Emit the documentation.");
    const suite_step = b.step("suite", "Build & Run the comprehensive suite of tests.");
    const test_step = b.step("test", "Build & Run the unit tests.");
    const zls_step = b.step("zls", "A step for ZLS to use.");

    doc_step.dependOn(&doc.step);
    suite_step.dependOn(&suite_run.step);
    test_step.dependOn(&test_run.step);
    zls_step.dependOn(&test_exe.step);
}

fn addSuite(
    b: *std.Build,
    mod: *std.Build.Module,
    optimize: std.builtin.OptimizeMode,
    target: std.Build.ResolvedTarget,
) *std.Build.Step.Run {
    const suite_mod = b.createModule(.{
        .root_source_file = b.path("src/test.zig"),
        .optimize = optimize,
        .target = target,
    });

    const max_option = b.option(
        MaxInt,
        "max",
        "The upper bound of the comprehensive test suite.",
    );

    const min_option = b.option(
        MinInt,
        "min",
        "The lower bound of the comprehensive test suite.",
    );

    suite_mod.addImport("bint", mod);

    const suite_exe = b.addTest(.{ .root_module = suite_mod });
    const suite_run = b.addRunArtifact(suite_exe);

    const missing_max = b.addFail("Building the comprehensive test suite requires the \"max\" value to be set.");
    const missing_min = b.addFail("Building the comprehensive test suite requires the \"min\" value to be set.");
    const min_greater_than_max = b.addFail("The \"max\" value can't be greater than the \"min\" value.");
    const max_sub_min_too_great = b.addFail(b.fmt(
        "The difference between the \"max\" and the \"min\" values must not exceed {}",
        .{std.math.maxInt(MaxInt)},
    ));

    if (max_option == null)
        suite_exe.step.dependOn(&missing_max.step);

    if (min_option == null)
        suite_exe.step.dependOn(&missing_min.step);

    if (max_option) |max| if (min_option) |min| {
        // -n <= min <  n
        //  0 <= max < 2n
        if (0 < min and max < @as(MaxInt, @intCast(min)))
            suite_exe.step.dependOn(&min_greater_than_max.step);

        //  min <= max
        const n = -std.math.minInt(MinInt);
        // 0 <= min < 2
        //     =>
        // 0 <= max - min < 2n
        //
        // and
        //
        // 0 <= max <= n
        //     =>
        // 0 <= max - min < 2n
        if (min < 0 and n < max) {
            // -n <= min < 0 => 0 <= min + n < n
            const min_add_n_sub_1 = min + (n - 1);
            const min_add_n: MaxInt = @intCast(min_add_n_sub_1 + 1);

            // n <= max < 2n => 0 <= max - n < n
            const max_sub_n = max - n;

            // (max - n) < (min + n)
            //    <=> max - n - min - n < 0
            //    <=> max - min < 2n
            if (min_add_n <= max_sub_n)
                suite_exe.step.dependOn(&max_sub_min_too_great.step);
        }
    };

    const suite_cfg = b.addOptions();
    suite_cfg.addOption(MinInt, "min", min_option orelse 0);
    suite_cfg.addOption(MaxInt, "max", max_option orelse 0);

    suite_exe.root_module.addImport("cfg", suite_cfg.createModule());
    return suite_run;
}
