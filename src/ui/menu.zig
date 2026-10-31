const SDL = @import("../SDL.zig");
const window = @import("../window.zig");
const fonts = @import("fonts.zig");

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

    /// Render the menu title with a line under it, returns the y coordinate under the line
    pub fn renderTitle(self: *MenuContext, title: []const u8) i16 {
        _ = self;
        const options = fonts.Font.RenderOptions{ .transparent = true };
        const title_width = fonts.Gold.metrics(title, options) + 4;
        var y: i16 = 8;
        fonts.Gold.render_center(title, y, options);
        y += 12;
        const bar = SDL.Rect{ .x = 160 - title_width / 2, .y = y, .w = title_width, .h = 1 };
        _ = SDL.fillSurfaceRect(window.screen.?, &bar, SDL.mapSurfaceRGB(window.screen, 0xd0, 0xb0, 0x00));
        return y + 1;
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
