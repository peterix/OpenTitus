const c = @import("c.zig");
const std = @import("std");
const Allocator = std.mem.Allocator;

const TrackingHashMap = std.AutoHashMap(*c.SDL_Surface, void);

var tracking_map: TrackingHashMap = undefined;

var sdl_allocator: ?std.mem.Allocator = null;
var sdl_allocations: ?std.AutoHashMap(usize, usize) = null;
var sdl_mutex: std.Thread.Mutex = .{};
const sdl_alignment = 16;

fn sdl_malloc(size: usize) callconv(.C) ?*anyopaque {
    sdl_mutex.lock();
    defer sdl_mutex.unlock();

    const mem = sdl_allocator.?.alignedAlloc(
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

    const mem = sdl_allocator.?.alignedAlloc(
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

    const new_mem = sdl_allocator.?.realloc(old_mem, size) catch @panic("SDL: out of memory");

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
            sdl_allocator.?.free(mem);
        }
        else
        {
            std.log.err("SDL tried to free an untracked pointer {*}", .{ptr});
        }
    }
}

pub fn init(allocator: Allocator, flags: c.Uint32) c_int {
    sdl_allocator = allocator;
    tracking_map = TrackingHashMap.init(allocator);
    sdl_allocations = std.AutoHashMap(usize, usize).init(allocator);
    //_ = c.SDL_SetMemoryFunctions(sdl_malloc, sdl_calloc, sdl_realloc, sdl_free);
    return c.SDL_Init(flags);
}

pub fn deinit() void {
    tracking_map.deinit();
    c.SDL_Quit();
    sdl_allocations.?.deinit();
    sdl_allocations = null;
    sdl_allocator = null;
}

/// Wait 'ms' milliseconds
pub fn delay(ms: u32) void {
    c.SDL_Delay(@truncate(ms));
}

/// Get the current time in milliseconds since start
pub fn getTicks() u32 {
    return c.SDL_GetTicks();
}

pub fn freeSurface(surface: [*c]c.SDL_Surface) void {
    if(tracking_map.remove(surface))
    {
        c.SDL_FreeSurface(surface);
    }
    else
    {
        std.log.err("freeSurface: DOUBLE FREE OF {*}", .{surface});
    }
}

pub fn convertSurface(src: [*c]c.SDL_Surface, fmt: [*c]const c.SDL_PixelFormat, flags: c.Uint32) [*c]c.SDL_Surface {
    const result = c.SDL_ConvertSurface(src, fmt, flags);
    if(tracking_map.remove(result))
    {
        std.log.err("convertSurface: surface was already tracked! {*}", .{result});
    }
    tracking_map.put(result, {}) catch {};
    return result;
}

pub fn convertSurfaceFormat(src: [*c]c.SDL_Surface, pixel_format: c.Uint32, flags: c.Uint32) [*c]c.SDL_Surface {
    const result = c.SDL_ConvertSurfaceFormat(src, pixel_format, flags);
    if(tracking_map.remove(result))
    {
        std.log.err("convertSurfaceFormat: surface was already tracked! {*}", .{result});
    }
    tracking_map.put(result, {}) catch {};
    return result;
}

pub fn createRGBSurface(
    flags: c.Uint32,
    width: c_int,
    height: c_int,
    depth: c_int,
    Rmask: c.Uint32,
    Gmask: c.Uint32,
    Bmask: c.Uint32,
    Amask: c.Uint32
) [*c]c.SDL_Surface {
    const result = c.SDL_CreateRGBSurface(flags, width, height, depth, Rmask, Gmask, Bmask, Amask);
    if(tracking_map.remove(result))
    {
        std.log.err("SDL_CreateRGBSurface: surface was already tracked! {*}", .{result});
    }
    tracking_map.put(result, {}) catch {};
    return result;
}

pub fn createRGBSurfaceWithFormat(flags: c.Uint32, width: c_int, height: c_int, depth: c_int, format: c.Uint32) [*c]c.SDL_Surface {
    const result = c.SDL_CreateRGBSurfaceWithFormat(flags, width, height, depth, format);
    if(tracking_map.remove(result))
    {
        std.log.err("createRGBSurfaceWithFormat: surface was already tracked! {*}", .{result});
    }
    tracking_map.put(result, {}) catch {};
    return result;
}

pub fn loadBMP_RW(src: [*c]c.SDL_RWops, freesrc: c_int) [*c]c.SDL_Surface {
    const result = c.SDL_LoadBMP_RW(src, freesrc);
    if(tracking_map.remove(result))
    {
        std.log.err("loadBMP_RW: surface was already tracked! {*}", .{result});
    }
    tracking_map.put(result, {}) catch {};
    return result;
}
