//
// Copyright (C) 2024 The OpenTitus team
//
// Authors:
// Petr Mrázek
//
// "Titus the Fox: To Marrakech and Back" (1992) and
// "Lagaf': Les Aventures de Moktar - Vol 1: La Zoubida" (1991)
// was developed by, and is probably copyrighted by Titus Software,
// which, according to Wikipedia, stopped buisness in 2005.
//
// OpenTitus is not affiliated with Titus Software.
//
// OpenTitus is  free software; you can redistribute  it and/or modify
// it under the  terms of the GNU General  Public License as published
// by the Free  Software Foundation; either version 3  of the License,
// or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful, but
// WITHOUT  ANY  WARRANTY;  without   even  the  implied  warranty  of
// MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.   See the GNU
// General Public License for more details.
//

const std = @import("std");

const SDL = @import("../SDL.zig");

const fonts = @import("fonts.zig");
const window = @import("../window.zig");
const audio = @import("../audio/audio.zig");

const events = @import("../events.zig");

const input = @import("../input.zig");
const InputAction = input.InputAction;

const menu = @import("menu.zig");
const hud = @import("hud.zig");
const MenuContext = menu.MenuContext;

const x_baseline = 90;

fn label(text: []const u8, y: i16, selected: bool) void {
    const font = if (selected) &fonts.Gold else &fonts.Gray;
    const options = fonts.Font.RenderOptions{ .transparent = true };
    const label_width = fonts.Gold.metrics(text, options);
    font.render(text, x_baseline - label_width - 4, y, options);
}

/// Right edge of the value column, where the sliders end
fn valueAreaRight() i16 {
    const bracket_width = fonts.Gold.metrics("[", .{ .transparent = true });
    return x_baseline + 4 + @as(i16, @intCast(bracket_width)) - 4 + 128;
}

/// A setting with a few possible values. The current value is in the middle between fixed `<` and `>`.
/// Left and right go through the values.
fn choice(
    comptime T: type,
    values: []const T,
    value: T,
    y: i16,
    selected: bool,
    action: InputAction,
    setter: *const fn (T) void,
) void {
    const options = fonts.Font.RenderOptions{ .transparent = true };
    const index = std.mem.indexOfScalar(T, values, value) orelse 0;
    if (selected) switch (action) {
        .Left => {
            if (index > 0) {
                setter(values[index - 1]);
            }
        },
        .Right => {
            if (index < values.len - 1) {
                setter(values[index + 1]);
            }
        },
        else => {
            // NIL
        },
    };

    // The arrows stay in place
    const left_x: i16 = x_baseline + 4;
    const right_x = valueAreaRight();
    const left_font = if (selected and index > 0) &fonts.Gold else &fonts.Gray;
    const right_font = if (selected and index < values.len - 1) &fonts.Gold else &fonts.Gray;
    left_font.render("<", left_x, y, options);
    right_font.render(">", right_x, y, options);

    // The value goes in the middle between them
    const arrow_width: i16 = @intCast(fonts.Gold.metrics("<", options));
    const center = @divTrunc(left_x + arrow_width + right_x, 2);
    const text = value.str();
    const width: i16 = @intCast(fonts.Gold.metrics(text, options));
    const value_font = if (selected) &fonts.Gold else &fonts.Gray;
    value_font.render(text, center - @divTrunc(width, 2), y, options);
}

fn toggle(
    value: bool,
    y: i16,
    selected: bool,
    action: InputAction,
    setter: *const fn (bool) void,
) void {
    const options = fonts.Font.RenderOptions{ .transparent = true };

    var set_value = value;
    if (selected) switch (action) {
        .Left => {
            set_value = false;
        },
        .Right => {
            set_value = true;
        },
        else => {
            // NIL
        },
    };
    if (set_value != value) {
        setter(set_value);
    }
    var x: u16 = x_baseline + 4;
    {
        const font = if (!value) &fonts.Gold else &fonts.Gray;
        const text = "Off";
        const label_width = fonts.Gold.metrics(text, options);
        font.render(text, x, y, options);
        x += label_width + 4;
    }
    {
        const font = if (value) &fonts.Gold else &fonts.Gray;
        const text = "On";
        const label_width = fonts.Gold.metrics(text, options);
        font.render(text, x, y, options);
        x += label_width + 4;
    }
}

const Color = struct {
    r: u8,
    g: u8,
    b: u8,
};

const gold_colors: []const Color = &.{
    Color{ .r = 0xf0, .g = 0xf0, .b = 0x30 },
    Color{ .r = 0xe0, .g = 0xc0, .b = 0x00 },
    Color{ .r = 0xb0, .g = 0x90, .b = 0x00 },
    Color{ .r = 0x80, .g = 0x60, .b = 0x00 },
};

