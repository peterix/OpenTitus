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
const SDL = @import("SDL.zig");
const image = @import("ui/image.zig");
const window = @import("window.zig");
const data = @import("data.zig");

// TODO: the sprite cache and sprites doesn't have to be global anymore once we aren't going through C code.
pub var sprite_cache: SpriteCache = undefined;
pub var sprites: SpriteData = undefined;

const SPRITECOUNT = 356;

const SpriteDefinition = extern struct {
    height: u8,
    width: u8,
    collheight: u8,
    collwidth: u8,
    refheight: u8,
    refwidth: u8,
};

fn load_sprite_defs(input: []const u8) ![SPRITECOUNT]SpriteDefinition {
    @setEvalBranchQuota(100000);
    var output: [SPRITECOUNT]SpriteDefinition = undefined;
    var lineIterator = std.mem.tokenizeScalar(u8, input, '\n');
    var index: usize = 0;

    // skip header, we don't use it.
    _ = lineIterator.next();

    while (lineIterator.next()) |line| {
        var entry = &output[index];
        var fieldIterator = std.mem.tokenizeScalar(u8, line, ',');
        entry.width = try std.fmt.parseInt(u8, fieldIterator.next().?, 10);
        entry.height = try std.fmt.parseInt(u8, fieldIterator.next().?, 10);
        entry.collwidth = try std.fmt.parseInt(u8, fieldIterator.next().?, 10);
        entry.collheight = try std.fmt.parseInt(u8, fieldIterator.next().?, 10);
        entry.refwidth = try std.fmt.parseInt(u8, fieldIterator.next().?, 10);
        entry.refheight = try std.fmt.parseInt(u8, fieldIterator.next().?, 10);
        index += 1;
    }
    const final = output[0..output.len].*;
    return final;
}

const titus_sprite_defs: [SPRITECOUNT]SpriteDefinition = load_sprite_defs(@embedFile("sprites_titus.csv")) catch {
    unreachable;
};
const moktar_sprite_defs: [SPRITECOUNT]SpriteDefinition = load_sprite_defs(@embedFile("sprites_moktar.csv")) catch {
    unreachable;
};

pub const SpriteData = struct {
    definitions: []const SpriteDefinition,
    bitmaps: [SPRITECOUNT]*c.SDL_Surface,

    fn init(self: *SpriteData, allocator: std.mem.Allocator, spritedata: []const u8, pixelformat: *c.SDL_PixelFormat) !void {
        defer allocator.free(spritedata);

        if (data.game == c.Titus) {
            self.definitions = &titus_sprite_defs;
        } else {
            self.definitions = &moktar_sprite_defs;
        }
        var remaining_data = spritedata;
        for (0..SPRITECOUNT) |i| {
            const surface = SDL.createRGBSurface(
                c.SDL_SWSURFACE,
                self.definitions[i].width,
                self.definitions[i].height,
                pixelformat.BitsPerPixel,
                pixelformat.Rmask,
                pixelformat.Gmask,
                pixelformat.Bmask,
                pixelformat.Amask,
            );
            if (surface == null) {
                return error.OutOfMemory;
            }
            _ = copypixelformat(surface.*.format, pixelformat);
            remaining_data = try image.load_planar_16color(remaining_data, self.definitions[i].width, self.definitions[i].height, surface);
            self.bitmaps[i] = surface;
        }
    }
    fn deinit(self: *SpriteData) void {
        for (self.bitmaps) |ptr| {
            SDL.freeSurface(ptr);
        }
    }

    pub fn setPixelFormat(self: *SpriteData, pixelformat: *c.SDL_PixelFormat) void {
        for (0..SPRITECOUNT) |i| {
            copypixelformat(self.bitmaps[i].format, pixelformat);
        }
    }
};

pub fn init(allocator: std.mem.Allocator, spritedata: []const u8, pixelformat: *c.SDL_PixelFormat) !void {
    try sprites.init(allocator, spritedata, pixelformat);
}

pub fn deinit() void {
    sprites.deinit();
}

