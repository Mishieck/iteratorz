const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("iteratorz", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const uppercase_vowels = b.addExecutable(.{
        .name = "iteratorz",
        .root_module = b.createModule(.{
            .root_source_file = b.path("./examples/uppercase_vowels.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    uppercase_vowels.root_module.addImport("iteratorz", mod);

    b.installArtifact(uppercase_vowels);
    const run_step = b.step("uppercase_vowels", "Run uppercase_vowels.");
    const run_cmd = b.addRunArtifact(uppercase_vowels);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| run_cmd.addArgs(args);

    const mod_tests = b.addTest(.{ .root_module = mod });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
}
