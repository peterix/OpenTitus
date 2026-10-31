//
// Copyright (C) 2026 The OpenTitus team
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

//! Status always on screen while playing, along the top where it doesn't hide the player: lives and energy on the left,
//! extra bonus on the right. The original only shows the energy, for a moment after it changes.

const std = @import("std");

const SDL = @import("../SDL.zig");
const window = @import("../window.zig");
const globals = @import("../globals.zig");
const sprites = @import("../sprites.zig");
const lvl = @import("../level.zig");
const common = @import("../common.zig");
const data = @import("../data.zig");
const game = @import("../game.zig");
const fonts = @import("fonts.zig");

const margin = 6;

/// Energy segments
const segment_width = 3;
const segment_height = 8;
const segment_spacing = 1;

/// The head in the standing player sprite, used as the lives icon
fn head() SDL.Rect {
    return switch (data.game) {
        .Moktar => .{ .x = 3, .y = 0, .w = 16, .h = 14 },
        else => .{ .x = 8, .y = 0, .w = 18, .h = 19 },
    };
}

const text_options = fonts.Font.RenderOptions{ .monospace = true, .shadow = true };
const text_height = 12;
/// Size of the bonus tile icon
const tile_size = 16;

/// Height of the status row. The icons and the text sit on its bottom edge.
fn rowHeight() c_int {
    return @max(head().h, tile_size);
}

fn textY() c_int {
    return margin + rowHeight() - text_height;
}

pub fn isEnabled() bool {
    return game.settings.status_display;
}

pub fn setEnabled(enabled: bool) void {
    game.settings.status_display = enabled;
}

pub fn render(level: *lvl.Level) void {
    common.subto0(&globals.BAR_FLAG);
    const screen = window.screen orelse return;
    const lives_right = renderLives(screen, level);
    renderEnergy(screen, level, lives_right + 6);
    renderBonus(screen, level);
}

fn renderEnergy(screen: *SDL.Surface, level: *lvl.Level, x: c_int) void {
    const outline = SDL.mapSurfaceRGB(screen, 0, 0, 0);
    // Flashes for a moment after the energy changes, like the original bars show up
    const full = if (globals.BAR_FLAG > 0 and (globals.BAR_FLAG / 4) % 2 == 0)
        SDL.mapSurfaceRGB(screen, 255, 255, 255)
    else
        SDL.mapSurfaceRGB(screen, 240, 200, 48);
    const empty = SDL.mapSurfaceRGB(screen, 72, 56, 32);

    const step = segment_width + segment_spacing;
    // Level with the middle of the text next to it
    const y = textY() + (text_height - segment_height) / 2;
    var backdrop = SDL.Rect{
        .x = x - 1,
        .y = y - 1,
        .w = globals.MAXIMUM_ENERGY * step + 1,
        .h = segment_height + 2,
    };
    _ = SDL.fillSurfaceRect(screen, &backdrop, outline);
    for (0..globals.MAXIMUM_ENERGY) |i| {
        var segment = SDL.Rect{
            .x = x + @as(c_int, @intCast(i)) * step,
            .y = y,
            .w = segment_width,
            .h = segment_height,
        };
        _ = SDL.fillSurfaceRect(screen, &segment, if (i < level.player.hp) full else empty);
    }
}

/// Returns where the lives end, room for two digits included so the energy bar doesn't move
fn renderLives(screen: *SDL.Surface, level: *lvl.Level) c_int {
    var source = head();
    const text_x = margin + source.w + 2;
    const right = text_x + @as(c_int, @intCast(fonts.Gold.metrics("x00", text_options)));

    if (sprites.sprite_cache.getSprite(.{ .number = 0, .flip = false, .flash = false })) |image| {
        var dest = SDL.Rect{ .x = margin, .y = margin + rowHeight() - source.h, .w = source.w, .h = source.h };
        _ = SDL.blitSurface(image, &source, screen, &dest);
    } else |_| {}

    var buffer: [16]u8 = undefined;
    const text = std.fmt.bufPrint(&buffer, "x{d}", .{level.lives}) catch return right;
    fonts.Gold.render(text, text_x, textY(), text_options);
    return right;
}

fn renderBonus(screen: *SDL.Surface, level: *lvl.Level) void {
    var buffer: [16]u8 = undefined;
    const text = std.fmt.bufPrint(&buffer, "x{d}", .{level.extrabonus}) catch return;
    const text_width: c_int = @intCast(fonts.Gold.metrics(text, text_options));
    const text_x = window.game_width - margin - text_width;
    fonts.Gold.render(text, text_x, textY(), text_options);

    // The level's own bonus tile
    const tile = bonusTile(level) orelse return;
    const animated_tile = level.tile[tile].animation[globals.tile_anim];
    const surface: *SDL.Surface = @ptrCast(@alignCast(level.tile[animated_tile].tiledata));
    var dest = SDL.Rect{ .x = text_x - tile_size - 2, .y = margin + rowHeight() - tile_size, .w = tile_size, .h = tile_size };
    _ = SDL.blitSurface(surface, null, screen, &dest);
}

/// The tile of the bonuses that count, the ones that give energy and extra bonus
fn bonusTile(level: *lvl.Level) ?u8 {
    for (level.bonus) |bonus| {
        if (bonus.exists and bonus.bonustile >= 255 - 2) {
            return bonus.bonustile;
        }
    }
    return null;
}
