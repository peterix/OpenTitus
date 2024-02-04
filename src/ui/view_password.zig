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
const window = @import("../window.zig");
const keyboard = @import("keyboard.zig");
const fonts = @import("fonts.zig");
const globals = @import("../globals.zig");
const data = @import("../data.zig");
const game = @import("../game.zig");
const game_state = @import("../game_state.zig");

// FIXME: this does not hold any allocator... nor can it find one easily.

pub export fn viewPassword(level: *c.TITUS_level, level_index: u8) c_int {
    var tmpchars: [10]u8 = .{};
    var retval: c_int = undefined;

    window.window_clear(null);

    // TODO: maybe we can print the level name here?

    // TODO: replace with proper localization
    if (data.game == c.Titus) {
        fonts.Gold.render("Level", 13 * 8, 13 * 8, .{});
    } else if (data.game == c.Moktar) {
        fonts.Gold.render("Etape", 13 * 8, 13 * 8, .{});
    }

    var level_index_ = std.fmt.bufPrint(&tmpchars, "{d}", .{level_index + 1}) catch {
        unreachable;
    };
    var level_index_width = fonts.Gold.metrics(level_index_, .{ .monospace = true });
    fonts.Gold.render(level_index_, 25 * 8 - level_index_width, 13 * 8, .{ .monospace = true });

    fonts.Gold.render_center("Unlocked!", 10 * 8, .{});
    game_state.unlock_level(
        game.allocator,
        level_index,
        level.lives,
    ) catch |err| {
        std.log.err("Could not record level unlock: {}", .{err});
    };

    window.window_render();
    retval = keyboard.waitforbutton();

    if (retval < 0)
        return retval;

    return (0);
}
