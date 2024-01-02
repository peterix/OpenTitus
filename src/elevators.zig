//
// Copyright (C) 2008 - 2011 The OpenTitus team
//
// Authors:
// Eirik Stople
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

// elevators.zig
// Handles elevators.

const std = @import("std");

const globals = @import("globals.zig");
const c = @import("c.zig");

pub fn elevators_move(level: *c.TITUS_level) void {
    var elevators = level.*.elevator;
    for (0..level.*.elevatorcount) |i| {
        var elevator = &elevators[i];
        if (elevator.*.enabled == false) {
            continue;
        }

        // move all elevators
        elevator.*.sprite.x += elevator.*.sprite.speedX;
        elevator.*.sprite.y += elevator.*.sprite.speedY;
        elevator.*.counter += 1;
        if (elevator.*.counter >= elevator.*.range) {
            elevator.*.counter = 0;
            elevator.*.sprite.speedX = 0 - elevator.*.sprite.speedX;
            elevator.*.sprite.speedY = 0 - elevator.*.sprite.speedY;
        }

        // if elevators are out of the screen space, turn them invisible
        if (((elevator.*.sprite.x + 16 - (globals.BITMAP_X * 16)) >= 0) and // +16: closer to center
            ((elevator.*.sprite.x - 16 - (globals.BITMAP_X * 16)) <= c.screen_width * 16) and // -16: closer to center
            ((elevator.*.sprite.y - (globals.BITMAP_Y * 16)) >= 0) and
            ((elevator.*.sprite.y - (globals.BITMAP_Y * 16)) - 16 <= c.screen_height * 16))
        {
            elevator.*.sprite.invisible = false;
        } else {
            elevator.*.sprite.invisible = true; //Not necessary, but to mimic the original game
        }
    }
}
