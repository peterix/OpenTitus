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

const std = @import("std");
const Backend = @This();
const audio = @import("audio.zig");
const AudioEngine = audio.AudioEngine;
const AudioTrack = audio.AudioTrack;

const events = @import("../events.zig");
const GameEvent = events.GameEvent;

pub const BackendType = enum(u8) {
    Silence = 0,
    Adlib,
    AdlibFast,
    PCSpeaker,
    Amiga,

    pub const NameTable = [@typeInfo(BackendType).@"enum".fields.len][]const u8{
        "Silence",
        "AdLib",
        "AdLib (fast)",
        "PC Speaker",
        "Amiga",
    };

    pub fn str(self: BackendType) []const u8 {
        return NameTable[@intFromEnum(self)];
    }
};

/// Song positions are in ticks of the DOS music drivers.
/// All the songs are in 4/4 with a whole note of 96 ticks, starting on a bar line.
pub const TicksPerBar = 96;

/// The bar line nearest to a song position: the start of its bar early in the bar, the next bar late in it.
/// Music that has to continue from somewhere else starts there, so it doesn't start mid-phrase.
pub fn nearestBar(song_ticks: u32) u32 {
    return song_ticks / TicksPerBar + @intFromBool(song_ticks % TicksPerBar >= TicksPerBar / 2);
}

test "nearestBar" {
    try std.testing.expectEqual(@as(u32, 2), nearestBar(2 * TicksPerBar + 6));
    try std.testing.expectEqual(@as(u32, 3), nearestBar(2 * TicksPerBar + 71));
    try std.testing.expectEqual(@as(u32, 0), nearestBar(0));
}

pub const Error = error{
    OutOfMemory,
    InvalidData,
    CannotInitialize,
};

ptr: *anyopaque,
vtable: *const VTable,
name: []const u8,
backend_type: BackendType,

pub const VTable = struct {
    init: *const fn (ctx: *anyopaque, io: std.Io, engine: *AudioEngine, allocator: std.mem.Allocator, sample_rate: u32) Error!void,
    deinit: *const fn (ctx: *anyopaque) void,
    fillBuffer: *const fn (ctx: *anyopaque, buffer: []i16, nsamples: u32) void,
    playTrack: *const fn (ctx: *anyopaque, track: ?AudioTrack) void,
    triggerEvent: *const fn (ctx: *anyopaque, event: GameEvent) void,
    isPlayingATrack: *const fn (ctx: *anyopaque) bool,
    /// How far the current song is, in DOS driver ticks. Null if it's not playing or the backend can't tell.
    songPosition: *const fn (ctx: *anyopaque) ?u32,
    /// Move the song started by `playTrack` to the start of a bar
    seekToBar: *const fn (ctx: *anyopaque, bar: u32) void,
    lock: *const fn (ctx: *anyopaque) void,
    unlock: *const fn (ctx: *anyopaque) void,
};

pub inline fn init(self: Backend, io: std.Io, engine: *AudioEngine, allocator: std.mem.Allocator, sample_rate: u32) Error!void {
    return self.vtable.init(self.ptr, io, engine, allocator, sample_rate);
}

pub inline fn deinit(self: Backend) void {
    return self.vtable.deinit(self.ptr);
}

pub inline fn fillBuffer(self: Backend, buffer: []i16, nsamples: u32) void {
    return self.vtable.fillBuffer(self.ptr, buffer, nsamples);
}

pub inline fn playTrack(self: Backend, song_number: ?AudioTrack) void {
    self.vtable.playTrack(self.ptr, song_number);
}

pub inline fn triggerEvent(self: Backend, event: GameEvent) void {
    self.vtable.triggerEvent(self.ptr, event);
}

pub inline fn isPlayingATrack(self: Backend) bool {
    return self.vtable.isPlayingATrack(self.ptr);
}

pub inline fn songPosition(self: Backend) ?u32 {
    return self.vtable.songPosition(self.ptr);
}

pub inline fn seekToBar(self: Backend, bar: u32) void {
    self.vtable.seekToBar(self.ptr, bar);
}

pub inline fn lock(self: Backend) void {
    self.vtable.lock(self.ptr);
}

pub inline fn unlock(self: Backend) void {
    self.vtable.unlock(self.ptr);
}
