const std = @import("std");

const c = @import("c.zig");
const globals = @import("globals.zig");

pub fn getGameTitle() [*c]const u8 {
    switch (c.game) {
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

var black: u32 = 0;

export var fullscreen = false;

pub export var screen: ?*c.struct_SDL_Surface = null;
pub export var window: ?*c.struct_SDL_Window = null;
var renderer: ?*c.struct_SDL_Renderer = null;

const WindowError = error{
    CannotSetDisplayMode,
    CannotCreateWindow,
    Other,
};

pub export fn window_toggle_fullscreen() void {
    if (!fullscreen) {
        // FIXME: process error.
        _ = c.SDL_SetWindowFullscreen(window, c.SDL_WINDOW_FULLSCREEN_DESKTOP);
        fullscreen = true;
    } else {
        // FIXME: process error.
        _ = c.SDL_SetWindowFullscreen(window, 0);
        fullscreen = false;
    }
}

pub fn window_init() !void {
    var windowflags: u32 = 0;
    var w: c_int = undefined;
    var h: c_int = undefined;
    switch (c.videomode) {
        // Fullscreen
        1 => {
            w = 0;
            h = 0;
            windowflags = c.SDL_WINDOW_FULLSCREEN_DESKTOP;
            fullscreen = true;
        },
        // Window = 0
        else => {
            w = 960;
            h = 600;
            windowflags = c.SDL_WINDOW_RESIZABLE;
            fullscreen = false;
        },
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
    renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_ACCELERATED);
    if (renderer == null) {
        std.debug.print("Unable to set video mode: {s}\n", .{c.SDL_GetError()});
        return WindowError.CannotSetDisplayMode;
    }
    errdefer {
        c.SDL_DestroyRenderer(renderer);
        renderer = null;
    }

    screen = c.SDL_CreateRGBSurfaceWithFormat(0, 320 + 32, 200, 32, c.SDL_GetWindowPixelFormat(window));
    if (screen == null) {
        std.debug.print("Unable to create screen surface: {s}\n", .{c.SDL_GetError()});
        return WindowError.Other;
    }
    errdefer {
        c.SDL_FreeSurface(screen);
        screen = null;
    }
    black = c.SDL_MapRGB(screen.?.*.format, 0, 0, 0);

    if (c.SDL_RenderSetLogicalSize(renderer, 320, 200) != 0) {
        return WindowError.Other;
    }

    if (c.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255) != 0) {
        return WindowError.Other;
    }
}

pub export fn window_clear(rect: [*c]c.SDL_Rect) void {
    // FIXME: process error.
    _ = c.SDL_FillRect(screen, rect, black);
}

pub export fn window_render() void {
    if (screen == null) {
        return;
    }
    var frame = c.SDL_CreateTextureFromSurface(renderer, screen);
    // FIXME: process error.
    _ = c.SDL_RenderClear(renderer);
    var src: c.SDL_Rect = undefined;
    src.x = 16 - globals.g_scroll_px_offset;
    src.y = 0;
    src.w = 320;
    src.h = 200;
    var dst = src;
    dst.x = 0;
    // FIXME: process error.
    _ = c.SDL_RenderCopy(renderer, frame, &src, &dst);
    c.SDL_RenderPresent(renderer);
    c.SDL_DestroyTexture(frame);
}
