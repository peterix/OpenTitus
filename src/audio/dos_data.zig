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

//! Loads the AdLib music and sound effect data straight out of the original DOS executables.
//!
//! Titus the Fox ships `FOX.COM`, which is packed with ZIVpack (see `sqz.unZIV`).
//! Moktar ships an unpacked `MOKTAR.EXE`.
//!
//! The music driver keeps all of its data in the data segment of the game. Instead of hardcoding
//! file offsets for each known executable, we find the driver code by its byte signatures and read
//! the data segment and table addresses out of the instructions themselves.

const std = @import("std");
const Allocator = std.mem.Allocator;

const sqz = @import("../sqz.zig");
const data = @import("../data.zig");

pub const Error = error{
    ExecutableNotFound,
    InvalidExecutable,
    DriverNotFound,
};

pub const MusicData = struct {
    /// The whole unpacked executable. Owned.
    executable: []u8,
    /// The initialized part of the data segment. All the pointers in the music data are offsets into this.
    data_segment: []const u8,
    /// Offset of the table of channel pointers for each song (each song terminated by 0xFFFF)
    music_table: u16,
    /// Offset of the table of instrument pointers for each song (each song terminated by 0xFFFF)
    instrument_table: u16,
    /// Offset of the table of sound effect instrument pointers. Moktar has no AdLib sound effects.
    sfx_table: ?u16,

    pub fn deinit(self: *MusicData, allocator: Allocator) void {
        allocator.free(self.executable);
        self.* = undefined;
    }
};

const Executable = struct {
    dir: []const u8,
    name: []const u8,
};

fn getExecutable(game: data.GameType) ?Executable {
    return switch (game) {
        .Titus => .{ .dir = "TITUS", .name = "FOX.COM" },
        .Moktar => .{ .dir = "MOKTAR", .name = "MOKTAR.EXE" },
        .None => null,
    };
}

/// Find `pattern` in `haystack`, where `null` in the pattern matches any byte.
fn findPattern(haystack: []const u8, pattern: []const ?u8) ?usize {
    if (haystack.len < pattern.len) {
        return null;
    }
    outer: for (0..haystack.len - pattern.len + 1) |i| {
        for (pattern, 0..) |maybe_byte, j| {
            if (maybe_byte) |byte| {
                if (haystack[i + j] != byte) {
                    continue :outer;
                }
            }
        }
        return i;
    }
    return null;
}

test "findPattern" {
    const haystack = [_]u8{ 0x00, 0xFC, 0xB8, 0x8F, 0x06, 0x8E, 0xD8 };
    try std.testing.expectEqual(@as(?usize, 1), findPattern(&haystack, &.{ 0xFC, 0xB8, null, null, 0x8E, 0xD8 }));
    try std.testing.expectEqual(@as(?usize, null), findPattern(&haystack, &.{ 0xFC, 0xB9 }));
}

inline fn getWord(bytes: []const u8, offset: usize) u16 {
    return std.mem.readInt(u16, bytes[offset..][0..2], .little);
}

// cld; mov ax, DATA_SEGMENT; mov ds, ax; dec byte [skip_counter]
// Start of the music tick routine called from the timer interrupt.
const pattern_data_segment = [_]?u8{ 0xFC, 0xB8, null, null, 0x8E, 0xD8, 0xFE, 0x0E };

// mov bx, MUSIC_TABLE; mov cx, ax; jcxz +10; (skip songs until 0xFFFF)...; mov cx, ax; mov ax, bx; mov bx, INSTRUMENT_TABLE; jcxz +10
// Part of the 'play song' routine.
const pattern_tables = [_]?u8{
    0xBB, null, null, 0x8B, 0xC8, 0xE3, 0x0A, 0x43, 0x43, 0x83, 0x7F, 0xFE, 0xFF, 0x75, 0xF8, 0xE2, 0xF6,
    0x8B, 0xC8, 0x8B, 0xC3, 0xBB, null, null, 0xE3, 0x0A,
};

// mov word [sfx_time], 15; mov bl, al; xor bh, bh; shl bx, 1; mov bx, [bx + SFX_TABLE]
// Part of the 'play sound effect' routine. Only in Titus the Fox.
const pattern_sfx = [_]?u8{ 0xC7, 0x06, null, null, 0x0F, 0x00, 0x8A, 0xD8, 0x32, 0xFF, 0xD1, 0xE3, 0x8B, 0x9F, null, null };

/// Locate the music driver data inside an unpacked MZ executable.
fn findMusicData(executable: []u8) Error!MusicData {
    if (executable.len < 0x1C or !std.mem.eql(u8, executable[0..2], "MZ")) {
        return Error.InvalidExecutable;
    }
    const header_size = @as(usize, getWord(executable, 0x08)) * 16;
    if (header_size >= executable.len) {
        return Error.InvalidExecutable;
    }
    const image = executable[header_size..];

    const ds_at = findPattern(image, &pattern_data_segment) orelse return Error.DriverNotFound;
    const data_segment_start = @as(usize, getWord(image, ds_at + 2)) * 16;
    if (data_segment_start >= image.len) {
        return Error.InvalidExecutable;
    }
    const data_segment = image[data_segment_start..];

    const tables_at = findPattern(image, &pattern_tables) orelse return Error.DriverNotFound;
    const music_table = getWord(image, tables_at + 1);
    const instrument_table = getWord(image, tables_at + 22);
    if (music_table >= data_segment.len or instrument_table >= data_segment.len) {
        return Error.InvalidExecutable;
    }

    var sfx_table: ?u16 = null;
    if (findPattern(image, &pattern_sfx)) |sfx_at| {
        sfx_table = getWord(image, sfx_at + 14);
        if (sfx_table.? >= data_segment.len) {
            return Error.InvalidExecutable;
        }
    }

    return .{
        .executable = executable,
        .data_segment = data_segment,
        .music_table = music_table,
        .instrument_table = instrument_table,
        .sfx_table = sfx_table,
    };
}

/// Load and unpack the game executable and locate the music data in it.
pub fn load(io: std.Io, allocator: Allocator, game: data.GameType) !MusicData {
    const exe_info = getExecutable(game) orelse return Error.ExecutableNotFound;
    const file_data = data.readGameFile(io, allocator, exe_info.dir, exe_info.name) catch |err| switch (err) {
        error.FileNotFound => return Error.ExecutableNotFound,
        else => return err,
    };

    var executable = file_data;
    if (!std.mem.startsWith(u8, file_data, "MZ")) {
        defer allocator.free(file_data);
        executable = sqz.unZIV(file_data, allocator) catch return Error.InvalidExecutable;
    }
    errdefer allocator.free(executable);

    return findMusicData(executable);
}
