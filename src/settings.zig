//
// Copyright (C) 2008 - 2024 The OpenTitus team
//
// Authors:
// Eirik Stople
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

const window = @import("window.zig");
const game = @import("game.zig");
const c = @import("c.zig");

const json = @import("json.zig");
const ManagedJSON = json.ManagedJSON;
const JsonList = json.JsonList;

const Allocator = std.mem.Allocator;

const settings_file_name = "settings.json";

pub const Settings = extern struct {
    devmode: bool = false,
    fullscreen: bool = false,
    music: bool = true,
    sound: bool = true,
    volume_music: u8 = 128,
    volume_sound: u8 = 128,
    volume_master: u8 = 128,
    window_width: u16 = window.game_width * 3,
    window_height: u16 = window.game_height * 3,

    pub fn make_new(allocator: Allocator) !ManagedJSON(Settings) {
        var seed: u32 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        var arena = try allocator.create(std.heap.ArenaAllocator);
        errdefer allocator.destroy(arena);

        arena.* = std.heap.ArenaAllocator.init(allocator);
        errdefer arena.deinit();

        return ManagedJSON(Settings){ .value = Settings{}, .arena = arena };
    }

    pub fn read(allocator: Allocator) !ManagedJSON(Settings) {
        var arena = try allocator.create(std.heap.ArenaAllocator);
        errdefer allocator.destroy(arena);

        arena.* = std.heap.ArenaAllocator.init(allocator);
        errdefer arena.deinit();

        const data = std.fs.cwd().readFileAlloc(allocator, settings_file_name, 20000) catch |err| {
            switch (err) {
                error.FileNotFound => {
                    std.log.info("No settings file found, starting with defaults.", .{});
                    return Settings.make_new(arena.allocator());
                },
                error.OutOfMemory => {
                    return error.OutOfMemory;
                },
                else => {
                    std.log.err("Could not read settings: {}, starting with defaults.", .{err});
                },
            }
            return Settings.make_new(arena.allocator());
        };
        defer allocator.free(data);

        var settings = std.json.parseFromSliceLeaky(
            Settings,
            arena.allocator(),
            data,
            .{ .allocate = .alloc_always },
        ) catch |err| {
            std.log.err("Could not read settings: {}, starting with defaults.", .{err});
            return Settings.make_new(arena.allocator());
        };
        if (settings.volume_music > 128) {
            settings.volume_music = 128;
        }
        if (settings.volume_sound > 128) {
            settings.volume_sound = 128;
        }
        if (settings.volume_master > 128) {
            settings.volume_master = 128;
        }
        if (settings.window_width < window.game_width) {
            settings.window_width = window.game_width;
        }
        if (settings.window_height < window.game_height) {
            settings.window_height = window.game_height;
        }
        return ManagedJSON(Settings){ .value = settings, .arena = arena };
    }

    pub fn write(self: *Settings, allocator: Allocator) !void {
        var data = try std.json.stringifyAlloc(allocator, self, .{ .whitespace = .indent_4, .emit_null_optional_fields = false });
        defer allocator.free(data);
        try std.fs.cwd().writeFile(settings_file_name, data);
    }
};
