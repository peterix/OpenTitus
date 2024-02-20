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

const _engine = @import("AudioEngine.zig");
const AudioEngine = _engine.AudioEngine;
const AudioTrack = _engine.AudioTrack;
const AudioEvent = _engine.AudioEvent;

const c = @import("../c.zig");
const data = @import("../data.zig");

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

fn getTrackData(track_in: ?AudioTrack) []const u8 {
    if (track_in == null) {
        return &track_null;
    }
    const track = track_in.?;
    if (data.game == c.Titus) switch (track) {
        .Play1 => return track_jeu1,
        .Play2 => return track_jeu2_ttf,
        .Play3 => return track_jeu3_ttf,
        .Play4 => return track_jeu4_ttf,
        .Play5 => return track_jeu5,
        .Bonus => return track_bonus,
        // Amiga version doesn't really have credits music, so we just reuse title music
        .Credits => return track_pres,
        .Death => return track_mort,
        .GameOver => return track_over_ttf,
        .LevelEnd => return track_cba,
        .MainTitle => return track_pres,
        .Win => return track_gagne_ttf,
    } else switch (track) {
        .Play1 => return track_jeu1,
        .Play2 => return track_jeu2_mok,
        .Play3 => return track_jeu3_mok,
        .Play4 => return track_jeu4_mok,
        .Play5 => return track_jeu5,
        .Bonus => return track_bonus,
        // Amiga version doesn't really have credits music, so we just reuse title music
        .Credits => return track_pres,
        .Death => return track_mort,
        .GameOver => return track_over_mok,
        .LevelEnd => return track_cba,
        .MainTitle => return track_pres,
        .Win => return track_gagne_mok,
    }
}

allocator: std.mem.Allocator = undefined,
current_track: ?AudioTrack = null,
mutex: Mutex = Mutex{},
sample_rate: u32 = undefined,
music_context: ?pocketmod.pocketmod_context = null,

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
            .playEvent = playEvent,
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
    self.current_track = null;
    self.music_context = null;
}

fn deinit(ctx: *anyopaque) void {
    const self: *Amiga = @ptrCast(@alignCast(ctx));
    self.mutex = Mutex{};
    self.sample_rate = undefined;
    self.current_track = null;
    self.music_context = null;
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
            // if we looped, stop playing
            const looped = pocketmod.pocketmod_loop_count(music_context) == 1;
            if (looped) {
                @memset(buffer[rendered * 2 ..], 0);
                self.music_context = null;
                self.current_track = null;
                return;
            }
        }
    }
}

fn playTrack(ctx: *anyopaque, track: ?AudioTrack) void {
    const self: *Amiga = @ptrCast(@alignCast(ctx));
    if (track == null) {
        self.music_context = null;
        self.current_track = null;
    } else {
        var music_context: pocketmod.pocketmod_context = undefined;
        const track_data = getTrackData(track);
        if (!pocketmod.pocketmod_init(&music_context, track_data.ptr, @truncate(track_data.len), self.sample_rate)) {
            unreachable;
        }
        self.music_context = music_context;
        self.current_track = track;
    }
}

// TODO: implement playing original sounds
fn playEvent(ctx: *anyopaque, event: AudioEvent) void {
    _ = ctx;
    _ = event;
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
