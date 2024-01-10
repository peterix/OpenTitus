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

const c = @import("c.zig");

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
const view_password = @import("ui/view_password.zig");
comptime {
    refAllDecls(view_password);
}

const fonts = @import("ui/fonts.zig");
const image = @import("ui/image.zig");
const ImageFile = image.ImageFile;
const intro_text = @import("ui/intro_text.zig");
const keyboard = @import("ui/keyboard.zig");
const menu = @import("ui/menu.zig");

const data = @import("data.zig");
const globals = @import("globals.zig");
const engine = @import("engine.zig");
const window = @import("window.zig");

const json = @import("json.zig");
const ManagedJSON = json.ManagedJSON;

const draw = @import("draw.zig");
comptime {
    refAllDecls(draw);
}

const TitusError = error{
    CannotReadConfig,
    CannotInitSDL,
    CannotInitAudio,
    CannotInitFonts,
};

const s = @import("settings.zig");
const Settings = s.Settings;
pub var settings_mem: ManagedJSON(Settings) = undefined;
pub export var settings: *Settings = undefined;

const gs = @import("game_state.zig");
const GameState = gs.GameState;
pub var game_state_mem: ManagedJSON(GameState) = undefined;
pub var game_state: *GameState = undefined;

pub var allocator: std.mem.Allocator = undefined;

pub fn run() !u8 {
    try data.init();

    globals.reset();

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

    if (c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_TIMER | c.SDL_INIT_AUDIO) != 0) {
        std.debug.print("Unable to initialize SDL: {s}\n", .{std.mem.span(c.SDL_GetError())});
        return TitusError.CannotInitSDL;
    }
    defer c.SDL_Quit();

    try window.window_init();

    if (c.audio_init() != 0) {
        std.debug.print("Unable to initialize Audio...\n", .{});
        return TitusError.CannotInitAudio;
    }
    defer c.audio_free();

    c.initoriginal();

    try fonts.fonts_load();
    defer fonts.fonts_free();

    // View the menu when the main loop starts
    var state: c_int = 1;
    var retval: c_int = 0;

    if (!game_state.seen_intro) {
        if (state != 0) {
            retval = intro_text.viewintrotext();
            if (retval < 0)
                state = 0;
            game_state.seen_intro = true;
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

    c.music_select_song(15);

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
        var curlevel = try menu.viewMenu(
            data.constants.*.menu,
            allocator,
        );

        if (curlevel == null)
            state = 0;

        if (state != 0 and (curlevel.? < data.constants.*.levelfiles.len)) {
            retval = engine.playtitus(
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
