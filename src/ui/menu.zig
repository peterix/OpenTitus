const SDL = @import("../SDL.zig");
const c = @import("../c.zig");
const window = @import("../window.zig");

pub const MenuAction = enum {
    None,
    Quit,
    ExitMenu,
    Left,
    Right,
    Up,
    Down,
    Activate,
};

pub const MenuContext = struct {
    background_fade: u8 = 0,
    background_image: *SDL.Surface,

    /// Render the background - should be the first thing a menu renderer calls
    pub fn renderBackground(self: *MenuContext) void {
        window.window_clear(null);
        _ = SDL.blitSurface(self.background_image, null, window.screen, null);
    }

    /// Update the background, returns number of milliseconds until next update
    pub fn updateBackground(self: *MenuContext) u32 {
        if (self.background_fade < 200) {
            self.background_fade += 1;
            _ = SDL.setSurfaceAlphaMod(self.background_image, 255 - self.background_fade);
            _ = SDL.setSurfaceBlendMode(self.background_image, SDL.BLENDMODE_BLEND);
            return 1;
        }
        return 10;
    }
};

pub fn getMenuAction() MenuAction {
    var action: MenuAction = .None;
    var event: SDL.Event = undefined;
    while (SDL.pollEvent(&event)) {
        switch (event.type) {
            SDL.QUIT => {
                return .Quit;
            },
            SDL.KEYDOWN => {
                switch (event.key.keysym.scancode) {
                    SDL.SCANCODE_ESCAPE,
                    SDL.SCANCODE_BACKSPACE,
                    => {
                        return .ExitMenu;
                    },
                    SDL.SCANCODE_KP_ENTER,
                    SDL.SCANCODE_RETURN,
                    SDL.SCANCODE_SPACE,
                    => {
                        action = .Activate;
                    },
                    SDL.SCANCODE_F11 => {
                        window.toggle_fullscreen();
                    },
                    SDL.SCANCODE_DOWN => {
                        action = .Down;
                    },
                    SDL.SCANCODE_UP => {
                        action = .Up;
                    },
                    SDL.SCANCODE_LEFT => {
                        action = .Left;
                    },
                    SDL.SCANCODE_RIGHT => {
                        action = .Right;
                    },
                    else => {
                        // NOOP
                    },
                }
            },
            else => {
                // NOOP
            },
        }
    }
    return action;
}
