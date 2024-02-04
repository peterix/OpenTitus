const c = @import("../c.zig");
const SDL = @import("../SDL.zig");

const draw = @import("../draw.zig");
const window = @import("../window.zig");
const sprites = @import("../sprites.zig");
const fonts = @import("fonts.zig");
const globals = @import("../globals.zig");
const audio = @import("../audio/engine.zig");

fn continueFn() ?c_int {
    return 0;
}

fn quitFn() ?c_int {
    return -1;
}

fn optionsFn() ?c_int {
    return null;
}

const MenuEntry = struct {
    text: []const u8,
    active: bool,
    handler: *const fn () ?c_int,
};

const menu_entries: []const MenuEntry = &.{
    .{ .text = "Continue", .active = true, .handler = continueFn },
    .{ .text = "Options", .active = false, .handler = optionsFn },
    .{ .text = "Quit", .active = true, .handler = quitFn },
};

fn renderLabel(font: *fonts.Font, text: []const u8, y: i16, selected: bool) void {
    const options = fonts.Font.RenderOptions{ .transpatent = true };
    const label_width = fonts.Gold.metrics(text, options);
    const x = 160 - label_width / 2;
    if (selected) {
        const left = ">";
        const right = "<";
        const left_width = font.metrics(left, .{});
        font.render(left, x - 4 - left_width, y, .{});
        font.render(right, x + label_width + 4, y, .{});
    }
    font.render_center(text, y, options);
}

fn drawMenu(fade: u8, selected: u8, image: *c.SDL_Surface) void {
    _ = c.SDL_SetSurfaceAlphaMod(image, 255 - fade);
    _ = c.SDL_SetSurfaceBlendMode(image, c.SDL_BLENDMODE_BLEND);
    window.window_clear(null);
    _ = c.SDL_BlitSurface(image, null, window.screen, null);
    const title_width = fonts.Gold.metrics("PAUSED", .{ .transpatent = true }) + 4;
    var y: i16 = 40;
    fonts.Gold.render_center("PAUSED", y, .{ .transpatent = true });
    y += 12;
    const bar = c.SDL_Rect{ .x = 160 - title_width / 2, .y = y, .w = title_width, .h = 1 };
    _ = c.SDL_FillRect(window.screen.?, &bar, c.SDL_MapRGB(window.screen.?.format, 0xd0, 0xb0, 0x00));
    y += 27;
    for (menu_entries, 0..) |entry, i| {
        renderLabel(if (entry.active) &fonts.Gold else &fonts.Gray, entry.text, y, selected == i);
        y += 14;
    }
    window.window_render();
}

// FIXME: int is really an error enum, see tituserror.h
pub export fn pauseMenu(context: *c.ScreenContext) c_int {
    const image = c.SDL_ConvertSurface(window.screen.?, window.screen.?.format, c.SDL_SWSURFACE);
    defer c.SDL_FreeSurface(image);

    defer draw.screencontext_reset(context);

    var fade: u8 = 0;
    var selected: u8 = 0;
    while (true) {
        SDL.delay(1);
        fade += 1;
        if (fade > 150) {
            fade = 150;
        }
        drawMenu(fade, selected, image);
        audio.music_restart_if_finished();
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) { //Check all events
            switch (event.type) {
                c.SDL_QUIT => {
                    return c.TITUS_ERROR_QUIT;
                },
                c.SDL_KEYDOWN => {
                    switch (event.key.keysym.scancode) {
                        c.KEY_ESC => {
                            return 0;
                        },
                        c.KEY_ENTER, c.KEY_RETURN, c.KEY_SPACE => {
                            const ret_val = menu_entries[selected].handler();
                            if (ret_val) |value| {
                                return value;
                            }
                        },
                        c.KEY_FULLSCREEN => {
                            window.toggle_fullscreen();
                        },
                        c.KEY_DOWN => {
                            if (selected < menu_entries.len - 1)
                                selected += 1;
                        },
                        c.KEY_UP => {
                            if (selected > 0)
                                selected -= 1;
                        },
                        c.KEY_M => {
                            _ = audio.music_toggle_c();
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
    }
}
