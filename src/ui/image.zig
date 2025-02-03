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

const sqz = @import("../sqz.zig");
const c = @import("../c.zig");
const SDL = @import("../SDL.zig");

pub const ManagedSurface = struct {
    value: [*c]c.SDL_Surface,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        if (self.value != null) {
            SDL.freeSurface(self.value);
        }
    }

    pub fn dump(self: *Self, filename: [:0]const u8) !void {
        if (c.SDL_SaveBMP(self.value, &filename[0]) != 0) {
            return error.DumpError;
        }
    }
};

const EGAColor = packed struct {
    redL: u1 = 0,
    greenL: u1 = 0,
    blueL: u1 = 0,
    redH: u1 = 0,
    greenH: u1 = 0,
    blueH: u1 = 0,
};

const EGA: [16]EGAColor = .{
    .{},
    .{ .blueH = 1 },
    .{ .greenH = 1 },
    .{ .greenH = 1, .blueH = 1 },
    .{ .redH = 1 },
    .{ .redH = 1, .blueH = 1 },
    .{ .greenL = 1, .redH = 1 },
    .{ .redH = 1, .greenH = 1, .blueH = 1 },
    .{ .redL = 1, .greenL = 1, .blueL = 1 },
    .{ .redL = 1, .greenL = 1, .blueL = 1, .blueH = 1 },
    .{ .redL = 1, .greenL = 1, .blueL = 1, .greenH = 1 },
    .{ .redL = 1, .greenL = 1, .blueL = 1, .greenH = 1, .blueH = 1 },
    .{ .redL = 1, .greenL = 1, .blueL = 1, .redH = 1 },
    .{ .redL = 1, .greenL = 1, .blueL = 1, .redH = 1, .blueH = 1 },
    .{ .redL = 1, .greenL = 1, .blueL = 1, .redH = 1, .greenH = 1 },
    .{ .redL = 1, .greenL = 1, .blueL = 1, .redH = 1, .greenH = 1, .blueH = 1 },
};

pub const ImageFormat = enum(c_int) {
    PlanarGreyscale16 = 0,
    PlanarEGA16 = 1,
    LinearPalette256 = 2,
};

pub const ImageFile = struct {
    filename: []const u8,
    format: ImageFormat,
};

pub fn load_planar_16color(data: []const u8, width: u16, height: u16, surface: *c.SDL_Surface) ![]const u8 {
    const groupsize = ((@as(u16, width) * @as(u16, height)) >> 3);
    if (data.len < groupsize * 4) {
        return error.NotEnoughData;
    }
    var tmpchar = @as([*c]u8, @ptrCast(surface.*.pixels));
    for (0..groupsize) |i| {
        for (0..8) |j| {
            const jj: u3 = 7 - @as(u3, @truncate(j));
            tmpchar.* = (data[i] >> jj) & 0x01;
            tmpchar.* += (data[i + groupsize] >> jj << 1) & 0x02;
            tmpchar.* += (data[i + groupsize * 2] >> jj << 2) & 0x04;
            tmpchar.* += (data[i + groupsize * 3] >> jj << 3) & 0x08;
            tmpchar += 1;
        }
    }
    return data[groupsize * 4 ..];
}

