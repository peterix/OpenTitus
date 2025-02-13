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

const globals = @import("globals.zig");
const lvl = @import("level.zig");

pub fn move(level: *lvl.Level) void {
    for (&level.elevator) |*elevator| {
        if (!elevator.enabled) {
            continue;
        }

        // move all elevators
        elevator.sprite.x += elevator.sprite.speed_x;
        elevator.sprite.y += elevator.sprite.speed_y;
        elevator.counter += 1;
        if (elevator.counter >= elevator.range) {
            elevator.counter = 0;
            elevator.sprite.speed_x = 0 - elevator.sprite.speed_x;
            elevator.sprite.speed_y = 0 - elevator.sprite.speed_y;
        }

        // if elevators are out of the screen space, turn them invisible
        if (((elevator.sprite.x + 16 - (globals.BITMAP_X * 16)) >= 0) and // +16: closer to center
            ((elevator.sprite.x - 16 - (globals.BITMAP_X * 16)) <= globals.screen_width * 16) and // -16: closer to center
            ((elevator.sprite.y - (globals.BITMAP_Y * 16)) >= 0) and
            ((elevator.sprite.y - (globals.BITMAP_Y * 16)) - 16 <= globals.screen_height * 16))
        {
            elevator.sprite.invisible = false;
        } else {
            elevator.sprite.invisible = true; //Not necessary, but to mimic the original game
        }
    }
}
