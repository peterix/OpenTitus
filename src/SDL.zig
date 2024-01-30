const c = @import("c.zig");

/// Wait 'ms' milliseconds
pub fn delay(ms: u32) void {
    c.SDL_Delay(@truncate(ms));
}

/// Get the current time in milliseconds since start
pub fn getTicks() u32 {
    return c.SDL_GetTicks();
}
