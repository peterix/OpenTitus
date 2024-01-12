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

// TODO: use a dynamic array for sprites so more sprites can be loaded on top of the base game ones.

const std = @import("std");
const c = @import("c.zig");

// TODO: the sprite cache doesn't have to be global anymore once we aren't passing through C code.
pub var sprite_cache: SpriteCache = undefined;

fn load_sprite(data: []const u8, width: u8, height: u8, offset: usize, pixelformat: *c.SDL_PixelFormat) !*c.SDL_Surface {
    var surface = c.SDL_CreateRGBSurface(c.SDL_SWSURFACE, width, height, pixelformat.BitsPerPixel, pixelformat.Rmask, pixelformat.Gmask, pixelformat.Bmask, pixelformat.Amask);
    if (surface == null) {
        return error.OutOfMemory;
    }
    _ = c.copypixelformat(surface.*.format, pixelformat);

    // TODO: this is duplicated with a few other places that load planar 16 color images
    //       for example, image view and main menu
    //       So, just have a common function...
    const groupsize = ((@as(u16, width) * @as(u16, height)) >> 3);
    var tmpchar = @as([*c]u8, @ptrCast(surface.*.pixels));
    for (offset..offset + groupsize) |i| {
        for (0..8) |j| {
            const jj: u3 = 7 - @as(u3, @truncate(j));
            tmpchar.* = (data[i] >> jj) & 0x01;
            tmpchar.* += (data[i + groupsize] >> jj << 1) & 0x02;
            tmpchar.* += (data[i + groupsize * 2] >> jj << 2) & 0x04;
            tmpchar.* += (data[i + groupsize * 3] >> jj << 3) & 0x08;
            tmpchar += 1;
        }
    }
    return surface;
}

pub fn init(allocator: std.mem.Allocator, sprites: *[c.SPRITECOUNT]c.TITUS_spritedata, spritedata: []const u8, pixelformat: *c.SDL_PixelFormat) !void {
    defer allocator.free(spritedata);
    var offset: usize = 0;
    for (0..c.SPRITECOUNT) |i| {
        sprites[i].data = try load_sprite(spritedata, c.spritewidth[i], c.spriteheight[i], offset, pixelformat);
        sprites[i].collheight = c.spritecollheight[i];
        sprites[i].collwidth = c.spritecollwidth[i];
        sprites[i].refheight = 0 - (@as(i16, c.spriterefheight[i]) - c.spriteheight[i]);
        sprites[i].refwidth = c.spriterefwidth[i];
        offset += (@as(usize, c.spritewidth[i]) * @as(usize, c.spriteheight[i])) >> 1;
    }
}

pub fn deinit(sprites: []c.TITUS_spritedata) void {
    for (sprites) |*sprite| {
        c.SDL_FreeSurface(sprite.data);
    }
}

// TODO: maybe this should be initialized with the desired pixel format instead of reaching out to `window`
pub const SpriteCache = struct {
    pub const Key = struct {
        number: i16,
        flip: bool,
        flash: bool,
    };

    const HashMap = std.AutoArrayHashMap(Key, *c.SDL_Surface);

    allocator: std.mem.Allocator,
    hashmap: HashMap,
    pixelformat: c.SDL_PixelFormatEnum,
    sprites: []c.TITUS_spritedata,

    pub fn init(self: *SpriteCache, sprites: []c.TITUS_spritedata, pixelformat: c.SDL_PixelFormatEnum, allocator: std.mem.Allocator) !void {
        self.allocator = allocator;
        self.hashmap = HashMap.init(allocator);
        self.pixelformat = pixelformat;
        self.sprites = sprites;
    }
    pub fn deinit(self: *SpriteCache) void {
        var iter = self.hashmap.iterator();
        while (iter.next()) |*entry| {
            c.SDL_FreeSurface(entry.value_ptr.*);
        }
        self.hashmap.deinit();
    }

    // Takes the original 16 color surface and gives you a render optimized surface
    // that is flipped the right way and has the flash effect applied.
    fn copysurface(self: *SpriteCache, original: *c.SDL_Surface, flip: bool, flash: bool) !*c.SDL_Surface {
        var surface = c.SDL_ConvertSurface(original, original.format, original.flags);
        if (surface == null)
            return error.FailedToConvertSurface;
        defer c.SDL_FreeSurface(surface);

        _ = c.SDL_SetColorKey(surface, c.SDL_TRUE | c.SDL_RLEACCEL, 0); //Set transparent colour

        const orig_pixels = @as([*]i8, @ptrCast(original.pixels));
        const pitch: usize = @intCast(original.pitch);
        const w: usize = @intCast(original.w);
        const h: usize = @intCast(original.h);

        var dest_pixels = @as([*]i8, @ptrCast(surface.*.pixels));
        if (flip) {
            for (0..pitch) |i| {
                for (0..h) |j| {
                    dest_pixels[j * pitch + i] = orig_pixels[j * pitch + (pitch - i - 1)];
                }
            }
        } else {
            for (0..pitch * h) |i| {
                dest_pixels[i] = orig_pixels[i];
            }
        }

        if (flash) {
            // TODO: add support for other pixel formats
            for (0..w * h) |i| {
                // 0: Transparent
                if (dest_pixels[i] != 0) {
                    dest_pixels[i] = dest_pixels[i] & 0x01;
                }
            }
        }
        var surface2 = c.SDL_ConvertSurfaceFormat(surface, self.pixelformat, 0);
        return (surface2);
    }

    pub fn getSprite(self: *SpriteCache, key: Key) !*c.SDL_Surface {
        var spritedata = &self.sprites[@as(usize, @intCast(key.number))];

        if (self.hashmap.get(key)) |surface| {
            return surface;
        }
        var new_surface = try copysurface(self, spritedata.*.data, key.flip, key.flash);
        try self.hashmap.put(key, new_surface);
        return new_surface;
    }
};
