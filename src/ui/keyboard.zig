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

const c = @import("../c.zig");
const SDL = @import("../SDL.zig");

const globals = @import("../globals.zig");
const window = @import("../window.zig");

pub fn waitforbutton() c_int {
    var event: c.SDL_Event = undefined;
    var waiting: c_int = 1;
    while (waiting > 0) {
        if (c.SDL_PollEvent(&event) != 0) {
            if (event.type == c.SDL_QUIT)
                waiting = -1;

            if (event.type == c.SDL_KEYDOWN) {
                switch (event.key.keysym.scancode) {
                    c.SDL_SCANCODE_RETURN,
                    c.SDL_SCANCODE_KP_ENTER,
                    c.SDL_SCANCODE_SPACE,
                    c.SDL_SCANCODE_ESCAPE,
                    => {
                        waiting = 0;
                    },
                    c.SDL_SCANCODE_F11 => {
                        window.toggle_fullscreen();
                    },
                    else => {
                        // NOOP
                    },
                }
            }
            if (event.type == c.SDL_WINDOWEVENT) {
                switch (event.window.event) {
                    c.SDL_WINDOWEVENT_RESIZED,
                    c.SDL_WINDOWEVENT_SIZE_CHANGED,
                    c.SDL_WINDOWEVENT_MAXIMIZED,
                    c.SDL_WINDOWEVENT_RESTORED,
                    c.SDL_WINDOWEVENT_EXPOSED,
                    => {
                        window.window_render();
                    },
                    else => {},
                }
            }
        }
        SDL.delay(1);
    }
    return waiting;
}
