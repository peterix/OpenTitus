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

//! Loads the music of the Amiga versions from the original files.
//!
//! Each song is a `.PAT` file: a compressed 15-instrument Soundtracker module without any sample data.
//! The samples are separate files, named by the instrument names in the module (`kiki`, `cristelle`, ...).
//! We put the two back together as a 31-instrument ProTracker (M.K.) module that pocketmod can play.

const std = @import("std");
const Allocator = std.mem.Allocator;

const data = @import("../data.zig");
const AudioTrack = @import("audio.zig").AudioTrack;

pub const Error = error{
    InvalidFile,
    NotImplemented,
};

/// Header: compression method (u8), unused (u8), unpacked size (u32 little endian)
const HeaderSize = 6;
const MethodStored = 0;
const MethodLZW = 2;

/// Decompress a `.PAT` file (or any other file using the same packer).
///
/// Method 2 is LZW exactly like the Unix `compress` tool: the first byte is the maximum code width,
/// codes start at 9 bits, are packed LSB first, and are read in groups of `code width` bytes.
/// Code 256 clears the dictionary. (Method 1 exists in the game too, but no music uses it.)
pub fn decompress(input: []const u8, allocator: Allocator) ![]u8 {
    if (input.len < HeaderSize) {
        return Error.InvalidFile;
    }
    const method = input[0];
    const size = std.mem.readInt(u32, input[2..6], .little);
    const packed_data = input[HeaderSize..];

    const output = try allocator.alloc(u8, size);
    errdefer allocator.free(output);

    switch (method) {
        MethodStored => {
            if (packed_data.len < size) {
                return Error.InvalidFile;
            }
            @memcpy(output, packed_data[0..size]);
        },
        MethodLZW => try lzwDecode(packed_data, output),
        else => return Error.NotImplemented,
    }
    return output;
}

const LzwReader = struct {
    input: []const u8,
    /// Start of the next group of bytes in the input
    position: usize = 0,
    group: [16]u8 = undefined,
    group_bits: usize = 0,
    bit_offset: usize = 0,
    code_bits: u5 = 9,
    max_bits: u5,
    max_code: u32 = (1 << 9) - 1,
    clear: bool = false,

    /// Read the next code. `next_free` is the next free dictionary slot, the code width grows when it outgrows it.
    fn next(self: *LzwReader, next_free: u32) ?u32 {
        if (self.clear or self.bit_offset >= self.group_bits or next_free > self.max_code) {
            if (next_free > self.max_code) {
                self.code_bits += 1;
                self.max_code = if (self.code_bits == self.max_bits) (@as(u32, 1) << self.max_bits) else (@as(u32, 1) << self.code_bits) - 1;
            }
            self.clear = false;
            // Each group holds 8 codes, the reader skips any left over bits when it moves on to the next group
            const count: usize = @min(@as(usize, self.code_bits), self.input.len - self.position);
            if (count == 0) {
                return null;
            }
            @memset(&self.group, 0);
            @memcpy(self.group[0..count], self.input[self.position..][0..count]);
            self.position += count;
            self.bit_offset = 0;
            // The last code has to fit entirely
            self.group_bits = (count * 8) -| (self.code_bits - 1);
        }
        const byte = self.bit_offset / 8;
        const window = std.mem.readInt(u32, self.group[byte..][0..4], .little);
        const shift: u5 = @intCast(self.bit_offset % 8);
        const code = (window >> shift) & ((@as(u32, 1) << self.code_bits) - 1);
        self.bit_offset += self.code_bits;
        return code;
    }
};

fn lzwDecode(input: []const u8, output: []u8) !void {
    if (output.len == 0) {
        return;
    }
    if (input.len < 1 or input[0] < 9 or input[0] > 12) {
        return Error.InvalidFile;
    }
    const ClearCode = 256;
    const FirstCode = 257;
    const TableSize = 1 << 12;

    var reader: LzwReader = .{ .input = input[1..], .max_bits = @intCast(input[0]) };
    const max_entries = @as(u32, 1) << reader.max_bits;

    var prefix: [TableSize]u16 = undefined;
    var suffix: [TableSize]u8 = undefined;
    var stack: [TableSize]u8 = undefined;
    var next_free: u32 = FirstCode;

    var old_code = reader.next(next_free) orelse return Error.InvalidFile;
    if (old_code > 255) {
        return Error.InvalidFile;
    }
    var first_char: u8 = @intCast(old_code);
    var out_pos: usize = 0;
    output[out_pos] = first_char;
    out_pos += 1;

    while (out_pos < output.len) {
        var code = reader.next(next_free) orelse break;
        if (code == ClearCode) {
            next_free = ClearCode;
            reader.clear = true;
            reader.code_bits = 9;
            reader.max_code = (1 << 9) - 1;
            code = reader.next(next_free) orelse break;
        }
        const in_code = code;

        var depth: usize = 0;
        if (code >= next_free) {
            // KwKwK case: the code is the one we are about to add
            if (code > next_free) {
                return Error.InvalidFile;
            }
            stack[depth] = first_char;
            depth += 1;
            code = old_code;
        }
        while (code >= 256) {
            if (depth >= stack.len) {
                return Error.InvalidFile;
            }
            stack[depth] = suffix[code];
            depth += 1;
            code = prefix[code];
        }
        first_char = @intCast(code);
        stack[depth] = first_char;
        depth += 1;

        while (depth > 0 and out_pos < output.len) {
            depth -= 1;
            output[out_pos] = stack[depth];
            out_pos += 1;
        }

        if (next_free < max_entries) {
            prefix[next_free] = @intCast(old_code);
            suffix[next_free] = first_char;
            next_free += 1;
        }
        old_code = in_code;
    }
    if (out_pos != output.len) {
        return Error.InvalidFile;
    }
}

