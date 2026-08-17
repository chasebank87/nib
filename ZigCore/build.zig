const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const root_module = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .name = "nib_core",
        .linkage = .static,
        .root_module = root_module,
    });
    b.installArtifact(lib);

    const header_install = b.addInstallFileWithDir(
        b.path("include/nib_core.h"),
        .header,
        "nib_core.h",
    );
    b.getInstallStep().dependOn(&header_install.step);

    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run Zig core unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
