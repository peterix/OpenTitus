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

const sqz = @import("../sqz.zig");
const image = @import("image.zig");
const window = @import("../window.zig");
const data = @import("../data.zig");
const fonts = @import("fonts.zig");
const render = @import("../render.zig");
const ImageFile = image.ImageFile;
const input = @import("../input.zig");

const menu = @import("menu.zig");
const options_menu = @import("options_menu.zig");
const level_select = @import("level_select.zig");
const credits = @import("credits.zig");
const game = @import("../game.zig");
const game_state = @import("../game_state.zig");

/// What the player chose to play
pub const Choice = union(enum) {
    /// Start a new game at this level
    new_game: u16,
    continue_game: game_state.SavedGame,
};

const MenuItem = enum {
    Start,
    LevelSelect,
    Options,
    Quit,

    fn label(self: MenuItem, can_continue: bool) []const u8 {
        return switch (self) {
            .Start => if (can_continue) "CONTINUE" else "START",
            .LevelSelect => "LEVEL SELECT",
            .Options => "OPTIONS",
            .Quit => "QUIT",
        };
    }
};
const menu_items = std.enums.values(MenuItem);
const line_height = 13;

/// Like in the original, the credits show up when nobody touches the menu for a while
const idle_ms_before_credits = 60 * 1000;

/// The original menu images have only two items painted on them. We paint over them and draw our own.
const Layout = struct {
    /// Part of the original image with the original items, painted over with black
    clear: SDL.Rect,
    /// Background for the items, if any
    panel: ?[]const u8 = null,
    panel_x: c_int = 0,
    panel_y: c_int = 0,
    font: *fonts.Font,
    font_options: fonts.Font.RenderOptions,
    /// Top left of the first menu item
    text_x: c_int,
    text_y: c_int,
    /// The selection marker, magenta is transparent
    cursor: []const u8,
    /// Position of the selection marker relative to its menu item
    cursor_dx: c_int,
    cursor_dy: c_int,
};

const titus_layout: Layout = .{
    .clear = .{ .x = 100, .y = 145, .w = 140, .h = 55 },
    .font = &fonts.Red,
    .font_options = .{ .monospace = true, .transparent = true },
    .text_x = 112,
    .text_y = 148,
    .cursor = @embedFile("menu_cursor_titus.bmp"),
    .cursor_dx = -10,
    .cursor_dy = -1,
};

const moktar_layout: Layout = .{
    .clear = .{ .x = 120, .y = 157, .w = 89, .h = 40 },
    .panel = @embedFile("moktar_menu_panel.bmp"),
    .panel_x = 96,
    .panel_y = 131,
    .font = &fonts.Gold,
    .font_options = .{ .monospace = true, .shadow = true },
    .text_x = 116,
    .text_y = 140,
    .cursor = @embedFile("menu_cursor_moktar.bmp"),
    .cursor_dx = -14,
    .cursor_dy = -1,
};

fn loadBitmap(bitmap: []const u8) !*SDL.Surface {
    const loaded = SDL.loadBMP_IO(SDL.IOFromMem(@constCast(bitmap.ptr), bitmap.len), true) orelse return error.CannotLoadBitmap;
    defer SDL.destroySurface(loaded);
    return SDL.convertSurface(loaded, SDL.getWindowPixelFormat(window.window));
}

/// The menu: the original image with our items on it
const MenuImage = struct {
    base: *SDL.Surface,
    cursor: *SDL.Surface,
    layout: *const Layout,

    fn init(original: *SDL.Surface, can_continue: bool) !MenuImage {
        const layout: *const Layout = if (data.game == .Moktar) &moktar_layout else &titus_layout;

        const base = try SDL.duplicateSurface(original);
        errdefer SDL.destroySurface(base);
        _ = SDL.fillSurfaceRect(base, &layout.clear, SDL.mapSurfaceRGB(base, 0, 0, 0));
        if (layout.panel) |panel_bitmap| {
            const panel = try loadBitmap(panel_bitmap);
            defer SDL.destroySurface(panel);
            var dest = SDL.Rect{ .x = layout.panel_x, .y = layout.panel_y, .w = panel.w, .h = panel.h };
            _ = SDL.blitSurface(panel, null, base, &dest);
        }
        for (menu_items, 0..) |item, i| {
            const y = layout.text_y + @as(c_int, @intCast(i)) * line_height;
            layout.font.renderOn(base, item.label(can_continue), layout.text_x, y, layout.font_options);
        }

        const cursor = try loadBitmap(layout.cursor);
        _ = SDL.setSurfaceColorKey(cursor, true, SDL.mapSurfaceRGB(cursor, 255, 0, 255));
        return .{ .base = base, .cursor = cursor, .layout = layout };
    }

    fn deinit(self: *MenuImage) void {
        SDL.destroySurface(self.cursor);
        SDL.destroySurface(self.base);
    }

    /// Draw the menu with the marker next to the selected item
    fn draw(self: *const MenuImage, target: *SDL.Surface, selection: usize) void {
        _ = SDL.blitSurface(self.base, null, target, null);
        var dest = SDL.Rect{
            .x = self.layout.text_x + self.layout.cursor_dx,
            .y = self.layout.text_y + @as(c_int, @intCast(selection)) * line_height + self.layout.cursor_dy,
            .w = self.cursor.w,
            .h = self.cursor.h,
        };
        _ = SDL.blitSurface(self.cursor, null, target, &dest);
    }
};

