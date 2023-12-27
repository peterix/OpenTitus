const std = @import("std");
const globals = @import("globals.zig");
const engine = @import("engine.zig");

pub fn getGameTitle() [*c]const u8 {
    switch (engine.c.game) {
        engine.c.Titus => {
            return "OpenTitus";
        },
        engine.c.Moktar => {
            return "OpenMoktar";
        },
        else => {
            return "Something else...";
        },
    }
}

var black: u32 = 0;

export var fullscreen = false;

pub export var screen: ?*engine.c.struct_SDL_Surface = null;
pub export var window: ?*engine.c.struct_SDL_Window = null;
var renderer: ?*engine.c.struct_SDL_Renderer = null;

const WindowError = error{
    CannotSetDisplayMode,
    CannotCreateWindow,
    Other,
};

pub export fn window_toggle_fullscreen() void {
    if (!fullscreen) {
        // FIXME: process error.
        _ = engine.c.SDL_SetWindowFullscreen(window, engine.c.SDL_WINDOW_FULLSCREEN_DESKTOP);
        fullscreen = true;
    } else {
        // FIXME: process error.
        _ = engine.c.SDL_SetWindowFullscreen(window, 0);
        fullscreen = false;
    }
}

pub fn window_init() !void {
    var windowflags: u32 = 0;
    var w: c_int = undefined;
    var h: c_int = undefined;
    switch (engine.c.videomode) {
        // Fullscreen
        1 => {
            w = 0;
            h = 0;
            windowflags = engine.c.SDL_WINDOW_FULLSCREEN_DESKTOP;
            fullscreen = true;
        },
        // Window = 0
        else => {
            w = 960;
            h = 600;
            windowflags = engine.c.SDL_WINDOW_RESIZABLE;
            fullscreen = false;
        },
    }

    window = engine.c.SDL_CreateWindow(getGameTitle(), engine.c.SDL_WINDOWPOS_UNDEFINED, engine.c.SDL_WINDOWPOS_UNDEFINED, w, h, windowflags);
    if (window == null) {
        std.debug.print("Unable to create window: {s}\n", .{engine.c.SDL_GetError()});
        return WindowError.CannotCreateWindow;
    }
    errdefer {
        engine.c.SDL_DestroyWindow(window);
        window = null;
    }
    renderer = engine.c.SDL_CreateRenderer(window, -1, engine.c.SDL_RENDERER_ACCELERATED);
    if (renderer == null) {
        std.debug.print("Unable to set video mode: {s}\n", .{engine.c.SDL_GetError()});
        return WindowError.CannotSetDisplayMode;
    }
    errdefer {
        engine.c.SDL_DestroyRenderer(renderer);
        renderer = null;
    }

    screen = engine.c.SDL_CreateRGBSurfaceWithFormat(0, 320 + 32, 200, 32, engine.c.SDL_GetWindowPixelFormat(window));
    if (screen == null) {
        std.debug.print("Unable to create screen surface: {s}\n", .{engine.c.SDL_GetError()});
        return WindowError.Other;
    }
    errdefer {
        engine.c.SDL_FreeSurface(screen);
        screen = null;
    }
    // FIXME: check if the above call succeeded
    black = engine.c.SDL_MapRGB(screen.?.*.format, 0, 0, 0);

    if (engine.c.SDL_RenderSetLogicalSize(renderer, 320, 200) != 0) {
        return WindowError.Other;
    }

    if (engine.c.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255) != 0) {
        return WindowError.Other;
    }
}

pub export fn window_clear(rect: [*c]engine.c.SDL_Rect) void {
    // FIXME: process error.
    _ = engine.c.SDL_FillRect(screen, rect, black);
}

pub export fn window_render() void {
    if (screen == null) {
        return;
    }
    var frame = engine.c.SDL_CreateTextureFromSurface(renderer, screen);
    // FIXME: process error.
    _ = engine.c.SDL_RenderClear(renderer);
    var src: engine.c.SDL_Rect = undefined;
    src.x = 16 - globals.g_scroll_px_offset;
    src.y = 0;
    src.w = 320;
    src.h = 200;
    var dst = src;
    dst.x = 0;
    // FIXME: process error.
    _ = engine.c.SDL_RenderCopy(renderer, frame, &src, &dst);
    engine.c.SDL_RenderPresent(renderer);
    engine.c.SDL_DestroyTexture(frame);
}
