const std = @import("std");

const c = @import("../c.zig");
const window = @import("../window.zig");
const keyboard = @import("../keyboard.zig");
const fonts = @import("fonts.zig");

// TODO: this is a nice throwback in the original game, but maybe we could do something better.
// Like replace the (missing) manual with an intro sequence to give the player some context.
pub fn viewintrotext() c_int {
    var tmpstring: [41]u8 = .{};
    var rawtime = c.time(null);
    var timeinfo = c.localtime(&rawtime);

    var year = std.fmt.bufPrint(&tmpstring, "     You are still playing Moktar in {d} !!", .{timeinfo.*.tm_year + 1900}) catch {
        unreachable;
    };

    fonts.text_render("     YEAAA . . .", 0, 4 * 12, false);
    fonts.text_render(year, 0, 6 * 12, false);
    fonts.text_render("     Programmed in 1991 on AT .286 12MHz.", 0, 11 * 12, false);
    fonts.text_render("              . . . Enjoy Moktar Adventure !!", 0, 13 * 12, false);

    window.window_render();

    var retval = keyboard.waitforbutton();
    if (retval < 0)
        return retval;

    if (retval < 0)
        return retval;

    return (0);
}
