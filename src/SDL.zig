usingnamespace @cImport({
    @cInclude("SDL2/SDL.h");
});

pub const Surface = @This().SDL_Surface;
pub const PixelFormat = @This().SDL_PixelFormat;

pub const Palette = @This().SDL_Palette;
pub const Color = @This().SDL_Color;
pub const Window = @This().SDL_Window;
pub const Renderer = @This().SDL_Renderer;
pub const Rect = @This().SDL_Rect;

pub const TRUE = @This().SDL_TRUE;
pub const FALSE = @This().SDL_FALSE;

// Event types
pub const Event = @This().SDL_Event;
pub const QUIT = @This().SDL_QUIT;
pub const KEYDOWN = @This().SDL_KEYDOWN;
pub const WINDOWEVENT = @This().SDL_WINDOWEVENT;
pub const WINDOWEVENT_RESIZED = @This().SDL_WINDOWEVENT_RESIZED;
pub const WINDOWEVENT_SIZE_CHANGED = @This().SDL_WINDOWEVENT_SIZE_CHANGED;
pub const WINDOWEVENT_MAXIMIZED = @This().SDL_WINDOWEVENT_MAXIMIZED;
pub const WINDOWEVENT_RESTORED = @This().SDL_WINDOWEVENT_RESTORED;
pub const WINDOWEVENT_EXPOSED = @This().SDL_WINDOWEVENT_EXPOSED;

// Blend modes
pub const BlendMode = @This().SDL_BlendMode;
pub const BLENDMODE_BLEND = @This().SDL_BLENDMODE_BLEND;

// Pixel format enum
pub const PixelFormatEnum = @This().SDL_PixelFormatEnum;
pub const PIXELFORMAT_INDEX8 = @This().SDL_PIXELFORMAT_INDEX8;

// Scancodes
pub const SCANCODE_ESCAPE = @This().SDL_SCANCODE_ESCAPE;
pub const SCANCODE_BACKSPACE = @This().SDL_SCANCODE_BACKSPACE;
pub const SCANCODE_KP_ENTER = @This().SDL_SCANCODE_KP_ENTER;
pub const SCANCODE_RETURN = @This().SDL_SCANCODE_RETURN;
pub const SCANCODE_SPACE = @This().SDL_SCANCODE_SPACE;
pub const SCANCODE_F11 = @This().SDL_SCANCODE_F11;
pub const SCANCODE_DOWN = @This().SDL_SCANCODE_DOWN;
pub const SCANCODE_UP = @This().SDL_SCANCODE_UP;
pub const SCANCODE_LEFT = @This().SDL_SCANCODE_LEFT;
pub const SCANCODE_RIGHT = @This().SDL_SCANCODE_RIGHT;

// Window creation flags
pub const WINDOW_FULLSCREEN_DESKTOP = @This().SDL_WINDOW_FULLSCREEN_DESKTOP;
pub const WINDOW_RESIZABLE = @This().SDL_WINDOW_RESIZABLE;

pub const WINDOWPOS_UNDEFINED = @This().SDL_WINDOWPOS_UNDEFINED;

pub const RENDERER_ACCELERATED = @This().SDL_RENDERER_ACCELERATED;

pub const SWSURFACE = @This().SDL_SWSURFACE;
pub const RLEACCEL = @This().SDL_RLEACCEL;

const std = @import("std");
const Allocator = std.mem.Allocator;

const TrackingHashMap = std.AutoHashMap(*Surface, void);

var tracking_map: TrackingHashMap = undefined;

const sdl_gpa_type = std.heap.GeneralPurposeAllocator(.{.retain_metadata = true, .never_unmap = true });
var sdl_gpa = sdl_gpa_type{};
var sdl_allocator: std.mem.Allocator = undefined;
var sdl_allocations: ?std.AutoHashMap(usize, usize) = null;
var sdl_mutex: std.Thread.Mutex = .{};
const sdl_alignment = 16;

fn sdl_malloc(size: usize) callconv(.C) ?*anyopaque {
    sdl_mutex.lock();
    defer sdl_mutex.unlock();

    const mem = sdl_allocator.alignedAlloc(
        u8,
        sdl_alignment,
        size,
    ) catch @panic("SDL: out of memory");

    sdl_allocations.?.put(@intFromPtr(mem.ptr), size) catch @panic("SDL: out of memory");

    return mem.ptr;
}

