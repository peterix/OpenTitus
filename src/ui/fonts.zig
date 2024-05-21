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

const c = @import("../c.zig");

const window = @import("../window.zig");
const globals = @import("../globals.zig");

const Character = struct {
    x: u16 = 0,
    x_mono: u16 = 0,
    y: u16 = 0,
    w: u16 = 0,
    w_mono: u16 = 0,
    h: u16 = 0,
    x_offset: i8 = 0,
};

pub const Font = struct {
    sheet: *c.SDL_Surface,
    characters: [256]Character,
    fallback: Character,

    fn init(self: *Font, data: []const u8) !void {
        const rwops = c.SDL_RWFromMem(@constCast(@ptrCast(&data[0])), @intCast(data.len));
        if (rwops == null) {
            print_sdl_error("Could not load font: {s}");
            return FontError.CannotLoad;
        }
        const image = c.SDL_LoadBMP_RW(rwops, c.SDL_TRUE);
        if (image == null) {
            print_sdl_error("Could not load font: {s}");
            return FontError.CannotLoad;
        }
        try loadfont(image, self);
    }
    fn deinit(self: *Font) void {
        c.SDL_FreeSurface(self.sheet);
    }

    pub const RenderOptions = packed struct {
        monospace: bool = false,
        transpatent: bool = false,
    };

    pub fn render_columns(self: *Font, left: []const u8, right: []const u8, y: c_int, options: RenderOptions) void {
        const margin = 5 * 8;
        const width_right = metrics(self, right, options);

        render(self, left, margin, y, options);
        render(self, right, 320 - margin - width_right, y, options);
    }

    pub fn render_center(self: *Font, text: []const u8, y: c_int, options: RenderOptions) void {
        const width = metrics(self, text, options);
        const x = 160 - width / 2;
        render(self, text, x, y, options);
    }

    pub fn render(self: *Font, text: []const u8, x: c_int, y: c_int, options: RenderOptions) void {
        var dest: c.SDL_Rect = .{ .x = x, .y = y, .w = 0, .h = 0 };

        _ = c.SDL_SetColorKey(self.sheet, if (options.transpatent) c.SDL_TRUE else c.SDL_FALSE, c.SDL_MapRGB(self.sheet.*.format, 0, 0, 0));

        // Let's assume ASCII for now... original code was trying to do something with UTF-8, but had the font files have no support for that
        for (text) |character| {
            const chardesc = self.characters[character];
            if (options.monospace) {
                var src = c.SDL_Rect{ .x = chardesc.x_mono, .y = chardesc.y, .w = chardesc.w_mono, .h = chardesc.h };
                dest.w = chardesc.w_mono;
                dest.h = chardesc.h;
                _ = c.SDL_BlitSurface(self.sheet, &src, window.screen, &dest);
                dest.x += chardesc.w_mono;
            } else {
                dest.x += chardesc.x_offset;
                var src = c.SDL_Rect{ .x = chardesc.x, .y = chardesc.y, .w = chardesc.w, .h = chardesc.h };
                dest.w = chardesc.w;
                dest.h = chardesc.h;
                _ = c.SDL_BlitSurface(self.sheet, &src, window.screen, &dest);
                dest.x += chardesc.w;
            }
        }
    }

    pub fn metrics(self: *Font, text: []const u8, options: RenderOptions) u16 {
        var size: i17 = 0;

        // Let's assume ASCII for now... original code was trying to do something with UTF-8, but had the font files have no support for that
        for (text) |character| {
            const chardesc = self.characters[character];
            if (options.monospace) {
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
};

const gold_font_data = @embedFile("gold_font.bmp");
pub var Gold: Font = undefined;

const gray_font_data = @embedFile("gray_font.bmp");
pub var Gray: Font = undefined;

pub fn fonts_load() !void {
    try Gold.init(gold_font_data);
    try Gray.init(gray_font_data);
}

pub fn fonts_free() void {
    Gold.deinit();
    Gray.deinit();
}

const CHAR_QUESTION = 63;

const FontError = error{
    CannotLoad,
    NotDivisibleBy16,
};

fn print_sdl_error(comptime format: []const u8) void {
    var buffer: [1024:0]u8 = undefined;
    const errstr = c.SDL_GetErrorMsg(&buffer, 1024);
    const span = std.mem.span(errstr);
    std.log.err(format, .{span});
}

fn loadfont(image: *c.SDL_Surface, font: *Font) !void {
    defer c.SDL_FreeSurface(image);

    const surface_w = @as(u16, @intCast(image.*.w));
    if (@rem(surface_w, 16) != 0) {
        std.log.err("Font width is not divisible by 16.", .{});
        return FontError.NotDivisibleBy16;
    }

    const surface_h = @as(u16, @intCast(image.*.h));
    if (@rem(surface_h, 16) != 0) {
        std.log.err("Font height is not divisible by 16.", .{});
        return FontError.NotDivisibleBy16;
    }

    const sheet = c.SDL_ConvertSurfaceFormat(image, c.SDL_GetWindowPixelFormat(window.window), 0);
    if (sheet == null) {
        print_sdl_error("Cannot convert font surface: {s}");
        return FontError.CannotLoad;
    }

    font.*.fallback = font.*.characters[CHAR_QUESTION];
    font.*.sheet = sheet;

    const character_w = @divTrunc(surface_w, 16);
    const character_h = @divTrunc(surface_h, 16);

    for (0..16) |y| {
        for (0..16) |x| {
            const xx = x * character_w;
            const yy = y * character_h;
            const character: u8 = @as(u8, @truncate(y)) * 16 + @as(u8, @truncate(x));
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
}
