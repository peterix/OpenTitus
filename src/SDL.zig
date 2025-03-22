usingnamespace @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_revision.h");
    // For programs that provide their own entry points instead of relying on SDL's main function
    // macro magic, 'SDL_MAIN_HANDLED' should be defined before including 'SDL_main.h'.
    @cDefine("SDL_MAIN_HANDLED", {});
    @cInclude("SDL3/SDL_main.h");
});

pub const Surface = @This().SDL_Surface;
pub const PixelFormat = @This().SDL_PixelFormat;
pub const ScaleMode = @This().SDL_ScaleMode;

pub const Palette = @This().SDL_Palette;
pub const Color = @This().SDL_Color;
pub const Window = @This().SDL_Window;
pub const Renderer = @This().SDL_Renderer;
pub const Rect = @This().SDL_Rect;
pub const FRect = @This().SDL_FRect;
pub const Keymod = @This().SDL_Keymod;

// Event types
pub const Event = @This().SDL_Event;
pub const EVENT_QUIT = @This().SDL_EVENT_QUIT;
pub const EVENT_KEY_DOWN = @This().SDL_EVENT_KEY_DOWN;
pub const EVENT_WINDOW_RESIZED = @This().SDL_EVENT_WINDOW_RESIZED;
pub const EVENT_WINDOW_PIXEL_SIZE_CHANGED = @This().SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED;
pub const EVENT_WINDOW_MAXIMIZED = @This().SDL_EVENT_WINDOW_MAXIMIZED;
pub const EVENT_WINDOW_RESTORED = @This().SDL_EVENT_WINDOW_RESTORED;
pub const EVENT_WINDOW_EXPOSED = @This().SDL_EVENT_WINDOW_EXPOSED;

// Blend modes
pub const BlendMode = @This().SDL_BlendMode;
pub const BLENDMODE_BLEND = @This().SDL_BLENDMODE_BLEND;

// Pixel format enum
pub const PIXELFORMAT_INDEX8 = @This().SDL_PIXELFORMAT_INDEX8;

// Scancodes
pub const SCANCODE_ESCAPE = @This().SDL_SCANCODE_ESCAPE;
pub const SCANCODE_BACKSPACE = @This().SDL_SCANCODE_BACKSPACE;
pub const SCANCODE_KP_ENTER = @This().SDL_SCANCODE_KP_ENTER;
pub const SCANCODE_RETURN = @This().SDL_SCANCODE_RETURN;
pub const SCANCODE_SPACE = @This().SDL_SCANCODE_SPACE;
pub const SCANCODE_F1 = @This().SDL_SCANCODE_F1;
pub const SCANCODE_F2 = @This().SDL_SCANCODE_F2;
pub const SCANCODE_F3 = @This().SDL_SCANCODE_F3;
pub const SCANCODE_F4 = @This().SDL_SCANCODE_F4;
pub const SCANCODE_F11 = @This().SDL_SCANCODE_F11;
pub const SCANCODE_UP = @This().SDL_SCANCODE_UP;
pub const SCANCODE_DOWN = @This().SDL_SCANCODE_DOWN;
pub const SCANCODE_LEFT = @This().SDL_SCANCODE_LEFT;
pub const SCANCODE_RIGHT = @This().SDL_SCANCODE_RIGHT;
pub const SCANCODE_W = @This().SDL_SCANCODE_W;
pub const SCANCODE_S = @This().SDL_SCANCODE_S;
pub const SCANCODE_A = @This().SDL_SCANCODE_A;
pub const SCANCODE_D = @This().SDL_SCANCODE_D;
pub const SCANCODE_G = @This().SDL_SCANCODE_G;
pub const SCANCODE_N = @This().SDL_SCANCODE_N;
pub const SCANCODE_Q = @This().SDL_SCANCODE_Q;
pub const SCANCODE_E = @This().SDL_SCANCODE_E;

pub const KMOD_ALT = @This().SDL_KMOD_ALT;
pub const KMOD_CTRL = @This().SDL_KMOD_CTRL;

// Window creation flags
pub const WINDOW_OPENGL = @This().SDL_WINDOW_OPENGL;
pub const WINDOW_FULLSCREEN = @This().SDL_WINDOW_FULLSCREEN;
pub const WINDOW_RESIZABLE = @This().SDL_WINDOW_RESIZABLE;

pub const WINDOWPOS_UNDEFINED = @This().SDL_WINDOWPOS_UNDEFINED;

pub const RENDERER_ACCELERATED = @This().SDL_RENDERER_ACCELERATED;

pub const RLEACCEL = @This().SDL_RLEACCEL;

const std = @import("std");
const Allocator = std.mem.Allocator;

const TrackingHashMap = std.AutoHashMap(*Surface, void);

var tracking_map: TrackingHashMap = undefined;

const sdl_gpa_type = std.heap.GeneralPurposeAllocator(.{ .retain_metadata = true, .never_unmap = true });
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
        } else {
            std.log.err("SDL tried to free an untracked pointer {*}", .{ptr});
        }
    }
}

