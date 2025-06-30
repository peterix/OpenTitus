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
const common = @import("common.zig");
const globals = @import("globals.zig");
const window = @import("window.zig");
const fonts = @import("ui/fonts.zig");
const sprites = @import("sprites.zig");
const lvl = @import("level.zig");
const input = @import("input.zig");

const SDL = @import("SDL.zig");

const tick_delay = 29;

pub const ScreenContext = struct {
    started: bool = false,
    LAST_CLOCK: u64 = 0,
    TARGET_CLOCK: u64 = 0,
};

pub fn screencontext_reset(context: *ScreenContext) void {
    context.* = ScreenContext{};
}

fn screencontext_initial(context: *ScreenContext, ticks: u32) void {
    const initial_clock = SDL.getTicks();
    context.TARGET_CLOCK = initial_clock + ticks;
    context.started = true;
    SDL.delay(@truncate(ticks));
    context.LAST_CLOCK = SDL.getTicks();
    context.TARGET_CLOCK += ticks;
}

fn screencontext_advance(context: *ScreenContext, ticks: u32) void {
    if (!context.started) {
        screencontext_initial(context, ticks);
        return;
    }
    const now = SDL.getTicks();
    if (context.TARGET_CLOCK > now) {
        SDL.delay(@truncate(context.TARGET_CLOCK - now));
    }
    context.LAST_CLOCK = SDL.getTicks();
    context.TARGET_CLOCK = context.LAST_CLOCK + ticks;
}

pub fn flip_screen(context: *ScreenContext, slow: bool) void {
    window.window_render();
    if (slow) {
        screencontext_advance(context, tick_delay);
    } else {
        SDL.delay(10);
        screencontext_reset(context);
    }
}

// We use this to fill the whole 320x200 space in most cases instead of not rendering the bottom 8 pixels
// TODO: actual vertical smooth scrolling instead of this coarse stuff and half-tile workarounds
fn get_y_offset() u8 {
    return if (globals.BITMAP_Y == 0) 0 else 8;
}

pub fn render_tiles(level: *lvl.Level) void {
    const y_offset = get_y_offset();
    var x: i16 = -1;
    while (x < 21) : (x += 1) {
        const checkX = globals.BITMAP_X + x;
        if (checkX < 0 or checkX >= level.width) {
            continue;
        }
        const tileX = @as(usize, @intCast(checkX));
        var y: i16 = -1;
        while (y < 13) : (y += 1) {
            const checkY = globals.BITMAP_Y + y;
            if (checkY < 0 or checkY >= level.height) {
                continue;
            }
            const tileY = @as(usize, @intCast(checkY));

            var dest: SDL.Rect = undefined;
            dest.x = x * 16 + globals.g_scroll_px_offset;
            dest.y = y * 16 + y_offset;
            const tile = level.getTile(tileX, tileY);
            const animated_tile = level.tile[tile].animation[globals.tile_anim];
            const surface = level.tile[animated_tile].tiledata;
            _ = SDL.blitSurface(@ptrCast(@alignCast(surface)), null, window.screen, &dest);
        }
    }
}

pub fn render_sprites(level: *lvl.Level) void {
    for (0..lvl.ELEVATOR_CAPACITY) |i| {
        render_sprite(&level.elevator[lvl.ELEVATOR_CAPACITY - 1 - i].sprite);
    }

    for (0..lvl.TRASH_CAPACITY) |i| {
        render_sprite(&level.trash[lvl.TRASH_CAPACITY - 1 - i]);
    }

    for (0..lvl.ENEMY_CAPACITY) |i| {
        render_sprite(&level.enemy[lvl.ENEMY_CAPACITY - 1 - i].sprite);
    }

    for (0..lvl.OBJECT_CAPACITY) |i| {
        render_sprite(&level.object[lvl.OBJECT_CAPACITY - 1 - i].sprite);
    }

    render_sprite(&level.player.sprite3);
    render_sprite(&level.player.sprite2);
    render_sprite(&level.player.sprite);

    if (globals.GODMODE) {
        fonts.Gold.render("GODMODE", 30 * 8, 0 * 12, .{ .monospace = true });
    }
    if (globals.NOCLIP) {
        fonts.Gold.render("NOCLIP", 30 * 8, 1 * 12, .{ .monospace = true });
    }
}

