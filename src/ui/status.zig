const std = @import("std");

const c = @import("../c.zig");
const window = @import("../window.zig");
const keyboard = @import("../keyboard.zig");
const game = @import("../game.zig");
const fonts = @import("fonts.zig");

// TODO: return the rect this has drawn over and blank it in the next iteration
fn draw_extrabonus(level: *c.TITUS_level) void {
    var tmpchars: [10]u8 = .{};
    var extrabonus = std.fmt.bufPrint(&tmpchars, "{d}", .{level.extrabonus}) catch {
        unreachable;
    };
    var extrabonus_width = fonts.text_width(extrabonus, true);
    fonts.text_render(extrabonus, 28 * 8 - extrabonus_width, 10 * 12, true);
}

// TODO: return the rect this has drawn over and blank it in the next iteration
fn draw_lives(level: *c.TITUS_level) void {
    var tmpchars: [10]u8 = .{};
    var lives = std.fmt.bufPrint(&tmpchars, "{d}", .{level.lives}) catch {
        unreachable;
    };
    var lives_width = fonts.text_width(lives, true);
    fonts.text_render(lives, 28 * 8 - lives_width, 11 * 12, true);
}

pub export fn viewstatus(level: *c.TITUS_level, countbonus: bool) c_int {
    var retval: c_int = undefined;
    var tmpchars: [10]u8 = .{};
    window.window_clear(null);

    if (game.game == c.Titus) {
        fonts.text_render("Level", 13 * 8, 12 * 5, false);
        fonts.text_render("Extra Bonus", 10 * 8, 10 * 12, false);
        fonts.text_render("Lives", 10 * 8, 11 * 12, false);
    } else if (game.game == c.Moktar) {
        fonts.text_render("Etape", 13 * 8, 12 * 5, false);
        fonts.text_render("Extra Bonus", 10 * 8, 10 * 12, false);
        fonts.text_render("Vie", 10 * 8, 11 * 12, false);
    }

    {
        const levelnumber = std.fmt.bufPrint(&tmpchars, "{d}", .{level.levelnumber + 1}) catch {
            return -1;
        };
        var levelnumber_width = fonts.text_width(levelnumber, false);
        fonts.text_render(levelnumber, 25 * 8 - levelnumber_width, 12 * 5, false);
    }

    {
        var constants = game.constants;
        var title = constants.levelfiles[level.levelnumber].title;
        var title_width = fonts.text_width(title, false);
        var position = (320 - title_width) / 2;
        fonts.text_render(title, position, 12 * 5 + 16, false);
    }

    draw_extrabonus(level);
    draw_lives(level);

    window.window_render();

    if (countbonus and (level.extrabonus >= 10)) {
        retval = keyboard.waitforbutton();
        if (retval < 0) {
            return retval;
        }
        while (level.extrabonus >= 10) {
            for (0..10) |_| {
                level.extrabonus -= 1;
                draw_extrabonus(level);
                window.window_render();
                // 150 ms
                c.SDL_Delay(150);
            }
            level.lives += 1;
            draw_lives(level);
            window.window_render();
            // 100 ms
            c.SDL_Delay(100);
        }
    }

    retval = keyboard.waitforbutton();
    if (retval < 0)
        return retval;

    window.window_clear(null);
    window.window_render();

    return (0);
}
