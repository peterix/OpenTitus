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

const Character = struct {
    x: u16,
    y: u16,
    w: u16,
    h: u16,
};

const Font = struct {
    sheet: [*c]c.SDL_Surface,
    characters: [256]Character,
    fallback: Character,
};

// TODO: handle errors
// TODO: embed the assets in the binary...
// TODO: shave pixels off some characters so they can be used in menus
// TODO: add a 'character' for menu bullet
// TODO: maybe load the font from the original SQZ file again?
var yellow_font: Font = undefined;
const CHAR_QUESTION = 63;

const FontError = error{
    CannotLoad,
    NotDivisibleBy16,
};

fn loadfont(fontfile: [*c]const u8, font: *Font) !void {
    var image = c.SDL_LoadBMP(fontfile);
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
            var character = &font.characters[y * 16 + x];
            character.x = @truncate(xx);
            character.y = @truncate(yy);
            character.w = @truncate(character_w);
            character.h = @truncate(character_h);
        }
    }
    font.*.fallback = font.*.characters[CHAR_QUESTION];
    font.*.sheet = c.SDL_ConvertSurfaceFormat(image, c.SDL_GetWindowPixelFormat(window.window), 0);
}

fn freefont(font: *Font) void {
    c.SDL_FreeSurface(font.*.sheet);
    font.*.sheet = null;
}

pub export fn fonts_load() c_int {
    loadfont("FONT.BMP", &yellow_font) catch {
        return -1;
    };
    return 0;
}

pub export fn fonts_free() void {
    freefont(&yellow_font);
}

pub export fn SDL_Print_Text(text: [*c]const u8, x: c_int, y: c_int) void {
    var dest: c.SDL_Rect = .{ .x = x + 16, .y = y, .w = 0, .h = 0 };

    // Let's assume ASCII for now... original code was trying to do something with UTF-8, but had the font files have no support for that
    var index: usize = 0;
    while (text[index] != 0) : ({
        index += 1;
        dest.x += 8;
    }) {
        var character = text[index];
        var chardesc = yellow_font.characters[character];
        var src = c.SDL_Rect{ .x = chardesc.x, .y = chardesc.y, .w = chardesc.w, .h = chardesc.h };
        dest.w = chardesc.w;
        dest.h = chardesc.h;
        _ = c.SDL_BlitSurface(yellow_font.sheet, &src, window.screen, &dest);
    }
}
