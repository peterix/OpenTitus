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

fn build_game(b: *std.Build, name: []const u8, target: ResolvedTarget, optimize: std.builtin.Mode) *Step.Compile {
    const exe = b.addExecutable(.{
        .name = name,
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });
    if (target.query.os_tag == .windows) {
        exe.subsystem = .Windows;
    }

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
    exe.linkSystemLibrary("m");
    exe.linkSystemLibrary("SDL2");
    exe.linkSystemLibrary("SDL2main");

    const game_tests = b.addTest(.{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });
    game_tests.addCSourceFiles(.{ .files = &.{
        "src/audio/opl3/opl3.c",
        "src/audio/miniaudio/miniaudio.c",
        "src/audio/pocketmod/pocketmod.c",
    }, .flags = &.{
        "-fno-sanitize=shift",
    } });
    game_tests.addIncludePath(b.path("src/"));
    game_tests.addIncludePath(b.path("src/audio/opl3/"));
    game_tests.addIncludePath(b.path("src/audio/miniaudio/"));
    game_tests.addIncludePath(b.path("src/audio/pocketmod/"));

    game_tests.linkLibC();
    game_tests.linkSystemLibrary("m");
    game_tests.linkSystemLibrary("SDL2");
    game_tests.linkSystemLibrary("SDL2main");

    const run_game_tests = b.addRunArtifact(game_tests);

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build test`
    // This will evaluate the `test` step rather than the default, which is "install".
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_game_tests.step);

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

    const game = build_game(b, "game", target, optimize);

    // This declares intent for the library to be installed into the standard
    // location when the user invokes the "install" step (the default step when
    // running `zig build`).
    const copy_step = b.addUpdateSourceFiles();
    copy_step.addCopyFileToSource(game.getEmittedBin(), "bin/moktar/openmoktar");
    copy_step.addCopyFileToSource(game.getEmittedBin(), "bin/titus/opentitus");
    b.getInstallStep().dependOn(&copy_step.step);
}
