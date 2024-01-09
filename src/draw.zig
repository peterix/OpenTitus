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

pub export fn draw_tiles(level: *c.TITUS_level) void {
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

pub export fn draw_sprites(level: *c.TITUS_level) void {
    // FIXME: this was for some reason originally drawing from last to first
    // zig makes it a bit harder to do that, so I flipped the order here
    for (0..level.elevatorcount) |i| {
        draw_sprite(level, &level.elevator[i].sprite);
    }

    for (0..level.trashcount) |i| {
        draw_sprite(level, &level.trash[i]);
    }

    for (0..level.enemycount) |i| {
        draw_sprite(level, &level.enemy[i].sprite);
    }

    for (0..level.objectcount) |i| {
        draw_sprite(level, &level.object[i].sprite);
    }

    draw_sprite(level, &level.player.sprite3);
    draw_sprite(level, &level.player.sprite2);
    draw_sprite(level, &level.player.sprite);

    if (globals.GODMODE) {
        fonts.text_render("GODMODE", 30 * 8, 0 * 12, true);
    }
    if (globals.NOCLIP) {
        fonts.text_render("NOCLIP", 30 * 8, 1 * 12, true);
    }
}

fn draw_sprite(level: *c.TITUS_level, spr: *allowzero c.TITUS_sprite) void {
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
        (dest.y >= globals.screen_height * 16)) //Below the screen
    {
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

// FIXME: this should really be in sprites? or in some sprite cache module?
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

pub fn draw_health_bars(level: *c.TITUS_level) void {
    c.subto0(&globals.BAR_FLAG);
    if (window.screen == null) {
        return;
    }

    const white = c.SDL_MapRGB(window.screen.?.format, 255, 255, 255);
    if (globals.BAR_FLAG <= 0) {
        return;
    }
    var offset: u8 = 96;

    //Draw big bars (4px*16px, spacing 4px)
    for (0..level.player.hp) |_| {
        const dest = c.SDL_Rect{
            .x = offset,
            .y = 9,
            .w = 4,
            .h = 16,
        };

        _ = c.SDL_FillRect(window.screen, &dest, white);
        offset += 8;
    }

    //Draw small bars (4px*4px, spacing 4px)
    for (0..@as(usize, c.MAXIMUM_ENERGY) - level.player.hp) |_| {
        const dest = c.SDL_Rect{
            .x = offset,
            .y = 15,
            .w = 4,
            .h = 3,
        };
        _ = c.SDL_FillRect(window.screen, &dest, white);
        offset += 8;
    }
}

pub fn fadeout() void {
    const fade_time: c_uint = 1000;

    var rect = c.SDL_Rect{
        .x = 0,
        .y = 0,
        .w = window.game_width,
        .h = window.game_height,
    };

    var image = c.SDL_ConvertSurface(window.screen, window.screen.?.format, c.SDL_SWSURFACE);
    defer c.SDL_FreeSurface(image);

    var tick_start = c.SDL_GetTicks();
    var image_alpha: c_uint = 0;
    while (image_alpha < 255) //Fade to black
    {
        var event: c.SDL_Event = undefined;
        if (c.SDL_PollEvent(&event) == 0) {
            if (event.type == c.SDL_QUIT) {
                // FIXME: handle this better
                return;
            }

            if (event.type == c.SDL_KEYDOWN) {
                if (event.key.keysym.scancode == c.SDL_SCANCODE_ESCAPE) {
                    // FIXME: handle this better
                    return;
                }
                if (event.key.keysym.scancode == c.KEY_FULLSCREEN) {
                    window.window_toggle_fullscreen();
                }
            }
        }

        image_alpha = (c.SDL_GetTicks() - tick_start) * 256 / fade_time;

        if (image_alpha > 255) {
            image_alpha = 255;
        }

        _ = c.SDL_SetSurfaceAlphaMod(image, 255 - @as(u8, @truncate(image_alpha)));
        _ = c.SDL_SetSurfaceBlendMode(image, c.SDL_BLENDMODE_BLEND);
        window.window_clear(null);
        _ = c.SDL_BlitSurface(image, &rect, window.screen, &rect);
        window.window_render();

        c.SDL_Delay(1);
    }
}
