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
const assert = std.debug.assert;

const globals = @import("globals.zig");
const window = @import("window.zig");
const lvl = @import("level.zig");

/// Easign function for the camera.
///
/// Assumes input is between edge0 and edge1 inclusive and that edge0 < edge1
///
/// See: https://www.wolframalpha.com/input?i=x%5E3+%2810+%2B+x+%28-15+%2B+6+x%29%29
fn smootherstep(edge0: f32, edge1: f32, input: f32) f32 {
    assert(edge0 < edge1);
    assert(input >= edge0 and input <= edge1);
    // Scale, and clamp input to 0..1 range
    const x = std.math.clamp((input - edge0) / (edge1 - edge0), 0.0, 1.0);
    // Evaluate polynomial
    return x * x * x * (x * (x * 6 - 15) + 10);
}

// NOTE: a full camera turn takes 2 * EASING_RANGE frames
const EASING_RANGE = 9;
const CAMERA_DISTANCE = 60;
const CAMERA_RANGE = CAMERA_DISTANCE * 2;

// TODO: put this on the player struct
var easing_value: i16 = 0;

fn X_ADJUST(level: *lvl.TITUS_level) void {
    const player = &(level.player);
    globals.g_scroll_x = true;

    const player_position = player.sprite.x;

    // determine the right side of the world
    var right_limit: i16 = undefined;
    if (player_position > globals.XLIMIT * 16 or globals.XLIMIT_BREACHED) {
        globals.XLIMIT_BREACHED = true;
        right_limit = @intCast(level.width * 16 - 160);
    } else {
        right_limit = @intCast(globals.XLIMIT * 16 - 160);
    }

    // update the camera offset from the player (using an easing function)
    const facing_right = !level.player.sprite.flipped;
    const easing_target: i16 = if (facing_right) EASING_RANGE else -EASING_RANGE;
    if (easing_value < easing_target) {
        easing_value += 1;
    } else if (easing_value > easing_target) {
        easing_value -= 1;
    }
    const real_camera_offset: i16 = @intFromFloat(@floor(smootherstep(-EASING_RANGE, EASING_RANGE, @floatFromInt(easing_value)) * CAMERA_RANGE - CAMERA_DISTANCE));

    // clamp the camera inside the world space
    var camera_position: i16 = player_position + real_camera_offset;
    if (camera_position < 160) {
        camera_position = 160;
    }
    if (camera_position > right_limit) {
        camera_position = right_limit;
    }

    // un-breach XLIMIT if we go one screen to the left of it
    if (globals.XLIMIT_BREACHED and camera_position < globals.XLIMIT * 16 - window.game_width) {
        globals.XLIMIT_BREACHED = false;
    }

    const camera_screen_px: i16 = camera_position - @as(i16, globals.BITMAP_X) * 16;
    const scroll_px_target: i16 = 160;
    const scroll_offset_x: i16 = scroll_px_target - camera_screen_px;
    const tile_offset_x: i16 = @divTrunc(scroll_offset_x, 16);
    const px_offset_x: i16 = @rem(scroll_offset_x, 16);
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

fn Y_ADJUST(level: *lvl.TITUS_level) void {
    const player = &(level.player);
    if (player.sprite.speed_y == 0) {
        globals.g_scroll_y = false;
    }
    const pstileY: i16 = (player.sprite.y >> 4) - globals.BITMAP_Y; //Player screen tile Y (0 to 11)
    if (!globals.g_scroll_y) {
        if ((player.sprite.speed_y == 0) and (globals.LADDER_FLAG == false)) {
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

    // TODO: do something about this weirdness of discrete tile scrolling.
    if ((player.sprite.y <= ((@as(i16, globals.ALTITUDE_ZERO) + globals.screen_height) >> 4)) and //If the player is above the horizontal limit
        (globals.BITMAP_Y > globals.ALTITUDE_ZERO + 1)) //... and the screen have scrolled below the the horizontal limit
    {
        if (scroll_up(level)) {
            globals.g_scroll_y = false;
        }
    } else if ((globals.BITMAP_Y > globals.ALTITUDE_ZERO - 5) and // If the screen is less than 5 tiles above the horizontal limit
        (globals.BITMAP_Y <= globals.ALTITUDE_ZERO) and // ... and still above the horizontal limit
        (player.sprite.y + (7 * 16) > ((globals.ALTITUDE_ZERO + globals.screen_height) << 4)))
    {
        if (scroll_down(level)) {
            globals.g_scroll_y = false;
        }
    } else if (globals.g_scroll_y) {
        if (globals.g_scroll_y_target == pstileY) {
            globals.g_scroll_y = false;
        } else if (globals.g_scroll_y_target > pstileY) {
            if (scroll_up(level)) {
                globals.g_scroll_y = false;
            }
        } else if ((player.sprite.y <= ((globals.ALTITUDE_ZERO + globals.screen_height) << 4)) and //If the player is above the horizontal limit
            (globals.BITMAP_Y > globals.ALTITUDE_ZERO)) //... and the screen is below the horizontal limit
        {
            globals.g_scroll_y = false; //Stop scrolling
        } else {
            if (scroll_down(level)) {
                globals.g_scroll_y = false;
            }
        }
    }
}

// TODO: put this somewhere else, like `engine`, it has nothing to do with scrolling
pub fn animate_tiles() void {
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
}

pub fn scrollToPlayer(level: *lvl.TITUS_level) void {
    globals.BITMAP_X = 0;
    globals.BITMAP_Y = 0;

    globals.g_scroll_y = true;
    globals.g_scroll_x = true;
    while (globals.g_scroll_y or globals.g_scroll_x) {
        scroll(level);
    }
}

pub fn scroll(level: *lvl.TITUS_level) void {
    animate_tiles();
    //Scroll
    if (!globals.NOSCROLL_FLAG) {
        X_ADJUST(level);
        Y_ADJUST(level);
    }
}

pub fn scroll_left(level: *lvl.TITUS_level) bool {
    _ = level;
    if (globals.BITMAP_X == 0) {
        return true;
    }
    globals.BITMAP_X -= 1;
    return false;
}

pub fn scroll_right(level: *lvl.TITUS_level) bool {
    const maxX: i16 = if (globals.XLIMIT_BREACHED) @as(i16, @intCast(level.width)) - globals.screen_width else globals.XLIMIT;
    if (globals.BITMAP_X >= maxX) {
        return true;
    }
    globals.BITMAP_X += 1;
    return false;
}

pub fn scroll_up(level: *lvl.TITUS_level) bool {
    _ = level;
    if (globals.BITMAP_Y == 0) {
        return true;
    }
    globals.BITMAP_Y -= 1;
    return false;
}

pub fn scroll_down(level: *lvl.TITUS_level) bool {
    if (globals.BITMAP_Y >= (level.height - globals.screen_height)) {
        return true;
    }
    globals.BITMAP_Y += 1;
    return false;
}
