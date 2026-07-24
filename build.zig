const std = @import("std");

const test_targets = [_]std.Target.Query{ .{}, .{
    .cpu_arch = .aarch64,
    .os_tag = .macos,
} };

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addLibrary(.{
        .name = "calculator",
        .linkage = .static,
        .root_module = b.createModule(.{ .root_source_file = b.path("src/calculator.zig"), .target = target, .optimize = optimize }),
    });

    b.installArtifact(lib);

    const test_step = b.step("test", "Run unit tests");

    for (test_targets) |test_target| {
        const unit_tests = b.addTest(.{ .root_module = b.createModule(.{
            .root_source_file = b.path("src/calculator.zig"),
            .target = b.resolveTargetQuery(test_target),
        }) });

        const run_unit_tests = b.addRunArtifact(unit_tests);
        run_unit_tests.skip_foreign_checks = true;
        test_step.dependOn(&run_unit_tests.step);
    }
}
