//
// Copyright (C) 2008 - 2024 The OpenTitus team
// Copyright (C) 2005 - 2014 Simon Howard (originally under GPL2 as part of the OPL library)
//
// Authors:
// Eirik Stople
// Petr Mrázek
// Simon Howard
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

const Adlib = @This();
const AdlibInstance = @import("AdlibInstance.zig");

const std = @import("std");
const Mutex = std.Thread.Mutex;

const Backend = @import("Backend.zig");

const audio = @import("audio.zig");
const AudioEngine = audio.AudioEngine;
const AudioTrack = audio.AudioTrack;

const events = @import("../events.zig");
const GameEvent = events.GameEvent;

const _bytes = @import("../bytes.zig");

const OPL3 = @import("opl3/opl3.zig");

const data = @import("../data.zig");

const data_titus = @embedFile("dos/titus.bin");
const data_moktar = @embedFile("dos/moktar.bin");

const BUFFER_INITIAL = 2048;

musicMachine: AdlibInstance = .{},
sfxMachine: AdlibInstance = .{},
mutex: Mutex = Mutex{},
engine: *AudioEngine = undefined,
allocator: std.mem.Allocator = undefined,

bufferSize: u32 = 0,
buffer: []i16 = undefined,
bufMusic: []i16 = undefined,
bufSfx: []i16 = undefined,

pub fn backend(self: *Adlib) Backend {
    return .{
        .name = "AdLib",
        .backend_type = .Adlib,
        .ptr = self,
        .vtable = &.{
            .init = init,
            .deinit = deinit,
            .fillBuffer = fillBuffer,
            .playTrack = playTrack,
            .triggerEvent = triggerEvent,
            .isPlayingATrack = isPlayingATrack,
            .lock = lock,
            .unlock = unlock,
        },
    };
}

fn init(ctx: *anyopaque, engine: *AudioEngine, allocator: std.mem.Allocator, sample_rate: u32) Backend.Error!void {
    const self: *Adlib = @ptrCast(@alignCast(ctx));
    self.engine = engine;
    self.mutex = Mutex{};
    self.allocator = allocator;
    try self.musicMachine.init(sample_rate);
    try self.sfxMachine.init(sample_rate);
    self.engine.setCallback(0, TimerCallback, @constCast(@ptrCast(self)));
}

fn deinit(ctx: *anyopaque) void {
    const self: *Adlib = @ptrCast(@alignCast(ctx));
    self.engine.clearCallbacks();
    if (self.bufferSize != 0) {
        self.allocator.free(self.buffer);
        self.bufferSize = 0;
    }
}

fn lock(ctx: *anyopaque) void {
    const self: *Adlib = @ptrCast(@alignCast(ctx));
    self.mutex.lock();
}

fn unlock(ctx: *anyopaque) void {
    const self: *Adlib = @ptrCast(@alignCast(ctx));
    self.mutex.unlock();
}

fn checkBuffers(self: *Adlib, nsamples: u32) !void {
    if(self.bufferSize >= nsamples) {
        return;
    }
    if(self.bufferSize != 0) {
        self.allocator.free(self.buffer);
    }
    self.bufferSize = @min(BUFFER_INITIAL, nsamples);

    self.buffer = try self.allocator.alloc(i16, self.bufferSize * 4);
    self.bufSfx = self.buffer[0..2 * self.bufferSize];
    self.bufMusic = self.buffer[2 * self.bufferSize .. 4 * self.bufferSize];
}

fn fillBuffer(ctx: *anyopaque, buffer: []i16, nsamples: u32) void {
    const self: *Adlib = @ptrCast(@alignCast(ctx));
    self.mutex.lock();
    defer self.mutex.unlock();
    self.checkBuffers(nsamples) catch |err| {
        std.log.err("Failed to allocate buffers fror audio! Error: {s}", .{@errorName(err)});
        return;
    };
    self.musicMachine.fillBuffer(self.bufMusic, nsamples);
    self.sfxMachine.fillBuffer(self.bufSfx, nsamples);
    const musicMult: f32 = if (self.sfxMachine.isPlayingATrack()) 0.2 else 1.0;
    for (0..2 * nsamples) |index| {
        const musicFrame: f32 = @as(f32, @floatFromInt(self.bufMusic[index])) / 32768.0;
        const sfxFrame: f32 =  @as(f32, @floatFromInt(self.bufSfx[index])) / 32768.0;
        const combinedFrame: f32 = std.math.clamp(musicFrame * musicMult + sfxFrame, -1.0, 1.0);
        buffer[index] = @intFromFloat(combinedFrame * 32767.0);
    }
}

fn isPlayingATrack(ctx: *anyopaque) bool {
    const self: *Adlib = @ptrCast(@alignCast(ctx));
    return self.musicMachine.isPlayingATrack();
}

fn playTrack(ctx: *anyopaque, track: ?AudioTrack) void {
    const self: *Adlib = @ptrCast(@alignCast(ctx));
    self.musicMachine.playTrack(track);
}

fn triggerEvent(ctx: *anyopaque, event: GameEvent) void {
    const self: *Adlib = @ptrCast(@alignCast(ctx));
    switch (event) {
        .Event_HitEnemy => {
            self.sfxMachine.playSfx(1);
        },
        .Event_HitPlayer => {
            self.sfxMachine.playSfx(4);
        },
        .Event_PlayerHeadImpact => {
            self.sfxMachine.playSfx(5);
        },
        .Event_PlayerPickup, .Event_PlayerPickupEnemy => {
            self.sfxMachine.playSfx(9);
        },
        .Event_PlayerThrow => {
            self.sfxMachine.playSfx(3);
        },
        .Event_PlayerJump => {
            // Nothing here, but we could
        },
        .Event_BallBounce => {
            self.sfxMachine.playSfx(12);
        },
        .Event_PlayerCollectWaypoint => {
            self.sfxMachine.playTrackNumber(5);
        },
        .Event_PlayerCollectBonus => {
            self.sfxMachine.playTrackNumber(6);
        },
        .Event_PlayerCollectLamp => {
            self.sfxMachine.playTrackNumber(7);
        },
    }
}

fn TimerCallback(callback_data: ?*anyopaque) void {
    var self: *Adlib = @alignCast(@ptrCast(callback_data));
    self.mutex.lock();
    // Read data until we must make a delay.
    self.sfxMachine.fillchip();
    self.musicMachine.fillchip();
    self.mutex.unlock();

    // Schedule the next timer callback.
    // Delay is original 13.75 ms
    self.engine.setCallback(13750, TimerCallback, callback_data);
}
