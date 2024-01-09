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
const c = @import("c.zig");
const globals = @import("globals.zig");
const window = @import("window.zig");
const fonts = @import("ui/fonts.zig");

const tick_delay = 29;

pub export fn DISPLAY_TILES(level: *c.TITUS_level) void {
    const src = c.SDL_Rect{
        .x = 0,
        .y = 0,
        .w = 16,
        .h = 16,
    };
    var dest = c.SDL_Rect{
        .x = undefined,
        .y = undefined,
        .w = 16,
        .h = 16,
    };

    var x: i16 = -1;
    while (x < 21) : (x += 1) {
        var y: i16 = -1;
        while (y < 12) : (y += 1) {
            const tileY = @as(usize, @intCast(std.math.clamp(globals.BITMAP_Y + y, 0, level.height - 1)));
            const tileX = @as(usize, @intCast(std.math.clamp(globals.BITMAP_X + x, 0, level.width - 1)));
            dest.x = x * 16 + globals.g_scroll_px_offset;
            dest.y = y * 16 + 8;
            const tile = level.tilemap[tileY][tileX];
            _ = c.SDL_BlitSurface(level.tile[level.tile[tile].animation[globals.tile_anim]].tiledata, &src, window.screen, &dest);
        }
    }
}

pub export fn DISPLAY_SPRITES(level: *c.TITUS_level) void {
    for (0..level.elevatorcount) |i| {
        display_sprite(level, &level.elevator[i].sprite);
    }

    for (0..level.trashcount) |i| {
        display_sprite(level, &level.trash[i]);
    }

    for (0..level.enemycount) |i| {
        display_sprite(level, &level.enemy[i].sprite);
    }

    for (0..level.objectcount) |i| {
        display_sprite(level, &level.object[i].sprite);
    }

    display_sprite(level, &level.player.sprite3);
    display_sprite(level, &level.player.sprite2);
    display_sprite(level, &level.player.sprite);

    if (globals.GODMODE) {
        fonts.text_render("GODMODE", 30 * 8, 0 * 12, true);
    }
    if (globals.NOCLIP) {
        fonts.text_render("NOCLIP", 30 * 8, 1 * 12, true);
    }
}

fn display_sprite(level: *c.TITUS_level, spr: *allowzero c.TITUS_sprite) void {
    if (!spr.enabled) {
        return;
    }
    if (spr.invisible) {
        return;
    }
    spr.visible = false;

    var dest: c.SDL_Rect = undefined;
    if (!spr.flipped) {
        dest.x = spr.x - spr.spritedata.*.refwidth - (globals.BITMAP_X * 16) + globals.g_scroll_px_offset;
    } else {
        dest.x = spr.x + spr.spritedata.*.refwidth - spr.spritedata.*.data.*.w - (globals.BITMAP_X * 16) + globals.g_scroll_px_offset;
    }
    dest.y = spr.y + spr.spritedata.*.refheight - spr.spritedata.*.data.*.h + 1 - (globals.BITMAP_Y * 16) + 8;

    var screen_limit: c_int = globals.screen_width + 2;

    if ((dest.x >= screen_limit * 16) or //Right for the screen
        (dest.x + spr.spritedata.*.data.*.w < 0) or //Left for the screen
        (dest.y + spr.spritedata.*.data.*.h < 0) or //Above the screen
        (dest.y >= globals.screen_height * 16))
    { //Below the screen
        return;
    }

    var image = sprite_from_cache(level, spr);

    var src = c.SDL_Rect{
        .x = 0,
        .y = 0,
        .w = image.w,
        .h = image.h,
    };

    if (dest.x < 0) {
        src.x = 0 - dest.x;
        src.w -= src.x;
        dest.x = 0;
    }
    if (dest.y < 0) {
        src.y = 0 - dest.y;
        src.h -= src.y;
        dest.y = 0;
    }
    if (dest.x + src.w > screen_limit * 16) {
        src.w = screen_limit * 16 - dest.x;
    }
    if (dest.y + src.h > globals.screen_height * 16) {
        src.h = globals.screen_height * 16 - dest.y;
    }

    _ = c.SDL_BlitSurface(image, &src, window.screen, &dest);

    spr.visible = true;
    spr.flash = false;
}

fn sprite_from_cache(level: *c.TITUS_level, spr: *allowzero c.TITUS_sprite) *c.SDL_Surface {
    var cache = level.spritecache;
    var spritedata = level.spritedata[@as(usize, @intCast(spr.number))];

    var spritebuffer: ?*c.TITUS_spritebuffer = null;
    var index: u8 = if (spr.flipped) 1 else 0;

    if (spr.flash) {
        var i: u16 = cache.*.count - cache.*.tmpcount;
        while (i < cache.*.count) : (i += 1) {
            spritebuffer = cache.*.spritebuffer[i];
            if (spritebuffer != null) {
                if ((spritebuffer.?.spritedata == spritedata) and
                    (spritebuffer.?.index == index + 2))
                {
                    return spritebuffer.?.data; //Already in buffer
                }
            }
        }
        //Not found, load into buffer
        cache.*.cycle2 += 1;
        if (cache.*.cycle2 >= cache.*.count) { //The last 3 buffer surfaces is temporary (reserved for flash)
            cache.*.cycle2 = cache.*.count - cache.*.tmpcount;
        }
        spritebuffer = cache.*.spritebuffer[cache.*.cycle2];
        c.SDL_FreeSurface(spritebuffer.?.data); //Free old surface
        spritebuffer.?.data = c.copysurface(spritedata.*.data, spr.flipped, spr.flash);
        spritebuffer.?.spritedata = spritedata;
        spritebuffer.?.index = index + 2;
        return spritebuffer.?.data;
    } else {
        if (spritedata.*.spritebuffer[index] == null) {
            cache.*.cycle += 1;
            if (cache.*.cycle + cache.*.tmpcount >= cache.*.count) { //The last 3 buffer surfaces is temporary (reserved for flash)
                cache.*.cycle = 0;
            }
            spritebuffer = cache.*.spritebuffer[cache.*.cycle];
            if (spritebuffer.?.spritedata != null) {
                spritebuffer.?.spritedata.*.spritebuffer[spritebuffer.?.index] = null; //Remove old link
            }
            c.SDL_FreeSurface(spritebuffer.?.data); //Free old surface
            spritebuffer.?.data = c.copysurface(spritedata.*.data, spr.flipped, spr.flash);
            spritebuffer.?.spritedata = spritedata;
            spritebuffer.?.index = index;
            spritedata.*.spritebuffer[index] = spritebuffer;
        }
        return spritedata.*.spritebuffer[index].*.data;
    }
}
