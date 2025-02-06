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
    var event: SDL.Event = undefined;
    var waiting: c_int = 1;
    while (waiting > 0) {
        if (SDL.pollEvent(&event)) {
            if (event.type == SDL.QUIT)
                waiting = -1;

            if (event.type == SDL.KEYDOWN) {
                switch (event.key.keysym.scancode) {
                    SDL.SCANCODE_RETURN,
                    SDL.SCANCODE_KP_ENTER,
                    SDL.SCANCODE_SPACE,
                    SDL.SCANCODE_ESCAPE,
                    => {
                        waiting = 0;
                    },
                    SDL.SCANCODE_F11 => {
                        window.toggle_fullscreen();
                    },
                    else => {
                        // NOOP
                    },
                }
            }
            if (event.type == SDL.WINDOWEVENT) {
                switch (event.window.event) {
                    SDL.WINDOWEVENT_RESIZED,
                    SDL.WINDOWEVENT_SIZE_CHANGED,
                    SDL.WINDOWEVENT_MAXIMIZED,
                    SDL.WINDOWEVENT_RESTORED,
                    SDL.WINDOWEVENT_EXPOSED,
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
