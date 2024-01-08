const std = @import("std");

const window = @import("window.zig");
const game = @import("game.zig");
const c = @import("c.zig");

const memory = @import("memory.zig");
const ManagedJSON = memory.ManagedJSON;
const JsonList = memory.JsonList;

const Allocator = std.mem.Allocator;

const settings_file_name = "settings.json";

fn game_file_name() []const u8 {
    if (game.game == c.Titus) {
        return "titus.json";
    } else {
        return "moktar.json";
    }
}

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
                else => {
                    std.log.err("Could not read settings: {}, starting with defaults.", .{err});
                },
            }
            return Settings.make_new(arena.allocator());
        };
        defer allocator.free(data);

        var settings = try std.json.parseFromSliceLeaky(Settings, arena.allocator(), data, .{ .allocate = .alloc_always });
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

pub const LevelEntry = struct {
    valid: bool = false,
    unlocked: bool = false,
    lives: ?u16 = 0,
    best_time: ?usize = null,
    most_bonus: ?usize = null,
    completed: bool = false,
    check: u64 = 0,

    fn makeCheck(self: *LevelEntry, seed: u32, level: u16) u64 {
        var buf: [2048]u8 = .{};
        const bytes = std.fmt.bufPrint(&buf, "{d}.{?d}.{d}.{?d}.{?d}.{}.{}", .{ level, self.lives, seed, self.best_time, self.most_bonus, self.unlocked, self.completed }) catch {
            unreachable;
        };
        return std.hash.Murmur2_64.hash(bytes);
    }

    fn stamp(self: *LevelEntry, seed: u32, level: u16) void {
        self.check = self.makeCheck(seed, level);
        self.valid = true;
    }

    fn validate(self: *LevelEntry, seed: u32, level: u16) bool {
        const check = self.makeCheck(seed, level);
        self.valid = self.check == check;
        return self.valid;
    }
};

pub const GameState = struct {
    levels: JsonList(LevelEntry),
    seen_intro: bool = false,
    seed: u32 = 0,

    pub fn make_new(allocator: Allocator) !ManagedJSON(GameState) {
        var seed: u32 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        var arena = std.heap.ArenaAllocator.init(allocator);
        const game_state = GameState{
            .levels = JsonList(LevelEntry){},
            .seed = seed,
            .seen_intro = false,
        };
        return ManagedJSON(GameState){ .value = game_state, .arena = &arena };
    }

    pub fn read(allocator: Allocator) !ManagedJSON(GameState) {
        const data = std.fs.cwd().readFileAlloc(allocator, game_file_name(), 20000) catch |err| {
            switch (err) {
                error.FileNotFound => {
                    std.log.info("No game state file found, starting with defaults.", .{});
                    return GameState.make_new(allocator);
                },
                error.OutOfMemory => {
                    return error.OutOfMemory;
                },
                else => {
                    std.log.err("Could not read game state: {}, starting with defaults.", .{err});
                },
            }
            return GameState.make_new(allocator);
        };
        defer allocator.free(data);

        var arena = try allocator.create(std.heap.ArenaAllocator);
        arena.* = std.heap.ArenaAllocator.init(allocator);
        var game_state = std.json.parseFromSliceLeaky(GameState, arena.allocator(), data, .{ .allocate = .alloc_always }) catch |err| {
            switch (err) {
                error.OutOfMemory => {
                    return error.OutOfMemory;
                },
                else => {
                    std.log.err("Could not understand game state file: {}, starting with defaults.", .{err});
                    return GameState.make_new(allocator);
                },
            }
        };

        // loop over the level entries and set their validation status
        for (game_state.levels.list.items, 0..) |*entry, level_index| {
            _ = LevelEntry.validate(entry, game_state.seed, @truncate(level_index));
        }
        return ManagedJSON(GameState){ .arena = arena, .value = game_state };
    }

    pub fn write(self: *GameState, allocator: Allocator) !void {
        var data = try std.json.stringifyAlloc(allocator, self, .{ .whitespace = .indent_4, .emit_null_optional_fields = false });
        defer allocator.free(data);
        try std.fs.cwd().writeFile(game_file_name(), data);
    }
};

// FIXME: called from C... so we can't use a good allocator.
// FIXME: this is kinda ugly... to manipulate the values, we need to know the wrapper
const c_alloc = std.heap.c_allocator;

fn ensure_entry(allocator: std.mem.Allocator, level: u16) !*LevelEntry {
    var list = &game.game_state.levels.list;
    if (list.items.len < level) {
        try list.appendNTimes(
            allocator,
            LevelEntry{},
            level,
        );
    }
    // if we are adding a fresh one...
    if (list.items.len == level) {
        try list.append(allocator, LevelEntry{});
    }
    var entry = &list.items[level];
    if (!entry.valid) {
        entry.* = LevelEntry{};
    }
    return entry;
}

pub export fn game_unlock_level(level: u16, lives: c_int) void {
    var allocator = game.game_state_mem.arena.*.allocator();
    var entry = ensure_entry(allocator, level) catch {
        // Errors go WHEEEE
        return;
    };

    entry.lives = @intCast(lives);
    entry.unlocked = true;
    entry.stamp(game.game_state.seed, level);

    game.game_state.write(c_alloc) catch {
        // Errors go WHEEEE
        return;
    };
}

pub export fn game_record_completion(level: u16, bonus: usize, ticks: usize) void {
    var allocator = game.game_state_mem.arena.*.allocator();
    var entry = ensure_entry(allocator, level) catch {
        // Errors go WHEEEE
        return;
    };

    if (entry.best_time == null) {
        entry.best_time = ticks;
    } else {
        if (ticks < entry.best_time.?) {
            entry.best_time = ticks;
        }
    }

    if (entry.most_bonus == null) {
        entry.most_bonus = bonus;
    } else {
        if (bonus > entry.most_bonus.?) {
            entry.most_bonus = bonus;
        }
    }
    entry.completed = true;
    entry.stamp(game.game_state.seed, level);

    game.game_state.write(c_alloc) catch {
        // Errors go WHEEEE
        return;
    };
}
