const std = @import("std");

const Step = std.Build.Step;
const CrossTarget = std.zig.CrossTarget;

const C_STANDARD = std.Build.CStd.C11;

const TARGETS = [_]std.zig.CrossTarget{
    .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .musl },
    .{ .cpu_arch = .aarch64, .os_tag = .linux },
    .{ .cpu_arch = .x86_64, .os_tag = .windows },
    .{ .cpu_arch = .aarch64, .os_tag = .macos },
};

fn build_opl(b: *std.Build, target: CrossTarget, optimize: std.builtin.Mode) *Step.Compile {
    const lib = b.addStaticLibrary(.{
        .name = "opl",
        .root_source_file = null, //.{ .path = "opl/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    lib.addCSourceFiles(&.{
        "opl/opl.c",
        "opl/opl_queue.c",
        "opl/opl_sdl.c",
        "opl/opl3.c",
    },
    // NOTE: the use of bit shifts of negative numbers is quite extensive, so we disable ubsan shooting us in the foot with those...
    // FIXME: remove the UB-ness
    &.{
        "-fno-sanitize=shift",
    });
    lib.addIncludePath(std.build.LazyPath.relative("opl/"));
    lib.c_std = C_STANDARD;
    lib.linkLibC();
    lib.linkSystemLibrary("SDL2_mixer");
    lib.installHeader("opl/opl.h", "opl.h");
    return lib;
}

fn build_game(b: *std.Build, name: []const u8, target: CrossTarget, optimize: std.builtin.Mode, opl: *Step.Compile) *Step.Compile {
    const exe = b.addExecutable(.{
        .name = name,
        .root_source_file = .{ .path = "main.zig" },
        .target = target,
        .optimize = optimize,
    });
    if (target.os_tag == .windows) {
        exe.subsystem = .Windows;
    }
    exe.c_std = C_STANDARD;

    exe.addCSourceFiles(&.{
        "src/audio.c",
        "src/draw.c",
        "src/enemies.c",
        "src/gates.c",
        "src/level.c",
        "src/objects.c",
        "src/original.c",
        "src/player.c",
        "src/reset.c",
        "src/sprites.c",
    },
    // NOTE: the use of bit shifts of negative numbers is quite extensive, so we disable ubsan shooting us in the foot with those...
    // FIXME: remove the UB-ness
    &.{
        "-fno-sanitize=shift",
    });
    exe.addIncludePath(std.build.LazyPath.relative("src/"));

    exe.linkLibC();
    exe.linkSystemLibrary("m");
    exe.linkSystemLibrary("SDL2");
    exe.linkSystemLibrary("SDL2main");
    exe.linkSystemLibrary("SDL2_mixer");
    exe.linkLibrary(opl);
    return exe;
}

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // TODO: we first need to set up SDL2 for cross-compilation
    //const target = TARGETS[0];

    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const opl = build_opl(b, target, optimize);
    const game = build_game(b, "game", target, optimize, opl);

    // This declares intent for the library to be installed into the standard
    // location when the user invokes the "install" step (the default step when
    // running `zig build`).
    const wf = b.addWriteFiles();
    wf.addCopyFileToSource(game.getEmittedBin(), "bin/moktar/openmoktar");
    wf.addCopyFileToSource(game.getEmittedBin(), "bin/titus/opentitus");
    b.getInstallStep().dependOn(&wf.step);

    // TODO: do something with unit tests?
    // // Creates a step for unit testing. This only builds the test executable
    // // but does not run it.
    // const main_tests = b.addTest(.{
    //     .root_source_file = .{ .path = "opl/main.zig" },
    //     .target = target,
    //     .optimize = optimize,
    // });

    // const run_main_tests = b.addRunArtifact(main_tests);

    // // This creates a build step. It will be visible in the `zig build --help` menu,
    // // and can be selected like this: `zig build test`
    // // This will evaluate the `test` step rather than the default, which is "install".
    // const test_step = b.step("test", "Run library tests");
    // test_step.dependOn(&run_main_tests.step);
}
