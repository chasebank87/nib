const std = @import("std");
const builtin = @import("builtin");

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

    // Apple ld requires 8-byte-aligned Mach-O archive members. Zig's llvm-ar
    // does not emit that padding. Running libtool on the raw archive drops
    // libnib_core_zcu.o; the script ranlib -D's first, then libtool.
    const lib_bin = if (builtin.os.tag == .macos and target.result.os.tag == .macos) blk: {
        const repack = b.addSystemCommand(&.{"/bin/sh"});
        repack.setName("repack-nib_core-for-apple-ld");
        repack.addFileArg(b.path("scripts/repack-archive-for-apple-ld.sh"));
        repack.addFileArg(lib.getEmittedBin());
        const aligned = repack.addOutputFileArg("libnib_core.a");
        break :blk aligned;
    } else lib.getEmittedBin();

    const install_lib = b.addInstallFileWithDir(lib_bin, .lib, "libnib_core.a");
    b.getInstallStep().dependOn(&install_lib.step);

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
