//
// Copyright (C) 2024 - 2026 The OpenTitus team
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

//! PC speaker music, as played by the original DOS games.
//!
//! The driver is a single voice interpreter of the same music byte code the AdLib driver uses for each of its channels.
//! It drives channel 2 of the PIT, which produces a square wave on the speaker.
//! The original has no PC speaker sound effects, only music (including the jingles for collecting things).
//! There are two players, so the jingles don't have to replace the music, see `jingles.zig`.

const PCSpeaker = @This();

const std = @import("std");
const Mutex = std.Io.Mutex;

const Backend = @import("Backend.zig");

const audio = @import("audio.zig");
const AudioEngine = audio.AudioEngine;
const AudioTrack = audio.AudioTrack;

const events = @import("../events.zig");
const GameEvent = events.GameEvent;

const data = @import("../data.zig");
const dos_data = @import("dos_data.zig");
const jingles = @import("jingles.zig");

/// Input clock of the PIT
const PitClock = 1193182;

/// Two ticks before a note ends, the driver switches to this low tone, unless the note is tied to the next one.
const ArticulationDivisor = 0x3A98;

/// The game sets the PIT channel 0 divisor to 0x4000, the driver runs at 1193182 Hz / 16384 = 72.8 Hz
const TickMicroseconds = 13731;

/// Loudness of the square wave. Roughly matches the level of the other backends.
const Amplitude = 7500;

// The real thing was a small speaker inside the case. It couldn't reproduce much bass or the sharp edges of the square
// wave, so we filter the output to sound less harsh than an ideal square wave out of proper speakers.
const LowPassHz = 3500;
const HighPassHz = 150;

/// Registers set by the music commands, in the order of their command numbers
const Register = enum(u3) {
    Duration = 0,
    Volume = 1,
    Tempo = 2,
    TripleDuration = 3,
    Lie = 4,
    Vox = 5,
    Instrument = 6,
};

const SubCommand = enum(u4) {
    CallSub = 0,
    UpdateLoopCounter = 1,
    Loop = 2,
    ReturnFromSub = 3,
    Jump = 4,
    Finish = 15,
    _,
};

io: std.Io = std.Io.failing,
allocator: std.mem.Allocator = undefined,
engine: *AudioEngine = undefined,
sample_rate: u32 = undefined,
mutex: Mutex = .init,

music: ?dos_data.MusicData = null,

music_player: Player = .{},
jingle_player: Player = .{},
mixer: jingles.Mixer = .{},
/// The music player at the start of the current bar, the music resumes from there after a jingle
bar_start: ?Player = null,
music_paused: bool = false,

// Small speaker filter state
low_pass_coefficient: f32 = 1,
high_pass_coefficient: f32 = 1,
low_pass: [2]f32 = .{ 0, 0 },
high_pass_input: f32 = 0,
high_pass_output: f32 = 0,