// FIXME: maybe we can have one big tile map surface just like we have one big font surface
pub fn load_tile(data_slice: []const u8, pixelformat: *c.SDL_PixelFormat) !*c.SDL_Surface {
    const width = 16;
    const height = 16;
    const surface = SDL.createRGBSurface(c.SDL_SWSURFACE, width, height, 8, 0, 0, 0, 0);
    if (surface == null) {
        return error.OutOfMemory;
    }
    defer SDL.freeSurface(surface);

    copypixelformat(surface.*.format, pixelformat);
    _ = try image.load_planar_16color(data_slice, width, height, surface);
    const surface2 = SDL.convertSurfaceFormat(surface, c.SDL_GetWindowPixelFormat(window.window), 0);
    if (surface2 == 0) {
        return error.OutOfMemory;
    }
    return (surface2);
}

fn copypixelformat(destformat: *c.SDL_PixelFormat, srcformat: *c.SDL_PixelFormat) void {
    if (srcformat.palette != null) {
        destformat.palette.*.ncolors = srcformat.palette.*.ncolors;
        for (0..@intCast(destformat.palette.*.ncolors)) |i| {
            destformat.palette.*.colors[i].r = srcformat.palette.*.colors[i].r;
            destformat.palette.*.colors[i].g = srcformat.palette.*.colors[i].g;
            destformat.palette.*.colors[i].b = srcformat.palette.*.colors[i].b;
        }
    }

    destformat.BitsPerPixel = srcformat.BitsPerPixel;
    destformat.BytesPerPixel = srcformat.BytesPerPixel;

    destformat.Rloss = srcformat.Rloss;
    destformat.Gloss = srcformat.Gloss;
    destformat.Bloss = srcformat.Bloss;
    destformat.Aloss = srcformat.Aloss;

    destformat.Rshift = srcformat.Rshift;
    destformat.Gshift = srcformat.Gshift;
    destformat.Bshift = srcformat.Bshift;
    destformat.Ashift = srcformat.Ashift;

    destformat.Rmask = srcformat.Rmask;
    destformat.Gmask = srcformat.Gmask;
    destformat.Bmask = srcformat.Bmask;
    destformat.Amask = srcformat.Amask;
}

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

    pub fn init(
        self: *SpriteCache,
        pixelformat: c.SDL_PixelFormatEnum,
        allocator: std.mem.Allocator,
    ) !void {
        self.allocator = allocator;
        self.hashmap = HashMap.init(allocator);
        self.pixelformat = pixelformat;
    }

    pub fn deinit(self: *SpriteCache) void {
        evictAll(self);
        self.hashmap.deinit();
    }

    // Takes the original 16 color surface and gives you a render optimized surface
    // that is flipped the right way and has the flash effect applied.
    fn copysurface(self: *SpriteCache, original: *c.SDL_Surface, flip: bool, flash: bool) !*c.SDL_Surface {
        const surface = SDL.convertSurface(original, original.format, original.flags);
        if (surface == null)
            return error.FailedToConvertSurface;
        defer SDL.freeSurface(surface);

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
        const surface2 = SDL.convertSurfaceFormat(surface, self.pixelformat, 0);
        return (surface2);
    }

    pub fn getSprite(self: *SpriteCache, key: Key) !*c.SDL_Surface {
        const spritedata = sprites.bitmaps[@as(usize, @intCast(key.number))];

        if (self.hashmap.get(key)) |surface| {
            return surface;
        }
        const new_surface = try copysurface(self, spritedata, key.flip, key.flash);
        try self.hashmap.put(key, new_surface);
        return new_surface;
    }

    pub fn evictAll(self: *SpriteCache) void {
        var index: u32 = 0;
        var iter = self.hashmap.iterator();
        while (iter.next()) |*entry| {
            SDL.freeSurface(entry.value_ptr.*);
            index += 1;
        }
        self.hashmap.clearAndFree();
    }
};

pub export fn updatesprite(level: *c.TITUS_level, spr: *c.TITUS_sprite, number: i16, clearflags: bool) void {
    spr.number = number;
    spr.spritedata = &level.spritedata[@intCast(number)];
    spr.enabled = true;
    if (clearflags) {
        spr.flipped = false;
        spr.flash = false;
        spr.visible = false;
        spr.droptobottom = false;
        spr.killing = false;
    }
    spr.invisible = false;
}

