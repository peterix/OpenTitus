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

const SDL = @import("SDL.zig");
const globals = @import("globals.zig");
const game = @import("game.zig");
const data = @import("data.zig");

pub fn getGameTitle() [*c]const u8 {
    switch (data.game) {
        .Titus, .None => {
            return "OpenTitus";
        },
        .Moktar => {
            return "OpenMoktar";
        },
    }
}

pub const game_width = 320;
pub const game_height = 200;

var black: u32 = 0;

pub var screen: ?*SDL.Surface = null;
pub var window: ?*SDL.Window = null;
var renderer: ?*SDL.Renderer = null;
pub var icon: ?*SDL.Surface = null;

const iconBMP = @embedFile("../res/titus.bmp");

const WindowError = error{
    CannotSetDisplayMode,
    CannotCreateWindow,
    Other,
};

pub fn toggle_fullscreen() void {
    if (!game.settings.fullscreen) {
        // FIXME: process error.
        _ = SDL.setWindowFullscreen(window, true);
        game.settings.fullscreen = true;
    } else {
        // FIXME: process error.
        _ = SDL.setWindowFullscreen(window, false);
        game.settings.fullscreen = false;
    }
}

pub fn window_init() !void {
    var windowflags: u32 = 0;
    const w: c_int = game.settings.window_width;
    const h: c_int = game.settings.window_height;
    if (game.settings.fullscreen) {
        windowflags = SDL.WINDOW_FULLSCREEN | SDL.WINDOW_OPENGL;
    } else {
        windowflags = SDL.WINDOW_RESIZABLE | SDL.WINDOW_OPENGL;
    }

    window = SDL.createWindow(getGameTitle(), w, h, windowflags);
    if (window == null) {
        std.debug.print("Unable to create window: {s}\n", .{SDL.getError()});
        return WindowError.CannotCreateWindow;
    }
    errdefer {
        SDL.destroyWindow(window);
        window = null;
    }
    _ = SDL.setWindowMinimumSize(window, game_width, game_height);

    {
        const rwops = SDL.IOFromMem(@constCast(@ptrCast(&iconBMP[0])), @intCast(iconBMP.len));
        if (rwops == null) {
            return error.CannotLoadIcon;
        }

        icon = SDL.loadBMP_IO(rwops, true);
        if (icon == null) {
            return error.CannotLoadIcon;
        }
        _ = SDL.setWindowIcon(window, icon);
    }

    renderer = SDL.createRenderer(window, null);
    if (renderer == null) {
        std.debug.print("Unable to set video mode: {s}\n", .{SDL.getError()});
        return WindowError.CannotSetDisplayMode;
    }
    errdefer {
        SDL.destroyRenderer(renderer);
        renderer = null;
    }

    const pixelFormat = SDL.getWindowPixelFormat(window);
    screen = SDL.createSurface(game_width, game_height, pixelFormat);
    if (screen == null) {
        std.debug.print("Unable to create screen surface: {s}\n", .{SDL.getError()});
        return WindowError.Other;
    }
    errdefer {
        SDL.destroySurface(screen);
        screen = null;
    }
    black = SDL.mapSurfaceRGB(screen, 0, 0, 0);

    if (!SDL.setRenderLogicalPresentation(renderer, game_width, game_height, SDL.LOGICAL_PRESENTATION_LETTERBOX)) {
        return WindowError.Other;
    }

    if (!SDL.setRenderDrawColor(renderer, 0, 0, 0, 255)) {
        return WindowError.Other;
    }
}

pub fn window_deinit() void {
    if (screen != null) {
        SDL.destroySurface(screen);
    }
    if(icon != null) {
        SDL.destroySurface(icon);
    }
}

pub fn window_clear(rect: [*c]SDL.Rect) void {
    // FIXME: process error.
    _ = SDL.fillSurfaceRect(screen, rect, black);
}

pub fn window_render() void {
    if (screen == null) {
        return;
    }
    const frame = SDL.createTextureFromSurface(renderer, screen);
    _ = SDL.setTextureScaleMode(frame, 0);
    // FIXME: process error.
    _ = SDL.renderClear(renderer);
    var rect = SDL.FRect{
        .x = 0,
        .y = 0,
        .w = game_width,
        .h = game_height,
    };
    // FIXME: process error.
    _ = SDL.renderTexture(renderer, frame, &rect, &rect);
    _ = SDL.renderPresent(renderer);
    SDL.destroyTexture(frame);
}
