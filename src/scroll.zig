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
const engine = @import("engine.zig");
const globals = @import("globals.zig");

// FIXME: maybe this is in standard library?
fn clamp(x: f32, lowerlimit: f32, upperlimit: f32) f32 {
    var temp = x;
    if (temp < lowerlimit)
        temp = lowerlimit;
    if (temp > upperlimit)
        temp = upperlimit;
    return temp;
}

fn smootherstep(edge0: f32, edge1: f32, x: f32) f32 {
    // Scale, and clamp x to 0..1 range
    var xx = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    // Evaluate polynomial
    return xx * xx * xx * (xx * (xx * 6 - 15) + 10);
}

var camera_offset: i16 = 0;

fn X_ADJUST(level: *engine.c.TITUS_level) void {
    var player = &(level.player);
    globals.g_scroll_x = true;

    var player_position = player.sprite.x;

    // determine the right side of the world
    var right_limit: i16 = undefined;
    if (player_position > globals.XLIMIT * 16 or globals.XLIMIT_BREACHED) {
        globals.XLIMIT_BREACHED = true;
        right_limit = @intCast(level.width * 16 - 160);
    } else {
        right_limit = @intCast(globals.XLIMIT * 16 - 160);
    }

    // update the camera offset from the player (using an easing function)
    var target_camera_offset: i16 = undefined;
    if (!level.player.sprite.flipped) {
        target_camera_offset = 60;
    } else {
        target_camera_offset = -60;
    }
    if (camera_offset < target_camera_offset) {
        camera_offset += 3;
    } else if (camera_offset > target_camera_offset) {
        camera_offset -= 3;
    }
    var real_camera_offset: i16 = @intFromFloat(@floor(smootherstep(-60.0, 60.0, @floatFromInt(camera_offset)) * 120.0 - 60.0));

    // clamp the camera inside the world space
    var camera_position: i16 = player_position + real_camera_offset;
    if (camera_position < 160) {
        camera_position = 160;
    }
    if (camera_position > right_limit) {
        camera_position = right_limit;
    }

    // un-breach XLIMIT if we go one screen to the left of it
    if (globals.XLIMIT_BREACHED and camera_position < globals.XLIMIT * 16 - 320) {
        globals.XLIMIT_BREACHED = false;
    }

    var camera_screen_px: i16 = camera_position - @as(i16, globals.BITMAP_X) * 16;
    var scroll_px_target: i16 = 160;
    var scroll_offset_x: i16 = scroll_px_target - camera_screen_px;
    var tile_offset_x: i16 = @divTrunc(scroll_offset_x, 16);
    var px_offset_x: i16 = @rem(scroll_offset_x, 16);
    if (tile_offset_x < 0) {
        globals.BITMAP_X += 1;
        globals.g_scroll_px_offset = px_offset_x;
        globals.g_scroll_x = true;
    } else if (tile_offset_x > 0) {
        globals.BITMAP_X -= 1;
        globals.g_scroll_px_offset = px_offset_x;
        globals.g_scroll_x = true;
    } else {
        globals.g_scroll_px_offset = scroll_offset_x;
        globals.g_scroll_x = false;
    }
}

