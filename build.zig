const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // TODO: Don't really need the addStaticLibrary intermediaries

    const fsb5_lib = b.addStaticLibrary(.{
        .name = "fsb5",
        .root_source_file = b.path("src/fsb5.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(fsb5_lib);

    const libatrac9 = b.dependency("libatrac9", .{
        .target = target,
        .optimize = optimize,
    });
    var libatrac9_root_module = b.addModule("libatrac9", .{
        .root_source_file = b.path("src/libatrac9/libatrac9.zig"),
        .target = target,
        .optimize = optimize,
    });
    libatrac9_root_module.addIncludePath(libatrac9.path("C/src"));
    libatrac9_root_module.addCSourceFiles(.{
        .root = libatrac9.path("C/src"),
        .files = &.{
            "band_extension.c",
            "bit_allocation.c",
            "bit_reader.c",
            "decinit.c",
            "decoder.c",
            "huffCodes.c",
            "imdct.c",
            "libatrac9.c",
            "quantization.c",
            "scale_factors.c",
            "tables.c",
            "unpack.c",
            "utility.c",
        },
        .flags = &.{
            // TODO: What flags here?
            "-Wall",
            "-Wextra",
            "-std=c99",
            "-fno-sanitize=undefined",
        },
    });
    const libatrac9_c = b.addTranslateC(.{
        .root_source_file = b.path("src/libatrac9/libatrac9_c.h"),
        .target = target,
        .optimize = optimize,
    });
    libatrac9_c.addIncludePath(libatrac9.path("C/src"));
    libatrac9_root_module.addImport("libatrac9_c", libatrac9_c.createModule());

    const libmp3lame = b.dependency("libmp3lame", .{
        .target = target,
        .optimize = optimize,
    });

    const libmp3lame_artifact = libmp3lame.artifact("mp3lame");
    for (libmp3lame_artifact.root_module.link_objects.items) |link_object| {
        switch (std.meta.activeTag(link_object)) {
            .c_source_files => {
                const new_flags = std.mem.concat(b.allocator, []const u8, &.{
                    link_object.c_source_files.flags,
                    &.{
                        "-fno-sanitize=undefined",
                    },
                }) catch @panic("OOM");
                link_object.c_source_files.flags = new_flags;
            },
            else => {},
        }
    }

    var libmp3lame_root_module = b.addModule("lame", .{
        .root_source_file = b.path("src/lame/libmp3lame.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lame_c = b.addTranslateC(.{
        .root_source_file = b.path("src/lame/lame_c.h"),
        .target = target,
        .optimize = optimize,
    });
    lame_c.addIncludePath(libmp3lame.path("include"));
    lame_c.addIncludePath(libmp3lame.path("libmp3lame"));
    libmp3lame_root_module.addImport("libmp3lame_c", lame_c.createModule());

    const exe_convert_single_file = b.addExecutable(.{
        .name = "bb-audio-fsb5-file-convert",
        .root_source_file = b.path("src/convert_util.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_convert_single_file.root_module.addImport("fsb5", &fsb5_lib.root_module);
    exe_convert_single_file.root_module.addImport("libatrac9", libatrac9_root_module);
    exe_convert_single_file.root_module.addImport("libmp3lame", libmp3lame_root_module);
    exe_convert_single_file.linkLibrary(libmp3lame.artifact("mp3lame"));

    exe_convert_single_file.linkLibC();

    b.installArtifact(exe_convert_single_file);

    // TEMP: v REMOVE THIS AFTER EXPERIMENT
    const exe_extract_single_file = b.addExecutable(.{
        .name = "test-extract-single-file-delete-me",
        .root_source_file = b.path("src/test_extract_single_file.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_extract_single_file.root_module.addImport("fsb5", &fsb5_lib.root_module);
    exe_extract_single_file.root_module.addImport("libatrac9", libatrac9_root_module);
    exe_extract_single_file.root_module.addImport("libmp3lame", libmp3lame_root_module);
    exe_extract_single_file.linkLibrary(libmp3lame.artifact("mp3lame"));

    exe_extract_single_file.linkLibC();

    b.installArtifact(exe_extract_single_file);
    // TEMP: ^ REMOVE THIS AFTER EXPERIMENT

    const exe_convert_batch = b.addExecutable(.{
        .name = "bb-audio-fsb5-batch-convert",
        .root_source_file = b.path("src/convert_batch_util.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_convert_batch.root_module.addImport("fsb5", &fsb5_lib.root_module);
    exe_convert_batch.root_module.addImport("libatrac9", libatrac9_root_module);
    exe_convert_batch.root_module.addImport("libmp3lame", libmp3lame_root_module);
    exe_convert_batch.linkLibrary(libmp3lame.artifact("mp3lame"));

    exe_convert_batch.linkLibC();

    libmp3lame_root_module.addImport("lame_c", lame_c.createModule());

    b.installArtifact(exe_convert_batch);

    const exe_info_batch = b.addExecutable(.{
        .name = "bb-audio-fsb5-batch-info",
        .root_source_file = b.path("src/info_batch_util.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_info_batch.root_module.addImport("fsb5", &fsb5_lib.root_module);

    b.installArtifact(exe_info_batch);

    const exe_info_single_file = b.addExecutable(.{
        .name = "bb-audio-fsb5-file-info",
        .root_source_file = b.path("src/info_util.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_info_single_file.root_module.addImport("fsb5", &fsb5_lib.root_module);

    b.installArtifact(exe_info_single_file);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe_info_batch);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/fsb5.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(lib_unit_tests);

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    // TODO: Get all paths working, maybe add for multiple exes
    // const exe_unit_tests = b.addTest(.{
    //     .root_source_file = b.path("src/fsb5.zig"),  // TODO: Fix paths
    //     .target = target,
    //     .optimize = optimize,
    // });

    // b.installArtifact(exe_unit_tests);

    // const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    // test_step.dependOn(&run_exe_unit_tests.step);
}
