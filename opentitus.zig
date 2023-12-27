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

// TODO: split, port one by one
const c = @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("viewimage.h");
    @cInclude("audio.h");
    @cInclude("tituserror.h");
    @cInclude("settings.h");
    @cInclude("sprites.h");
    @cInclude("window.h");
    @cInclude("fonts.h");
    @cInclude("menu.h");
    @cInclude("original.h");
    @cInclude("objects.h");
    @cInclude("window.h");
});

const globals = @import("src/globals.zig");
const engine = @import("src/engine.zig");
const window = @import("src/window.zig");
const levelcodes = @import("src/levelcodes.zig");

const span = std.mem.span;

// FIXME: report errors in a reasonable way, handle them in a reasonable way
// FIXME: stop using c_int, actually return errors instead
fn init() c_int {
    var retval: c_int = 0;

    globals.reset();

    retval = c.readconfig("game.conf");
    if (retval < 0)
        return retval;

    if (c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_TIMER | c.SDL_INIT_AUDIO) != 0) {
        std.debug.print("Unable to initialize SDL: {s}\n", .{span(c.SDL_GetError())});
        return c.TITUS_ERROR_SDL_ERROR;
    }

    window.window_init() catch {
        return c.TITUS_ERROR_SDL_ERROR;
    };

    retval = c.audio_init();
    if (retval != 0) {
        return retval;
    }

    retval = c.initoriginal();
    if (retval != 0) {
        return retval;
    }

    levelcodes.initCodes();

    retval = c.loadfonts();
    if (retval != 0) {
        return retval;
    }

    return 0;
}

pub fn main() u8 {
    // View the menu when the main loop starts
    var state: c_int = 1;
    var retval = init();
    if (retval < 0)
        state = 0;

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

    // FIXME: use defer()
    c.freefonts();

    c.audio_free();

    c.SDL_Quit();

    checkerror();

    if (retval == -1)
        retval = 0;

    return @as(u8, @intCast(retval));
}

fn checkerror() void {
    // FIXME: this is straight out of hell, shows how bad error reporting here is...
    std.debug.print("{s}\n", .{span(@as([*c]u8, @ptrCast(&c.lasterror)))});
}
