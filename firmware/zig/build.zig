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

    if (b.option([]const u8, "idf-build-dir", "ESP-IDF CMake build directory, for main.c's compile_commands.json flags")) |idf_build_dir| {
        addEspIdfFlags(b, lib_mod, idf_build_dir);
    }

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
    const post_processing_mod = b.createModule(.{ .root_source_file = b.path("src/post_processing.zig") });
    post_processing_mod.addImport("color", color_mod);
    post_processing_mod.addImport("config", config_mod);
    post_processing_mod.addImport("frame_buffer", frame_buffer_mod);
    const state_mod = b.createModule(.{ .root_source_file = b.path("src/state.zig") });
    lib_mod.addImport("state", state_mod);
    const persistence_mod = b.createModule(.{ .root_source_file = b.path("src/persistence.zig") });
    persistence_mod.addImport("state", state_mod);
    const effect_engine_mod = b.createModule(.{ .root_source_file = b.path("src/effect_engine.zig") });
    effect_engine_mod.addImport("color", color_mod);
    effect_engine_mod.addImport("config", config_mod);
    effect_engine_mod.addImport("frame_buffer", frame_buffer_mod);
    effect_engine_mod.addImport("state", state_mod);
    effect_engine_mod.addImport("palette", palette_mod);
    effect_engine_mod.addImport("effect_engine", effect_engine_mod);
    const zigbee_iface_mod = b.createModule(.{ .root_source_file = b.path("src/zigbee_iface.zig") });
    zigbee_iface_mod.addImport("state", state_mod);

    lib_mod.addImport("config", config_mod);
    lib_mod.addImport("color", color_mod);
    lib_mod.addImport("frame_buffer", frame_buffer_mod);
    lib_mod.addImport("post_processing", post_processing_mod);
    lib_mod.addImport("persistence", persistence_mod);
    lib_mod.addImport("effect_engine", effect_engine_mod);

    const TestSpec = struct {
        src: []const u8,
        imports: []const struct { name: []const u8, mod: *std.Build.Module } = &.{},
    };

    const test_specs = [_]TestSpec{
        .{ .src = "src/lib.zig", .imports = &.{
            .{ .name = "state", .mod = state_mod },
            .{ .name = "config", .mod = config_mod },
        } },
        .{ .src = "src/config.zig" },
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
        .{ .src = "tests/post_processing_test.zig", .imports = &.{
            .{ .name = "color", .mod = color_mod },
            .{ .name = "config", .mod = config_mod },
            .{ .name = "frame_buffer", .mod = frame_buffer_mod },
            .{ .name = "post_processing", .mod = post_processing_mod },
        } },
        .{ .src = "tests/state_test.zig", .imports = &.{
            .{ .name = "state", .mod = state_mod },
        } },
        .{ .src = "tests/effect_engine_test.zig", .imports = &.{
            .{ .name = "effect_engine", .mod = effect_engine_mod },
            .{ .name = "frame_buffer", .mod = frame_buffer_mod },
            .{ .name = "config", .mod = config_mod },
            .{ .name = "state", .mod = state_mod },
        } },
        .{ .src = "tests/effects_test.zig", .imports = &.{
            .{ .name = "effect_engine", .mod = effect_engine_mod },
            .{ .name = "frame_buffer", .mod = frame_buffer_mod },
            .{ .name = "config", .mod = config_mod },
            .{ .name = "state", .mod = state_mod },
        } },
        .{ .src = "tests/persistence_test.zig", .imports = &.{
            .{ .name = "persistence", .mod = persistence_mod },
            .{ .name = "state", .mod = state_mod },
        } },
        .{ .src = "tests/zigbee_iface_test.zig", .imports = &.{
            .{ .name = "zigbee_iface", .mod = zigbee_iface_mod },
            .{ .name = "state", .mod = state_mod },
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

fn addEspIdfFlags(b: *std.Build, mod: *std.Build.Module, idf_build_dir: []const u8) void {
    const io = b.graph.io;
    const compile_db_path = b.pathJoin(&.{ idf_build_dir, "compile_commands.json" });
    const data = std.Io.Dir.cwd().readFileAlloc(io, compile_db_path, b.allocator, .limited(16 * 1024 * 1024)) catch |err| {
        std.debug.print("addEspIdfFlags: could not read {s}: {t}\n", .{ compile_db_path, err });
        return;
    };

    const parsed = std.json.parseFromSlice(std.json.Value, b.allocator, data, .{}) catch |err| {
        std.debug.print("addEspIdfFlags: could not parse {s}: {t}\n", .{ compile_db_path, err });
        return;
    };

    for (parsed.value.array.items) |entry| {
        const file = entry.object.get("file").?.string;
        if (!std.mem.endsWith(u8, file, "/main/main.c")) continue;

        const command = entry.object.get("command").?.string;

        // The toolchain's own libc (newlib) headers must come first in the
        // search list: ESP-IDF's `newlib/platform_include` override headers
        // use `#include_next<sys/reent.h>` to chain into the real one, and
        // Zig 0.16's translate-c (the `aro` C frontend, not clang) only
        // resolves that correctly when the real header is reachable ahead
        // of the override in the list.
        var first_tok = std.mem.tokenizeScalar(u8, command, ' ');
        if (first_tok.next()) |compiler_path| addToolchainSysrootIncludes(b, mod, io, compiler_path);

        var it = std.mem.tokenizeScalar(u8, command, ' ');
        _ = it.next(); // skip compiler path, already handled above
        while (it.next()) |tok| {
            if (std.mem.startsWith(u8, tok, "-I")) {
                const path = tok[2..];
                if (path.len > 0) mod.addIncludePath(.{ .cwd_relative = path });
            } else if (std.mem.startsWith(u8, tok, "-D") and std.mem.indexOfScalar(u8, tok, '\\') == null) {
                const def = tok[2..];
                if (std.mem.indexOfScalar(u8, def, '=')) |eq| {
                    mod.addCMacro(def[0..eq], def[eq + 1 ..]);
                } else if (def.len > 0) {
                    mod.addCMacro(def, "1");
                }
            }
        }
        return;
    }

    std.debug.print("addEspIdfFlags: no main.c entry found in {s}\n", .{compile_db_path});
}

// riscv32-esp-elf-gcc's own libc (newlib) and built-in headers (stdio.h,
// stdint.h, stdarg.h, ...) live in the toolchain's implicit search path,
// which gcc never spells out as an explicit -I flag in compile_commands.json.
// Ask the compiler itself where they are, so Zig's translate-c can resolve
// the ESP-IDF headers' plain #include <stdio.h>-style system includes.
fn addToolchainSysrootIncludes(b: *std.Build, mod: *std.Build.Module, io: std.Io, compiler_path: []const u8) void {
    const result = std.process.run(b.allocator, io, .{
        .argv = &.{ compiler_path, "-E", "-Wp,-v", "-xc", "-" },
    }) catch |err| {
        std.debug.print("addToolchainSysrootIncludes: could not run {s}: {t}\n", .{ compiler_path, err });
        return;
    };

    var in_list = false;
    var lines = std.mem.splitScalar(u8, result.stderr, '\n');
    while (lines.next()) |line| {
        if (std.mem.endsWith(u8, line, "search starts here:")) {
            in_list = true;
            continue;
        }
        if (std.mem.startsWith(u8, line, "End of search list")) break;
        if (!in_list) continue;
        const dir = std.mem.trim(u8, line, " \t");
        if (dir.len == 0) continue;
        const resolved = std.fs.path.resolve(b.allocator, &.{dir}) catch dir;
        mod.addIncludePath(.{ .cwd_relative = resolved });
    }
}