test "decompress LZW" {
    // "abababab" as the codes 'a', 'b', 257 ("ab"), 259 ("aba"), 'b'
    const input = [_]u8{ 2, 0, 8, 0, 0, 0, 12, 0x61, 0xC4, 0x04, 0x1C, 0x28, 0x06 };
    const output = try decompress(&input, std.testing.allocator);
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("abababab", output);
}

/// Name of the `.PAT` file for a track
fn getTrackFile(game: data.GameType, track: AudioTrack) []const u8 {
    return switch (track) {
        .Play1 => "jeu1.pat",
        .Play2 => if (game == .Moktar) "jeu2.pat" else "jeu22.pat",
        .Play3 => if (game == .Moktar) "jeu3.pat" else "jeu32.pat",
        .Play4 => if (game == .Moktar) "jeu4.pat" else "jeu42.pat",
        .Play5 => "jeu5.pat",
        .Bonus => "bonus.pat",
        // Amiga version doesn't really have credits music, so we just reuse title music
        .Credits, .MainTitle => "pres2.pat",
        .Death => "mort.pat",
        .GameOver => if (game == .Moktar) "over.pat" else "over2.pat",
        .LevelEnd => "cba1.pat",
        .Win => if (game == .Moktar) "gagne.pat" else "gagne2.pat",
    };
}

const OldHeaderSize = 600;
const SampleRecordsOffset = 20;
const SampleRecordSize = 30;
const OldSampleCount = 15;
const OldOrderOffset = 470;
const NewHeaderSize = 1084;
const NewOrderOffset = 950;
const PatternSize = 1024;

/// Load a track from the given directory and turn it into a ProTracker module. Caller owns the result.
pub fn loadTrack(io: std.Io, allocator: Allocator, dir: []const u8, game: data.GameType, track: AudioTrack) ![]u8 {
    const file_name = getTrackFile(game, track);
    const packed_data = try data.readGameFile(io, allocator, dir, file_name);
    defer allocator.free(packed_data);
    const song = try decompress(packed_data, allocator);
    defer allocator.free(song);

    if (song.len < OldHeaderSize) {
        return Error.InvalidFile;
    }
    const song_length = song[OldOrderOffset];
    if (song_length == 0 or song_length > 128) {
        return Error.InvalidFile;
    }
    var pattern_count: usize = 0;
    for (song[OldOrderOffset + 2 ..][0..128]) |pattern| {
        pattern_count = @max(pattern_count, @as(usize, pattern) + 1);
    }
    const pattern_bytes = pattern_count * PatternSize;
    if (song.len < OldHeaderSize + pattern_bytes) {
        return Error.InvalidFile;
    }

    var sample_bytes: usize = 0;
    for (0..OldSampleCount) |i| {
        sample_bytes += sampleLength(song, i);
    }

    const module = try allocator.alloc(u8, NewHeaderSize + pattern_bytes + sample_bytes);
    errdefer allocator.free(module);
    @memset(module, 0);

    // Title and the 15 sample records stay where they are
    @memcpy(module[0 .. SampleRecordsOffset + OldSampleCount * SampleRecordSize], song[0 .. SampleRecordsOffset + OldSampleCount * SampleRecordSize]);
    // The 16 extra sample records are unused, with the customary loop length of 1 word
    for (OldSampleCount..31) |i| {
        module[SampleRecordsOffset + i * SampleRecordSize + 29] = 1;
    }
    // Song length, restart position and the order table
    @memcpy(module[NewOrderOffset..][0..130], song[OldOrderOffset..][0..130]);
    @memcpy(module[1080..1084], "M.K.");
    @memcpy(module[NewHeaderSize..][0..pattern_bytes], song[OldHeaderSize..][0..pattern_bytes]);

    var sample_out = module[NewHeaderSize + pattern_bytes ..];
    for (0..OldSampleCount) |i| {
        const length = sampleLength(song, i);
        if (length == 0) {
            continue;
        }
        const name_bytes = song[SampleRecordsOffset + i * SampleRecordSize ..][0..22];
        const name = name_bytes[0 .. std.mem.indexOfScalar(u8, name_bytes, 0) orelse name_bytes.len];
        if (name.len > 0) {
            const sample_file = try data.readGameFile(io, allocator, dir, name);
            defer allocator.free(sample_file);
            // Like the game: two zero bytes, then the file. Anything the file doesn't cover stays silent.
            const count = @min(length - 2, sample_file.len);
            @memcpy(sample_out[2..][0..count], sample_file[0..count]);
        }
        sample_out = sample_out[length..];
    }
    return module;
}

/// Sample length in bytes, as declared in the song
fn sampleLength(song: []const u8, index: usize) usize {
    const record = song[SampleRecordsOffset + index * SampleRecordSize ..];
    const words = std.mem.readInt(u16, record[22..24], .big);
    // Lengths of 1 word or less mean 'no sample'
    return if (words > 1) @as(usize, words) * 2 else 0;
}
