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

const sdl_gpa_type = std.heap.GeneralPurposeAllocator(.{ .retain_metadata = true, .never_unmap = true, .stack_trace_frames = 10 });
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
    return @This().SDL_Init(@This().SDL_INIT_VIDEO | @This().SDL_INIT_EVENTS | @This().SDL_INIT_JOYSTICK | @This().SDL_INIT_GAMEPAD);
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
pub const saveBMP = @This().SDL_SaveBMP;

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
pub const updateGamepads = @This().SDL_UpdateGamepads;

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
pub const setWindowIcon = @This().SDL_SetWindowIcon;

pub const createRenderer = @This().SDL_CreateRenderer;
pub const destroyRenderer = @This().SDL_DestroyRenderer;

pub const LOGICAL_PRESENTATION_LETTERBOX = @This().SDL_LOGICAL_PRESENTATION_LETTERBOX;
pub const setRenderLogicalPresentation = @This().SDL_SetRenderLogicalPresentation;
pub const setRenderDrawColor = @This().SDL_SetRenderDrawColor;
pub const createTextureFromSurface = @This().SDL_CreateTextureFromSurface;
pub const setTextureScaleMode = @This().SDL_SetTextureScaleMode;
pub const destroyTexture = @This().SDL_DestroyTexture;
pub const renderLine = @This().SDL_RenderLine;
pub const writeSurfacePixel = @This().SDL_WriteSurfacePixel;

pub const renderClear = @This().SDL_RenderClear;
pub const renderTexture = @This().SDL_RenderTexture;
pub const renderPresent = @This().SDL_RenderPresent;

// IO

pub const IOFromMem = @This().SDL_IOFromMem;

// Gamepad support

pub const EVENT_GAMEPAD_AXIS_MOTION = @This().SDL_EVENT_GAMEPAD_AXIS_MOTION;
pub const EVENT_GAMEPAD_BUTTON_DOWN = @This().SDL_EVENT_GAMEPAD_BUTTON_DOWN;
pub const EVENT_GAMEPAD_BUTTON_UP = @This().SDL_EVENT_GAMEPAD_BUTTON_UP;
pub const EVENT_GAMEPAD_ADDED = @This().SDL_EVENT_GAMEPAD_ADDED;
pub const EVENT_GAMEPAD_REMOVED = @This().SDL_EVENT_GAMEPAD_REMOVED;
pub const EVENT_GAMEPAD_REMAPPED = @This().SDL_EVENT_GAMEPAD_REMAPPED;
pub const EVENT_GAMEPAD_TOUCHPAD_DOWN = @This().SDL_EVENT_GAMEPAD_TOUCHPAD_DOWN;
pub const EVENT_GAMEPAD_TOUCHPAD_MOTION = @This().SDL_EVENT_GAMEPAD_TOUCHPAD_MOTION;
pub const EVENT_GAMEPAD_TOUCHPAD_UP = @This().SDL_EVENT_GAMEPAD_TOUCHPAD_UP;
pub const EVENT_GAMEPAD_SENSOR_UPDATE = @This().SDL_EVENT_GAMEPAD_SENSOR_UPDATE;
pub const EVENT_GAMEPAD_UPDATE_COMPLETE = @This().SDL_EVENT_GAMEPAD_UPDATE_COMPLETE;
pub const EVENT_GAMEPAD_STEAM_HANDLE_UPDATED = @This().SDL_EVENT_GAMEPAD_STEAM_HANDLE_UPDATED;

