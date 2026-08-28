const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .riscv32,
        .os_tag = .freestanding,
        .abi = .eabi,
        .cpu_model = .{ .explicit = &std.Target.riscv.cpu.generic_rv32 },
        .cpu_features_add = std.Target.riscv.featureSet(&.{ .m, .a, .c }),
    });
    const optimize = b.standardOptimizeOption(.{});

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "zigled",
        .root_module = lib_mod,
    });
    lib.bundle_compiler_rt = true;
    b.installArtifact(lib);

    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/lib.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    });

    const host_tests = b.addTest(.{
        .root_module = test_mod,
    });
    const run_tests = b.addRunArtifact(host_tests);
    b.step("test", "Run host unit tests").dependOn(&run_tests.step);
}
