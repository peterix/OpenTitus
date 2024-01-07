//
// Copyright (C) 2008 - 2011 The OpenTitus team
//
// Authors:
// Eirik Stople
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

// fonts.zig
// Font functions
//

const std = @import("std");

const c = @import("c.zig");

const window = @import("window.zig");
const globals = @import("globals.zig");

const Character = struct {
    x: u16,
    x_mono: u16,
    y: u16,
    w: u16,
    w_mono: u16,
    h: u16,
    x_offset: i8,
};

const Font = struct {
    sheet: [*c]c.SDL_Surface,
    characters: [256]Character,
    fallback: Character,
};

const yellow_font_data = @embedFile("../assets/yellow_font.bmp");
var yellow_font: Font = undefined;
const CHAR_QUESTION = 63;

const FontError = error{
    CannotLoad,
    NotDivisibleBy16,
};

fn loadfont(image: [*c]c.SDL_Surface, font: *Font) !void {
    defer c.SDL_FreeSurface(image);

    var surface_w = @as(u16, @intCast(image.*.w));
    var surface_h = @as(u16, @intCast(image.*.h));
    if (@rem(surface_w, 16) != 0) {
        return FontError.NotDivisibleBy16;
    }
    if (@rem(surface_h, 16) != 0) {
        return FontError.NotDivisibleBy16;
    }

    var character_w = @divTrunc(surface_w, 16);
    var character_h = @divTrunc(surface_h, 16);

    for (0..16) |y| {
        for (0..16) |x| {
            var xx = x * character_w;
            var yy = y * character_h;
            var character: u8 = @as(u8, @truncate(y)) * 16 + @as(u8, @truncate(x));
            var chardesc = &font.characters[character];
            // FIXME: read the pixels, use a special color to use the font file as a source of this information
            chardesc.x_mono = @truncate(xx);
            chardesc.w_mono = @truncate(character_w);
            chardesc.x_offset = 0;
            switch (character) {
                '1', ' ', '`' => {
                    chardesc.x = @truncate(xx + 1);
                    chardesc.y = @truncate(yy);
                    chardesc.w = @truncate(character_w - 3);
                    chardesc.h = @truncate(character_h);
                },
                '\'' => {
                    chardesc.x = @truncate(xx);
                    chardesc.y = @truncate(yy);
                    chardesc.w = @truncate(character_w - 3);
                    chardesc.h = @truncate(character_h);
                },
                ',' => {
                    chardesc.x = @truncate(xx);
                    chardesc.y = @truncate(yy);
                    chardesc.w = @truncate(character_w - 2);
                    chardesc.h = @truncate(character_h);
                },
                'I', '!', '|' => {
                    chardesc.x = @truncate(xx + 2);
                    chardesc.y = @truncate(yy);
                    chardesc.w = @truncate(character_w - 4);
                    chardesc.h = @truncate(character_h);
                },
                'J', '.' => {
                    chardesc.x = @truncate(xx);
                    chardesc.y = @truncate(yy);
                    chardesc.w = @truncate(character_w - 2);
                    chardesc.h = @truncate(character_h);
                },
                'C', 'c', 'E', 'e', 'F', 'f', 'i', 'j', 'l', 'L', 'n', 'o', 's', 't', 'v', 'z', '{', '}', '%', '(', ')' => {
                    chardesc.x = @truncate(xx);
                    chardesc.y = @truncate(yy);
                    chardesc.w = @truncate(character_w - 1);
                    chardesc.h = @truncate(character_h);
                },
                '[', ']' => {
                    chardesc.x = @truncate(xx + 1);
                    chardesc.y = @truncate(yy);
                    chardesc.w = @truncate(character_w - 2);
                    chardesc.h = @truncate(character_h);
                },
                'y' => {
                    chardesc.x = @truncate(xx);
                    chardesc.y = @truncate(yy);
                    chardesc.w = @truncate(character_w);
                    chardesc.h = @truncate(character_h);
                    chardesc.x_offset = -1;
                },
                else => {
                    chardesc.x = @truncate(xx);
                    chardesc.y = @truncate(yy);
                    chardesc.w = @truncate(character_w);
                    chardesc.h = @truncate(character_h);
                },
            }
        }
    }
    font.*.fallback = font.*.characters[CHAR_QUESTION];
    font.*.sheet = c.SDL_ConvertSurfaceFormat(image, c.SDL_GetWindowPixelFormat(window.window), 0);

    // TODO: good font with transparency...

    // _ = c.SDL_SetColorKey(font.*.sheet, c.SDL_TRUE, c.SDL_MapRGB(font.*.sheet.*.format, 0, 0, 0));
}

fn freefont(font: *Font) void {
    c.SDL_FreeSurface(font.*.sheet);
    font.*.sheet = null;
}

pub export fn fonts_load() c_int {
    var rwops = c.SDL_RWFromMem(@constCast(@ptrCast(&yellow_font_data[0])), yellow_font_data.len);
    var image = c.SDL_LoadBMP_RW(rwops, c.SDL_TRUE);
    loadfont(image, &yellow_font) catch {
        return -1;
    };
    return 0;
}

pub export fn fonts_free() void {
    freefont(&yellow_font);
}

pub export fn text_render(text: [*c]const u8, x: c_int, y: c_int, monospace: bool) void {
    var dest: c.SDL_Rect = .{ .x = x + 16 - globals.g_scroll_px_offset, .y = y, .w = 0, .h = 0 };

    // Let's assume ASCII for now... original code was trying to do something with UTF-8, but had the font files have no support for that
    var index: usize = 0;
    while (text[index] != 0) : (index += 1) {
        var character = text[index];
        var chardesc = yellow_font.characters[character];
        if (monospace) {
            var src = c.SDL_Rect{ .x = chardesc.x_mono, .y = chardesc.y, .w = chardesc.w_mono, .h = chardesc.h };
            dest.w = chardesc.w_mono;
            dest.h = chardesc.h;
            _ = c.SDL_BlitSurface(yellow_font.sheet, &src, window.screen, &dest);
            dest.x += chardesc.w_mono;
        } else {
            dest.x += chardesc.x_offset;
            var src = c.SDL_Rect{ .x = chardesc.x, .y = chardesc.y, .w = chardesc.w, .h = chardesc.h };
            dest.w = chardesc.w;
            dest.h = chardesc.h;
            _ = c.SDL_BlitSurface(yellow_font.sheet, &src, window.screen, &dest);
            dest.x += chardesc.w;
        }
    }
}

pub export fn text_width(text: [*c]const u8, monospace: bool) u16 {
    var size: i17 = 0;

    // Let's assume ASCII for now... original code was trying to do something with UTF-8, but had the font files have no support for that
    var index: usize = 0;
    while (text[index] != 0) : (index += 1) {
        var character = text[index];
        var chardesc = yellow_font.characters[character];
        if (monospace) {
            size += chardesc.w_mono;
        } else {
            size += chardesc.x_offset;
            size += chardesc.w;
        }
    }
    if (size > 0) {
        return @intCast(size);
    }
    return 0;
}
