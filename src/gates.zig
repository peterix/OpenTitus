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
const globals = @import("globals.zig");
const window = @import("window.zig");
const scroll = @import("scroll.zig");
const draw = @import("draw.zig");

fn check_finish(context: *c.ScreenContext, level: *c.TITUS_level) void {
    var player = &level.player;
    if (globals.boss_alive) { //There is still a boss that needs to be killed!
        return;
    }
    if (level.levelid == 9) { //The level with a cage
        if ((level.player.sprite2.number != c.FIRST_OBJET + 26) and
            (level.player.sprite2.number != c.FIRST_OBJET + 27))
        {
            return;
        }
    }
    if (((player.sprite.x & 0x7FF0) != level.finishX) and
        ((player.sprite.x & 0x7FF0) - 16 != level.finishX))
    {
        return;
    }
    if (((player.sprite.y & 0x7FF0) != level.finishY) and
        ((player.sprite.y & 0x7FF0) - 16 != level.finishY))
    {
        return;
    }
    c.music_select_song(4);
    c.music_wait_to_finish();
    CLOSE_SCREEN(context);
    globals.NEWLEVEL_FLAG = true;
}

fn check_gates(context: *c.ScreenContext, level: *c.TITUS_level) void {
    var player = &level.player;
    if ((globals.CROSS_FLAG == 0) or //not kneestanding
        (globals.NEWLEVEL_FLAG))
    { //the player has finished the level
        return;
    }
    for (0..c.GATE_CAPACITY) |i| {
        if ((level.gate[i].exists) and
            (level.gate[i].entranceX == (player.sprite.x >> 4)) and
            (level.gate[i].entranceY == (player.sprite.y >> 4)))
        {
            player.sprite.speed_x = 0;
            player.sprite.speed_y = 0;
            CLOSE_SCREEN(context);
            defer OPEN_SCREEN(context, level);
            const orig_xlimit = globals.XLIMIT;
            defer globals.XLIMIT = orig_xlimit;
            const orig_xlimit_breached = globals.XLIMIT_BREACHED;
            defer globals.XLIMIT_BREACHED = orig_xlimit_breached;

            globals.XLIMIT = @as(i16, @intCast(level.width)) - globals.screen_width;
            player.sprite.x = @intCast(level.gate[i].exitX * 16);
            player.sprite.y = @intCast(level.gate[i].exitY * 16);
            while (globals.BITMAP_Y < level.gate[i].screenY) {
                _ = scroll.scroll_down(level);
            }
            while (globals.BITMAP_Y > level.gate[i].screenY) {
                _ = scroll.scroll_up(level);
            }
            while (globals.BITMAP_X < level.gate[i].screenX) {
                _ = scroll.scroll_right(level);
            }
            while (globals.BITMAP_X > level.gate[i].screenX) {
                _ = scroll.scroll_left(level);
            }
            globals.NOSCROLL_FLAG = level.gate[i].noscroll;
        }
    }
}

//Check and handle level completion, and if the player does a kneestand on a secret entrance
pub export fn CROSSING_GATE(context: *c.ScreenContext, level: *c.TITUS_level) void {
    check_finish(context, level);
    check_gates(context, level);
}

const step_count: usize = 10;
const rwidth: usize = 320;
const rheight: usize = 200;
const incX: usize = rwidth / (step_count * 2);
const incY: usize = rheight / (step_count * 2);

pub export fn CLOSE_SCREEN(context: *c.ScreenContext) void {
    var dest: c.SDL_Rect = undefined;
    for (0..step_count) |i| {
        //Clear top
        dest.x = 0;
        dest.y = 0;
        dest.w = globals.screen_width * 16;
        dest.h = @intCast(i * incY);
        window.window_clear(&dest);

        //Clear left
        dest.x = 0;
        dest.y = 0;
        dest.w = @intCast(i * incX);
        dest.h = globals.screen_height * 16;
        window.window_clear(&dest);

        //Clear bottom
        dest.x = 0;
        dest.y = @intCast(rheight - (i * incY));
        dest.w = globals.screen_width * 16;
        dest.h = @intCast(i * incY);
        window.window_clear(&dest);

        //Clear right
        dest.x = @intCast(rwidth - (i * incX));
        dest.y = 0;
        dest.w = @intCast(i * incX);
        dest.h = globals.screen_height * 16;
        window.window_clear(&dest);

        draw.flip_screen(context, true);
    }
}

pub export fn OPEN_SCREEN(context: *c.ScreenContext, level: *c.TITUS_level) void {
    var dest: c.SDL_Rect = undefined;
    var i: u32 = step_count - 1;
    while (i >= 2) : (i -= 2) {
        // draw all tiles
        draw.draw_tiles(level);

        //Clear top
        dest.x = 0;
        dest.y = 0;
        dest.w = globals.screen_width * 16;
        dest.h = @intCast(i * incY);
        window.window_clear(&dest);

        //Clear left
        dest.x = 0;
        dest.y = 0;
        dest.w = @intCast(i * incX);
        dest.h = globals.screen_height * 16;
        window.window_clear(&dest);

        //Clear bottom
        dest.x = 0;
        dest.y = @intCast(rheight - (i * incY));
        dest.w = globals.screen_width * 16;
        dest.h = @intCast(i * incY);
        window.window_clear(&dest);

        //Clear right
        dest.x = @intCast(rwidth - (i * incX));
        dest.y = 0;
        dest.w = @intCast(i * incX);
        dest.h = globals.screen_height * 16;
        window.window_clear(&dest);

        draw.flip_screen(context, true);
    }
}
