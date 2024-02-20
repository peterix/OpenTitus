//
// Copyright (C) 2024 The OpenTitus team
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

const c = @import("../c.zig");
const SDL = @import("../SDL.zig");

const render = @import("../render.zig");
const window = @import("../window.zig");
const sprites = @import("../sprites.zig");
const fonts = @import("fonts.zig");
const globals = @import("../globals.zig");
const audio = @import("../audio/AudioEngine.zig");
const options_menu = @import("options_menu.zig");

const menu = @import("menu.zig");
const MenuAction = menu.MenuAction;
const MenuContext = menu.MenuContext;

fn continueFn(menu_context: *MenuContext) ?c_int {
    _ = menu_context;
    return 0;
}

fn quitFn(menu_context: *MenuContext) ?c_int {
    _ = menu_context;
    return -1;
}

const MenuEntry = struct {
    text: []const u8,
    handler: *const fn (*MenuContext) ?c_int,
};

const menu_entries: []const MenuEntry = &.{
    .{ .text = "Continue", .handler = continueFn },
    .{ .text = "Options", .handler = options_menu.optionsMenu },
    .{ .text = "Quit", .handler = quitFn },
};

fn renderLabel(text: []const u8, y: i16, selected: bool) void {
    const font = if (selected) &fonts.Gold else &fonts.Gray;
    const options = fonts.Font.RenderOptions{ .transpatent = true };
    font.render_center(text, y, options);
}

pub export fn pauseMenu(context: *c.ScreenContext) c_int {

    // take a screenshot and use it as a background that fades to black a bit
    const image = c.SDL_ConvertSurface(window.screen.?, window.screen.?.format, c.SDL_SWSURFACE);
    defer c.SDL_FreeSurface(image);

    defer render.screencontext_reset(context);

    var menu_context: MenuContext = .{
        .background_image = image,
        .background_fade = 0,
    };
    var selected: u8 = 0;
    while (true) {
        const timeout = menu_context.updateBackground();
        SDL.delay(timeout);

        const action = menu.getMenuAction();
        switch (action) {
            .Quit => {
                return c.TITUS_ERROR_QUIT;
            },
            .ExitMenu => {
                return 0;
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
                const ret_val = menu_entries[selected].handler(&menu_context);
                if (ret_val) |value| {
                    return value;
                }
            },
            else => {},
        }

        menu_context.renderBackground();
        const title_width = fonts.Gold.metrics("PAUSED", .{ .transpatent = true }) + 4;
        var y: i16 = 40;
        fonts.Gold.render_center("PAUSED", y, .{ .transpatent = true });
        y += 12;
        const bar = c.SDL_Rect{ .x = 160 - title_width / 2, .y = y, .w = title_width, .h = 1 };
        _ = c.SDL_FillRect(window.screen.?, &bar, c.SDL_MapRGB(window.screen.?.format, 0xd0, 0xb0, 0x00));
        y += 27;
        for (menu_entries, 0..) |entry, i| {
            renderLabel(entry.text, y, selected == i);
            y += 14;
        }
        window.window_render();

        audio.music_restart_if_finished();
    }
}
