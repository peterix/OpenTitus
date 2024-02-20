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

const Silence = @This();

const std = @import("std");

const Backend = @import("Backend.zig");

const _engine = @import("engine.zig");
const AudioEngine = _engine.AudioEngine;

pub fn backend(self: *Silence) Backend {
    return .{
        .name = "Silence",
        .backend_type = .Silence,
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
    _ = ctx;
    _ = allocator;
    _ = sample_rate;
    _ = engine;
}

fn deinit(ctx: *anyopaque) void {
    _ = ctx;
}

fn lock(ctx: *anyopaque) void {
    _ = ctx;
}

fn unlock(ctx: *anyopaque) void {
    _ = ctx;
}

fn fillBuffer(ctx: *anyopaque, buffer: []i16, nsamples: u32) void {
    _ = ctx;
    if (nsamples > 0) {
        //pocketmod.OPL3_GenerateStream(&self.opl_chip, &buffer[0], nsamples);
        @memset(buffer, 0);
    }
}

fn stopTrack(ctx: *anyopaque, song_number: u8) void {
    _ = ctx;
    _ = song_number;
}

fn playTrack(ctx: *anyopaque, song_number: u8) void {
    _ = ctx;
    _ = song_number;
}

fn isPlayingATrack(ctx: *anyopaque) bool {
    _ = ctx;
    return false;
}

fn play_sfx(ctx: *anyopaque, fx_number: u8) void {
    _ = ctx;
    _ = fx_number;
}