/// The music driver and the PIT channel 2 square wave it plays on
const Player = struct {
    music_data: []const u8 = "",
    tables: dos_data.PCSpeakerData = undefined,

    // Driver state
    current_song: ?u8 = null,
    /// Offset of the next music byte, null when not playing
    position: ?usize = null,
    delay_counter: u8 = 0,
    skip_counter: u8 = 0,
    skip_reload: u8 = 0,
    registers: [7]u8 = @splat(0),
    return_offset: usize = 0,
    loop_counter: u8 = 0,
    /// Driver ticks (not counting the skipped ones) since the first note of the song.
    /// The delay counter carries over from the previous song, so the song may start a few ticks late.
    song_ticks: ?u32 = null,

    // Speaker and PIT channel 2 state
    speaker_on: bool = false,
    /// PIT channel 2 divisor (a written value of 0 means 65536)
    divisor: u32 = 65536,
    /// Position within the square wave period, in PIT clock ticks
    phase: u32 = 0,
    /// Fractional PIT clock ticks carried between output samples, in units of 1/sample_rate
    clock_remainder: u32 = 0,

    fn isPlaying(self: *const Player) bool {
        return self.position != null;
    }

    /// Whether the next tick starts a bar (or a skipped tick before it)
    fn atBarLine(self: *const Player) bool {
        const ticks = self.song_ticks orelse return false;
        return self.isPlaying() and ticks % Backend.TicksPerBar == 0;
    }

    /// Run the driver without sound up to the start of a bar
    fn skipToBar(self: *Player, bar: u32) void {
        while (self.isPlaying() and (self.song_ticks orelse 0) < bar * Backend.TicksPerBar) {
            self.tick();
        }
    }

    fn getWord(self: *Player, offset: usize) u16 {
        return std.mem.readInt(u16, self.music_data[offset..][0..2], .little);
    }

    fn setDivisor(self: *Player, value: u16) void {
        self.divisor = if (value == 0) 65536 else value;
        self.phase %= self.divisor;
    }

    fn stop(self: *Player) void {
        self.position = null;
        self.current_song = null;
        self.speaker_on = false;
    }

    fn playTrackNumber(self: *Player, song_number: u8) void {
        const pointer = self.getWord(self.tables.song_table + @as(usize, song_number) * 2);
        if (pointer == 0) {
            self.stop();
            return;
        }
        self.skip_reload = self.music_data[self.tables.skip_table + song_number];
        self.skip_counter = self.skip_reload;
        // NOTE: like in the original, the delay counter and registers carry over from the previous song
        self.position = pointer;
        self.current_song = song_number;
        self.speaker_on = true;
        self.song_ticks = null;
    }

    /// One tick of the music driver
    fn tick(self: *Player) void {
        var position = self.position orelse return;
        defer {
            if (self.position != null) {
                self.position = position;
            }
        }

        self.skip_counter -%= 1;
        if (self.skip_counter == 0) {
            self.skip_counter = self.skip_reload;
            return; // Skip (for modifying tempo)
        }
        if (self.song_ticks) |*ticks| {
            ticks.* += 1;
        }

        if (self.delay_counter == 2 and self.registers[@intFromEnum(Register.Lie)] != 1) {
            self.setDivisor(ArticulationDivisor);
        }

        const delay = self.delay_counter;
        self.delay_counter = delay -% 1;
        if (delay > 1) {
            return;
        }

        var byte: u8 = undefined;
        while (true) {
            byte = self.music_data[position];
            position += 1;
            if (byte & 0x80 == 0) {
                break;
            }
            const command: u3 = @truncate(byte >> 4);
            const argument: u4 = @truncate(byte);
            if (command != 7) {
                self.registers[command] = argument;
                continue;
            }
            switch (@as(SubCommand, @enumFromInt(argument))) {
                .CallSub => {
                    self.return_offset = position + 2;
                    position = self.getWord(position);
                },
                .UpdateLoopCounter => {
                    self.loop_counter = self.music_data[position];
                    position += 1;
                },
                .Loop => {
                    self.loop_counter -%= 1;
                    if (self.loop_counter != 0) {
                        position = self.getWord(position);
                    } else {
                        position += 2;
                    }
                },
                .ReturnFromSub => {
                    position = self.return_offset;
                },
                .Jump => {
                    position = self.getWord(position);
                },
                .Finish => {
                    self.stop();
                    return;
                },
                _ => {
                    // The original would jump through garbage here. None of the songs do this.
                    std.log.warn("PC speaker: unknown music command {x:0>2}", .{byte});
                    self.stop();
                    return;
                },
            }
        }

        if (self.song_ticks == null) {
            self.song_ticks = 1;
        }
        const note: u4 = @truncate(byte);
        const octave: u3 = @truncate(byte >> 4);
        self.setDivisor(self.getWord(self.tables.divisor_table + @as(usize, note) * 2) >> octave);

        const duration = self.registers[@intFromEnum(Register.Duration)];
        if (duration == 7) {
            self.delay_counter = shr8(0x40, self.registers[@intFromEnum(Register.TripleDuration)]);
        } else {
            self.delay_counter = shr8(0x60, duration);
        }
    }

    /// The speaker level for the next output sample, between -1 and 1
    fn nextLevel(self: *Player, sample_rate: u32) f32 {
        // Advance the PIT by however many clock ticks fit into this output sample
        self.clock_remainder += PitClock;
        const ticks = self.clock_remainder / sample_rate;
        self.clock_remainder %= sample_rate;

        var level: f32 = 0;
        if (self.speaker_on and ticks > 0) {
            // Average of the +1/-1 square wave over the sample
            const high: f32 = @floatFromInt(highTicks(self.phase, ticks, self.divisor));
            const total: f32 = @floatFromInt(ticks);
            level = (2 * high - total) / total;
        }
        self.phase = (self.phase + ticks) % self.divisor;
        return level;
    }
};

