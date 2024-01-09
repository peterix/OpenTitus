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
const sqz = @import("../sqz.zig");
const image = @import("image.zig");
const window = @import("../window.zig");
const ImageFile = image.ImageFile;

// TODO: redo all UI
// - Add settings menu
// - Remove level code input and replace it with level select
// - Levels are unlocked by collecting the locks and the unlock state is persisted on disk instead of codes
// - Add pause menu
// - Esc opens pause menu instead of instant quit

pub fn viewMenu(file: ImageFile, allocator: std.mem.Allocator) !c_int {
    var selection: usize = 0;
    var curlevel: c_int = 1;

    var fade_time: c_uint = 1000;
    var tick_start: c_uint = 0;
    var image_alpha: c_uint = 0;

    var menudata = try sqz.unSQZ(file.filename, allocator);
    var image_memory = try image.loadImage(menudata, file.format, allocator);
    defer image_memory.deinit();
    var menu = image_memory.value;

    var src = c.SDL_Rect{
        .x = 0,
        .y = 0,
        .w = menu.*.w,
        .h = menu.*.h,
    };

    var dest = c.SDL_Rect{
        .x = 0,
        .y = 0,
        .w = menu.*.w,
        .h = menu.*.h,
    };

    var sel: [2]c.SDL_Rect = undefined;
    var sel_dest: [2]c.SDL_Rect = undefined;

    if (c.game == c.Titus) {
        sel[0].x = 120;
        sel[0].y = 160;
        sel[0].w = 8;
        sel[0].h = 8;

        sel[1].x = 120;
        sel[1].y = 173;
        sel[1].w = 8;
        sel[1].h = 8;
    } else if (c.game == c.Moktar) {
        sel[0].x = 130;
        sel[0].y = 167;
        sel[0].w = 8;
        sel[0].h = 8;

        sel[1].x = 130;
        sel[1].y = 180;
        sel[1].w = 8;
        sel[1].h = 8;
    }
    sel_dest[0] = sel[0];
    //sel_dest[0].x += 16;
    sel_dest[1] = sel[1];
    //sel_dest[1].x += 16;

    tick_start = c.SDL_GetTicks();

    while (image_alpha < 255) { //Fade in
        var event: c.SDL_Event = undefined;
        if (c.SDL_PollEvent(&event) != c.SDL_FALSE) {
            if (event.type == c.SDL_QUIT) {
                return (-1);
            }

            if (event.type == c.SDL_KEYDOWN) {
                if (event.key.keysym.scancode == c.SDL_SCANCODE_ESCAPE) {
                    return (-1);
                }
                if (event.key.keysym.scancode == c.KEY_FULLSCREEN) {
                    window.window_toggle_fullscreen();
                }
            }
        }

        image_alpha = (c.SDL_GetTicks() - tick_start) * 256 / fade_time;

        if (image_alpha > 255)
            image_alpha = 255;

        window.window_clear(null);
        // FIXME: handle errors?
        _ = c.SDL_SetSurfaceBlendMode(menu, c.SDL_BLENDMODE_BLEND);
        _ = c.SDL_SetSurfaceAlphaMod(menu, @truncate(image_alpha));
        _ = c.SDL_BlitSurface(menu, &src, window.screen, &dest);
        _ = c.SDL_BlitSurface(menu, &sel[1], window.screen, &sel_dest[0]);
        _ = c.SDL_BlitSurface(menu, &sel[0], window.screen, &sel_dest[selection]);
        window.window_render();
        c.SDL_Delay(1);
    }

    // View the menu
    MENULOOP: while (true) {
        var event: c.SDL_Event = undefined;
        if (c.SDL_PollEvent(&event) != c.SDL_FALSE) {
            if (event.type == c.SDL_QUIT) {
                return (-1);
            }

            if (event.type == c.SDL_KEYDOWN) {
                if (event.key.keysym.scancode == c.SDL_SCANCODE_ESCAPE) {
                    return (-1);
                }
                if (event.key.keysym.scancode == c.SDL_SCANCODE_UP)
                    selection = 0;
                if (event.key.keysym.scancode == c.SDL_SCANCODE_DOWN)
                    selection = 1;
                if (event.key.keysym.scancode == c.KEY_RETURN or event.key.keysym.scancode == c.KEY_ENTER or event.key.keysym.scancode == c.KEY_SPACE) {
                    switch (selection) {
                        0 => break :MENULOOP,
                        1 => {
                            // TODO: implement level select sub-menu
                            // retval = enterpassword(levelcount);

                            // if (retval < 0)
                            //     return retval;

                            // if (retval > 0) {
                            //     curlevel = retval;
                            // }
                            selection = 0;
                        },
                        else => {
                            unreachable;
                        },
                    }
                }

                if (event.key.keysym.scancode == c.KEY_FULLSCREEN) {
                    window.window_toggle_fullscreen();
                }
            }
        }

        window.window_clear(null);
        _ = c.SDL_BlitSurface(menu, &src, window.screen, &dest);
        _ = c.SDL_BlitSurface(menu, &sel[1], window.screen, &sel_dest[0]);
        _ = c.SDL_BlitSurface(menu, &sel[0], window.screen, &sel_dest[selection]);
        window.window_render();
        c.SDL_Delay(1);
    }

    // Close the menu
    tick_start = c.SDL_GetTicks();
    image_alpha = 0;
    while (image_alpha < 255) { //Fade out
        var event: c.SDL_Event = undefined;
        if (c.SDL_PollEvent(&event) != c.SDL_FALSE) {
            if (event.type == c.SDL_QUIT) {
                return (-1);
            }

            if (event.type == c.SDL_KEYDOWN) {
                if (event.key.keysym.scancode == c.SDL_SCANCODE_ESCAPE) {
                    return (-1);
                }
                if (event.key.keysym.scancode == c.KEY_FULLSCREEN) {
                    window.window_toggle_fullscreen();
                }
                // TODO: add a way to activate devmode from here (cheat code style using state machine)
            }
        }

        image_alpha = (c.SDL_GetTicks() - tick_start) * 256 / fade_time;

        if (image_alpha > 255)
            image_alpha = 255;

        window.window_clear(null);
        _ = c.SDL_SetSurfaceBlendMode(menu, c.SDL_BLENDMODE_BLEND);
        _ = c.SDL_SetSurfaceAlphaMod(menu, 255 - @as(u8, @truncate(image_alpha)));
        _ = c.SDL_BlitSurface(menu, &src, window.screen, &dest);
        _ = c.SDL_FillRect(window.screen, &sel_dest[0], 0); //SDL_MapRGB(surface->format, 0, 0, 0));
        _ = c.SDL_BlitSurface(menu, &sel[0], window.screen, &sel_dest[selection]);
        window.window_render();
        c.SDL_Delay(1);
    }

    return (curlevel);
}
