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

const Amiga = @This();

const std = @import("std");
const Mutex = std.Io.Mutex;

const Backend = @import("Backend.zig");

const audio = @import("audio.zig");
const AudioEngine = audio.AudioEngine;
const AudioTrack = audio.AudioTrack;

const events = @import("../events.zig");
const GameEvent = events.GameEvent;

const data = @import("../data.zig");
const amiga_music = @import("amiga_music.zig");

const pocketmod = @cImport({
    @cInclude("pocketmod.h");
});



/// Sound effects of the Amiga version, in the order the game loads them.
///
/// The samples are raw signed 8-bit PCM files, loaded from the `AMIGA` folder next to the DOS game files.
const SoundEffect = enum(u8) {
    Ressort,
    Ballon,
    Fox,
    Tirperso,
    Coup,

    fn fileName(self: SoundEffect) []const u8 {
        return switch (self) {
            .Ressort => "ressort",
            .Ballon => "ballon",
            // Moktar has a sample of Lagaf' where Titus has the fox
            .Fox => if (data.game == .Moktar) "lagaf" else "fox",
            .Tirperso => "tirperso",
            .Coup => "coup",
        };
    }

    /// Sample rates in Hz, from the table the Amiga version of Titus uses to compute the Paula period
    fn sampleRate(self: SoundEffect) u32 {
        return switch (self) {
            .Ressort => 4000,
            .Ballon => 5000,
            .Fox => 5500,
            .Tirperso => 4000,
            .Coup => 4000,
        };
    }
};
const SoundEffectCount = @typeInfo(SoundEffect).@"enum".fields.len;

/// How many module ticks make one bar of the DOS version of a song, so the music can continue from where another
/// backend was. Measured by matching the notes of the two versions bar by bar. Songs that don't line up start over.
fn ticksPerBar(track: AudioTrack) ?u32 {
    return switch (track) {
        .Play1, .Play2 => 72,
        .Play3 => 128,
        // Titus and Moktar have a different song here
        .Play4 => if (data.game == .Moktar) 96 else 112,
        .Play5 => 96,
        .MainTitle => 64,
        .Bonus => 84,
        // The DOS credits have their own song, the Amiga version reuses the title music
        .Credits, .Win, .LevelEnd, .GameOver, .Death => null,
    };
}

const TrackCount = @typeInfo(AudioTrack).@"enum".fields.len;

/// NTSC Paula clock the Amiga version uses to compute sample periods
const PaulaClock = 3579545;

/// Sound effects play on Paula channel 3, which also carries music. The music on that channel is silenced meanwhile.
const SfxChannel = 3;

// Match the level and panning pocketmod uses for MOD channel 3, so effects sit at the same volume as the music.
const SfxLevel = 1.0 / 512.0;
const SfxLevelLeft = SfxLevel * (1.0 - 96.0 / 255.0);
const SfxLevelRight = SfxLevel * (96.0 / 255.0);

const Sound = struct {
    sample: []const i8,
    /// Position in the sample, as 32.32 fixed point
    position: u64 = 0,
    /// How much to advance per output frame, as 32.32 fixed point
    step: u64,
};

allocator: std.mem.Allocator = undefined,
current_track: ?AudioTrack = null,
mutex: Mutex = .init,
io: std.Io = std.Io.failing,
sample_rate: u32 = undefined,
music_context: ?pocketmod.pocketmod_context = null,
/// Module ticks skipped by `seekToBar`, and samples rendered since. Together they are the position in the song.
skipped_ticks: u32 = 0,
music_samples: u64 = 0,
sound_context: ?Sound = null,
samples: [SoundEffectCount]?[]u8 = @splat(null),
/// Music, rebuilt from the original files as ProTracker modules
tracks: [TrackCount]?[]u8 = @splat(null),

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
            .triggerEvent = triggerEvent,
            .isPlayingATrack = isPlayingATrack,
            .songPosition = songPosition,
            .seekToBar = seekToBar,
            .lock = lock,
            .unlock = unlock,
        },
    };
}

fn init(ctx: *anyopaque, io: std.Io, engine: *AudioEngine, allocator: std.mem.Allocator, sample_rate: u32) Backend.Error!void {
    const self: *Amiga = @ptrCast(@alignCast(ctx));
    self.engine = engine;
    self.io = io;
    self.allocator = allocator;
    self.mutex = .init;
    self.sample_rate = sample_rate;
    self.current_track = null;
    self.music_context = null;
    self.sound_context = null;
    self.loadSamples();
    self.loadTracks();
}

fn getGameDir() ?[]const u8 {
    return switch (data.game) {
        .Titus => "TITUS/AMIGA",
        .Moktar => "MOKTAR/AMIGA",
        .None => null,
    };
}

