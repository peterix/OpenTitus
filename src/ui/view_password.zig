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
const g = @import("../game.zig");
const settings = @import("../settings.zig");

pub export fn view_password(game: c.GameType, level: *c.TITUS_level, level_index: u8) c_int {
    var tmpchars: [10]u8 = .{};
    var retval: c_int = undefined;

    window.window_clear(null);
    window.window_render();

    // FIXME: this should not be necessary
    var saved_value = globals.g_scroll_px_offset;
    globals.g_scroll_px_offset = 0;

    if (game == c.Titus) {
        fonts.text_render("Level", 13 * 8, 13 * 8, false);
    } else if (game == c.Moktar) {
        fonts.text_render("Etape", 13 * 8, 13 * 8, false);
    }

    var level_index_ = std.fmt.bufPrint(&tmpchars, "{d}", .{level_index + 1}) catch {
        unreachable;
    };
    var level_index_width = fonts.text_width(level_index_, true);
    fonts.text_render(level_index_, 25 * 8 - level_index_width, 13 * 8, false);

    fonts.text_render("Unlocked!", 14 * 8, 10 * 8, false);
    settings.game_unlock_level(level_index, level.lives);

    window.window_render();
    retval = keyboard.waitforbutton();
    globals.g_scroll_px_offset = saved_value;
    if (retval < 0)
        return retval;

    return (0);
}
