//
// Copyright (C) 2026 The OpenTitus team
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

//! Deterministic replay, for checking that changes to the game logic don't change how the game behaves.
//!
//! Plays every level with scripted input (the same every time) and prints fingerprints of the whole game state.
//! The game has no randomness, so the same code always prints the same fingerprints. Save the output before
//! a refactor and compare it with the output after:
//!
//!     zig build replay > before.txt
//!     (change the code)
//!     zig build replay > after.txt
//!     diff before.txt after.txt
//!
//! Runs without a visible window (SDL's offscreen video driver) and without audio. God mode is on, so the
//! player doesn't die and each level runs for the whole replay, unless it ends early (like the boss levels).

const std = @import("std");

const lvl = @import("level.zig");
const globals = @import("globals.zig");
const input = @import("input.zig");
const engine = @import("engine.zig");
const reset = @import("reset.zig");
const scroll = @import("scroll.zig");
const render = @import("render.zig");
const data = @import("data.zig");

pub const default_frames = 3000;

/// Print a fingerprint every this many frames, to see roughly when things start to differ
const checkpoint_interval = 250;

var seed: u64 = 0;
var frame: usize = 0;

/// Pseudo-random input that changes every 24 frames: walking, jumping, crouching, climbing, grabbing and throwing
fn scriptedInput(state: *input.InputState) void {
    const segment: u64 = frame / 24;
    var r: u64 = seed *% 0x9E3779B97F4A7C15 +% segment *% 0xBF58476D1CE4E5B9;
    r ^= r >> 31;
    r *%= 0x94D049BB133111EB;
    r ^= r >> 29;
    const phase = frame % 24;
    state.x_axis = @as(i8, @intCast(r % 3)) - 1;
    state.crouch_pressed = (r >> 5) % 7 == 0;
    state.y_axis = if (state.crouch_pressed) 1 else if ((r >> 11) % 6 == 0) -1 else 0;
    state.jump_pressed = (r >> 3) % 4 == 0 and phase < 6;
    state.action_pressed = (r >> 8) % 5 == 0 and phase >= 10 and phase < 13;
    state.aim_direction = .Forward;
}

/// Hash all the plain values in `value`, skipping pointers
fn hashValue(hasher: *std.hash.Wyhash, value: anytype) void {
    switch (@typeInfo(@TypeOf(value))) {
        .int => |info| {
            // Debug builds fill undefined memory with 0xAA. Hash it the same no matter the type of the field.
            if (info.bits % 8 == 0 and info.bits <= 64) {
                const Unsigned = std.meta.Int(.unsigned, info.bits);
                const pattern: Unsigned = @truncate(@as(u64, 0xAAAAAAAAAAAAAAAA));
                if (@as(Unsigned, @bitCast(value)) == pattern) {
                    hasher.update("U");
                    return;
                }
            }
            const wide: i128 = value;
            hasher.update(std.mem.asBytes(&wide));
        },
        .bool => hasher.update(if (value) "1" else "0"),
        .@"enum" => {
            const wide: i128 = @intFromEnum(value);
            hasher.update(std.mem.asBytes(&wide));
        },
        .@"struct" => |info| inline for (info.fields) |field| hashValue(hasher, @field(value, field.name)),
        .array => for (value) |element| hashValue(hasher, element),
        .optional => if (value) |inner| {
            hasher.update("s");
            hashValue(hasher, inner);
        } else hasher.update("n"),
        else => {},
    }
}

fn hashState(previous: u64, level: *const lvl.Level) u64 {
    var hasher = std.hash.Wyhash.init(previous);
    hashValue(&hasher, level.player);
    hashValue(&hasher, level.object);
    for (level.enemy) |enemy| {
        // Disabled enemies have undefined sprites
        if (enemy.sprite.enabled) {
            hashValue(&hasher, enemy);
        }
    }
    hashValue(&hasher, level.trash);
    hashValue(&hasher, level.elevator);
    hashValue(&hasher, level.bonuscollected);
    inline for (@typeInfo(globals).@"struct".decls) |decl| {
        hashValue(&hasher, @field(globals, decl.name));
    }
    return hasher.final();
}

/// Play all levels of the current game and print the fingerprints to `out`
pub fn run(io: std.Io, allocator: std.mem.Allocator, out: *std.Io.Writer, frames: usize) !void {
    var context = render.ScreenContext{};
    var level: lvl.Level = undefined;
    level.lives = 2;
    level.extrabonus = 0;

    try engine.loadSprites(io, allocator);
    defer engine.unloadSprites();

    input.scripted_input = scriptedInput;
    defer input.scripted_input = null;

    try out.print("replay of {s}, {d} frames per level\n", .{ @tagName(data.game), frames });

    level.levelnumber = 0;
    while (level.levelnumber < data.constants.levelfiles.len) : (level.levelnumber += 1) {
        if (try engine.loadLevel(io, allocator, &level) < 0) {
            return error.CannotLoadLevel;
        }
        defer lvl.freelevel(&level, allocator);

        reset.CLEAR_DATA(&level);
        globals.GODMODE = true;
        scroll.scrollToPlayer(&level);
        seed = level.levelnumber + 1;

        var fingerprint: u64 = 0;
        var ended: []const u8 = "ran out of frames";
        frame = 0;
        while (frame < frames) : (frame += 1) {
            if (engine.updateFrame(io, &context, &level) == -1) {
                ended = "quit";
                break;
            }
            fingerprint = hashState(fingerprint, &level);
            if (frame % checkpoint_interval == checkpoint_interval - 1) {
                try out.print("level {d:>2} frame {d:>5} {x:0>16}\n", .{ level.levelnumber + 1, frame + 1, fingerprint });
            }
            if (globals.NEWLEVEL_FLAG or globals.GAMEOVER_FLAG or globals.RESETLEVEL_FLAG == 1) {
                ended = "level ended";
                break;
            }
        }
        try out.print("level {d:>2} end after {d} frames ({s}) {x:0>16}\n", .{ level.levelnumber + 1, frame, ended, fingerprint });
        try out.flush();
    }
}