pub const GAMEPAD_BUTTON_INVALID = @This().SDL_GAMEPAD_BUTTON_INVALID;
pub const GAMEPAD_BUTTON_SOUTH = @This().SDL_GAMEPAD_BUTTON_SOUTH; // Bottom face button (e.g. Xbox A button)
pub const GAMEPAD_BUTTON_EAST = @This().SDL_GAMEPAD_BUTTON_EAST; // Right face button (e.g. Xbox B button)
pub const GAMEPAD_BUTTON_WEST = @This().SDL_GAMEPAD_BUTTON_WEST; // Left face button (e.g. Xbox X button)
pub const GAMEPAD_BUTTON_NORTH = @This().SDL_GAMEPAD_BUTTON_NORTH; // Top face button (e.g. Xbox Y button)
pub const GAMEPAD_BUTTON_BACK = @This().SDL_GAMEPAD_BUTTON_BACK; // Right center button on Xbox
pub const GAMEPAD_BUTTON_GUIDE = @This().SDL_GAMEPAD_BUTTON_GUIDE; // Big center button (Xbox, Steam, etc. logo buttons)
pub const GAMEPAD_BUTTON_START = @This().SDL_GAMEPAD_BUTTON_START; // Left center button on Xbox
pub const GAMEPAD_BUTTON_LEFT_STICK = @This().SDL_GAMEPAD_BUTTON_LEFT_STICK;
pub const GAMEPAD_BUTTON_RIGHT_STICK = @This().SDL_GAMEPAD_BUTTON_RIGHT_STICK;
pub const GAMEPAD_BUTTON_LEFT_SHOULDER = @This().SDL_GAMEPAD_BUTTON_LEFT_SHOULDER;
pub const GAMEPAD_BUTTON_RIGHT_SHOULDER = @This().SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER;
pub const GAMEPAD_BUTTON_DPAD_UP = @This().SDL_GAMEPAD_BUTTON_DPAD_UP;
pub const GAMEPAD_BUTTON_DPAD_DOWN = @This().SDL_GAMEPAD_BUTTON_DPAD_DOWN;
pub const GAMEPAD_BUTTON_DPAD_LEFT = @This().SDL_GAMEPAD_BUTTON_DPAD_LEFT;
pub const GAMEPAD_BUTTON_DPAD_RIGHT = @This().SDL_GAMEPAD_BUTTON_DPAD_RIGHT;
pub const GAMEPAD_BUTTON_MISC1 = @This().SDL_GAMEPAD_BUTTON_MISC1; // Additional button (e.g. Xbox Series X share button)
pub const GAMEPAD_BUTTON_RIGHT_PADDLE1 = @This().SDL_GAMEPAD_BUTTON_RIGHT_PADDLE1; // Upper or primary paddle, under your right hand (e.g. Xbox Elite paddle P1)
pub const GAMEPAD_BUTTON_LEFT_PADDLE1 = @This().SDL_GAMEPAD_BUTTON_LEFT_PADDLE1; // Upper or primary paddle, under your left hand (e.g. Xbox Elite paddle P3)
pub const GAMEPAD_BUTTON_RIGHT_PADDLE2 = @This().SDL_GAMEPAD_BUTTON_RIGHT_PADDLE2; // Lower or secondary paddle, under your right hand (e.g. Xbox Elite paddle P2)
pub const GAMEPAD_BUTTON_LEFT_PADDLE2 = @This().SDL_GAMEPAD_BUTTON_LEFT_PADDLE2; // Lower or secondary paddle, under your left hand (e.g. Xbox Elite paddle P4)
pub const GAMEPAD_BUTTON_TOUCHPAD = @This().SDL_GAMEPAD_BUTTON_TOUCHPAD; // PS4/PS5 touchpad button
pub const GAMEPAD_BUTTON_MISC2 = @This().SDL_GAMEPAD_BUTTON_MISC2;
pub const GAMEPAD_BUTTON_MISC3 = @This().SDL_GAMEPAD_BUTTON_MISC3;
pub const GAMEPAD_BUTTON_MISC4 = @This().SDL_GAMEPAD_BUTTON_MISC4;
pub const GAMEPAD_BUTTON_MISC5 = @This().SDL_GAMEPAD_BUTTON_MISC5;
pub const GAMEPAD_BUTTON_MISC6 = @This().SDL_GAMEPAD_BUTTON_MISC6;
pub const GAMEPAD_BUTTON_COUNT = @This().SDL_GAMEPAD_BUTTON_COUNT;