fn loadTracks(self: *Amiga) void {
    const game_dir = getGameDir() orelse return;
    for (&self.tracks, 0..) |*track, i| {
        const audio_track: AudioTrack = @enumFromInt(i);
        track.* = amiga_music.loadTrack(self.io, self.allocator, game_dir, data.game, audio_track) catch |err| blk: {
            std.log.warn("Amiga music for '{s}' not available: {}", .{ @tagName(audio_track), err });
            break :blk null;
        };
    }
}

fn loadSamples(self: *Amiga) void {
    const game_dir = getGameDir() orelse return;
    for (&self.samples, 0..) |*sample, i| {
        const effect: SoundEffect = @enumFromInt(i);
        sample.* = data.readGameFile(self.io, self.allocator, game_dir, effect.fileName()) catch |err| blk: {
            std.log.warn("Amiga sound effect '{s}/{s}' not available: {}", .{ game_dir, effect.fileName(), err });
            break :blk null;
        };
    }
}

fn deinit(ctx: *anyopaque) void {
    const self: *Amiga = @ptrCast(@alignCast(ctx));
    self.mutex = .init;
    self.sample_rate = undefined;
    self.current_track = null;
    self.music_context = null;
    self.sound_context = null;
    for (&self.samples) |*sample| {
        if (sample.*) |bytes| {
            self.allocator.free(bytes);
        }
        sample.* = null;
    }
    for (&self.tracks) |*track| {
        if (track.*) |bytes| {
            self.allocator.free(bytes);
        }
        track.* = null;
    }
}

fn lock(ctx: *anyopaque) void {
    const self: *Amiga = @ptrCast(@alignCast(ctx));
    self.mutex.lock(self.io) catch { unreachable; };
}

fn unlock(ctx: *anyopaque) void {
    const self: *Amiga = @ptrCast(@alignCast(ctx));
    self.mutex.unlock(self.io);
}

fn fillBuffer(ctx: *anyopaque, buffer: []i16, nFrames: u32) void {
    const self: *Amiga = @ptrCast(@alignCast(ctx));
    self.mutex.lock(self.io) catch { unreachable; };
    defer self.mutex.unlock(self.io);

    // we render two channels, f32
    var float_buffer: [2048][2]f32 = undefined;
    var done: u32 = 0;
    while (done < nFrames) {
        const count: u32 = @min(float_buffer.len, nFrames - done);
        const frames = float_buffer[0..count];
        self.renderMusic(frames);
        self.mixSoundEffect(frames);
        for (frames, 0..) |frame, i| {
            const ii = (done + i) * 2;
            buffer[ii] = @intFromFloat(std.math.clamp(frame[0], -1.0, 1.0) * std.math.maxInt(i16));
            buffer[ii + 1] = @intFromFloat(std.math.clamp(frame[1], -1.0, 1.0) * std.math.maxInt(i16));
        }
        done += count;
    }
}

fn renderMusic(self: *Amiga, frames: [][2]f32) void {
    @memset(frames, .{ 0, 0 });
    const music_context = &(self.music_context orelse return);
    music_context.muted_channels = if (self.sound_context != null) 1 << SfxChannel else 0;

    const frame_size = @sizeOf([2]f32);
    var rendered: usize = 0;
    while (rendered < frames.len) {
        // NOTE: pocketmod takes and returns sizes in bytes
        const rendered_now: usize = @intCast(@divExact(pocketmod.pocketmod_render(
            music_context,
            &frames[rendered],
            @intCast((frames.len - rendered) * frame_size),
        ), frame_size));
        rendered += rendered_now;
        self.music_samples += rendered_now;
        // if we looped, stop playing
        if (pocketmod.pocketmod_loop_count(music_context) >= 1) {
            @memset(frames[rendered..], .{ 0, 0 });
            self.music_context = null;
            self.current_track = null;
            return;
        }
    }
}

fn mixSoundEffect(self: *Amiga, frames: [][2]f32) void {
    const sound = &(self.sound_context orelse return);
    for (frames) |*frame| {
        const index: usize = @intCast(sound.position >> 32);
        if (index >= sound.sample.len) {
            self.sound_context = null;
            return;
        }
        // Paula doesn't interpolate, it holds each sample value until the next one
        const value: f32 = @floatFromInt(sound.sample[index]);
        frame[0] += value * SfxLevelLeft;
        frame[1] += value * SfxLevelRight;
        sound.position += sound.step;
    }
}

fn playSoundEffect(self: *Amiga, effect: SoundEffect) void {
    const bytes = self.samples[@intFromEnum(effect)] orelse return;
    // Paula plays whole 16-bit words, so an odd last byte is dropped
    const sample: []const i8 = @ptrCast(bytes[0 .. bytes.len & ~@as(usize, 1)]);
    // The game converts the sample rate to a Paula period, which then sets the real playback rate
    const period: u64 = PaulaClock / effect.sampleRate();
    self.sound_context = .{
        .sample = sample,
        .step = (@as(u64, PaulaClock) << 32) / (period * self.sample_rate),
    };
}

