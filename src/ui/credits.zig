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

const window = @import("../window.zig");
const audio = @import("../audio/audio.zig");
const keyboard = @import("keyboard.zig");
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

pub fn credits_screen() c_int {
    const last_song = audio.music_get_last_song();
    audio.playTrack(.Credits);

    // TODO: have a way for the event loop to re-run this rendering code... maybe to animate it?
    window.window_clear(null);
    const options = fonts.Font.RenderOptions{ .monospace = false };
    var y: c_int = 2 * 12;
    for (credits, 0..) |credits_line, index| {
        _ = index;
        fonts.Gold.render_columns(credits_line[0], credits_line[1], y, options);
        y += 13;
    }
    y += 2 * 12 + 6 - 8;
    fonts.Gold.render_center("Thanks to", y, options);
    y += 12 + 6;
    fonts.Gold.render_center("Cristelle, Ana Luisa, Corinne and Manou.", y, options);
    window.window_render();

    const retval = keyboard.waitforbutton();
    if (retval < 0)
        return retval;

    audio.playTrack(last_song);
    return (0);
}
