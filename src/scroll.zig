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

fn X_ADJUST(level: *lvl.Level) void {
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

// Vertical camera.
//
// Unlike the horizontal camera, this one is deliberately asymmetric: the levels hide things below the player
// (like the sewers in level 3), so the view never moves down just to frame the player nicely.
// Like in the original, it only shows the tile the player stands on, and looks further down only during a real fall.
// Moving up is fine, and it eases up when the player stands or climbs high on the screen.

/// Top of the view in world pixels
var camera_top: i16 = 0;

/// Height of the player's feet the last time they stood on something or held on to a ladder
var last_settled_feet: i16 = 0;

/// If the player's feet go below this line on the screen, the view follows them down.
/// This shows the tile they stand on and nothing more, same as the original.
const BOTTOM_LINE = window.game_height - 16;
/// When the player falls further than this below where they last stood, the view starts looking ahead down
const FALL_LOOKAHEAD_START = 32;
/// The most the view looks ahead while falling
const FALL_LOOKAHEAD_MAX = 80;
/// If the player's feet go above this line on the screen, the view follows them up
const TOP_LINE = 64;
/// When standing or climbing above this line, the view eases up to put the feet here
const REST_LINE = 136;
/// Easing speed: the view moves by 1/EASING_DIVISOR of the remaining distance each frame
const EASING_DIVISOR = 6;

fn easeTowards(current: i16, target: i16) i16 {
    const distance = target - current;
    if (distance == 0) {
        return current;
    }
    var step = @divTrunc(distance, EASING_DIVISOR);
    if (step == 0) {
        step = if (distance > 0) 1 else -1;
    }
    return current + step;
}

/// Lowest allowed top of the view for the whole level
fn levelBottomLimit(level: *lvl.Level) i16 {
    return @max(0, @as(i16, @intCast(level.height)) * 16 - window.game_height);
}

/// Lowest allowed top of the view while the player is above the ALTITUDE_ZERO line
fn altitudeLimit(level: *lvl.Level) ?i16 {
    const line: i16 = (@as(i16, globals.ALTITUDE_ZERO) + globals.screen_height) * 16;
    if (level.player.sprite.y > line) {
        return null;
    }
    // The original stops one tile row past the line
    return @max(0, line + 16 - window.game_height);
}

fn applyCamera() void {
    // BITMAP_Y is the first tile row that starts on the screen, the row above it is partially visible
    globals.BITMAP_Y = @intCast(@divFloor(camera_top + 15, 16));
    globals.g_scroll_py_offset = globals.BITMAP_Y * 16 - camera_top;
}

fn Y_ADJUST(level: *lvl.Level) void {
    const player = &level.player;
    const feet = player.sprite.y;
    var top = camera_top;

    const in_air = globals.YFALL != 0 or globals.jump_acceleration_counter != 0;
    const settled = !in_air or globals.LADDER_FLAG;
    if (settled) {
        last_settled_feet = feet;
    }

    // Show what's above when the player stands or climbs high on the screen
    if (settled and feet - top < REST_LINE) {
        top = easeTowards(top, feet - REST_LINE);
    }

    // Look ahead while falling, but not during ordinary jumps
    const fall_depth = feet - last_settled_feet;
    const lookahead = std.math.clamp(fall_depth - FALL_LOOKAHEAD_START, 0, FALL_LOOKAHEAD_MAX);
    const bottom_line = BOTTOM_LINE - lookahead;

    // Don't show anything below ALTITUDE_ZERO while the player is above it
    const altitude_limit = altitudeLimit(level);
    if (altitude_limit) |limit| {
        if (top > limit) {
            top = easeTowards(top, limit);
        }
    }

    // Keep the player on the screen
    if (feet - top > bottom_line) {
        top = feet - bottom_line;
        if (altitude_limit) |limit| {
            // The feet are above the ALTITUDE_ZERO line, so the player stays visible anyway
            top = @min(top, @max(limit, camera_top));
        }
    }
    if (feet - top < TOP_LINE) {
        top = feet - TOP_LINE;
    }

    camera_top = std.math.clamp(top, 0, levelBottomLimit(level));
    globals.g_scroll_y = camera_top != top;
    applyCamera();
}

/// Put the camera where it would settle around the player, without easing
fn snapCameraY(level: *lvl.Level) void {
    last_settled_feet = level.player.sprite.y;
    var top = level.player.sprite.y - BOTTOM_LINE;
    if (altitudeLimit(level)) |limit| {
        top = @min(top, limit);
    }
    camera_top = std.math.clamp(top, 0, levelBottomLimit(level));
    applyCamera();
}

/// Call after moving BITMAP_Y by whole tiles (like the gates do), so the camera continues from there.
/// Matches how those fixed screens always looked: half a tile of the row above is visible.
pub fn syncCameraY() void {
    camera_top = if (globals.BITMAP_Y > 0) globals.BITMAP_Y * 16 - 8 else 0;
    applyCamera();
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

pub fn scrollToPlayer(level: *lvl.Level) void {
    globals.BITMAP_X = 0;
    snapCameraY(level);

    globals.g_scroll_x = true;
    while (globals.g_scroll_x) {
        animate_tiles();
        X_ADJUST(level);
    }
}

pub fn scroll(level: *lvl.Level) void {
    animate_tiles();
    //Scroll
    if (!globals.NOSCROLL_FLAG) {
        X_ADJUST(level);
        Y_ADJUST(level);
    }
}

pub fn scroll_left(level: *lvl.Level) bool {
    _ = level;
    if (globals.BITMAP_X == 0) {
        return true;
    }
    globals.BITMAP_X -= 1;
    return false;
}

pub fn scroll_right(level: *lvl.Level) bool {
    const maxX: i16 = if (globals.XLIMIT_BREACHED) @as(i16, @intCast(level.width)) - globals.screen_width else globals.XLIMIT;
    if (globals.BITMAP_X >= maxX) {
        return true;
    }
    globals.BITMAP_X += 1;
    return false;
}

pub fn scroll_up(level: *lvl.Level) bool {
    _ = level;
    if (globals.BITMAP_Y == 0) {
        return true;
    }
    globals.BITMAP_Y -= 1;
    return false;
}

pub fn scroll_down(level: *lvl.Level) bool {
    if (globals.BITMAP_Y >= (level.height - globals.screen_height)) {
        return true;
    }
    globals.BITMAP_Y += 1;
    return false;
}
