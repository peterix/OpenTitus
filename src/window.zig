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
const game = @import("game.zig");
const data = @import("data.zig");

pub fn getGameTitle() [*c]const u8 {
    switch (data.game) {
        c.Titus => {
            return "OpenTitus";
        },
        c.Moktar => {
            return "OpenMoktar";
        },
        else => {
            return "Something else...";
        },
    }
}

pub const game_width = 320;
pub const game_height = 200;

var black: u32 = 0;

pub export var screen: ?*c.struct_SDL_Surface = null;
pub export var window: ?*c.struct_SDL_Window = null;
var renderer: ?*c.struct_SDL_Renderer = null;

const WindowError = error{
    CannotSetDisplayMode,
    CannotCreateWindow,
    Other,
};

pub export fn toggle_fullscreen() void {
    if (!game.settings.fullscreen) {
        // FIXME: process error.
        _ = c.SDL_SetWindowFullscreen(window, c.SDL_WINDOW_FULLSCREEN_DESKTOP);
        game.settings.fullscreen = true;
    } else {
        // FIXME: process error.
        _ = c.SDL_SetWindowFullscreen(window, 0);
        game.settings.fullscreen = false;
    }
}

pub fn window_init() !void {
    var windowflags: u32 = 0;
    const w: c_int = game.settings.window_width;
    const h: c_int = game.settings.window_height;
    if (game.settings.fullscreen) {
        windowflags = c.SDL_WINDOW_FULLSCREEN_DESKTOP;
    } else {
        windowflags = c.SDL_WINDOW_RESIZABLE;
    }

    window = c.SDL_CreateWindow(getGameTitle(), c.SDL_WINDOWPOS_UNDEFINED, c.SDL_WINDOWPOS_UNDEFINED, w, h, windowflags);
    if (window == null) {
        std.debug.print("Unable to create window: {s}\n", .{c.SDL_GetError()});
        return WindowError.CannotCreateWindow;
    }
    errdefer {
        c.SDL_DestroyWindow(window);
        window = null;
    }
    c.SDL_SetWindowMinimumSize(window, game_width, game_height);

    renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_ACCELERATED);
    if (renderer == null) {
        std.debug.print("Unable to set video mode: {s}\n", .{c.SDL_GetError()});
        return WindowError.CannotSetDisplayMode;
    }
    errdefer {
        c.SDL_DestroyRenderer(renderer);
        renderer = null;
    }

    screen = c.SDL_CreateRGBSurfaceWithFormat(0, game_width, game_height, 32, c.SDL_GetWindowPixelFormat(window));
    if (screen == null) {
        std.debug.print("Unable to create screen surface: {s}\n", .{c.SDL_GetError()});
        return WindowError.Other;
    }
    errdefer {
        c.SDL_FreeSurface(screen);
        screen = null;
    }
    black = c.SDL_MapRGB(screen.?.*.format, 0, 0, 0);

    if (c.SDL_RenderSetLogicalSize(renderer, game_width, game_height) != 0) {
        return WindowError.Other;
    }

    if (c.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255) != 0) {
        return WindowError.Other;
    }
}

pub fn window_clear(rect: [*c]c.SDL_Rect) void {
    // FIXME: process error.
    _ = c.SDL_FillRect(screen, rect, black);
}

pub fn window_render() void {
    if (screen == null) {
        return;
    }
    const frame = c.SDL_CreateTextureFromSurface(renderer, screen);
    // FIXME: process error.
    _ = c.SDL_RenderClear(renderer);
    var rect = c.SDL_Rect{
        .x = 0,
        .y = 0,
        .w = game_width,
        .h = game_height,
    };
    // FIXME: process error.
    _ = c.SDL_RenderCopy(renderer, frame, &rect, &rect);
    c.SDL_RenderPresent(renderer);
    c.SDL_DestroyTexture(frame);
}
