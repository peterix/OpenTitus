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
const levelcodes = @import("levelcodes.zig");

const TitusError = error{
    CannotReadConfig,
    CannotInitSDL,
    CannotInitAudio,
    CannotInitFonts,
};

pub fn main() !u8 {
    globals.reset();

    if (c.readconfig("game.conf") < 0)
        return TitusError.CannotReadConfig;

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
    levelcodes.initCodes();

    if (c.loadfonts() != 0) {
        return TitusError.CannotInitFonts;
    }
    defer c.freefonts();

    // View the menu when the main loop starts
    var state: c_int = 1;
    var retval: c_int = 0;

    // TODO: add a way to skip all the intro stuff and go straight to the menu
    if (state != 0) {
        retval = c.viewintrotext();
        if (retval < 0)
            state = 0;
    }

    if (state != 0) {
        retval = c.viewimage(&c.tituslogofile, c.tituslogoformat, 0, 4000);
        if (retval < 0)
            state = 0;
    }

    c.music_select_song(15);

    if (state != 0) {
        retval = c.viewimage(&c.titusintrofile, c.titusintroformat, 0, 6500);
        if (retval < 0)
            state = 0;
    }

    while (state != 0) {
        retval = c.viewmenu(&c.titusmenufile, c.titusmenuformat);

        if (retval <= 0)
            state = 0;

        if (state != 0 and (retval <= c.levelcount)) {
            retval = engine.playtitus(@as(u16, @intCast(retval - 1)));
            if (retval < 0)
                state = 0;
        }
    }

    // TODO: completely stop usign this. it's not consistent across the codebase...
    var error_span = std.mem.span(@as([*c]u8, @ptrCast(&c.lasterror)));
    if (error_span.len > 0) {
        std.debug.print("{s}\n", .{error_span});
        return 1;
    }
    return 0;
}