pub export fn copysprite(level: *c.TITUS_level, dest: *c.TITUS_sprite, src: *c.TITUS_sprite) void {
    dest.number = src.number;
    dest.spritedata = &level.spritedata[@intCast(src.number)];
    dest.enabled = src.enabled;
    dest.flipped = src.flipped;
    dest.flash = src.flash;
    dest.visible = src.visible;
    dest.invisible = false;
}

fn animate_sprite(level: *c.TITUS_level, spr: *c.TITUS_sprite) void {
    if (!spr.visible) return; //Not on screen?
    if (!spr.enabled) return;
    if (spr.number == (c.FIRST_OBJET + 26)) { //Cage
        if ((c.IMAGE_COUNTER & 0x0007) == 0) { //Every 8
            updatesprite(level, spr, c.FIRST_OBJET + 27, false); //Cage, 2nd sprite
        }
    } else if (spr.number == (c.FIRST_OBJET + 27)) { //Cage, 2nd sprite
        if ((c.IMAGE_COUNTER & 0x003F) == 0) { //Every 64
            updatesprite(level, spr, c.FIRST_OBJET + 26, false); //Cage, 1st sprite
        }
    } else if (spr.number == (c.FIRST_OBJET + 21)) { //Flying carpet
        if ((c.IMAGE_COUNTER & 0x0007) == 0) { //Every 8
            updatesprite(level, spr, c.FIRST_OBJET + 22, false); //Flying carpet, 2nd sprite
        }
    } else if (spr.number == (c.FIRST_OBJET + 22)) { //Flying carpet, 2nd sprite
        if ((c.IMAGE_COUNTER & 0x0007) == 0) { //Every 8
            updatesprite(level, spr, c.FIRST_OBJET + 21, false); //Flying carpet, 1st sprite
        }
    } else if (spr.number == (c.FIRST_OBJET + 24)) { //Small spring
        if ((c.IMAGE_COUNTER & 0x0001) == 0) { //Every 2
            if (spr.UNDER == 0) { //Spring is not loaded
                updatesprite(level, spr, c.FIRST_OBJET + 25, false); //Spring is not loaded; convert into big spring
            } else if (c.GRAVITY_FLAG > 1) { //if not gravity, not clear
                spr.UNDER = 0;
            } else {
                spr.UNDER = spr.UNDER & 0x01; //Keep eventually object load, remove player load
            }
        }
    } else if (spr.number == (c.FIRST_OBJET + 25)) { //Big spring
        if ((c.IMAGE_COUNTER & 0x0001) == 0) { //Every 2
            if (spr.UNDER == 0) {
                return; //Spring is not loaded; remain big
            } else if (c.GRAVITY_FLAG > 1) { //if not gravity, not clear
                spr.UNDER = 0;
            } else {
                spr.UNDER = spr.UNDER & 0x01; //Keep eventually object load, remove player load
            }
            // FIXME: maybe null sanity check in debug mode
            spr.ONTOP.*.y += 5;
            c.GRAVITY_FLAG = 3;
            updatesprite(level, spr, c.FIRST_OBJET + 24, false); //Small spring
        }
    }
}

pub fn animateSprites(level: *c.TITUS_level) void {
    //Animate player
    if ((c.LAST_ORDER == 0) and
        (c.POCKET_FLAG) and
        (c.ACTION_TIMER >= 35 * 4))
    {
        updatesprite(level, &(level.player.sprite), 29, false); //"Pause"-sprite
        if (c.ACTION_TIMER >= 35 * 5) {
            updatesprite(level, &(level.player.sprite), 0, false); //Normal player sprite
            c.ACTION_TIMER = 0;
        }
    }
    //Animate other objects

    animate_sprite(level, &(level.player.sprite2));
    animate_sprite(level, &(level.player.sprite3));

    for (0..c.OBJECT_CAPACITY) |i| {
        animate_sprite(level, &(level.object[i].sprite));
    }

    for (0..c.ENEMY_CAPACITY) |i| {
        animate_sprite(level, &(level.enemy[i].sprite));
    }

    for (0..c.ELEVATOR_CAPACITY) |i| {
        animate_sprite(level, &(level.elevator[i].sprite));
    }
}
