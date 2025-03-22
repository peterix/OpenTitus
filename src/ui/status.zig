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

const window = @import("../window.zig");
const keyboard = @import("keyboard.zig");
const data = @import("../data.zig");
const fonts = @import("fonts.zig");
const globals = @import("../globals.zig");
const lvl = @import("../level.zig");

const Rect = struct {
    x: u16,
    y: u16,
    w: u16,
    h: u16,
};

// FIXME: deduplicate these two...
// TODO: return the rect this has drawn over and blank it in the next iteration
fn render_extrabonus(level: *lvl.Level, last_bounds: ?Rect) Rect {
    if (last_bounds != null) {
        var rect = SDL.Rect{
            // FIXME: move all UI screens to an overlay that's independent from the scroll buffer madness
            .x = last_bounds.?.x,
            .y = last_bounds.?.y,
            .w = last_bounds.?.w,
            .h = last_bounds.?.h,
        };
        window.window_clear(&rect);
    }
    var tmpchars = [_]u8{0} ** 10;
    const extrabonus = std.fmt.bufPrint(&tmpchars, "{d}", .{level.extrabonus}) catch {
        unreachable;
    };
    const extrabonus_width = fonts.Gold.metrics(extrabonus, .{ .monospace = true });
    fonts.Gold.render(extrabonus, 28 * 8 - extrabonus_width, 10 * 12, .{ .monospace = true });
    const bounds = Rect{
        .x = 28 * 8 - extrabonus_width,
        .y = 10 * 12,
        .w = extrabonus_width,
        .h = 12,
    };
    return bounds;
}

// TODO: return the rect this has drawn over and blank it in the next iteration
fn render_lives(level: *lvl.Level, last_bounds: ?Rect) Rect {
    if (last_bounds != null) {
        var rect = SDL.Rect{
            // FIXME: move all UI screens to an overlay that's independent from the scroll buffer madness
            .x = last_bounds.?.x,
            .y = last_bounds.?.y,
            .w = last_bounds.?.w,
            .h = last_bounds.?.h,
        };
        _ = SDL.fillSurfaceRect(window.screen, &rect, 0);
    }
    var tmpchars = [_]u8{0} ** 10;
    const lives = std.fmt.bufPrint(&tmpchars, "{d}", .{level.lives}) catch {
        unreachable;
    };
    const lives_width = fonts.Gold.metrics(lives, .{ .monospace = true });

    fonts.Gold.render(lives, 28 * 8 - lives_width, 11 * 12, .{ .monospace = true });
    const bounds = Rect{
        .x = 28 * 8 - lives_width,
        .y = 11 * 12,
        .w = lives_width,
        .h = 12,
    };
    return bounds;
}

pub fn viewstatus(level: *lvl.Level, countbonus: bool) c_int {
    var retval: c_int = undefined;
    var tmpchars = [_]u8{0} ** 10;
    window.window_clear(null);

    if (data.game == .Titus) {
        fonts.Gold.render("Level", 13 * 8, 12 * 5, .{});
        fonts.Gold.render("Extra Bonus", 10 * 8, 10 * 12, .{});
        fonts.Gold.render("Lives", 10 * 8, 11 * 12, .{});
    } else if (data.game == .Moktar) {
        fonts.Gold.render("Etape", 13 * 8, 12 * 5, .{});
        fonts.Gold.render("Extra Bonus", 10 * 8, 10 * 12, .{});
        fonts.Gold.render("Vie", 10 * 8, 11 * 12, .{});
    }

    {
        const levelnumber = std.fmt.bufPrint(&tmpchars, "{d}", .{level.levelnumber + 1}) catch {
            return -1;
        };
        const levelnumber_width = fonts.Gold.metrics(levelnumber, .{});
        fonts.Gold.render(levelnumber, 25 * 8 - levelnumber_width, 12 * 5, .{});
    }

    {
        const constants = data.constants;
        const title = constants.levelfiles[level.levelnumber].title;
        const title_width = fonts.Gold.metrics(title, .{});
        const position = (320 - title_width) / 2;
        fonts.Gold.render(title, position, 12 * 6, .{});
    }

    var last_extrabonus = render_extrabonus(level, null);
    var last_lives = render_lives(level, null);

    window.window_render();

    if (countbonus and (level.extrabonus >= 10)) {
        retval = keyboard.waitforbutton();
        if (retval < 0) {
            return retval;
        }
        while (level.extrabonus >= 10) {
            for (0..10) |_| {
                level.extrabonus -= 1;
                last_extrabonus = render_extrabonus(level, last_extrabonus);
                window.window_render();
                // 150 ms
                SDL.delay(150);
            }
            level.lives += 1;
            last_lives = render_lives(level, last_lives);
            window.window_render();
            // 100 ms
            SDL.delay(100);
        }
    }

    retval = keyboard.waitforbutton();
    if (retval < 0)
        return retval;

    window.window_clear(null);
    window.window_render();

    return (0);
}