pub const GAMEPAD_AXIS_INVALID = @This().SDL_GAMEPAD_AXIS_INVALID;
pub const GAMEPAD_AXIS_LEFTX = @This().SDL_GAMEPAD_AXIS_LEFTX;
pub const GAMEPAD_AXIS_LEFTY = @This().SDL_GAMEPAD_AXIS_LEFTY;
pub const GAMEPAD_AXIS_RIGHTX = @This().SDL_GAMEPAD_AXIS_RIGHTX;
pub const GAMEPAD_AXIS_RIGHTY = @This().SDL_GAMEPAD_AXIS_RIGHTY;
pub const GAMEPAD_AXIS_LEFT_TRIGGER = @This().SDL_GAMEPAD_AXIS_LEFT_TRIGGER;
pub const GAMEPAD_AXIS_RIGHT_TRIGGER = @This().SDL_GAMEPAD_AXIS_RIGHT_TRIGGER;
pub const GAMEPAD_AXIS_COUNT = @This().SDL_GAMEPAD_AXIS_COUNT;

pub const PROP_GAMEPAD_CAP_MONO_LED_BOOLEAN = @This().SDL_PROP_GAMEPAD_CAP_MONO_LED_BOOLEAN;
pub const PROP_GAMEPAD_CAP_RGB_LED_BOOLEAN = @This().SDL_PROP_GAMEPAD_CAP_RGB_LED_BOOLEAN;
pub const PROP_GAMEPAD_CAP_PLAYER_LED_BOOLEAN = @This().SDL_PROP_GAMEPAD_CAP_PLAYER_LED_BOOLEAN;
pub const PROP_GAMEPAD_CAP_RUMBLE_BOOLEAN = @This().SDL_PROP_GAMEPAD_CAP_RUMBLE_BOOLEAN;
pub const PROP_GAMEPAD_CAP_TRIGGER_RUMBLE_BOOLEAN = @This().SDL_PROP_GAMEPAD_CAP_TRIGGER_RUMBLE_BOOLEAN;

pub const JoystickID = @This().SDL_JoystickID;
pub const PropertiesID = @This().SDL_PropertiesID;
pub const Gamepad = @This().SDL_Gamepad;

pub const openGamepad = @This().SDL_OpenGamepad;
pub const isGamepad = @This().SDL_IsGamepad;
pub const closeGamepad = @This().SDL_CloseGamepad;
pub fn getGamepadName(gamepad: *Gamepad) []const u8 {
    return std.mem.span(@This().SDL_GetGamepadName(gamepad));
}
pub const getGamepadProperties = @This().SDL_GetGamepadProperties;
pub const getBooleanProperty = @This().SDL_GetBooleanProperty;
pub const rumbleGamepad = @This().SDL_RumbleGamepad;
pub const rumbleGamepadTriggers = @This().SDL_RumbleGamepadTriggers;

// Thumbstick axis values range from SDL_JOYSTICK_AXIS_MIN to SDL_JOYSTICK_AXIS_MAX, and are centered within ~8000 of zero,
// though advanced UI will allow users to set or autodetect the dead zone, which varies between gamepads.

// Trigger axis values range from 0 (released) to SDL_JOYSTICK_AXIS_MAX (fully pressed) when reported by SDL_GetGamepadAxis().
// Note that this is not the same range that will be reported by the lower-level SDL_GetJoystickAxis().
pub const JOYSTICK_AXIS_MIN = @This().SDL_JOYSTICK_AXIS_MIN;
pub const JOYSTICK_AXIS_MAX = @This().SDL_JOYSTICK_AXIS_MAX;



// Time handling

pub const Time = @This().SDL_Time;
pub const DateTime = @This().SDL_DateTime;
pub const timeToDateTime = @This().SDL_TimeToDateTime;
pub const getCurrentTime = @This().SDL_GetCurrentTime;
