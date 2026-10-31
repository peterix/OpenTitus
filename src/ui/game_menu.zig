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

//! Choosing between Titus the Fox and Moktar, when both are installed.
//! Each game is shown as a card made from its own title picture and logo.

const std = @import("std");

const SDL = @import("../SDL.zig");

const window = @import("../window.zig");
const fonts = @import("fonts.zig");
const image = @import("image.zig");
const sqz = @import("../sqz.zig");

const input = @import("../input.zig");

const data = @import("../data.zig");

const card_width = 148;
/// The title picture, at a bit less than half size
const art_height = 92;
const card_gap = 8;
const cards_y = 22;

/// Where the logo is in each game's menu picture
fn logoRect(game_type: data.GameType) SDL.Rect {
    return switch (game_type) {
        .Moktar => .{ .x = 25, .y = 2, .w = 268, .h = 130 },
        else => .{ .x = 20, .y = 24, .w = 276, .h = 123 },
    };
}

const Card = struct {
    game_type: data.GameType,
    surface: *SDL.Surface,

    fn init(io: std.Io, allocator: std.mem.Allocator, game_type: data.GameType) !Card {
        const constants = data.constantsFor(game_type);
        const format = SDL.getWindowPixelFormat(window.window);
        const logo = logoRect(game_type);
        const logo_height: c_int = @divTrunc(logo.h * card_width, logo.w);

        const surface = SDL.createSurface(card_width, art_height + 2 + logo_height, format) orelse return error.OutOfMemory;
        errdefer SDL.destroySurface(surface);
        _ = SDL.fillSurfaceRect(surface, null, SDL.mapSurfaceRGB(surface, 0, 0, 0));

        if (constants.intro) |file| {
            var art = try loadPicture(io, allocator, file);
            defer art.deinit();
            // Halve it first, scaling down a lot in one go skips over pixels instead of averaging them
            const half = SDL.createSurface(160, 100, format) orelse return error.OutOfMemory;
            defer SDL.destroySurface(half);
            var half_rect = SDL.Rect{ .x = 0, .y = 0, .w = 160, .h = 100 };
            _ = SDL.blitSurfaceScaled(art.value, null, half, &half_rect, SDL.SCALEMODE_LINEAR);
            var dest = SDL.Rect{ .x = 0, .y = 0, .w = card_width, .h = art_height };
            _ = SDL.blitSurfaceScaled(half, null, surface, &dest, SDL.SCALEMODE_LINEAR);
        }
        if (constants.menu) |file| {
            var menu_picture = try loadPicture(io, allocator, file);
            defer menu_picture.deinit();
            var source = logo;
            var dest = SDL.Rect{ .x = 0, .y = art_height + 2, .w = card_width, .h = logo_height };
            _ = SDL.blitSurfaceScaled(menu_picture.value, &source, surface, &dest, SDL.SCALEMODE_LINEAR);
        }
        return .{ .game_type = game_type, .surface = surface };
    }

    fn deinit(self: *Card) void {
        SDL.destroySurface(self.surface);
    }

    fn draw(self: *const Card, x: c_int, selected: bool) void {
        const screen = window.screen.?;
        if (selected) {
            var frame = SDL.Rect{ .x = x - 2, .y = cards_y - 2, .w = self.surface.w + 4, .h = self.surface.h + 4 };
            _ = SDL.fillSurfaceRect(screen, &frame, SDL.mapSurfaceRGB(screen, 0xd0, 0xb0, 0x00));
            _ = SDL.setSurfaceColorMod(self.surface, 255, 255, 255);
        } else {
            _ = SDL.setSurfaceColorMod(self.surface, 96, 96, 96);
        }
        var dest = SDL.Rect{ .x = x, .y = cards_y, .w = self.surface.w, .h = self.surface.h };
        _ = SDL.blitSurface(self.surface, null, screen, &dest);
    }
};

fn loadPicture(io: std.Io, allocator: std.mem.Allocator, file: image.ImageFile) !image.ManagedSurface {
    const bytes = try sqz.unSQZ(io, file.filename, allocator);
    return image.loadImage(bytes, file.format, allocator);
}

/// Returns `.None` when the player quits instead
pub fn gameMenu(io: std.Io, allocator: std.mem.Allocator) data.GameType {
    const game_types = [_]data.GameType{ .Titus, .Moktar };
    var cards: [game_types.len]Card = undefined;
    for (game_types, 0..) |game_type, i| {
        cards[i] = Card.init(io, allocator, game_type) catch |err| {
            std.log.err("Cannot load the pictures of {s}: {}", .{ @tagName(game_type), err });
            for (cards[0..i]) |*card| card.deinit();
            return textMenu();
        };
    }
    defer for (&cards) |*card| card.deinit();

    var selected: usize = 0;
    while (true) {
        SDL.delay(10);

        const input_state = input.processEvents();
        switch (input_state.action) {
            .Quit, .Escape, .Cancel => {
                return .None;
            },
            .Left, .Up => {
                selected = 0;
            },
            .Right, .Down => {
                selected = 1;
            },
            .Activate => {
                return cards[selected].game_type;
            },
            else => {},
        }

        window.window_clear(null);
        fonts.Gold.render_center("Select Game", 5, .{ .transparent = true });
        const left_x = (window.game_width - 2 * card_width - card_gap) / 2;
        for (&cards, 0..) |*card, i| {
            card.draw(left_x + @as(c_int, @intCast(i)) * (card_width + card_gap), selected == i);
        }
        window.window_render();
    }
}

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
    const options = fonts.Font.RenderOptions{ .transparent = true };
    font.render_center(text, y, options);
}

/// The plain menu, if the pictures can't be loaded
fn textMenu() data.GameType {
    var selected: u8 = 0;

    while (true) {
        SDL.delay(10);

        const input_state = input.processEvents();
        switch (input_state.action) {
            .Quit => {
                return .None;
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

        window.window_clear(null);
        const title_width = fonts.Gold.metrics("Select Game", .{ .transparent = true }) + 4;
        var y: i16 = 40;
        fonts.Gold.render_center("Select Game", y, .{ .transparent = true });
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

/// Neither game is installed. Tell the player what to do, and wait for them to read it.
pub fn noGameData() void {
    const lines = [_][]const u8{
        "OpenTitus needs the files of the original",
        "DOS version of Titus the Fox or Moktar.",
        "",
        "Put them in a folder called TITUS or",
        "MOKTAR, next to where OpenTitus is",
        "started from. The README has the details.",
    };
    window.window_clear(null);
    var y: c_int = 40;
    fonts.Gold.render_center("No game data found", y, .{ .transparent = true });
    y += 30;
    for (lines) |line| {
        fonts.Gray.render_center(line, y, .{ .transparent = true });
        y += 13;
    }
    fonts.Gray.render_center("Press any key to quit", 170, .{ .transparent = true });
    window.window_render();
    _ = input.waitforbutton();
}