const grey_colors: []const Color = &.{
    Color{ .r = 0xf0, .g = 0xf0, .b = 0xf0 },
    Color{ .r = 0xe0, .g = 0xe0, .b = 0xe0 },
    Color{ .r = 0xb0, .g = 0xb0, .b = 0xb0 },
    Color{ .r = 0x80, .g = 0x80, .b = 0x80 },
};

fn line(x: i16, y: i16, width: u16, colors: []const Color, index: usize) void {
    var bar = SDL.Rect{ .x = x, .y = y, .w = width, .h = 1 };
    const color = SDL.mapSurfaceRGB(window.screen, colors[index].r, colors[index].g, colors[index].b);
    _ = SDL.fillSurfaceRect(window.screen.?, &bar, color);
}

fn slider(
    comptime T: type,
    value: T,
    comptime min: T,
    comptime max: T,
    comptime step: T,
    comptime scale: T,
    y: i16,
    selected: bool,
    action: InputAction,
    setter: *const fn (T) void,
    event: events.GameEvent,
) void {
    const options = fonts.Font.RenderOptions{ .transparent = true };
    if (@typeInfo(T) != .int) {
        @compileError("slider can only be used with an enum type");
    }
    var set_value = value;
    if (selected) switch (action) {
        .Left => {
            if (value > min) {
                if (value - min < step) {
                    set_value = min;
                }
                else {
                    set_value = value - step;
                }
            }
        },
        .Right => {
            if (value < max) {
                if (max - value < step) {
                    set_value = max;
                }
                else
                {
                    set_value = value + step;
                }
            }
        },
        else => {
            // NIL
        },
    };
    if (set_value != value) {
        setter(set_value);
        if(event != .None) {
            events.triggerEvent(event);
        }
    }
    var x: i16 = x_baseline + 4;
    const font = if (selected) &fonts.Gold else &fonts.Gray;
    const label_width = fonts.Gold.metrics("[", options);
    font.render("[", x, y, options);
    x += @intCast(label_width);
    x -= 2;
    const colors = if (selected) gold_colors else grey_colors;
    for (0..4) |i| {
        line(x, y + 3 + @as(i16, @intCast(i)), set_value * scale, colors, i);
    }
    x += max * scale - 2;
    font.render("]", x, y, options);
}

const Row = enum {
    Audio,
    Music,
    Volume,
    Rumble,
    Status,
    Fullscreen,
};

const rows = std.enums.values(Row);
const audio_backends = std.enums.values(audio.BackendType);

pub fn optionsMenu(menu_context: *MenuContext) ?c_int {
    var selected: usize = 0;
    while (true) {
        const timeout = menu_context.updateBackground();
        SDL.delay(timeout);

        const input_state = input.processEvents();
        switch (input_state.action) {
            .Quit => {
                return -1;// c.TITUS_ERROR_QUIT;
            },
            .Escape, .Cancel => {
                return null;
            },
            .Up => {
                if (selected > 0) {
                    selected -= 1;
                }
            },
            .Down => {
                if (selected < rows.len - 1) {
                    selected += 1;
                }
            },
            else => {},
        }

        menu_context.renderBackground();
        var y: i16 = menu_context.renderTitle("OPTIONS");
        y += 26;

        for (rows, 0..) |row, i| {
            const is_selected = selected == i;
            switch (row) {
                .Audio => {
                    label("Audio", y, is_selected);
                    choice(audio.BackendType, audio_backends, audio.getBackendType(), y, is_selected, input_state.action, audio.setBackendType);
                },
                .Music => {
                    label("Music", y, is_selected);
                    toggle(audio.music_is_playing(), y, is_selected, input_state.action, audio.music_set_playing);
                },
                .Volume => {
                    label("Volume", y, is_selected);
                    slider(u8, audio.get_volume(), 0, 128, 2, 1, y, is_selected, input_state.action, audio.set_volume, .None);
                },
                .Rumble => {
                    label("Rumble", y, is_selected);
                    slider(u8, input.getRumble(), 0, 16, 1, 8, y, is_selected, input_state.action, input.setRumble, .Options_TestRumble);
                },
                .Status => {
                    label("Status", y, is_selected);
                    toggle(hud.isEnabled(), y, is_selected, input_state.action, hud.setEnabled);
                },
                .Fullscreen => {
                    label("Fullscreen", y, is_selected);
                    toggle(window.is_fullscreen(), y, is_selected, input_state.action, window.set_fullscreen);
                },
            }
            y += 13;
        }

        window.window_render();
        audio.music_restart_if_finished();
    }
    unreachable;
}
