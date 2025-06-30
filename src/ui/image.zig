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
const SDL = @import("../SDL.zig");
const window = @import("../window.zig");
const input = @import("../input.zig");

pub const ManagedSurface = struct {
    value: *SDL.Surface,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        SDL.destroySurface(self.value);
    }

    pub fn dump(self: *Self, filename: [:0]const u8) !void {
        if (SDL.saveBMP(self.value, &filename[0]) != 0) {
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

pub fn load_planar_16color(data: []const u8, width: u16, height: u16, surface: *SDL.Surface) ![]const u8 {
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
    const surface = SDL.createSurface(320, 200, SDL.PIXELFORMAT_INDEX8);
    defer SDL.destroySurface(surface);
    const palette = SDL.createSurfacePalette(surface);

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
    return ManagedSurface{ .value = try SDL.convertSurface(surface, SDL.getWindowPixelFormat(window.window)) };
}

pub const DisplayMode = enum(c_int) {
    FadeInFadeOut = 0,
    FadeOut = 1,
};

pub fn viewImageFile(file: ImageFile, display_mode: DisplayMode, delay: c_int, allocator: std.mem.Allocator) !c_int {
    const fade_time = 1000;

    const image_data = try sqz.unSQZ(file.filename, allocator);
    var image_memory = try loadImage(image_data, file.format, allocator);
    defer image_memory.deinit();
    const image_surface = image_memory.value;
    var src = SDL.Rect{
        .x = 0,
        .y = 0,
        .w = image_surface.*.w,
        .h = image_surface.*.h,
    };

    var dest = SDL.Rect{
        .x = 0,
        .y = 0,
        .w = image_surface.*.w,
        .h = image_surface.*.h,
    };
    switch (display_mode) {
        .FadeInFadeOut => {
            var tick_start = SDL.getTicks();
            var image_alpha: u64 = 0;
            var activedelay = true;
            var fadeoutskip: u64 = 0;
            while ((image_alpha < 255) and activedelay) //Fade to visible
            {
                const input_state = input.processEvents();
                switch (input_state.action) {
                    .Quit => {
                        return (-1);
                    },
                    .Escape, .Cancel, .Activate => {
                        activedelay = false;
                        fadeoutskip = 255 - image_alpha;
                    },
                    else => {},
                }

                image_alpha = (SDL.getTicks() - tick_start) * 256 / fade_time;

                if (image_alpha > 255)
                    image_alpha = 255;

                _ = SDL.setSurfaceAlphaMod(image_surface, @truncate(image_alpha));
                _ = SDL.setSurfaceBlendMode(image_surface, SDL.BLENDMODE_BLEND);
                window.window_clear(null);
                _ = SDL.blitSurface(image_surface, &src, window.screen, &dest);
                window.window_render();
                SDL.delay(1);
            }

            while (activedelay) //Visible delay
            {
                const input_state = input.processEvents();
                switch (input_state.action) {
                    .Quit => {
                        return (-1);
                    },
                    .Escape, .Cancel, .Activate => {
                        activedelay = false;
                    },
                    else => {},
                }
                if (input_state.should_redraw)
                {
                    window.window_render();
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
                const input_state = input.processEvents();
                switch (input_state.action) {
                    .Quit => {
                        return (-1);
                    },
                    else => {},
                }

                image_alpha = (SDL.getTicks() - tick_start) * 256 / fade_time + fadeoutskip;

                if (image_alpha > 255)
                    image_alpha = 255;

                _ = SDL.setSurfaceAlphaMod(image_surface, 255 - @as(u8, @truncate(image_alpha)));
                _ = SDL.setSurfaceBlendMode(image_surface, SDL.BLENDMODE_BLEND);
                window.window_clear(null);
                _ = SDL.blitSurface(image_surface, &src, window.screen, &dest);
                window.window_render();
                SDL.delay(1);
            }
        },
        .FadeOut => {
            var image_alpha: u64 = 0;

            window.window_clear(null);
            _ = SDL.blitSurface(image_surface, &src, window.screen, &dest);
            window.window_render();

            const retval = input.waitforbutton();
            if (retval < 0) {
                return retval;
            }

            const tick_start = SDL.getTicks();
            while (image_alpha < 255) //Fade to black
            {
                const input_state = input.processEvents();
                switch (input_state.action) {
                    .Quit => {
                        return (-1);
                    },
                    else => {},
                }

                image_alpha = (SDL.getTicks() - tick_start) * 256 / fade_time;

                if (image_alpha > 255)
                    image_alpha = 255;

                _ = SDL.setSurfaceAlphaMod(image_surface, 255 - @as(u8, @truncate(image_alpha)));
                _ = SDL.setSurfaceBlendMode(image_surface, SDL.BLENDMODE_BLEND);
                window.window_clear(null);
                _ = SDL.blitSurface(image_surface, &src, window.screen, &dest);
                window.window_render();
                SDL.delay(1);
            }
        },
    }
    return 0;
}