fn render_sprite(spr: *allowzero lvl.Sprite) void {
    if (!spr.enabled) {
        return;
    }
    if (spr.invisible) {
        return;
    }
    spr.visible = false;

    var dest: SDL.Rect = undefined;
    if (!spr.flipped) {
        // FIXME: crash in final level!
        dest.x = spr.x - spr.spritedata.?.refwidth - (globals.BITMAP_X * 16) + globals.g_scroll_px_offset;
    } else {
        dest.x = spr.x + spr.spritedata.?.refwidth - spr.spritedata.?.width - (globals.BITMAP_X * 16) + globals.g_scroll_px_offset;
    }

    const sprite_offset: i16 = 0 - (@as(i16, spr.spritedata.?.refheight) - spr.spritedata.?.height);
    dest.y = spr.y + sprite_offset - spr.spritedata.?.height + 1 - (globals.BITMAP_Y * 16) + get_y_offset();

    if ((dest.x >= globals.screen_width * 16) or //Right for the screen
        (dest.x + spr.spritedata.?.width < 0) or //Left for the screen
        (dest.y + spr.spritedata.?.height < 0) or //Above the screen
        (dest.y >= globals.screen_height * 16)) //Below the screen
    {
        return;
    }

    const image = sprites.sprite_cache.getSprite(.{
        .number = spr.*.number,
        .flip = spr.*.flipped,
        .flash = spr.*.flash,
    }) catch {
        _ = SDL.fillSurfaceRect(window.screen, &dest, SDL.mapSurfaceRGB(window.screen, 255, 180, 128));
        spr.visible = true;
        spr.flash = false;
        return;
    };

    var src = SDL.Rect{
        .x = 0,
        .y = 0,
        .w = image.w,
        .h = image.h,
    };

    _ = SDL.blitSurface(image, &src, window.screen, &dest);

    spr.visible = true;
    spr.flash = false;
}

pub fn render_health_bars(level: *lvl.Level) void {
    common.subto0(&globals.BAR_FLAG);
    if (window.screen == null) {
        return;
    }

    const white = SDL.mapSurfaceRGB(window.screen, 255, 255, 255);
    if (globals.BAR_FLAG <= 0) {
        return;
    }
    var offset: u8 = 96;

    //render big bars (4px*16px, spacing 4px)
    for (0..level.player.hp) |_| {
        const dest = SDL.Rect{
            .x = offset,
            .y = 9,
            .w = 4,
            .h = 16,
        };

        _ = SDL.fillSurfaceRect(window.screen, &dest, white);
        offset += 8;
    }

    //render small bars (4px*4px, spacing 4px)
    for (0..@as(usize, globals.MAXIMUM_ENERGY) - level.player.hp) |_| {
        const dest = SDL.Rect{
            .x = offset,
            .y = 15,
            .w = 4,
            .h = 3,
        };
        _ = SDL.fillSurfaceRect(window.screen, &dest, white);
        offset += 8;
    }
}

pub fn fadeout() void {
    const fade_time: c_uint = 1000;

    var rect = SDL.Rect{
        .x = 0,
        .y = 0,
        .w = window.game_width,
        .h = window.game_height,
    };

    const image = SDL.convertSurface(window.screen.?, window.screen.?.format) catch {
        @panic("OOPS");
    };
    defer SDL.destroySurface(image);

    const tick_start = SDL.getTicks();
    var image_alpha: u64 = 0;
    while (image_alpha < 255) //Fade to black
    {
        const input_state = input.processEvents();
        switch (input_state.action) {
            .Quit => {
                // FIXME: handle this better
                return;
            },
            .Escape, .Cancel => {
                return;
            },
            else => {},
        }

        image_alpha = (SDL.getTicks() - tick_start) * 256 / fade_time;

        if (image_alpha > 255) {
            image_alpha = 255;
        }

        _ = SDL.setSurfaceAlphaMod(image, 255 - @as(u8, @truncate(image_alpha)));
        _ = SDL.setSurfaceBlendMode(image, SDL.BLENDMODE_BLEND);
        window.window_clear(null);
        _ = SDL.blitSurface(image, &rect, window.screen, &rect);
        window.window_render();

        SDL.delay(1);
    }
}
