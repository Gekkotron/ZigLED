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

    const color_mod = b.createModule(.{ .root_source_file = b.path("src/color.zig") });
    const palette_mod = b.createModule(.{ .root_source_file = b.path("src/palette.zig") });
    palette_mod.addImport("color", color_mod);
    const config_mod = b.createModule(.{ .root_source_file = b.path("src/config.zig") });
    const frame_buffer_mod = b.createModule(.{ .root_source_file = b.path("src/frame_buffer.zig") });
    frame_buffer_mod.addImport("color", color_mod);
    frame_buffer_mod.addImport("config", config_mod);

    const TestSpec = struct {
        src: []const u8,
        imports: []const struct { name: []const u8, mod: *std.Build.Module } = &.{},
    };

    const test_specs = [_]TestSpec{
        .{ .src = "src/lib.zig" },
        .{ .src = "tests/color_test.zig", .imports = &.{
            .{ .name = "color", .mod = color_mod },
        } },
        .{ .src = "tests/palette_test.zig", .imports = &.{
            .{ .name = "color", .mod = color_mod },
            .{ .name = "palette", .mod = palette_mod },
        } },
        .{ .src = "tests/frame_buffer_test.zig", .imports = &.{
            .{ .name = "color", .mod = color_mod },
            .{ .name = "config", .mod = config_mod },
            .{ .name = "frame_buffer", .mod = frame_buffer_mod },
        } },
    };

    const test_step = b.step("test", "Run host unit tests");
    for (test_specs) |spec| {
        const tm = b.createModule(.{
            .root_source_file = b.path(spec.src),
            .target = b.graph.host,
            .optimize = .Debug,
        });
        for (spec.imports) |imp| tm.addImport(imp.name, imp.mod);
        const t = b.addTest(.{ .root_module = tm });
        const run = b.addRunArtifact(t);
        test_step.dependOn(&run.step);
    }
}
