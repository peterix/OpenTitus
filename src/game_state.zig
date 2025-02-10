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
const data = @import("data.zig");

const json = @import("json.zig");
const ManagedJSON = json.ManagedJSON;
const JsonList = json.JsonList;

const Allocator = std.mem.Allocator;

// FIXME: this shares a large amount of code with settings.zig... factor it out?

fn game_file_name() []const u8 {
    if (data.game == .Titus) {
        return "titus.json";
    } else {
        return "moktar.json";
    }
}

pub const LevelEntry = struct {
    valid: bool = false,
    unlocked: bool = false,
    lives: ?u16 = 0,
    best_time: ?usize = null,
    most_bonus: ?usize = null,
    completed: bool = false,
    check: u64 = 0,

    fn makeCheck(self: *LevelEntry, seed: u32, level: u16) u64 {
        var buf = [_]u8{0} ** 2048;
        const bytes = std.fmt.bufPrint(&buf, "{d}.{?d}.{d}.{?d}.{?d}.{}.{}", .{
            level,
            self.lives,
            seed,
            self.best_time,
            self.most_bonus,
            self.unlocked,
            self.completed,
        }) catch {
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
        try std.posix.getrandom(std.mem.asBytes(&seed));
        var arena = std.heap.ArenaAllocator.init(allocator);
        const game_state = GameState{
            .levels = JsonList(LevelEntry){},
            .seed = seed,
            .seen_intro = false,
        };
        return ManagedJSON(GameState){ .value = game_state, .arena = &arena };
    }

    pub fn read(allocator: Allocator) !ManagedJSON(GameState) {
        const bytes = std.fs.cwd().readFileAlloc(
            allocator,
            game_file_name(),
            20000,
        ) catch |err| {
            switch (err) {
                error.FileNotFound => {
                    std.log.info("No game state file found, starting with defaults.", .{});
                    return GameState.make_new(allocator);
                },
                error.OutOfMemory => {
                    return error.OutOfMemory;
                },
                else => {
                    std.log.err("Could not understand game state: {}, starting with defaults.", .{err});
                },
            }
            return GameState.make_new(allocator);
        };
        defer allocator.free(bytes);

        var arena = try allocator.create(std.heap.ArenaAllocator);
        arena.* = std.heap.ArenaAllocator.init(allocator);
        const game_state = std.json.parseFromSliceLeaky(
            GameState,
            arena.allocator(),
            bytes,
            .{
                .allocate = .alloc_always,
                .ignore_unknown_fields = true,
                .duplicate_field_behavior = .use_last,
            },
        ) catch |err| {
            switch (err) {
                error.OutOfMemory => {
                    return error.OutOfMemory;
                },
                else => {
                    std.log.err("Could not understand game state: {}, starting with defaults.", .{err});
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
        const bytes = try std.json.stringifyAlloc(allocator, self, .{ .whitespace = .indent_4, .emit_null_optional_fields = false });
        defer allocator.free(bytes);
        try std.fs.cwd().writeFile(.{ .data = bytes, .sub_path = game_file_name() });
    }

    pub fn isUnlocked(self: *GameState, level: usize) bool {
        if (level == 0) {
            return true;
        }
        if (level >= self.levels.list.items.len) {
            return false;
        }
        return self.levels.list.items[level].unlocked and self.levels.list.items[level].valid;
    }
    pub fn isKnown(self: *GameState, level: usize) bool {
        return level == 0 or level < self.levels.list.items.len;
    }
};

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
    const entry = &list.items[level];
    if (!entry.valid) {
        entry.* = LevelEntry{};
    }
    return entry;
}

pub fn visit_level(allocator: std.mem.Allocator, level: u16) !void {
    const internal_allocator = game.game_state_mem.arena.*.allocator();
    var entry = try ensure_entry(internal_allocator, level);
    entry.stamp(game.game_state.seed, level);

    try game.game_state.write(allocator);
}

pub fn unlock_level(allocator: std.mem.Allocator, level: u16, lives: c_int) !void {
    const internal_allocator = game.game_state_mem.arena.*.allocator();
    var entry = try ensure_entry(internal_allocator, level);

    entry.lives = @intCast(lives);
    entry.unlocked = true;
    entry.stamp(game.game_state.seed, level);

    try game.game_state.write(allocator);
}

pub fn record_completion(allocator: std.mem.Allocator, level: u16, bonus: usize, ticks: usize) !void {
    const internal_allocator = game.game_state_mem.arena.*.allocator();
    var entry = try ensure_entry(internal_allocator, level);

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

    try game.game_state.write(allocator);
}
