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

const c = @import("../c.zig");
const SDL = @import("../SDL.zig");

const fonts = @import("fonts.zig");
const window = @import("../window.zig");
const audio = @import("../audio/engine.zig");

const menu = @import("menu.zig");
const MenuAction = menu.MenuAction;
const MenuContext = menu.MenuContext;

fn label(text: []const u8, y: i16, selected: bool) void {
    const font = if (selected) &fonts.Gold else &fonts.Gray;
    const options = fonts.Font.RenderOptions{ .transpatent = true };
    const label_width = fonts.Gold.metrics(text, options);
    font.render(text, 70 - label_width - 4, y, options);
}

// TODO: maybe not... maybe we ask the audio engine for a list of things that managed to load?
const SoundTypes = enum(u8) {
    Adlib = 0,
    Amiga,
    PCSpeaker,

    pub const NameTable = [@typeInfo(SoundTypes).Enum.fields.len][]const u8{
        "AdLib",
        "Amiga",
        "PC-Speaker",
    };

    pub fn str(self: SoundTypes) []const u8 {
        return NameTable[@intFromEnum(self)];
    }
};

var sound_types: SoundTypes = .Adlib;
var music: bool = true;

fn enumOptions(comptime T: type, value: *T, y: i16, selected: bool, action: MenuAction) void {
    if (@typeInfo(T) != .Enum) {
        @compileError("enumOptions can only be used with an enum type");
    }

    const options = fonts.Font.RenderOptions{ .transpatent = true };
    const fields = std.meta.fields(T);

    const intValue = @intFromEnum(value.*);
    var x: u16 = 74;
    inline for (fields, 0..) |f, index| {
        const value_selected = f.value == intValue;
        const enum_value: T = @enumFromInt(f.value);
        if (selected and value_selected) switch (action) {
            .Left => {
                if (index > 0) {
                    value.* = @enumFromInt(fields[index - 1].value);
                }
            },
            .Right => {
                if (index < fields.len - 1) {
                    value.* = @enumFromInt(fields[index + 1].value);
                }
            },
            else => {
                // NIL
            },
        };
        const font = if (value_selected) &fonts.Gold else &fonts.Gray;
        const text = enum_value.str();
        const label_width = fonts.Gold.metrics(text, options);
        font.render(text, x, y, options);
        x += label_width + 4;
    }
}

fn toggle(
    value: bool,
    y: i16,
    selected: bool,
    action: MenuAction,
    setter: *const fn (bool) void,
) void {
    const options = fonts.Font.RenderOptions{ .transpatent = true };

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
    var x: u16 = 74;
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
    var bar = c.SDL_Rect{ .x = x, .y = y, .w = width, .h = 1 };
    const color = c.SDL_MapRGB(window.screen.?.format, colors[index].r, colors[index].g, colors[index].b);
    _ = c.SDL_FillRect(window.screen.?, &bar, color);
}

fn slider(
    comptime T: type,
    value: T,
    comptime min: T,
    comptime max: T,
    y: i16,
    selected: bool,
    action: MenuAction,
    setter: *const fn (u8) void,
) void {
    const options = fonts.Font.RenderOptions{ .transpatent = true };
    if (@typeInfo(T) != .Int) {
        @compileError("slider can only be used with an enum type");
    }
    var set_value = value;
    if (selected) switch (action) {
        .Left => {
            if (value > min) {
                set_value = value - 2;
            }
        },
        .Right => {
            if (value < max) {
                set_value = value + 2;
            }
        },
        else => {
            // NIL
        },
    };
    if (set_value != value) {
        setter(set_value);
    }
    var x: i16 = 74;
    const font = if (selected) &fonts.Gold else &fonts.Gray;
    const label_width = fonts.Gold.metrics("[", options);
    font.render("[", x, y, options);
    x += @intCast(label_width);
    x -= 2;
    const colors = if (selected) gold_colors else grey_colors;
    for (0..4) |i| {
        line(x, y + 3 + @as(i16, @intCast(i)), set_value, colors, i);
    }
    x += max - 2;
    font.render("]", x, y, options);
}

pub fn optionsMenu(menu_context: *MenuContext) ?c_int {
    var selected: u8 = 0;
    while (true) {
        const timeout = menu_context.updateBackground();
        SDL.delay(timeout);

        const action = menu.getMenuAction();
        switch (action) {
            .Quit => {
                return c.TITUS_ERROR_QUIT;
            },
            .ExitMenu => {
                return null;
            },
            .Up => {
                if (selected > 0) {
                    selected -= 1;
                }
            },
            .Down => {
                if (selected < 2) {
                    selected += 1;
                }
            },
            else => {},
        }

        menu_context.renderBackground();
        const title_width = fonts.Gold.metrics("OPTIONS", .{ .transpatent = true }) + 4;
        var y: i16 = 8;
        fonts.Gold.render_center("OPTIONS", y, .{ .transpatent = true });
        y += 12;
        const bar = c.SDL_Rect{ .x = 160 - title_width / 2, .y = y, .w = title_width, .h = 1 };
        _ = c.SDL_FillRect(window.screen.?, &bar, c.SDL_MapRGB(window.screen.?.format, 0xd0, 0xb0, 0x00));
        y += 27;

        label("Audio", y, selected == 0);
        enumOptions(
            SoundTypes,
            &sound_types,
            y,
            selected == 0,
            action,
        );
        y += 13;
        label("Music", y, selected == 1);
        toggle(
            audio.music_is_playing(),
            y,
            selected == 1,
            action,
            audio.music_set_playing,
        );
        y += 13;
        label("Volume", y, selected == 2);
        slider(
            u8,
            audio.get_volume(),
            0,
            128,
            y,
            selected == 2,
            action,
            audio.set_volume,
        );
        y += 13;
        window.window_render();
        audio.music_restart_if_finished();
    }
    unreachable;
}
