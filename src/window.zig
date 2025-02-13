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
        .Titus => {
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

const WindowError = error{
    CannotSetDisplayMode,
    CannotCreateWindow,
    Other,
};

pub fn toggle_fullscreen() void {
    if (!game.settings.fullscreen) {
        // FIXME: process error.
        _ = SDL.setWindowFullscreen(window, SDL.WINDOW_FULLSCREEN_DESKTOP);
        game.settings.fullscreen = true;
    } else {
        // FIXME: process error.
        _ = SDL.setWindowFullscreen(window, 0);
        game.settings.fullscreen = false;
    }
}

pub fn window_init() !void {
    var windowflags: u32 = 0;
    const w: c_int = game.settings.window_width;
    const h: c_int = game.settings.window_height;
    if (game.settings.fullscreen) {
        windowflags = SDL.WINDOW_FULLSCREEN_DESKTOP;
    } else {
        windowflags = SDL.WINDOW_RESIZABLE;
    }

    window = SDL.createWindow(getGameTitle(), SDL.WINDOWPOS_UNDEFINED, SDL.WINDOWPOS_UNDEFINED, w, h, windowflags);
    if (window == null) {
        std.debug.print("Unable to create window: {s}\n", .{SDL.getError()});
        return WindowError.CannotCreateWindow;
    }
    errdefer {
        SDL.destroyWindow(window);
        window = null;
    }
    SDL.setWindowMinimumSize(window, game_width, game_height);

    renderer = SDL.createRenderer(window, -1, SDL.RENDERER_ACCELERATED);
    if (renderer == null) {
        std.debug.print("Unable to set video mode: {s}\n", .{SDL.getError()});
        return WindowError.CannotSetDisplayMode;
    }
    errdefer {
        SDL.destroyRenderer(renderer);
        renderer = null;
    }

    screen = SDL.createRGBSurfaceWithFormat(0, game_width, game_height, 32, SDL.getWindowPixelFormat(window));
    if (screen == null) {
        std.debug.print("Unable to create screen surface: {s}\n", .{SDL.getError()});
        return WindowError.Other;
    }
    errdefer {
        SDL.freeSurface(screen);
        screen = null;
    }
    black = SDL.mapRGB(screen.?.*.format, 0, 0, 0);

    if (SDL.renderSetLogicalSize(renderer, game_width, game_height) != 0) {
        return WindowError.Other;
    }

    if (SDL.setRenderDrawColor(renderer, 0, 0, 0, 255) != 0) {
        return WindowError.Other;
    }
}

pub fn window_clear(rect: [*c]SDL.Rect) void {
    // FIXME: process error.
    _ = SDL.fillRect(screen, rect, black);
}

pub fn window_render() void {
    if (screen == null) {
        return;
    }
    const frame = SDL.createTextureFromSurface(renderer, screen);
    // FIXME: process error.
    _ = SDL.renderClear(renderer);
    var rect = SDL.Rect{
        .x = 0,
        .y = 0,
        .w = game_width,
        .h = game_height,
    };
    // FIXME: process error.
    _ = SDL.renderCopy(renderer, frame, &rect, &rect);
    SDL.renderPresent(renderer);
    SDL.destroyTexture(frame);
}