fn Y_ADJUST(level: *engine.c.TITUS_level) void {
    var player = &(level.player);
    if (player.sprite.speedY == 0) {
        globals.g_scroll_y = false;
    }
    var pstileY: i16 = (player.sprite.y >> 4) - globals.BITMAP_Y; //Player screen tile Y (0 to 11)
    if (!globals.g_scroll_y) {
        if ((player.sprite.speedY == 0) and (globals.LADDER_FLAG == false)) {
            if (pstileY >= globals.screen_height - 1) {
                globals.g_scroll_y_target = globals.screen_height - 2;
                globals.g_scroll_y = true;
            } else if (pstileY <= 2) {
                globals.g_scroll_y_target = globals.screen_height - 3;
                globals.g_scroll_y = true;
            }
        } else {
            if (pstileY >= globals.screen_height - 2) { //The player is at the bottom of the screen, scroll down!
                globals.g_scroll_y_target = 3;
                globals.g_scroll_y = true;
            } else if (pstileY <= 2) { //The player is at the top of the screen, scroll up!
                globals.g_scroll_y_target = globals.screen_height - 3;
                globals.g_scroll_y = true;
            }
        }
    }

    if ((player.sprite.y <= ((@as(i16, globals.ALTITUDE_ZERO) + globals.screen_height) >> 4)) and //If the player is above the horizontal limit
        (globals.BITMAP_Y > globals.ALTITUDE_ZERO + 1))
    { //... and the screen have scrolled below the the horizontal limit
        if (U_SCROLL(level)) { //Scroll up
            globals.g_scroll_y = false;
        }
    } else if ((globals.BITMAP_Y > globals.ALTITUDE_ZERO - 5) and //If the screen is less than 5 tiles above the horizontal limit
        (globals.BITMAP_Y <= globals.ALTITUDE_ZERO) and //... and still above the horizontal limit
        (player.sprite.y + (7 * 16) > ((globals.ALTITUDE_ZERO + globals.screen_height) << 4)))
    {
        if (D_SCROLL(level)) { //Scroll down
            globals.g_scroll_y = false;
        }
    } else if (globals.g_scroll_y) {
        if (globals.g_scroll_y_target == pstileY) {
            globals.g_scroll_y = false;
        } else if (globals.g_scroll_y_target > pstileY) {
            if (U_SCROLL(level)) {
                globals.g_scroll_y = false;
            }
        } else if ((player.sprite.y <= ((globals.ALTITUDE_ZERO + globals.screen_height) << 4)) and //If the player is above the horizontal limit
            (globals.BITMAP_Y > globals.ALTITUDE_ZERO))
        { //... and the screen is below the horizontal limit
            globals.g_scroll_y = false; //Stop scrolling
        } else {
            if (D_SCROLL(level)) { //Scroll down
                globals.g_scroll_y = false;
            }
        }
    }
}

pub export fn scroll(level: *engine.c.TITUS_level) void {
    //Scroll screen and update tile animation
    globals.loop_cycle += 1; //Cycle from 0 to 3
    if (globals.loop_cycle > 3) {
        globals.loop_cycle = 0;
    }
    if (globals.loop_cycle == 0) { //Every 4th call
        globals.tile_anim += 1; //Cycle tile animation (0-1-2)
        if (globals.tile_anim > 2) {
            globals.tile_anim = 0;
        }
    }
    //Scroll
    if (!globals.NOSCROLL_FLAG) {
        X_ADJUST(level);
        Y_ADJUST(level);
    }
}

pub export fn L_SCROLL(level: *engine.c.TITUS_level) bool {
    _ = level;
    //Scroll left
    if (globals.BITMAP_X == 0) {
        return true; //Stop scrolling
    }
    globals.BITMAP_X -= 1; //Scroll 1 tile left
    return false; //Continue scrolling
}

pub export fn R_SCROLL(level: *engine.c.TITUS_level) bool {
    //Scroll right
    var maxX: i32 = undefined;
    if (((level.player.sprite.x >> 4) - globals.screen_width) > globals.XLIMIT) { //Scroll limit
        maxX = level.width - globals.screen_width; //256 - 20
    } else {
        maxX = globals.XLIMIT;
    }
    if (globals.BITMAP_X >= maxX) {
        return true; //Stop scrolling
    }
    globals.BITMAP_X += 1; //Increase pointer
    return false;
}

pub export fn U_SCROLL(level: *engine.c.TITUS_level) bool {
    _ = level;
    //Scroll up
    if (globals.BITMAP_Y == 0) {
        return true;
    }
    globals.BITMAP_Y -= 1; //Scroll 1 tile up
    return false;
}

pub export fn D_SCROLL(level: *engine.c.TITUS_level) bool {
    //Scroll down
    if (globals.BITMAP_Y >= (level.height - globals.screen_height)) { //The screen is already at the bottom
        return true; //Stop scrolling
    }
    globals.BITMAP_Y += 1; //Increase pointer
    return false;
}