/// Menus opened from the main menu draw themselves over a dimmed picture of it.
/// It's much brighter and busier than a level, so it fades darker and faster than in the pause menu.
fn subMenuContext(background: *SDL.Surface) menu.MenuContext {
    return .{
        .background_image = background,
        .fade_target = 230,
        .fade_step = 6,
    };
}

pub fn view_menu(io: std.Io, file: ImageFile, allocator: std.mem.Allocator) !?Choice {
    var selection: usize = 0;
    // Start continues the game in progress, if there is one
    const saved_game = game.game_state.getSavedGame();

    const menudata = try sqz.unSQZ(io, file.filename, allocator);
    var image_memory = try image.loadImage(menudata, file.format, allocator);
    defer image_memory.deinit();

    var menu_image = try MenuImage.init(image_memory.value, saved_game != null);
    defer menu_image.deinit();

    // The menu with the cursor
    const frame = try SDL.duplicateSurface(menu_image.base);
    defer SDL.destroySurface(frame);

    // FIXME: move to render.zig
    const fade_time = 1000;
    var image_alpha: u64 = 0;
    const tick_start = SDL.getTicks();

    // Fade in
    while (image_alpha < 255) {
        const input_state = input.processEvents();
        switch (input_state.action) {
            .Escape, .Cancel, .Quit => {
                return null;
            },
            else => {},
        }

        image_alpha = (SDL.getTicks() - tick_start) * 256 / fade_time;

        if (image_alpha > 255)
            image_alpha = 255;

        window.window_clear(null);
        menu_image.draw(frame, selection);
        // FIXME: handle errors?
        _ = SDL.setSurfaceBlendMode(frame, SDL.BLENDMODE_BLEND);
        _ = SDL.setSurfaceAlphaMod(frame, @truncate(image_alpha));
        _ = SDL.blitSurface(frame, null, window.screen, null);
        window.window_render();
        SDL.delay(1);
    }
    _ = SDL.setSurfaceBlendMode(frame, SDL.BLENDMODE_NONE);

    var choice: ?Choice = null;
    var last_input = SDL.getTicks();
    // View the menu
    MENULOOP: while (true) {
        const input_state = input.processEvents();
        if (input_state.any_key_pressed or input_state.action != .None) {
            last_input = SDL.getTicks();
        } else if (SDL.getTicks() - last_input > idle_ms_before_credits) {
            // Any key goes back to the menu
            if (credits.credits_screen() < 0) {
                return null;
            }
            last_input = SDL.getTicks();
        }
        switch (input_state.action) {
            .Escape, .Cancel, .Quit => {
                return null;
            },
            .Up => {
                if (selection > 0) {
                    selection -= 1;
                }
            },
            .Down => {
                if (selection < menu_items.len - 1) {
                    selection += 1;
                }
            },
            .Activate => {
                switch (menu_items[selection]) {
                    .Start => {
                        choice = if (saved_game) |saved| .{ .continue_game = saved } else .{ .new_game = 0 };
                        break :MENULOOP;
                    },
                    .LevelSelect => {
                        const background = try SDL.duplicateSurface(frame);
                        defer SDL.destroySurface(background);
                        var menu_context = subMenuContext(background);
                        switch (try level_select.levelSelect(&menu_context, allocator)) {
                            .level => |level| {
                                choice = .{ .new_game = @intCast(level) };
                                break :MENULOOP;
                            },
                            .cancel => {},
                            .quit => return null,
                        }
                    },
                    .Options => {
                        const background = try SDL.duplicateSurface(frame);
                        defer SDL.destroySurface(background);
                        var menu_context = subMenuContext(background);
                        if (options_menu.optionsMenu(&menu_context)) |result| {
                            if (result < 0) {
                                return null;
                            }
                        }
                    },
                    .Quit => {
                        return null;
                    },
                }
            },
            else => {},
        }

        window.window_clear(null);
        menu_image.draw(frame, selection);
        _ = SDL.blitSurface(frame, null, window.screen, null);
        window.window_render();
        SDL.delay(1);
    }

    // Close the menu
    render.fadeout();
    return choice;
}
