//
// Copyright (C) 2008 - 2011 The OpenTitus team
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
const globals = @import("globals.zig");
const engine = @import("engine.zig");
const window = @import("window.zig");
const keyboard = @import("keyboard.zig");
const fonts = @import("fonts.zig");

const memory = @import("memory.zig");
const Managed = memory.Managed;

const TitusError = error{
    CannotDetermineGameType,
    CannotReadConfig,
    CannotInitSDL,
    CannotInitAudio,
    CannotInitFonts,
};

pub export var game: c.GameType = undefined;

const s = @import("settings.zig");
const Settings = s.Settings;
pub var settings_mem: Managed(Settings) = undefined;
pub export var settings: *Settings = undefined;

const GameState = s.GameState;
pub var game_state_mem: Managed(GameState) = undefined;
pub var game_state: *GameState = undefined;

pub const TITUS_constants = struct {
    levelfiles: [16][:0]const u8,
    levelcount: u16,
    tituslogofile: [:0]const u8,
    tituslogoformat: c_int,
    titusintrofile: [:0]const u8,
    titusintroformat: c_int,
    titusmenufile: [:0]const u8,
    titusmenuformat: c_int,
    titusfinishfile: [:0]const u8,
    titusfinishformat: c_int,
    spritefile: [:0]const u8,
};

const titus_consts: TITUS_constants = .{
    .levelfiles = .{ "LEVEL0.SQZ", "LEVELJ.SQZ", "LEVEL1.SQZ", "LEVEL2.SQZ", "LEVEL3.SQZ", "LEVEL4.SQZ", "LEVEL5.SQZ", "LEVEL6.SQZ", "LEVEL7.SQZ", "LEVEL8.SQZ", "LEVEL9.SQZ", "LEVELB.SQZ", "LEVELC.SQZ", "LEVELE.SQZ", "LEVELG.SQZ", "" },
    .levelcount = 15,
    .tituslogofile = "TITUS.SQZ",
    .tituslogoformat = 2,
    .titusintrofile = "TITRE.SQZ",
    .titusintroformat = 2,
    .titusmenufile = "MENU.SQZ",
    .titusmenuformat = 2,
    .titusfinishfile = "LEVELA.SQZ",
    .titusfinishformat = 0,
    .spritefile = "SPREXP.SQZ",
};

const moktar_consts: TITUS_constants = .{
    .levelfiles = .{ "LEVEL0.SQZ", "LEVELJ.SQZ", "LEVEL1.SQZ", "LEVEL2.SQZ", "LEVEL3.SQZ", "LEVEL4.SQZ", "LEVEL5.SQZ", "LEVEL6.SQZ", "LEVEL7.SQZ", "LEVEL8.SQZ", "LEVEL9.SQZ", "LEVELB.SQZ", "LEVELC.SQZ", "LEVELE.SQZ", "LEVELF.SQZ", "LEVELG.SQZ" },
    .levelcount = 16,
    .tituslogofile = "TITUS.SQZ",
    .tituslogoformat = 2,
    .titusintrofile = "TITRE.SQZ",
    .titusintroformat = 2,
    .titusmenufile = "MENU.SQZ",
    .titusmenuformat = 2,
    .titusfinishfile = "",
    .titusfinishformat = 0,
    .spritefile = "SPRITES.SQZ",
};

fn isFileOpenable(path: []const u8) bool {
    if (std.fs.cwd().openFile(path, .{})) |file| {
        file.close();
        return true;
    } else |_| {
        // NOTE: we assume that any issue opening the file means it's not present
        // TODO: catch all the other errors that aren't 'FileNotFound' and report them?
        return false;
    }
}

fn initGameType() !*const TITUS_constants {
    if (isFileOpenable(titus_consts.spritefile)) {
        game = c.Titus;
        return &titus_consts;
    } else if (isFileOpenable(moktar_consts.spritefile)) {
        game = c.Moktar;
        return &moktar_consts;
    } else {
        return TitusError.CannotDetermineGameType;
    }
}

// TODO: this is a nice throwback in the original game, but maybe we could do something better.
// Like replace the (missing) manual with an intro sequence to give the player some context.
fn viewintrotext() c_int {
    var tmpstring: [41]u8 = .{};
    var rawtime = c.time(null);
    var timeinfo = c.localtime(&rawtime);

    _ = std.fmt.bufPrint(&tmpstring, "     You are still playing Moktar in {d} !!", .{timeinfo.*.tm_year + 1900}) catch {};

    fonts.text_render("     YEAAA . . .", 0, 4 * 12, false);
    fonts.text_render(&tmpstring[0], 0, 6 * 12, false);
    fonts.text_render("     Programmed in 1991 on AT .286 12MHz.", 0, 11 * 12, false);
    fonts.text_render("              . . . Enjoy Moktar Adventure !!", 0, 13 * 12, false);

    window.window_render();

    var retval = keyboard.waitforbutton();
    if (retval < 0)
        return retval;

    game_state.seen_intro = true;

    if (retval < 0)
        return retval;

    return (0);
}

pub fn run() !u8 {
    // FIXME: report the missing files to the user in a better way than erroring into a terminal? dialog box if available?
    const constants = try initGameType();

    globals.reset();

    const c_alloc = std.heap.c_allocator;

    settings_mem = try Settings.read(c_alloc);
    settings = &settings_mem.value;
    defer settings_mem.deinit();

    game_state_mem = try GameState.read(c_alloc);
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

    if (c.fonts_load() != 0) {
        return TitusError.CannotInitFonts;
    }
    defer c.fonts_free();

    // View the menu when the main loop starts
    var state: c_int = 1;
    var retval: c_int = 0;

    if (!game_state.seen_intro) {
        if (state != 0) {
            retval = viewintrotext();
            if (retval < 0)
                state = 0;
        }
    }

    if (state != 0) {
        retval = c.viewimage(constants.*.tituslogofile, constants.*.tituslogoformat, 0, 4000);
        if (retval < 0)
            state = 0;
    }

    c.music_select_song(15);

    if (state != 0) {
        retval = c.viewimage(constants.*.titusintrofile, constants.*.titusintroformat, 0, 6500);
        if (retval < 0)
            state = 0;
    }

    while (state != 0) {
        retval = c.viewmenu(constants.*.titusmenufile, constants.*.titusmenuformat, constants.*.levelcount);

        if (retval <= 0)
            state = 0;

        if (state != 0 and (retval <= constants.*.levelcount)) {
            retval = engine.playtitus(constants, @as(u16, @intCast(retval - 1)));
            if (retval < 0)
                state = 0;
        }
    }

    try settings.write(c_alloc);
    try game_state.write(c_alloc);

    // TODO: completely stop using this. it's not consistent across the codebase...
    var error_span = std.mem.span(@as([*c]u8, @ptrCast(&c.lasterror)));
    if (error_span.len > 0) {
        std.debug.print("{s}\n", .{error_span});
        return 1;
    }
    return 0;
}
