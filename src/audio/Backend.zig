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
const _engine = @import("AudioEngine.zig");
const AudioEngine = _engine.AudioEngine;
const AudioTrack = _engine.AudioTrack;
const AudioEvent = _engine.AudioEvent;

pub const BackendType = enum(u8) {
    Adlib = 0,
    Amiga,
    PCSpeaker,
    Silence,

    pub const NameTable = [@typeInfo(BackendType).Enum.fields.len][]const u8{
        "AdLib",
        "Amiga",
        "PC-Speaker",
        "Silence",
    };

    pub fn str(self: BackendType) []const u8 {
        return NameTable[@intFromEnum(self)];
    }
};

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
    init: *const fn (ctx: *anyopaque, engine: *AudioEngine, allocator: std.mem.Allocator, sample_rate: u32) Error!void,
    deinit: *const fn (ctx: *anyopaque) void,
    fillBuffer: *const fn (ctx: *anyopaque, buffer: []i16, nsamples: u32) void,
    playTrack: *const fn (ctx: *anyopaque, track: ?AudioTrack) void,
    playEvent: *const fn (ctx: *anyopaque, event: AudioEvent) void,
    isPlayingATrack: *const fn (ctx: *anyopaque) bool,
    lock: *const fn (ctx: *anyopaque) void,
    unlock: *const fn (ctx: *anyopaque) void,
};

pub inline fn init(self: Backend, engine: *AudioEngine, allocator: std.mem.Allocator, sample_rate: u32) Error!void {
    return self.vtable.init(self.ptr, engine, allocator, sample_rate);
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

pub inline fn playEvent(self: Backend, event: AudioEvent) void {
    self.vtable.playEvent(self.ptr, event);
}

pub inline fn isPlayingATrack(self: Backend) bool {
    return self.vtable.isPlayingATrack(self.ptr);
}

pub inline fn lock(self: Backend) void {
    self.vtable.lock(self.ptr);
}

pub inline fn unlock(self: Backend) void {
    self.vtable.unlock(self.ptr);
}
