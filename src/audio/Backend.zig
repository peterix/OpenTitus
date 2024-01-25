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
const _engine = @import("engine.zig");
const AudioEngine = _engine.AudioEngine;

pub const Error = error{
    OutOfMemory,
    InvalidData,
    CannotInitialize,
};

ptr: *anyopaque,
vtable: *const VTable,
name: []const u8,

pub const VTable = struct {
    init: *const fn (ctx: *anyopaque, engine: *AudioEngine, allocator: std.mem.Allocator, sample_rate: u32) Error!void,
    deinit: *const fn (ctx: *anyopaque) void,
    fillBuffer: *const fn (ctx: *anyopaque, buffer: []i16, nsamples: u32) void,
    playTrack: *const fn (ctx: *anyopaque, song_number: u8) void,
    stopTrack: *const fn (ctx: *anyopaque, song_number: u8) void,
    playSfx: *const fn (ctx: *anyopaque, sfx_number: u8) void,
    isPlayingATrack: *const fn (ctx: *anyopaque) bool,
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

pub inline fn playTrack(self: Backend, song_number: u8) void {
    self.vtable.playTrack(self.ptr, song_number);
}

pub inline fn stopTrack(self: Backend, song_number: u8) void {
    self.vtable.stopTrack(self.ptr, song_number);
}

pub inline fn playSfx(self: Backend, sfx_number: u8) void {
    self.vtable.playSfx(self.ptr, sfx_number);
}

pub inline fn isPlayingATrack(self: Backend) bool {
    return self.vtable.isPlayingATrack(self.ptr);
}
