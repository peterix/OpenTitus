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

const pocketmod = @cImport({
    @cInclude("pocketmod.h");
});


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

fn getTrackData(track_in: ?AudioTrack) []const u8 {
    if (track_in == null) {
        return &track_null;
    }
    const track = track_in.?;
    if (data.game == .Titus) switch (track) {
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
mutex: Mutex = .init,
io: std.Io = std.Io.failing,
sample_rate: u32 = undefined,
music_context: ?pocketmod.pocketmod_context = null,
sound_context: ?Sound = null,
samples: [SoundEffectCount]?[]u8 = @splat(null),

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
}

fn loadSamples(self: *Amiga) void {
    const game_dir = switch (data.game) {
        .Titus => "TITUS/AMIGA",
        .Moktar => "MOKTAR/AMIGA",
        .None => return,
    };
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
