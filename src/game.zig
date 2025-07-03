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

const SDL = @import("SDL.zig");
const sqz = @import("sqz.zig");
const sqz_amiga = @import("sqz_amiga.zig");

// NOTE: force-imported modules
pub fn refAllDecls(comptime T: type) void {
    inline for (comptime std.meta.declarations(T)) |decl| {
        _ = &@field(T, decl.name);
    }
}
const credits = @import("ui/credits.zig");
comptime {
    refAllDecls(credits);
}

const pauseMenu = @import("ui/pause_menu.zig");
comptime {
    refAllDecls(pauseMenu);
}

const fonts = @import("ui/fonts.zig");
const image = @import("ui/image.zig");
const ImageFile = image.ImageFile;
const intro_text = @import("ui/intro_text.zig");
const input = @import("input.zig");
const main_menu = @import("ui/main_menu.zig");

const audio = @import("audio/audio.zig");
const data = @import("data.zig");
const globals = @import("globals.zig");
const engine = @import("engine.zig");
const window = @import("window.zig");

const json = @import("json.zig");
const ManagedJSON = json.ManagedJSON;

const TitusError = error{
    CannotReadConfig,
    CannotInitSDL,
    CannotInitInput,
    CannotInitAudio,
    CannotInitFonts,
};

const s = @import("settings.zig");
const Settings = s.Settings;
pub var settings_mem: ManagedJSON(Settings) = undefined;
pub var settings: *Settings = undefined;

const gs = @import("game_state.zig");
const GameState = gs.GameState;
pub var game_state_mem: ManagedJSON(GameState) = undefined;
pub var game_state: *GameState = undefined;

pub var allocator: std.mem.Allocator = undefined;

pub fn run() !u8 {
    try data.init();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("Memory leaked!");
    }
    // FIXME: stop this. We only do this because the control flow travels through C,
    //        so we need a global to pass the allocator around.
    allocator = gpa.allocator();

    settings_mem = try Settings.read(allocator);
    settings = &settings_mem.value;
    defer settings_mem.deinit();

    game_state_mem = try GameState.read(allocator);
    game_state = &game_state_mem.value;
    defer game_state_mem.deinit();

    // NOTE: we want to allocate memory for gamepad state before we start up SDL
    if(!input.init(allocator)) {
        std.debug.print("Unable to initialize Input...\n", .{});
        return TitusError.CannotInitInput;
    }

    if (!SDL.init(allocator)) {
        std.debug.print("Unable to initialize SDL: {s}\n", .{SDL.getError()});
        return TitusError.CannotInitSDL;
    }
    defer SDL.deinit();
    // NOTE: we want to close the gamepads before SDL exits
    defer input.deinit();

    try window.window_init();
    defer window.window_deinit();

    try audio.engine.init(allocator);
    defer audio.engine.deinit();

    data.init_anim_player();

    try fonts.fonts_load();
    defer fonts.fonts_free();

    try amigaTest();

    // View the menu when the main loop starts
    var state: c_int = 1;
    var retval: c_int = 0;

    if (!settings.seen_intro) {
        if (state != 0) {
            retval = intro_text.viewintrotext(allocator) catch |err| VALUE: {
                std.debug.print("Unable to view intro screen: {}", .{err});
                break :VALUE -1;
            };
            if (retval < 0) {
                state = 0;
            } else {
                settings.seen_intro = true;
                try settings.write(allocator);
            }
        }
    }

    if (state != 0) {
        retval = try image.viewImageFile(
            data.constants.*.logo,
            .FadeInFadeOut,
            4000,
            allocator,
        );
        if (retval < 0)
            state = 0;
    }

    audio.playTrack(.MainTitle);

    if (state != 0) {
        retval = try image.viewImageFile(
            data.constants.*.intro,
            .FadeInFadeOut,
            6500,
            allocator,
        );
        if (retval < 0)
            state = 0;
    }

    while (state != 0) {
        const curlevel = try main_menu.view_menu(
            data.constants.*.menu,
            allocator,
        );

        if (curlevel == null)
            state = 0;

        if (state != 0 and (curlevel.? < data.constants.*.levelfiles.len)) {
            retval = try engine.playtitus(
                @truncate(curlevel.?),
                allocator,
            );
            if (retval < 0)
                state = 0;
        }
    }

    try settings.write(allocator);
    try game_state.write(allocator);

    return 0;
}

fn amigaTest2() !void {
    const amiga_music: []const u8 = sqz_amiga.unSQZ("amiga/JEU1.PAT", allocator) catch foo: {
        std.debug.print("Too bad, Amiga file didn't uncompreess well...", .{});
        break :foo "";
    };
    if (amiga_music.len > 0) {
        try std.fs.cwd().writeFile("amiga/JEU1.PAT.UNSQZ", amiga_music);
    }

    allocator.free(amiga_music);
}

fn amigaTest1() !void {
    const amiga_huffman: []const u8 = sqz_amiga.unSQZ("amiga/fox.spr", allocator) catch foo: {
        std.debug.print("Too bad, Amiga file didn't uncompreess well...", .{});
        break :foo "";
    };
    if (amiga_huffman.len > 0) {
        try std.fs.cwd().writeFile("amiga/fox.spr.UNSQZ", amiga_huffman);
    }

    allocator.free(amiga_huffman);
}

fn amigaTest() !void {
    // try amigaTest1();
    // try amigaTest2();
}
