const SDL = @import("../SDL.zig");
const window = @import("../window.zig");

pub const MenuContext = struct {
    background_fade: u8 = 0,
    background_image: *SDL.Surface,
    /// How dark the background gets (255 is black)
    fade_target: u8 = 200,
    /// How much darker it gets with each update
    fade_step: u8 = 1,

    /// Render the background - should be the first thing a menu renderer calls
    pub fn renderBackground(self: *MenuContext) void {
        window.window_clear(null);
        _ = SDL.blitSurface(self.background_image, null, window.screen, null);
    }

    /// Update the background, returns number of milliseconds until next update
    pub fn updateBackground(self: *MenuContext) u32 {
        if (self.background_fade < self.fade_target) {
            self.background_fade = @min(self.fade_target, @as(u16, self.background_fade) + self.fade_step);
            _ = SDL.setSurfaceAlphaMod(self.background_image, 255 - self.background_fade);
            _ = SDL.setSurfaceBlendMode(self.background_image, SDL.BLENDMODE_BLEND);
            return 1;
        }
        return 10;
    }
};
