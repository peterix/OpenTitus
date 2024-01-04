const std = @import("std");

const window = @import("window.zig");

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
    seen_intro: bool = false,
};

pub fn read(allocator: Allocator) !Settings {
    const data = std.fs.cwd().readFileAlloc(allocator, settings_file_name, 20000) catch |err| {
        switch (err) {
            error.FileNotFound => {
                std.log.info("No settings file found, starting with defaults.", .{});
                return Settings{};
            },
            else => {
                std.log.err("Could not read settings: {}, starting with defaults.", .{err});
            },
        }
        return Settings{};
    };
    defer allocator.free(data);
    var parsed = try std.json.parseFromSlice(Settings, allocator, data, .{ .allocate = .alloc_always });
    var settings = parsed.value;
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
    return settings;
}

pub fn write(allocator: Allocator, settings: Settings) !void {
    var data = try std.json.stringifyAlloc(allocator, settings, .{ .whitespace = .indent_4, .emit_null_optional_fields = false });
    try std.fs.cwd().writeFile(settings_file_name, data);
}
