const std = @import("std");

const c = @import("../c.zig");
const window = @import("../window.zig");
const keyboard = @import("../keyboard.zig");
const fonts = @import("fonts.zig");

// TODO: check for the actual names, some accented characters may have been lost because of technical limitations
const credits: [8][2][:0]const u8 = .{
    .{ "IBM Engineer", "Eric Zmiro" }, // Éric?
    .{ "Musics", "Christophe Fevre" },
    .{ "The Sleeper", "Gil Espeche" },
    .{ "Background", "Francis Fournier" },
    .{ "Sprites", "Stephane Beaufils" },
    .{ "Game Designer", "Florent Moreau" },
    .{ "Amiga Version", "Carlo Perconti" },
    .{ "Funny Friend", "Carole Delannoy" },
};

pub export fn credits_screen() c_int {
    var last_song = c.music_get_last_song();
    c.music_select_song(9);

    // TODO: have a way for the event loop to re-run this rendering code... maybe to animate it?
    window.window_clear(null);
    const monospace = false;
    var y: c_int = 2 * 12;
    for (credits, 0..) |credits_line, index| {
        _ = index;
        fonts.text_render_columns(credits_line[0], credits_line[1], y, monospace);
        y += 13;
    }
    y += 2 * 12 + 6 - 8;
    fonts.text_render_center("Thanks to", y, monospace);
    y += 12 + 6;
    fonts.text_render_center("Cristelle, Ana Luisa, Corinne and Manou.", y, monospace);
    window.window_render();

    var retval = keyboard.waitforbutton();
    if (retval < 0)
        return retval;

    c.music_select_song(last_song);
    return (0);
}
