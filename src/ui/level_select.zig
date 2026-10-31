//
// Copyright (C) 2008 - 2026 The OpenTitus team
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

//! Level select: the levels the player has seen, the unlocked ones can be started.

const std = @import("std");

const SDL = @import("../SDL.zig");
const fonts = @import("fonts.zig");
const window = @import("../window.zig");
const data = @import("../data.zig");
const game = @import("../game.zig");
const input = @import("../input.zig");

const menu = @import("menu.zig");
const MenuContext = menu.MenuContext;

pub const Result = union(enum) {
    /// Start this level
    level: usize,
    /// Back to the main menu
    cancel,
    /// Quit the game
    quit,
};

const line_height = 13;
/// The list scrolls under the title, in this part of the screen.
/// A whole number of rows, so no row is left cut in half when the scrolling stops.
const visible_rows = 12;
const list_top = 32;
const list_height = visible_rows * line_height;
const list_bottom = list_top + list_height;
/// Rows kept visible above and below the selected one, when there are any
const scroll_margin = 1;

const Entry = struct {
    text: []const u8,
    font: *fonts.Font,
    unlocked: bool,
};

/// Smoothly scrolling view of the list
const Scroll = struct {
    position: i32 = 0,

    /// Where the view should be to show the selected row with some rows around it
    fn target(self: *const Scroll, selection: usize, count: usize) i32 {
        const max_position: i32 = @max(0, @as(i32, @intCast(count)) * line_height - list_height);
        const row_top = @as(i32, @intCast(selection)) * line_height;
        var result = self.position;
        if (row_top - scroll_margin * line_height < result) {
            result = row_top - scroll_margin * line_height;
        }
        if (row_top + (1 + scroll_margin) * line_height > result + list_height) {
            result = row_top + (1 + scroll_margin) * line_height - list_height;
        }
        return std.math.clamp(result, 0, max_position);
    }

    fn update(self: *Scroll, selection: usize, count: usize) void {
        const distance = self.target(selection, count) - self.position;
        if (distance == 0) {
            return;
        }
        var step = @divTrunc(distance, 3);
        if (step == 0) {
            step = if (distance > 0) 1 else -1;
        }
        self.position += step;
    }

    /// Jump straight to where the view should be
    fn snap(self: *Scroll, selection: usize, count: usize) void {
        self.position = self.target(selection, count);
    }
};

pub fn levelSelect(menu_context: *MenuContext, allocator: std.mem.Allocator) !Result {
    var entries = try std.ArrayList(Entry).initCapacity(allocator, data.constants.levelfiles.len);
    defer entries.deinit(allocator);

    for (data.constants.levelfiles, 0..) |level, i| {
        if (!game.game_state.isKnown(i)) {
            // Show that there's more, but not what it is
            entries.appendAssumeCapacity(.{ .text = "...", .font = &fonts.Gray, .unlocked = false });
            break;
        }
        const unlocked = game.game_state.isUnlocked(i);
        entries.appendAssumeCapacity(.{
            .text = level.title,
            .font = if (unlocked) &fonts.Gold else &fonts.Gray,
            .unlocked = unlocked,
        });
    }

    var selection: usize = 0;
    var scroll: Scroll = .{};
    scroll.snap(selection, entries.items.len);

    while (true) {
        const timeout = menu_context.updateBackground();
        SDL.delay(timeout);

        const input_state = input.processEvents();
        switch (input_state.action) {
            .Quit => {
                return .quit;
            },
            .Escape, .Cancel => {
                return .cancel;
            },
            .Up => {
                if (selection > 0) {
                    selection -= 1;
                }
            },
            .Down => {
                if (selection < entries.items.len - 1) {
                    selection += 1;
                }
            },
            .Activate => {
                if (entries.items[selection].unlocked) {
                    return .{ .level = selection };
                }
            },
            else => {},
        }
        scroll.update(selection, entries.items.len);

        menu_context.renderBackground();
        _ = menu_context.renderTitle("LEVEL SELECT");
        renderList(entries.items, selection, scroll.position);
        window.window_render();
    }
}

fn renderList(entries: []const Entry, selection: usize, scroll_position: i32) void {
    const screen = window.screen.?;
    const clip = SDL.Rect{ .x = 0, .y = list_top, .w = 320, .h = list_height };
    _ = SDL.setSurfaceClipRect(screen, &clip);
    defer _ = SDL.setSurfaceClipRect(screen, null);

    const options = fonts.Font.RenderOptions{ .transparent = true };
    for (entries, 0..) |entry, i| {
        const y: c_int = list_top + @as(c_int, @intCast(i)) * line_height - scroll_position;
        if (y + line_height <= list_top or y >= list_bottom) {
            continue;
        }
        if (selection == i) {
            const width: c_int = entry.font.metrics(entry.text, options);
            const x = 160 - @divTrunc(width, 2);
            entry.font.render(entry.text, x, y, options);
            fonts.Gold.render(">", x - 4 - @as(c_int, fonts.Gold.metrics(">", options)), y, options);
            fonts.Gold.render("<", x + width + 4, y, options);
        } else {
            entry.font.render_center(entry.text, y, options);
        }
    }

    // Show when there are more levels above or below
    _ = SDL.setSurfaceClipRect(screen, null);
    const content_height = @as(i32, @intCast(entries.len)) * line_height;
    if (scroll_position > 0) {
        fonts.Gray.render("^", 300, list_top, options);
    }
    if (scroll_position + list_height < content_height) {
        fonts.Gray.render("v", 300, list_bottom - line_height, options);
    }
}
