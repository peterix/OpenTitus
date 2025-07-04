//
// Copyright (C) 2008 - 2024 The OpenTitus team
//
// Authors:
// Eirik Stople
// Petr Mrázek
//
// "Titus the Fox: To Marrakech and Back" (1992) and
// "Lagaf': Les Aventures de Moktar - Vol 1: La Zoubida" (1991)
// was developed by, and is probably copyrighted by Titus Software,
// which, according to Wikipedia, stopped buisness in 2005.
//
// OpenTitus is not affiliated with Titus Software.
//
// OpenTitus is  free software; you can redistribute  it and/or modify
// it under the  terms of the GNU General  Public License as published
// by the Free  Software Foundation; either version 3  of the License,
// or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful, but
// WITHOUT  ANY  WARRANTY;  without   even  the  implied  warranty  of
// MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.   See the GNU
// General Public License for more details.
//

const std = @import("std");

const Step = std.Build.Step;
const ResolvedTarget = std.Build.ResolvedTarget;
const LazyPath = std.Build.LazyPath;

const C_STANDARD = std.Build.CStd.C11;

fn setup_game_build(
    b: *std.Build,
    options: *std.Build.Step.Options,
    sdl_lib: *std.Build.Step.Compile,
    exe: *Step.Compile,
) void {
    // NOTE: the use of bit shifts of negative numbers is quite extensive, so we disable ubsan shooting us in the foot with those...
    // FIXME: remove the UB-ness
    exe.addCSourceFiles(.{ .files = &.{
        "src/audio/opl3/opl3.c",
        "src/audio/miniaudio/miniaudio.c",
        "src/audio/pocketmod/pocketmod.c",
    }, .flags = &.{
        "-fno-sanitize=shift",
    } });
    exe.addIncludePath(b.path("src/"));
    exe.addIncludePath(b.path("src/audio/opl3/"));
    exe.addIncludePath(b.path("src/audio/miniaudio/"));
    exe.addIncludePath(b.path("src/audio/pocketmod/"));

    exe.linkLibC();
    exe.linkLibrary(sdl_lib);
    exe.linkSystemLibrary("m");
    exe.root_module.addOptions("config", options);
}


fn build_game(
    b: *std.Build,
    name: []const u8,
    target: ResolvedTarget,
    optimize: std.builtin.Mode,
    options: *std.Build.Step.Options,
    sdl_lib: *std.Build.Step.Compile
) *Step.Compile {
    const exe = b.addExecutable(.{
        .name = name,
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });
    if (target.query.os_tag == .windows) {
        exe.subsystem = .Windows;
    }

    setup_game_build(b, options, sdl_lib, exe);
    return exe;
}

fn run_tests (
    b: *std.Build,
    target: ResolvedTarget,
    optimize: std.builtin.Mode,
    options: *std.Build.Step.Options,
    sdl_lib: *std.Build.Step.Compile
) void {
    const game_tests = b.addTest(.{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });
    setup_game_build(b, options, sdl_lib, game_tests);

    const run_game_tests = b.addRunArtifact(game_tests);

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build test`
    // This will evaluate the `test` step rather than the default, which is "install".
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_game_tests.step);

}

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {

    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const version = b.option([]const u8, "version", "application version string") orelse "0.0.0";
    const options = b.addOptions();
    options.addOption([]const u8, "version", version);

    const sdl_dep = b.dependency("sdl", .{
        .target = target,
        .optimize = optimize,
    });
    const sdl_lib = sdl_dep.artifact("SDL3");

    run_tests(b, target, optimize, options, sdl_lib);

    const titus = build_game(b, "opentitus", target, optimize, options, sdl_lib);
    const install_titus = b.addInstallArtifact(titus, .{.dest_dir = .{ .override = .{ .custom =  "./" } }});
    b.default_step.dependOn(&install_titus.step);
    b.installFile("./install/README.txt.titus", "./TITUS/README.txt");
    b.installFile("./install/README.txt.moktar", "./MOKTAR/README.txt");
}