pub fn backend(self: *PCSpeaker) Backend {
    return .{
        .name = "PC Speaker",
        .backend_type = .PCSpeaker,
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
    const self: *PCSpeaker = @ptrCast(@alignCast(ctx));
    self.* = .{
        .io = io,
        .allocator = allocator,
        .engine = engine,
        .sample_rate = sample_rate,
    };
    self.setupFilter();
    self.mixer = jingles.Mixer.init(sample_rate);

    var music = dos_data.load(io, allocator, data.game) catch |err| {
        std.log.err("Cannot load PC speaker music from the game executable: {}", .{err});
        return Backend.Error.InvalidData;
    };
    const tables = music.pc_speaker orelse {
        std.log.err("No PC speaker music found in the game executable", .{});
        music.deinit(allocator);
        return Backend.Error.InvalidData;
    };
    self.music = music;
    self.music_player = .{ .music_data = music.data_segment, .tables = tables };
    self.jingle_player = .{ .music_data = music.data_segment, .tables = tables };

    self.engine.setCallback(0, TimerCallback, @ptrCast(self));
}

fn deinit(ctx: *anyopaque) void {
    const self: *PCSpeaker = @ptrCast(@alignCast(ctx));
    self.engine.clearCallbacks();
    if (self.music) |*music| {
        music.deinit(self.allocator);
    }
    self.music = null;
    self.music_player = .{};
    self.jingle_player = .{};
    self.bar_start = null;
    self.music_paused = false;
}

fn lock(ctx: *anyopaque) void {
    const self: *PCSpeaker = @ptrCast(@alignCast(ctx));
    self.mutex.lock(self.io) catch {
        unreachable;
    };
}

fn unlock(ctx: *anyopaque) void {
    const self: *PCSpeaker = @ptrCast(@alignCast(ctx));
    self.mutex.unlock(self.io);
}

fn playTrack(ctx: *anyopaque, track: ?AudioTrack) void {
    const self: *PCSpeaker = @ptrCast(@alignCast(ctx));
    // A new song replaces any jingle too
    self.jingle_player.stop();
    self.mixer.stopJingle();
    self.bar_start = null;
    const track_ = track orelse {
        self.music_player.stop();
        return;
    };
    self.music_player.playTrackNumber(dos_data.getTrackNumber(track_));
    self.bar_start = self.music_player;
}

fn playJingle(self: *PCSpeaker, song_number: u8) void {
    self.jingle_player.playTrackNumber(song_number);
    self.mixer.startJingle();
}

fn triggerEvent(ctx: *anyopaque, event: GameEvent) void {
    const self: *PCSpeaker = @ptrCast(@alignCast(ctx));
    switch (event) {
        .PlayerCollectWaypoint => self.playJingle(dos_data.SongCollectWaypoint),
        .PlayerCollectBonus => self.playJingle(dos_data.SongCollectBonus),
        .PlayerCollectLamp => self.playJingle(dos_data.SongCollectLamp),
        else => {},
    }
}

fn isPlayingATrack(ctx: *anyopaque) bool {
    const self: *PCSpeaker = @ptrCast(@alignCast(ctx));
    return self.music_player.isPlaying();
}

fn songPosition(ctx: *anyopaque) ?u32 {
    const self: *PCSpeaker = @ptrCast(@alignCast(ctx));
    if (!self.music_player.isPlaying()) {
        return null;
    }
    return self.music_player.song_ticks orelse 0;
}

fn seekToBar(ctx: *anyopaque, bar: u32) void {
    const self: *PCSpeaker = @ptrCast(@alignCast(ctx));
    self.music_player.skipToBar(bar);
    self.bar_start = self.music_player;
}

/// x86 `shr` of an 8-bit register: counts of 8 and more shift everything out
fn shr8(value: u8, count: u8) u8 {
    if (count >= 8) {
        return 0;
    }
    return value >> @intCast(count);
}

fn TimerCallback(callback_data: ?*anyopaque) void {
    var self: *PCSpeaker = @ptrCast(@alignCast(callback_data));
    self.mutex.lock(self.io) catch {
        unreachable;
    };
    self.updatePause();
    if (!self.music_paused) {
        if (self.music_player.atBarLine()) {
            self.bar_start = self.music_player;
        }
        self.music_player.tick();
    }
    self.jingle_player.tick();
    self.mutex.unlock(self.io);

    self.engine.setNextCallback(TickMicroseconds, TimerCallback, callback_data);
}

fn setupFilter(self: *PCSpeaker) void {
    const rate: f32 = @floatFromInt(self.sample_rate);
    self.low_pass_coefficient = 1.0 - @exp(-2.0 * std.math.pi * LowPassHz / rate);
    self.high_pass_coefficient = @exp(-2.0 * std.math.pi * HighPassHz / rate);
}

/// Two one-pole low-pass stages followed by a one-pole high-pass
fn filter(self: *PCSpeaker, input: f32) f32 {
    self.low_pass[0] += self.low_pass_coefficient * (input - self.low_pass[0]);
    self.low_pass[1] += self.low_pass_coefficient * (self.low_pass[0] - self.low_pass[1]);
    const low_passed = self.low_pass[1];
    self.high_pass_output = self.high_pass_coefficient * (self.high_pass_output + low_passed - self.high_pass_input);
    self.high_pass_input = low_passed;
    return self.high_pass_output;
}

test "speaker filter removes DC and ultrasonic tones" {
    var pc: PCSpeaker = .{ .sample_rate = 44100 };
    pc.setupFilter();
    // a held level (like a speaker that's switched on but not moving) fades away
    var out: f32 = 0;
    for (0..44100) |_| out = pc.filter(1.0);
    try std.testing.expect(@abs(out) < 0.001);
    // the 'rest' note (divisor 10, ~119 kHz) averages out to silence before filtering already
    try std.testing.expectEqual(@as(u32, 5), highTicks(0, 10, 10));
}

/// Number of PIT ticks the square wave output is high within [start, start + count), with start inside one period
fn highTicks(start: u32, count: u32, period: u32) u32 {
    // In mode 3 the output is high for the first half of the period (the longer half for odd divisors)
    const high = (period + 1) / 2;
    const overlap = struct {
        fn f(a: u32, b: u32, h: u32) u32 {
            if (a >= h) return 0;
            return @min(b, h) - a;
        }
    }.f;
    var result = (count / period) * high;
    const rest = count % period;
    if (start + rest <= period) {
        result += overlap(start, start + rest, high);
    } else {
        result += overlap(start, period, high) + overlap(0, start + rest - period, high);
    }
    return result;
}

test "highTicks" {
    try std.testing.expectEqual(@as(u32, 5), highTicks(0, 10, 10));
    try std.testing.expectEqual(@as(u32, 2), highTicks(3, 4, 10));
    try std.testing.expectEqual(@as(u32, 2), highTicks(8, 4, 10));
    try std.testing.expectEqual(@as(u32, 3), highTicks(0, 5, 5));
    try std.testing.expectEqual(@as(u32, 9), highTicks(4, 19, 6));
}

/// When the music stops being paused for a jingle, move it to the nearest bar line
fn updatePause(self: *PCSpeaker) void {
    const paused = self.mixer.musicPaused(self.jingle_player.isPlaying());
    if (self.music_paused and !paused) {
        // Before the first note, the song is at its start anyway
        const song_ticks = self.music_player.song_ticks orelse 0;
        const bar = Backend.nearestBar(song_ticks);
        if (bar * Backend.TicksPerBar > song_ticks) {
            self.music_player.skipToBar(bar);
        } else if (self.bar_start) |bar_start| {
            self.music_player = bar_start;
        }
    }
    self.music_paused = paused;
}

fn fillBuffer(ctx: *anyopaque, buffer: []i16, nsamples: u32) void {
    const self: *PCSpeaker = @ptrCast(@alignCast(ctx));
    self.mutex.lock(self.io) catch {
        unreachable;
    };
    defer self.mutex.unlock(self.io);
    self.updatePause();

    const jingle_playing = self.jingle_player.isPlaying();
    const render_music = self.mixer.musicAudible(jingle_playing);
    const render_jingle = self.mixer.jingleAudible(jingle_playing);

    for (0..nsamples) |i| {
        // A paused player's square wave stops where it is
        const music = if (render_music) self.music_player.nextLevel(self.sample_rate) else 0;
        const jingle = if (render_jingle) self.jingle_player.nextLevel(self.sample_rate) else 0;
        const level = self.mixer.mix(jingle_playing, music, jingle);
        const value: i16 = @intFromFloat(std.math.clamp(self.filter(level) * Amplitude, -32768, 32767));
        buffer[i * 2] = value;
        buffer[i * 2 + 1] = value;
    }
}
