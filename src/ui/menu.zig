const c = @import("../c.zig");
const window = @import("../window.zig");

pub const MenuAction = enum {
    None,
    Left,
    Right,
    Up,
    Down,
    Activate,
};

pub const MenuContext = struct {
    background_fade: u8,
    background_image: *c.SDL_Surface,

    /// Render the background - should be the first thing a menu renderer calls
    pub fn renderBackground(self: *MenuContext) void {
        window.window_clear(null);
        _ = c.SDL_BlitSurface(self.background_image, null, window.screen, null);
    }

    /// Update the background, returns number of milliseconds until next update
    pub fn updateBackground(self: *MenuContext) u32 {
        if (self.background_fade < 200) {
            self.background_fade += 1;
            _ = c.SDL_SetSurfaceAlphaMod(self.background_image, 255 - self.background_fade);
            _ = c.SDL_SetSurfaceBlendMode(self.background_image, c.SDL_BLENDMODE_BLEND);
            return 1;
        }
        return 10;
    }
};