pub fn init(allocator: Allocator) bool {
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
    if (sdl_gpa.deinit() == .leak) {
        std.log.err("SDL memory leaked!", .{});
    }
}

// Timers

pub fn delay(ms: u32) void {
    @This().SDL_Delay(ms);
}

pub fn getTicks() u64 {
    return @This().SDL_GetTicks();
}

// Surfaces

pub fn destroySurface(surface: [*c]Surface) void {
    if (tracking_map.remove(surface)) {
        @This().SDL_DestroySurface(surface);
    } else {
        std.log.err("destroySurface: DOUBLE FREE OF {*}", .{surface});
    }
}

pub fn duplicateSurface(surface: [*c]Surface) !*Surface {
    const result = @This().SDL_DuplicateSurface(surface);
    if (result == null) {
        return error.Failed;
    }
    if (tracking_map.remove(result)) {
        std.log.err("duplicateSurface: surface was already tracked! {*}", .{result});
    }
    tracking_map.put(result, {}) catch {};
    return result;
}

pub fn convertSurface(src: *Surface, pixel_format: PixelFormat) !*Surface {
    const result = @This().SDL_ConvertSurface(src, pixel_format);
    if (result == null) {
        return error.Failed;
    }
    if (tracking_map.remove(result)) {
        std.log.err("convertSurface: surface was already tracked! {*}", .{result});
    }
    tracking_map.put(result, {}) catch {};
    return result;
}

pub fn createSurface(width: c_int, height: c_int, format: u32) [*c]Surface {
    const result = @This().SDL_CreateSurface(width, height, format);
    if (tracking_map.remove(result)) {
        std.log.err("createSurface: surface was already tracked! {*}", .{result});
    }
    tracking_map.put(result, {}) catch {};
    return result;
}

pub const setSurfacePalette = @This().SDL_SetSurfacePalette;

pub const createSurfacePalette = @This().SDL_CreateSurfacePalette;

pub fn loadBMP_IO(src: ?*@This().SDL_IOStream, closeio: bool) [*c]@This().Surface {
    const result = @This().SDL_LoadBMP_IO(src, closeio);
    if (tracking_map.remove(result)) {
        std.log.err("loadBMP_IO: surface was already tracked! {*}", .{result});
    }
    tracking_map.put(result, {}) catch {};
    return result;
}

pub const setSurfaceColorKey = @This().SDL_SetSurfaceColorKey;

pub fn setSurfaceAlphaMod(surface: *Surface, alpha: u8) bool {
    return @This().SDL_SetSurfaceAlphaMod(surface, alpha);
}

pub fn setSurfaceBlendMode(surface: *Surface, blendMode: BlendMode) bool {
    return @This().SDL_SetSurfaceBlendMode(surface, blendMode);
}

// Getting errors

pub fn getError() []const u8 {
    return std.mem.span(@This().SDL_GetError());
}

// drawing

pub const mapSurfaceRGB = @This().SDL_MapSurfaceRGB;

pub const fillSurfaceRect = @This().SDL_FillSurfaceRect;
pub const blitSurface = @This().SDL_BlitSurface;

// Event loop

pub const pollEvent = @This().SDL_PollEvent;
pub const pumpEvents = @This().SDL_PumpEvents;

pub fn getKeyboardState() []const u8 {
    var num_keys: c_int = 0;
    const address = @This().SDL_GetKeyboardState(&num_keys);
    return @as(*const[]const u8, @ptrCast(&.{.ptr=address, .len=num_keys})).*;
}

pub fn getModState() Keymod {
    return @This().SDL_GetModState();
}

// Window and final render

pub const createWindow = @This().SDL_CreateWindow;
pub const destroyWindow = @This().SDL_DestroyWindow;

pub fn setWindowMinimumSize(window: ?*Window, min_w: c_int, min_h: c_int) bool {
    return @This().SDL_SetWindowMinimumSize(window, min_w, min_h);
}

pub const setWindowFullscreen = @This().SDL_SetWindowFullscreen;

pub const getWindowPixelFormat = @This().SDL_GetWindowPixelFormat;

pub const createRenderer = @This().SDL_CreateRenderer;
pub const destroyRenderer = @This().SDL_DestroyRenderer;

pub const LOGICAL_PRESENTATION_LETTERBOX = @This().SDL_LOGICAL_PRESENTATION_LETTERBOX;
pub const setRenderLogicalPresentation = @This().SDL_SetRenderLogicalPresentation;
pub const setRenderDrawColor = @This().SDL_SetRenderDrawColor;
pub const createTextureFromSurface = @This().SDL_CreateTextureFromSurface;
pub const setTextureScaleMode = @This().SDL_SetTextureScaleMode;
pub const destroyTexture = @This().SDL_DestroyTexture;

pub const renderClear = @This().SDL_RenderClear;
pub const renderTexture = @This().SDL_RenderTexture;
pub const renderPresent = @This().SDL_RenderPresent;

// IO

pub const IOFromMem = @This().SDL_IOFromMem;