fn sdl_calloc(size: usize, count: usize) callconv(.C) ?*anyopaque {
    sdl_mutex.lock();
    defer sdl_mutex.unlock();

    const mem = sdl_allocator.alignedAlloc(
        u8,
        sdl_alignment,
        size * count,
    ) catch @panic("SDL: out of memory");
    @memset(mem, 0);

    sdl_allocations.?.put(@intFromPtr(mem.ptr), size * count) catch @panic("SDL: out of memory");

    return mem.ptr;
}

fn sdl_realloc(ptr: ?*anyopaque, size: usize) callconv(.C) ?*anyopaque {
    sdl_mutex.lock();
    defer sdl_mutex.unlock();

    const old_size = if (ptr != null) sdl_allocations.?.get(@intFromPtr(ptr.?)).? else 0;
    const old_mem = if (old_size > 0)
        @as([*]align(sdl_alignment) u8, @ptrCast(@alignCast(ptr)))[0..old_size]
    else
        @as([*]align(sdl_alignment) u8, undefined)[0..0];

    const new_mem = sdl_allocator.realloc(old_mem, size) catch @panic("SDL: out of memory");

    if (ptr != null) {
        const removed = sdl_allocations.?.remove(@intFromPtr(ptr.?));
        std.debug.assert(removed);
    }

    sdl_allocations.?.put(@intFromPtr(new_mem.ptr), size) catch @panic("SDL: out of memory");

    return new_mem.ptr;
}

fn sdl_free(maybe_ptr: ?*anyopaque) callconv(.C) void {
    if (maybe_ptr) |ptr| {
        sdl_mutex.lock();
        defer sdl_mutex.unlock();

        if (sdl_allocations.?.fetchRemove(@intFromPtr(ptr))) |kv| {
            const size = kv.value;
            const mem = @as([*]align(sdl_alignment) u8, @ptrCast(@alignCast(ptr)))[0..size];
            sdl_allocator.free(mem);
        }
        else
        {
            std.log.err("SDL tried to free an untracked pointer {*}", .{ptr});
        }
    }
}

pub fn init(allocator: Allocator) c_int {
    sdl_allocator = sdl_gpa.allocator();
    tracking_map = TrackingHashMap.init(allocator);
    sdl_allocations = std.AutoHashMap(usize, usize).init(allocator);
    _ = @This().SDL_SetMemoryFunctions(sdl_malloc, sdl_calloc, sdl_realloc, sdl_free);
    return @This().SDL_Init(@This().SDL_INIT_VIDEO);
}

pub fn deinit() void {
    tracking_map.deinit();
    @This().SDL_Quit();
    sdl_allocations.?.deinit();
    sdl_allocations = null;
    if (sdl_gpa.deinit() == .leak)
    {
        std.log.err("SDL memory leaked!", .{});
    }
}

// Timers

pub fn delay(ms: u32) void {
    @This().SDL_Delay(@truncate(ms));
}

pub fn getTicks() u32 {
    return @This().SDL_GetTicks();
}

// Surfaces

pub fn freeSurface(surface: [*c]Surface) void {
    if(tracking_map.remove(surface))
    {
        @This().SDL_FreeSurface(surface);
    }
    else
    {
        std.log.err("freeSurface: DOUBLE FREE OF {*}", .{surface});
    }
}

pub fn convertSurface(src: *Surface, fmt: *const PixelFormat, flags: u32) !*Surface {
    const result = @This().SDL_ConvertSurface(src, fmt, flags);
    if (result == null)
    {
        return error.Failed;
    }
    if(tracking_map.remove(result))
    {
        std.log.err("convertSurface: surface was already tracked! {*}", .{result});
    }
    tracking_map.put(result, {}) catch {};
    return result;
}

pub fn convertSurfaceFormat(src: *Surface, pixel_format: u32, flags: u32) !*Surface {
    const result = @This().SDL_ConvertSurfaceFormat(src, pixel_format, flags);
    if (result == null)
    {
        return error.Failed;
    }
    if(tracking_map.remove(result))
    {
        std.log.err("convertSurfaceFormat: surface was already tracked! {*}", .{result});
    }
    tracking_map.put(result, {}) catch {};
    return result;
}

