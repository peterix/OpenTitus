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

// TODO: research how Amiga version does sound effects, use those too

const Amiga = @This();

const std = @import("std");
const Mutex = std.Thread.Mutex;

const Backend = @import("Backend.zig");

const _engine = @import("engine.zig");
const AudioEngine = _engine.AudioEngine;

const pocketmod = @import("pocketmod/pocketmod.zig");

// TODO: implement a way to use the original game files from the Amiga version of the game
const track_bonus = @embedFile("amiga/bonus.mod");
const track_cba = @embedFile("amiga/cba.mod");
const track_gagne_ttf = @embedFile("amiga/gagnettf.mod");
const track_gagne_mok = @embedFile("amiga/gagnemok.mod");
const track_jeu1 = @embedFile("amiga/jeu1.mod");
const track_jeu2_ttf = @embedFile("amiga/jeu2ttf.mod");
const track_jeu2_mok = @embedFile("amiga/jeu2mok.mod");
const track_jeu3_ttf = @embedFile("amiga/jeu3ttf.mod");
const track_jeu3_mok = @embedFile("amiga/jeu3mok.mod");
const track_jeu4_ttf = @embedFile("amiga/jeu4ttf.mod");
const track_jeu4_mok = @embedFile("amiga/jeu4mok.mod");
const track_jeu5 = @embedFile("amiga/jeu5.mod");
const track_mort = @embedFile("amiga/mort.mod");
const track_over_ttf = @embedFile("amiga/overttf.mod");
const track_over_mok = @embedFile("amiga/overmok.mod");
const track_pres = @embedFile("amiga/pres.mod");
const track_null: [0]u8 = .{};

allocator: std.mem.Allocator = undefined,
current_track: ?u8 = null,
mutex: Mutex = Mutex{},
sample_rate: u32 = undefined,
music_context: ?pocketmod.pocketmod_context = null,

data: []const u8 = "",
engine: *AudioEngine = undefined,

pub fn backend(self: *Amiga) Backend {
    return .{
        .name = "Amiga",
        .backend_type = .Amiga,
        .ptr = self,
        .vtable = &.{
            .init = init,
            .deinit = deinit,
            .fillBuffer = fillBuffer,
            .playTrack = playTrack,
            .stopTrack = stopTrack,
            .playSfx = play_sfx,
            .isPlayingATrack = isPlayingATrack,
            .lock = lock,
            .unlock = unlock,
        },
    };
}

fn init(ctx: *anyopaque, engine: *AudioEngine, allocator: std.mem.Allocator, sample_rate: u32) Backend.Error!void {
    const self: *Amiga = @ptrCast(@alignCast(ctx));
    self.engine = engine;
    self.allocator = allocator;
    self.mutex = Mutex{};
    self.sample_rate = sample_rate;
}

fn deinit(ctx: *anyopaque) void {
    const self: *Amiga = @ptrCast(@alignCast(ctx));
    self.allocator.free(self.data);
}

fn lock(ctx: *anyopaque) void {
    const self: *Amiga = @ptrCast(@alignCast(ctx));
    self.mutex.lock();
}

fn unlock(ctx: *anyopaque) void {
    const self: *Amiga = @ptrCast(@alignCast(ctx));
    self.mutex.unlock();
}

fn fillBuffer(ctx: *anyopaque, buffer: []i16, nFrames: u32) void {
    if (nFrames == 0) {
        return;
    }
    // TODO: deal with this
    const sample_buffer_size = 32000;
    // we render two channels, f32, which is 8 bytes per frame
    const frameSize = @sizeOf(f32) * 2;
    if (nFrames * frameSize > sample_buffer_size) {
        unreachable;
    }
    var floatBuffer: [sample_buffer_size]f32 = undefined;

    const self: *Amiga = @ptrCast(@alignCast(ctx));
    self.mutex.lock();
    defer self.mutex.unlock();

    if (self.music_context) |*music_context| {
        var rendered: u32 = 0;
        var to_render: u32 = nFrames;
        while (rendered != nFrames) {
            // FIXME: this returns number of bytes instead of number of frames, which is insane
            const rendered_now = pocketmod.pocketmod_render(
                music_context,
                &floatBuffer[rendered * 2],
                to_render * frameSize,
            ) / frameSize;
            for (rendered..rendered + rendered_now) |i| {
                var ii = i * 2;
                buffer[ii] = @intFromFloat(std.math.clamp(floatBuffer[ii], -1.0, 1.0) * std.math.maxInt(i16));
                buffer[ii + 1] = @intFromFloat(std.math.clamp(floatBuffer[ii + 1], -1.0, 1.0) * std.math.maxInt(i16));
            }
            to_render -= rendered_now;
            rendered += rendered_now;
        }
    }
}

fn stopTrack(ctx: *anyopaque, song_number: u8) void {
    const self: *Amiga = @ptrCast(@alignCast(ctx));
    if (self.current_track) |track| {
        if (track == song_number) {
            self.current_track = null;
        }
    }
}

fn playTrack(ctx: *anyopaque, song_number: u8) void {
    const self: *Amiga = @ptrCast(@alignCast(ctx));
    var music_context: pocketmod.pocketmod_context = undefined;
    if (!pocketmod.pocketmod_init(&music_context, track_jeu1.ptr, track_jeu1.len, self.sample_rate)) {
        unreachable;
    }
    self.music_context = music_context;
    self.current_track = song_number;
}

fn isPlayingATrack(ctx: *anyopaque) bool {
    const self: *Amiga = @ptrCast(@alignCast(ctx));
    if (self.current_track) |_| {
        return true;
    }
    return false;
}

fn play_sfx(ctx: *anyopaque, fx_number: u8) void {
    _ = ctx;
    _ = fx_number;
}
