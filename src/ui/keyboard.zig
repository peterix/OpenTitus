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

const SDL = @import("../SDL.zig");

const globals = @import("../globals.zig");
const window = @import("../window.zig");

pub fn waitforbutton() c_int {
    var event: SDL.Event = undefined;
    var waiting: c_int = 1;
    while (waiting > 0) {
        if (SDL.pollEvent(&event)) {
            switch (event.type) {
                SDL.EVENT_QUIT => {
                    waiting = -1;
                },
                SDL.EVENT_KEY_DOWN => {
                    switch (event.key.scancode) {
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
                },
                SDL.EVENT_WINDOW_RESIZED,
                SDL.EVENT_WINDOW_PIXEL_SIZE_CHANGED,
                SDL.EVENT_WINDOW_MAXIMIZED,
                SDL.EVENT_WINDOW_RESTORED,
                SDL.EVENT_WINDOW_EXPOSED,
                => {
                    window.window_render();
                },
                else => {},
            }
        }
        SDL.delay(1);
    }
    return waiting;
}
