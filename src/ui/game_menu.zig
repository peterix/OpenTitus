//
// Copyright (C) 2025 The OpenTitus team
//
// Authors:
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

const SDL = @import("../SDL.zig");

const render = @import("../render.zig");
const ScreenContext = render.ScreenContext;
const window = @import("../window.zig");
const sprites = @import("../sprites.zig");
const fonts = @import("fonts.zig");
const globals = @import("../globals.zig");

const input = @import("../input.zig");
const InputAction = input.InputAction;

const data = @import("../data.zig");

const MenuEntry = struct {
    text: []const u8,
    result: data.GameType,
};

const menu_entries: []const MenuEntry = &.{
    .{ .text = "Titus The Fox", .result = .Titus },
    .{ .text = "Moktar", .result = .Moktar },
    .{ .text = "Quit", .result = .None },
};

fn renderLabel(text: []const u8, y: i16, selected: bool) void {
    const font = if (selected) &fonts.Gold else &fonts.Gray;
    const options = fonts.Font.RenderOptions{ .transpatent = true };
    font.render_center(text, y, options);
}

pub fn gameMenu() data.GameType {
    var selected: u8 = 0;
    while (true) {
        SDL.delay(10);

        const input_state = input.processEvents();
        switch (input_state.action) {
            .Quit => {
                return .None; //c.TITUS_ERROR_QUIT;
            },
            .Escape, .Cancel => {
                return .None;
            },
            .Up => {
                if (selected > 0) {
                    selected -= 1;
                }
            },
            .Down => {
                if (selected < menu_entries.len - 1) {
                    selected += 1;
                }
            },
            .Activate => {
                return menu_entries[selected].result;
            },
            else => {},
        }

        const title_width = fonts.Gold.metrics("Select Game", .{ .transpatent = true }) + 4;
        var y: i16 = 40;
        fonts.Gold.render_center("Select Game", y, .{ .transpatent = true });
        y += 12;
        const bar = SDL.Rect{ .x = 160 - title_width / 2, .y = y, .w = title_width, .h = 1 };
        _ = SDL.fillSurfaceRect(window.screen.?, &bar, SDL.mapSurfaceRGB(window.screen, 0xd0, 0xb0, 0x00));
        y += 27;
        for (menu_entries, 0..) |entry, i| {
            renderLabel(entry.text, y, selected == i);
            y += 14;
        }
        window.window_render();
    }
}