/// `data` is consumed - deallocated using the supplied `allocator`
///
/// Example use:
///
///     var menudata = try sqz.unSQZ(menufile, allocator);
///     var image_memory = try image.loadImage(menudata, format, allocator);
///     defer image_memory.deinit();
pub fn loadImage(data: []const u8, format: ImageFormat, allocator: std.mem.Allocator) !ManagedSurface {
    defer allocator.free(data);

    // FIXME: handle this returning null
    const surface = SDL.createRGBSurface(c.SDL_SWSURFACE, 320, 200, 8, 0, 0, 0, 0);
    defer SDL.freeSurface(surface);
    // FIXME: handle palette being null
    const palette = surface.*.format.*.palette;

    switch (format) {
        .PlanarGreyscale16 => {
            for (0..16) |i| {
                palette.*.colors[i].r = @truncate(i * 16);
                palette.*.colors[i].g = @truncate(i * 16);
                palette.*.colors[i].b = @truncate(i * 16);
            }
            palette.*.ncolors = 16;
            _ = try load_planar_16color(data, 320, 200, surface);
        },

        .PlanarEGA16 => {
            for (0..16) |i| {
                const ega = EGA[i];
                palette.*.colors[i].r = 85 * @as(u8, ega.redL) + 170 * @as(u8, ega.redH);
                palette.*.colors[i].g = 85 * @as(u8, ega.greenL) + 170 * @as(u8, ega.greenH);
                palette.*.colors[i].b = 85 * @as(u8, ega.blueL) + 170 * @as(u8, ega.blueH);
            }
            palette.*.ncolors = 16;

            _ = try load_planar_16color(data, 320, 200, surface);
        },

        .LinearPalette256 => {
            for (0..256) |i| {
                palette.*.colors[i].r = (data[i * 3]) * 4;
                palette.*.colors[i].g = (data[i * 3 + 1]) * 4;
                palette.*.colors[i].b = (data[i * 3 + 2]) * 4;
            }
            palette.*.ncolors = 256;

            const slice_out = @as([*]u8, @ptrCast(surface.*.pixels))[0 .. 320 * 200];
            const slice_in = data[256 * 3 .. 256 * 3 + 320 * 200];
            @memcpy(slice_out, slice_in);
        },
    }
    const result = SDL.convertSurfaceFormat(surface, c.SDL_GetWindowPixelFormat(c.window), 0);
    if (result == null) {
        return error.CannotConvertSurface;
    }
    return ManagedSurface{ .value = result };
}

pub const DisplayMode = enum(c_int) {
    FadeInFadeOut = 0,
    FadeOut = 1,
};

const window = @import("../window.zig");
const keyboard = @import("keyboard.zig");