pub fn createRGBSurface(
    flags: u32,
    width: c_int,
    height: c_int,
    depth: c_int,
    Rmask: u32,
    Gmask: u32,
    Bmask: u32,
    Amask: u32
) !*Surface {
    const result = @This().SDL_CreateRGBSurface(flags, width, height, depth, Rmask, Gmask, Bmask, Amask);
    if (result == null)
    {
        return error.Failed;
    }
    if(tracking_map.remove(result))
    {
        std.log.err("SDL_CreateRGBSurface: surface was already tracked! {*}", .{result});
    }
    tracking_map.put(result, {}) catch {};
    return result;
}

pub fn createRGBSurfaceWithFormat(flags: u32, width: c_int, height: c_int, depth: c_int, format: u32) [*c]Surface {
    const result = @This().SDL_CreateRGBSurfaceWithFormat(flags, width, height, depth, format);
    if(tracking_map.remove(result))
    {
        std.log.err("createRGBSurfaceWithFormat: surface was already tracked! {*}", .{result});
    }
    tracking_map.put(result, {}) catch {};
    return result;
}

pub fn loadBMP_RW(src: [*c]@This().SDL_RWops, freesrc: c_int) [*c]@This().Surface {
    const result = @This().SDL_LoadBMP_RW(src, freesrc);
    if(tracking_map.remove(result))
    {
        std.log.err("loadBMP_RW: surface was already tracked! {*}", .{result});
    }
    tracking_map.put(result, {}) catch {};
    return result;
}

pub fn setColorKey(surface: *Surface, flag: c_int, key: u32) c_int {
    return @This().SDL_SetColorKey(surface, flag, key);
}

pub fn setSurfaceAlphaMod(surface: *Surface, alpha: u8) c_int {
    return @This().SDL_SetSurfaceAlphaMod(surface, alpha);
}

pub fn setSurfaceBlendMode(surface: *Surface, blendMode: BlendMode) c_int {
    return @This().SDL_SetSurfaceBlendMode(surface, blendMode);
}

// Getting errors

pub fn getError() [*c]const u8 {
    return @This().SDL_GetError();
}

pub fn getErrorMsg(errstr: [*c]u8, maxlen: c_int) [*c]u8 {
    return @This().SDL_GetErrorMsg(errstr, maxlen);
}

// drawing

pub fn mapRGB(format: [*c]const PixelFormat, r: u8, g: u8, b: u8) u32 {
    return @This().SDL_MapRGB(format, r, g, b);
}

pub fn fillRect(dst: [*c]Surface, rect: [*c]const Rect, color: u32) c_int {
    return @This().SDL_FillRect(dst, rect, color);
}

pub fn blitSurface(src: [*c]Surface, srcrect: [*c]const Rect, dst: [*c]Surface, dstrect: [*c]Rect) c_int {
    return @This().SDL_BlitSurface(src, srcrect, dst, dstrect);
}

// Event loop

pub fn pollEvent(event: *Event) bool {
    return @This().SDL_PollEvent(event) == 1;
}

pub const pumpEvents = @This().SDL_PumpEvents;

// Window and final render

pub fn createWindow(title: [*c]const u8, x: c_int, y: c_int, w: c_int, h: c_int, flags: u32) ?*Window {
    return @This().SDL_CreateWindow(title, x, y, w, h, flags);
}

pub const destroyWindow = @This().SDL_DestroyWindow;

pub fn setWindowMinimumSize(window: ?*Window, min_w: c_int, min_h: c_int) void {
    @This().SDL_SetWindowMinimumSize(window, min_w, min_h);
}

pub fn setWindowFullscreen(window: ?*Window, flags: u32) c_int {
    return @This().SDL_SetWindowFullscreen(window, flags);
}

pub const getWindowPixelFormat = @This().SDL_GetWindowPixelFormat;

pub const createRenderer = @This().SDL_CreateRenderer;
pub const destroyRenderer = @This().SDL_DestroyRenderer;

pub const renderSetLogicalSize = @This().SDL_RenderSetLogicalSize;
pub const setRenderDrawColor = @This().SDL_SetRenderDrawColor;
pub const createTextureFromSurface = @This().SDL_CreateTextureFromSurface;
pub const destroyTexture = @This().SDL_DestroyTexture;

pub const renderClear = @This().SDL_RenderClear;
pub const renderCopy = @This().SDL_RenderCopy;
pub const renderPresent = @This().SDL_RenderPresent;

// IO

pub const RWFromMem = @This().SDL_RWFromMem;