fn playTrack(ctx: *anyopaque, track: ?AudioTrack) void {
    const self: *Amiga = @ptrCast(@alignCast(ctx));
    self.music_context = null;
    self.current_track = null;
    const track_ = track orelse return;
    const track_data = self.tracks[@intFromEnum(track_)] orelse return;
    var music_context: pocketmod.pocketmod_context = undefined;
    if (!pocketmod.pocketmod_init(&music_context, track_data.ptr, @intCast(track_data.len), self.sample_rate)) {
        std.log.err("Amiga music for '{s}' cannot be played", .{@tagName(track_)});
        return;
    }
    self.music_context = music_context;
    self.current_track = track;
    self.skipped_ticks = 0;
    self.music_samples = 0;
}

fn songPosition(ctx: *anyopaque) ?u32 {
    const self: *Amiga = @ptrCast(@alignCast(ctx));
    const music_context = &(self.music_context orelse return null);
    const ticks_per_bar = ticksPerBar(self.current_track orelse return null) orelse return null;
    const rendered_ticks: u64 = @intFromFloat(@as(f64, @floatFromInt(self.music_samples)) / music_context.samples_per_tick);
    const module_ticks = self.skipped_ticks + rendered_ticks;
    return @intCast(module_ticks * Backend.TicksPerBar / ticks_per_bar);
}

fn seekToBar(ctx: *anyopaque, bar: u32) void {
    const self: *Amiga = @ptrCast(@alignCast(ctx));
    const music_context = &(self.music_context orelse return);
    const ticks_per_bar = ticksPerBar(self.current_track orelse return) orelse return;
    var target = bar * ticks_per_bar;
    // The DOS songs loop forever, the module plays once and then the game starts it again
    const length = moduleLength(music_context);
    if (length > 0) {
        target %= length;
    }
    pocketmod.pocketmod_skip_ticks(music_context, target);
    self.skipped_ticks = target;
    self.music_samples = 0;
}

/// Length of one pass through the module, in ticks
fn moduleLength(music_context: *const pocketmod.pocketmod_context) u32 {
    var scratch = music_context.*;
    const loops = pocketmod.pocketmod_loop_count(&scratch);
    var ticks: u32 = 0;
    // Give up on anything longer than half an hour
    while (ticks < 90_000) : (ticks += 1) {
        pocketmod.pocketmod_skip_ticks(&scratch, 1);
        if (pocketmod.pocketmod_loop_count(&scratch) != loops) {
            return ticks + 1;
        }
    }
    return 0;
}

fn triggerEvent(ctx: *anyopaque, event: GameEvent) void {
    const self: *Amiga = @ptrCast(@alignCast(ctx));
    switch (event) {
        .HitEnemy, .HitPlayer => self.playSoundEffect(.Coup),
        .PlayerThrow, .EnemyShoot => self.playSoundEffect(.Tirperso),
        .BallBounce => self.playSoundEffect(.Ballon),
        .SpringBounce => self.playSoundEffect(.Ressort),
        .PlayerCollectWaypoint, .PlayerCollectBonus => self.playSoundEffect(.Fox),
        .None,
        .PlayerHeadImpact,
        .PlayerPickup,
        .PlayerPickupEnemy,
        .PlayerJump,
        .PlayerCollectLamp,
        .Options_TestRumble,
        => {},
    }
}

fn isPlayingATrack(ctx: *anyopaque) bool {
    const self: *Amiga = @ptrCast(@alignCast(ctx));
    if (self.current_track) |_| {
        return true;
    }
    return false;
}


test "sound effects play at the Paula rate without interpolation" {
    var amiga: Amiga = .{ .sample_rate = 44100 };
    var sample = [_]u8{ 0x40, 0xC0, 0x7F };
    amiga.samples[@intFromEnum(SoundEffect.Coup)] = &sample;
    amiga.playSoundEffect(.Coup);

    // 4000 Hz -> period 894 -> 4004 Hz, so each sample value lasts for ~11 output frames
    var frames: [32][2]f32 = @splat(.{ 0, 0 });
    amiga.mixSoundEffect(&frames);
    try std.testing.expectEqual(@as(f32, 64.0 * SfxLevelLeft), frames[0][0]);
    try std.testing.expectEqual(@as(f32, 64.0 * SfxLevelRight), frames[0][1]);
    try std.testing.expectEqual(frames[0], frames[10]);
    try std.testing.expectEqual(@as(f32, -64.0 * SfxLevelLeft), frames[12][0]);
    // the odd last byte is not played, and the sound ends after two samples
    try std.testing.expectEqual(@as(f32, 0), frames[23][0]);
    try std.testing.expectEqual(@as(?Sound, null), amiga.sound_context);
}