pub fn viewImageFile(file: ImageFile, display_mode: DisplayMode, delay: c_int, allocator: std.mem.Allocator) !c_int {
    const fade_time: c_uint = 1000;

    const image_data = try sqz.unSQZ(file.filename, allocator);
    var image_memory = try loadImage(image_data, file.format, allocator);
    defer image_memory.deinit();
    const image_surface = image_memory.value;
    var src = c.SDL_Rect{
        .x = 0,
        .y = 0,
        .w = image_surface.*.w,
        .h = image_surface.*.h,
    };

    var dest = c.SDL_Rect{
        .x = 0,
        .y = 0,
        .w = image_surface.*.w,
        .h = image_surface.*.h,
    };
    switch (display_mode) {
        .FadeInFadeOut => {
            var tick_start = c.SDL_GetTicks();
            var image_alpha: c_uint = 0;
            var activedelay = true;
            var fadeoutskip: c_uint = 0;
            while ((image_alpha < 255) and activedelay) //Fade to visible
            {
                var event: c.SDL_Event = undefined;
                if (c.SDL_PollEvent(&event) != 0) {
                    if (event.type == c.SDL_QUIT) {
                        return (-1);
                    }

                    if (event.type == c.SDL_KEYDOWN) {
                        if (event.key.keysym.scancode == c.SDL_SCANCODE_RETURN or
                            event.key.keysym.scancode == c.SDL_SCANCODE_KP_ENTER or
                            event.key.keysym.scancode == c.SDL_SCANCODE_SPACE or
                            event.key.keysym.scancode == c.SDL_SCANCODE_ESCAPE)
                        {
                            activedelay = false;
                            fadeoutskip = 255 - image_alpha;
                        }

                        if (event.key.keysym.scancode == c.SDL_SCANCODE_F11) {
                            window.toggle_fullscreen();
                        }
                    }
                }

                image_alpha = (SDL.getTicks() - tick_start) * 256 / fade_time;

                if (image_alpha > 255)
                    image_alpha = 255;

                _ = c.SDL_SetSurfaceAlphaMod(image_surface, @truncate(image_alpha));
                _ = c.SDL_SetSurfaceBlendMode(image_surface, c.SDL_BLENDMODE_BLEND);
                window.window_clear(null);
                _ = c.SDL_BlitSurface(image_surface, &src, c.screen, &dest);
                window.window_render();
                SDL.delay(1);
            }

            while (activedelay) //Visible delay
            {
                var event: c.SDL_Event = undefined;
                if (c.SDL_PollEvent(&event) != 0) {
                    if (event.type == c.SDL_QUIT) {
                        return (-1);
                    }

                    if (event.type == c.SDL_KEYDOWN) {
                        if (event.key.keysym.scancode == c.SDL_SCANCODE_RETURN or
                            event.key.keysym.scancode == c.SDL_SCANCODE_KP_ENTER or
                            event.key.keysym.scancode == c.SDL_SCANCODE_SPACE or
                            event.key.keysym.scancode == c.SDL_SCANCODE_ESCAPE)
                            activedelay = false;

                        if (event.key.keysym.scancode == c.SDL_SCANCODE_F11) {
                            window.toggle_fullscreen();
                        }
                    }

                    if (event.type == c.SDL_WINDOWEVENT) {
                        switch (event.window.event) {
                            c.SDL_WINDOWEVENT_RESIZED,
                            c.SDL_WINDOWEVENT_SIZE_CHANGED,
                            c.SDL_WINDOWEVENT_MAXIMIZED,
                            c.SDL_WINDOWEVENT_RESTORED,
                            c.SDL_WINDOWEVENT_EXPOSED,
                            => {
                                window.window_render();
                            },

                            else => {},
                        }
                    }
                }
                SDL.delay(1);
                if ((SDL.getTicks() - tick_start + fade_time) >= delay) {
                    activedelay = false;
                }
            }

            image_alpha = 255 - image_alpha;
            tick_start = SDL.getTicks();
            // Fade to black
            while (image_alpha < 255) {
                var event: c.SDL_Event = undefined;
                if (c.SDL_PollEvent(&event) != 0) {
                    if (event.type == c.SDL_QUIT) {
                        return (-1);
                    }

                    if (event.type == c.SDL_KEYDOWN) {
                        if (event.key.keysym.scancode == c.SDL_SCANCODE_F11) {
                            window.toggle_fullscreen();
                        }
                    }
                }

                image_alpha = (SDL.getTicks() - tick_start) * 256 / fade_time + fadeoutskip;

                if (image_alpha > 255)
                    image_alpha = 255;

                _ = c.SDL_SetSurfaceAlphaMod(image_surface, 255 - @as(u8, @truncate(image_alpha)));
                _ = c.SDL_SetSurfaceBlendMode(image_surface, c.SDL_BLENDMODE_BLEND);
                window.window_clear(null);
                _ = c.SDL_BlitSurface(image_surface, &src, c.screen, &dest);
                window.window_render();
                SDL.delay(1);
            }
        },
        .FadeOut => {
            var image_alpha: c_uint = 0;

            window.window_clear(null);
            _ = c.SDL_BlitSurface(image_surface, &src, c.screen, &dest);
            window.window_render();

            const retval = keyboard.waitforbutton();
            if (retval < 0) {
                return retval;
            }

            const tick_start = SDL.getTicks();
            while (image_alpha < 255) //Fade to black
            {
                var event: c.SDL_Event = undefined;
                if (c.SDL_PollEvent(&event) != 0) {
                    if (event.type == c.SDL_QUIT) {
                        return (-1);
                    }

                    if (event.type == c.SDL_KEYDOWN) {
                        if (event.key.keysym.scancode == c.SDL_SCANCODE_F11) {
                            window.toggle_fullscreen();
                        }
                    }
                }

                image_alpha = (c.SDL_GetTicks() - tick_start) * 256 / fade_time;

                if (image_alpha > 255)
                    image_alpha = 255;

                _ = c.SDL_SetSurfaceAlphaMod(image_surface, 255 - @as(u8, @truncate(image_alpha)));
                _ = c.SDL_SetSurfaceBlendMode(image_surface, c.SDL_BLENDMODE_BLEND);
                window.window_clear(null);
                _ = c.SDL_BlitSurface(image_surface, &src, c.screen, &dest);
                window.window_render();
                SDL.delay(1);
            }
        },
    }
    return 0;
}
