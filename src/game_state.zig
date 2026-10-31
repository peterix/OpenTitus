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
const lvl = @import("level.zig");

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

/// Where to continue the game from: the state a level restarts in when the player dies.
/// That's the level, the last checkpoint and the bonuses collected so far. Everything else starts over.
pub const SavedGame = struct {
    level: u16 = 0,
    lives: u16 = 0,
    extrabonus: u16 = 0,
    checkpoint_x: i16 = 0,
    checkpoint_y: i16 = 0,
    cage_x: i16 = 0,
    cage_y: i16 = 0,
    /// One bit for each entry of the level's bonus list, set when it was collected
    collected: [2]u64 = .{ 0, 0 },
    bonus_collected: usize = 0,
    ticks: usize = 0,
    check: u64 = 0,

    pub fn fromLevel(level: *const lvl.Level) SavedGame {
        var result = SavedGame{
            .level = level.levelnumber,
            .lives = @intCast(level.lives),
            .extrabonus = @intCast(level.extrabonus),
            .checkpoint_x = level.player.initX,
            .checkpoint_y = level.player.initY,
            .cage_x = level.player.cageX,
            .cage_y = level.player.cageY,
            .bonus_collected = level.bonuscollected,
            .ticks = level.tickcount,
        };
        for (level.bonus, 0..) |bonus, i| {
            // A collected bonus has its tile replaced
            if (bonus.exists and level.getTile(bonus.x, bonus.y) != bonus.bonustile) {
                result.collected[i / 64] |= @as(u64, 1) << @intCast(i % 64);
            }
        }
        return result;
    }

    /// Put a freshly loaded level into the saved state
    pub fn apply(self: *const SavedGame, level: *lvl.Level) void {
        level.lives = self.lives;
        level.extrabonus = self.extrabonus;
        level.player.initX = self.checkpoint_x;
        level.player.initY = self.checkpoint_y;
        level.player.cageX = self.cage_x;
        level.player.cageY = self.cage_y;
        level.bonuscollected = self.bonus_collected;
        level.tickcount = self.ticks;
        for (&level.bonus, 0..) |*bonus, i| {
            if (bonus.exists and self.collected[i / 64] & (@as(u64, 1) << @intCast(i % 64)) != 0) {
                level.setTile(bonus.x, bonus.y, bonus.replacetile);
            }
        }
    }

    fn makeCheck(self: *const SavedGame, seed: u32) u64 {
        var buf = [_]u8{0} ** 256;
        const bytes = std.fmt.bufPrint(&buf, "{d}.{d}.{d}.{d}.{d}.{d}.{d}.{d}.{d}.{d}.{d}.{d}", .{
            self.level,
            self.lives,
            self.extrabonus,
            self.checkpoint_x,
            self.checkpoint_y,
            self.cage_x,
            self.cage_y,
            self.collected[0],
            self.collected[1],
            self.bonus_collected,
            self.ticks,
            seed,
        }) catch {
            unreachable;
        };
        return std.hash.Murmur2_64.hash(bytes);
    }
};

/// When false, changes to the game state are kept in memory only (used by the replay)
pub var persist: bool = true;

pub const GameState = struct {
    levels: JsonList(LevelEntry),
    seed: u32 = 0,
    /// The game in progress, if any
    saved_game: ?SavedGame = null,

    pub fn make_new(io: std.Io, allocator: Allocator) !ManagedJSON(GameState) {
        var seed: u32 = undefined;
        std.Io.random(io, std.mem.asBytes(&seed));
        const arena = try allocator.create(std.heap.ArenaAllocator);
        arena.* = std.heap.ArenaAllocator.init(allocator);
        const game_state = GameState{
            .levels = JsonList(LevelEntry){},
            .seed = seed,
        };
        return ManagedJSON(GameState){ .value = game_state, .arena = arena };
    }

    pub fn read(io: std.Io, allocator: Allocator) !ManagedJSON(GameState) {
        const bytes = std.Io.Dir.cwd().readFileAlloc(
            io,
            game_file_name(),
            allocator,
            std.Io.Limit.limited(20000),
        ) catch |err| {
            switch (err) {
                error.FileNotFound => {
                    std.log.info("No game state file found, starting with defaults.", .{});
                    return GameState.make_new(io, allocator);
                },
                error.OutOfMemory => {
                    return error.OutOfMemory;
                },
                else => {
                    std.log.err("Could not understand game state: {}, starting with defaults.", .{err});
                },
            }
            return GameState.make_new(io, allocator);
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
                    return GameState.make_new(io, allocator);
                },
            }
        };

        // loop over the level entries and set their validation status
        for (game_state.levels.list.items, 0..) |*entry, level_index| {
            _ = LevelEntry.validate(entry, game_state.seed, @truncate(level_index));
        }
        return ManagedJSON(GameState){ .arena = arena, .value = game_state };
    }

    pub fn write(self: *GameState, io: std.Io, allocator: Allocator) !void {
        _ = allocator;
        if (!persist) {
            return;
        }
        try json.WriteJSON(io, game_file_name(), self);
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

    /// The game to continue, if there is one and it wasn't tampered with
    pub fn getSavedGame(self: *const GameState) ?SavedGame {
        const saved = self.saved_game orelse return null;
        if (saved.check != saved.makeCheck(self.seed) or saved.level >= data.constants.levelfiles.len) {
            return null;
        }
        return saved;
    }
};

/// Remember where to continue the game from
pub fn save_game(io: std.Io, allocator: std.mem.Allocator, level: *const lvl.Level) !void {
    var saved = SavedGame.fromLevel(level);
    saved.check = saved.makeCheck(game.game_state.seed);
    game.game_state.saved_game = saved;
    try game.game_state.write(io, allocator);
}

/// The game is over, there's nothing to continue
pub fn clear_saved_game(io: std.Io, allocator: std.mem.Allocator) !void {
    if (game.game_state.saved_game == null) {
        return;
    }
    game.game_state.saved_game = null;
    try game.game_state.write(io, allocator);
}

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

pub fn visit_level(io: std.Io, allocator: std.mem.Allocator, level: u16) !void {
    const internal_allocator = game.game_state_mem.arena.*.allocator();
    var entry = try ensure_entry(internal_allocator, level);
    entry.stamp(game.game_state.seed, level);

    try game.game_state.write(io, allocator);
}

pub fn unlock_level(io: std.Io, allocator: std.mem.Allocator, level: u16, lives: c_int) !void {
    const internal_allocator = game.game_state_mem.arena.*.allocator();
    var entry = try ensure_entry(internal_allocator, level);

    entry.lives = @intCast(lives);
    entry.unlocked = true;
    entry.stamp(game.game_state.seed, level);

    try game.game_state.write(io, allocator);
}

pub fn record_completion(io: std.Io, allocator: std.mem.Allocator, level: u16, bonus: usize, ticks: usize) !void {
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

    try game.game_state.write(io, allocator);
}
