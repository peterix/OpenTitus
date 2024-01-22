//
// Copyright (C) 2008 - 2024 The OpenTitus team
//
// Authors:
// Eirik Stople
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

// TODO: refactor heavily
// TODO: move Adlib stuff out of here
//       It's most of the file, but we want more audio backends and this file should be the dispatch, not Adlib.
// TODO: bring in SDL logic from the OPL lib and divorce it from OPL
// TODO: implement a way to use music from the Amiga version of the game
// TODO: research how Amiga version does sound effects, use those too
// FIXME: further reduce the bit twiddling noise here...

const std = @import("std");
const c = @import("c.zig");
const game = @import("game.zig");
const data = @import("data.zig");
const globals = @import("globals.zig");

extern var OPL_SDL_VOLUME: u8;

const MUS_OFFSET = 0;
const INS_OFFSET = 352;
const SFX_OFFSET = 1950;

const opera: []const u8 = &.{ 0, 0, 1, 2, 3, 4, 5, 8, 9, 0xA, 0xB, 0xC, 0xD, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15 };
const voxp: []const u8 = &.{ 1, 2, 3, 7, 8, 9, 13, 17, 15, 18, 14 };
const gamme: []const c_uint = &.{ 343, 363, 385, 408, 432, 458, 485, 514, 544, 577, 611, 647, 0 };
const song_type: []const c_uint = &.{ 0, 1, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0 };

const ADLIB_INSTR = struct {
    op: [2][5]u8 = .{
        .{ 0, 0, 0, 0, 0 },
        .{ 0, 0, 0, 0, 0 },
    }, //Two operators and five data settings
    fb_alg: u8 = 0,
    vox: u8 = 0, //(only for perc instruments, 0xFE if this is melodic instrument, 0xFF if this instrument is disabled)
};

const AdlibData = struct {
    const ChannelCount = 10;
    const SfxCount = 14;
    const InstrumentCount = 20;

    const Channel = struct {
        duration: u8 = 0,
        volume: u8 = 0,
        tempo: u8 = 0,
        triple_duration: u8 = 0,
        lie: u8 = 0,
        vox: u8 = 0, //(range: 0-10)
        instrument: ?usize = null,
        delay_counter: u8 = 0,
        freq: u8 = 0,
        octave: u8 = 0,
        return_offset: ?usize = null,
        loop_counter: u8 = 0,
        offset: ?usize = null,
        lie_late: u8 = 0,
    };

    const Instruction = packed struct {
        freq: u4,
        oct: u3,
        is_command: bool,

        const MainCommand = enum(u3) {
            Duration = 0,
            Volume = 1,
            Tempo = 2,
            TripleDuration = 3,
            Lie = 4,
            Vox = 5,
            Instrument = 6,
            SubCommand = 7,
        };

        const SubCommand = enum(u4) {
            CallSub = 0,
            UpdateLoopCounter = 1,
            Loop = 2,
            ReturnFromSub = 3,
            Jump = 4,
            Finish = 15,
        };

        fn mainCommand(self: *Instruction) MainCommand {
            return @enumFromInt(self.oct);
        }

        fn subCommand(self: *Instruction) SubCommand {
            return @enumFromInt(self.freq);
        }
    };

    channels: [ChannelCount]Channel = [_]Channel{.{}} ** ChannelCount,
    active_channels: c_int = 0,
    perc_stat: u8 = 0,
    skip_delay: u8 = 0,
    skip_delay_counter: u8 = 0,

    sfx: [SfxCount]ADLIB_INSTR = [_]ADLIB_INSTR{.{}} ** SfxCount,
    instrument_data: [InstrumentCount]ADLIB_INSTR = [_]ADLIB_INSTR{.{}} ** InstrumentCount,
    data: []const u8 = "",

    fn fillchip_channel(self: *AdlibData, i: usize) void {
        var channel = &self.channels[i];
        if (channel.offset == null) {
            return;
        }
        if (channel.delay_counter > 1) {
            channel.delay_counter -= 1;
            return;
        }
        var instruction: Instruction = undefined;
        var tmp1: c_int = undefined;
        var tmp2: c_int = undefined;
        var tmpC: u8 = undefined;

        while (true) {
            instruction = @bitCast(self.data[channel.offset.?]);
            channel.offset.? += 1;

            //Escape the loop and play some notes based on oct and freq
            if (!instruction.is_command) {
                break;
            }

            // TODO: this could be some sort of 'processCommand' function...
            switch (instruction.mainCommand()) {
                .Duration => {
                    channel.duration = instruction.freq;
                },

                .Volume => {
                    channel.volume = instruction.freq;
                    tmpC = self.instrument_data[channel.instrument.?].op[0][2];
                    // What the F is going on here?
                    tmpC = @subWithOverflow(tmpC & 0x3F, 63)[0];

                    tmp1 = (((256 - @as(u16, tmpC)) << 4) & 0x0FF0) * (@as(u8, instruction.freq) + 1);
                    tmp1 = 63 - ((tmp1 >> 8) & 0xFF);
                    tmp2 = voxp[channel.vox];
                    if (tmp2 <= 13)
                        tmp2 += 3;
                    tmp2 = opera[@intCast(tmp2)];
                    c.OPL_WriteRegister(0x40 + tmp2, tmp1);
                },
                .Tempo => {
                    channel.tempo = instruction.freq;
                },
                .TripleDuration => {
                    channel.triple_duration = instruction.freq;
                },
                .Lie => {
                    channel.lie = instruction.freq;
                },
                .Vox => {
                    channel.vox = instruction.freq;
                },
                .Instrument => {
                    if (instruction.freq == 1) {
                        // Not melodic
                        // Turn on a percussion instrument
                        channel.instrument = channel.octave + 15; //(1st perc instrument is the 16th instrument)
                        channel.vox = self.instrument_data[channel.instrument.?].vox;
                        const percussion_bit = @as(c_int, channel.vox) - 6;
                        self.perc_stat = self.perc_stat | (@as(u8, 0x10) >> @intCast(percussion_bit)); //set a bit in perc_stat
                    } else {
                        // Melodic
                        if (instruction.freq > 1) {
                            instruction.freq -= 1;
                        }
                        channel.instrument = instruction.freq;
                        const percussion_bit = @as(c_int, channel.vox) - 6;
                        if (percussion_bit >= 0) {
                            // turn off a percussion instrument ?
                            // clear a bit from perc_stat
                            var temp: u8 = @as(u8, 0x10) << @intCast(percussion_bit);
                            self.perc_stat = self.perc_stat | temp;
                            temp = ~(temp) & 0xFF;
                            self.perc_stat = self.perc_stat & temp;
                            c.OPL_WriteRegister(0xBD, self.perc_stat);
                        }
                    }
                    tmp2 = voxp[channel.vox];
                    if (channel.vox <= 6)
                        tmp2 += 3;
                    tmp2 = opera[@intCast(tmp2)]; //Adlib channel
                    const instrument = &self.instrument_data[channel.instrument.?];
                    insmaker(&instrument.op[0], tmp2);
                    if (channel.vox < 7) {
                        insmaker(&instrument.op[1], tmp2 - 3);
                        c.OPL_WriteRegister(0xC0 + channel.vox, instrument.fb_alg);
                    }
                },
                .SubCommand => {
                    switch (instruction.subCommand()) {
                        .CallSub => {
                            channel.return_offset = channel.offset.? + 2;
                            var temp = (@as(c_uint, self.data[channel.offset.? + 1]) << 8) & 0xFF00;
                            temp += @as(c_uint, self.data[channel.offset.?]) & 0xFF;
                            channel.offset = temp - audio_engine.seg_reduction;
                        },

                        .UpdateLoopCounter => {
                            channel.loop_counter = self.data[channel.offset.?];
                            channel.offset.? += 1;
                        },

                        .Loop => {
                            if (channel.loop_counter > 1) {
                                channel.loop_counter -= 1;
                                var temp = (@as(c_uint, self.data[channel.offset.? + 1]) << 8);
                                temp += @as(c_uint, self.data[channel.offset.?]);
                                channel.offset = temp - audio_engine.seg_reduction;
                            } else {
                                channel.offset.? += 2;
                            }
                        },

                        .ReturnFromSub => {
                            channel.offset = channel.return_offset;
                            channel.return_offset = null;
                        },

                        .Jump => {
                            var temp = (@as(c_uint, self.data[channel.offset.? + 1]) << 8);
                            temp += @as(c_uint, self.data[channel.offset.?]);
                            channel.offset = temp - audio_engine.seg_reduction;
                        },

                        .Finish => {
                            channel.offset = null;
                            self.active_channels -= 1;
                        },
                    }
                },
            }

            // if we have no more data to read, stop processing the channel
            if (channel.offset == null) {
                return;
            }
        }

        channel.octave = instruction.oct;
        channel.freq = instruction.freq;

        //Play note
        if (gamme[channel.freq] != 0) {
            if (self.instrument_data[channel.instrument.?].vox == 0xFE) {
                //Play a frequence
                //Output lower 8 bits of frequence
                c.OPL_WriteRegister(0xA0 + channel.vox, @as(u8, @truncate(gamme[channel.freq] & 0xFF)));
                if (channel.lie_late != 1) {
                    c.OPL_WriteRegister(0xB0 + channel.vox, 0); //Silence the channel
                }
                tmp1 = (channel.octave + 2) & 0x07; //Octave (3 bits)
                tmp2 = @as(u8, @truncate((gamme[channel.freq] >> 8) & 0x03)); //Frequency (higher 2 bits)
                c.OPL_WriteRegister(0xB0 + channel.vox, 0x20 + (tmp1 << 2) + tmp2); //Voices the channel, and output octave and last bits of frequency
                channel.lie_late = channel.lie;
            } else {
                //Play a perc instrument
                if (channel.instrument != channel.octave + 15) {
                    //New instrument

                    //Similar to escape, oct = 6 (change instrument)
                    channel.instrument = channel.octave + 15; //(1st perc instrument is the 16th instrument)
                    const instrument = &(self.instrument_data[channel.instrument.?]);
                    channel.vox = instrument.vox;
                    const percussion_bit = @as(c_int, channel.vox) - 6;
                    self.perc_stat = self.perc_stat | (@as(u8, 0x10) >> @intCast(percussion_bit)); //set a bit in perc_stat
                    tmp2 = voxp[channel.vox];
                    if (channel.vox <= 6)
                        tmp2 += 3;
                    tmp2 = opera[@intCast(tmp2)]; //Adlib channel
                    insmaker(&instrument.op[0], tmp2);
                    if (channel.vox < 7) {
                        insmaker(&instrument.op[1], tmp2 - 3);
                        c.OPL_WriteRegister(0xC0 + channel.vox, instrument.fb_alg);
                    }

                    //Similar to escape, oct = 1 (change volume)
                    tmpC = instrument.op[0][2];
                    tmpC = @subWithOverflow(tmpC & 0x3F, 63)[0];
                    tmp1 = (((256 - @as(u16, tmpC)) << 4) & 0x0FF0) * (channel.volume + 1);
                    tmp1 = 63 - ((tmp1 >> 8) & 0xFF);
                    tmp2 = voxp[channel.vox];
                    if (tmp2 <= 13)
                        tmp2 += 3;
                    tmp2 = opera[@intCast(tmp2)];
                    c.OPL_WriteRegister(0x40 + tmp2, tmp1);
                }
                const percussion_bit = @as(c_int, channel.vox) - 6;
                tmpC = @as(u8, 0x10) >> @intCast(percussion_bit);
                c.OPL_WriteRegister(0xBD, self.perc_stat & ~tmpC); //Output perc_stat with one bit removed
                if (channel.vox == 6) {
                    c.OPL_WriteRegister(0xA6, 0x57); //
                    c.OPL_WriteRegister(0xB6, 0); // Output the perc sound
                    c.OPL_WriteRegister(0xB6, 5); //
                }
                c.OPL_WriteRegister(0xBD, self.perc_stat); //Output perc_stat
            }
        } else {
            channel.lie_late = channel.lie;
        }

        if (channel.duration == 7) {
            channel.delay_counter = @as(u8, 0x40) >> @truncate(channel.triple_duration);
        } else {
            channel.delay_counter = @as(u8, 0x60) >> @truncate(channel.duration);
        }
    }

    fn fillchip(self: *AdlibData) c_int {
        sfx_driver();

        if (!game.settings.music and !audio_engine.playing_musical_sfx) {
            return (self.active_channels);
        }

        self.skip_delay_counter = @subWithOverflow(self.skip_delay_counter, 1)[0];

        if (self.skip_delay_counter == 0) {
            self.skip_delay_counter = self.skip_delay;
            return (self.active_channels); //Skip (for modifying tempo)
        }
        for (0..ChannelCount) |i| {
            self.fillchip_channel(i);
        }
        return (self.active_channels);
    }
};

fn load_file_expected_size(inputfile: []const u8, allocator: std.mem.Allocator, expected_bytes: usize) ![]const u8 {
    var file = try std.fs.cwd().openFile(inputfile, .{});
    defer file.close();
    const bytes = file.readToEndAlloc(allocator, std.math.maxInt(usize)) catch |err| {
        std.log.err("Could not open {s}: {}", .{ inputfile, err });
        return err;
    };
    errdefer allocator.free(bytes);
    if (bytes.len != expected_bytes) {
        std.log.err("{s} has unexpected size! Expected: {}, Got: {}", .{ inputfile, expected_bytes, bytes.len });
        return error.InvalidFile;
    }
    return bytes;
}

fn insmaker(insdata: []const u8, channel: c_int) void {
    c.OPL_WriteRegister(0x60 + channel, insdata[0]); //Attack Rate / Decay Rate
    c.OPL_WriteRegister(0x80 + channel, insdata[1]); //Sustain Level / Release Rate
    c.OPL_WriteRegister(0x40 + channel, insdata[2]); //Key scaling level / Operator output level
    c.OPL_WriteRegister(0x20 + channel, insdata[3]); //Amp Mod / Vibrato / EG type / Key Scaling / Multiple
    c.OPL_WriteRegister(0xE0 + channel, insdata[4]); //Wave type
}

fn all_vox_zero() void {
    for (0xB0..0xB9) |i|
        c.OPL_WriteRegister(@intCast(i), 0); //Clear voice, octave and upper bits of frequence
    for (0xA0..0xB9) |i|
        c.OPL_WriteRegister(@intCast(i), 0); //Clear lower byte of frequence

    c.OPL_WriteRegister(0x08, 0x00);
    c.OPL_WriteRegister(0xBD, 0x00);
    c.OPL_WriteRegister(0x40, 0x3F);
    c.OPL_WriteRegister(0x41, 0x3F);
    c.OPL_WriteRegister(0x42, 0x3F);
    c.OPL_WriteRegister(0x43, 0x3F);
    c.OPL_WriteRegister(0x44, 0x3F);
    c.OPL_WriteRegister(0x45, 0x3F);
    c.OPL_WriteRegister(0x48, 0x3F);
    c.OPL_WriteRegister(0x49, 0x3F);
    c.OPL_WriteRegister(0x4A, 0x3F);
    c.OPL_WriteRegister(0x4B, 0x3F);
    c.OPL_WriteRegister(0x4C, 0x3F);
    c.OPL_WriteRegister(0x4D, 0x3F);
    c.OPL_WriteRegister(0x50, 0x3F);
    c.OPL_WriteRegister(0x51, 0x3F);
    c.OPL_WriteRegister(0x52, 0x3F);
    c.OPL_WriteRegister(0x53, 0x3F);
    c.OPL_WriteRegister(0x54, 0x3F);
    c.OPL_WriteRegister(0x55, 0x3F);
}

export fn TimerCallback(callback_data: ?*anyopaque) void {
    if (!game.settings.music and !game.settings.sound) {
        return;
    }
    var self: *AudioEngine = @alignCast(@ptrCast(callback_data));
    // Read data until we must make a delay.
    self.playing = self.aad.fillchip();

    // Schedule the next timer callback.
    // Delay is original 13.75 ms
    c.OPL_SetCallback(13750, TimerCallback, callback_data);
}

pub const AudioEngine = struct {
    allocator: std.mem.Allocator = undefined,
    aad: AdlibData = .{},
    playing: c_int = 0,
    last_song: u8 = 0,
    seg_reduction: u16 = 0,
    playing_musical_sfx: bool = false,
    sfx_on: bool = false,
    sfx_time: u16 = 0,

    pub fn init(self: *AudioEngine, allocator: std.mem.Allocator) !void {
        self.allocator = allocator;
        self.last_song = 0;
        var expected_file_size: usize = 0;
        if (data.game == c.Titus) {
            self.seg_reduction = 1301;
            expected_file_size = 18749;
        } else if (data.game == c.Moktar) {
            self.seg_reduction = 1345;
            expected_file_size = 18184;
        } else {
            unreachable;
        }
        const bytes = try load_file_expected_size(
            "music.bin",
            allocator,
            expected_file_size,
        );
        errdefer allocator.free(bytes);

        c.OPL_SetSampleRate(44100);
        if (c.OPL_Init(0x388) == 0) {
            std.log.err("Unable to initialise OPL layer", .{});
            return error.CannotInitializeOPL;
        }

        // This makes no difference, but specifying 1 (OPL3) does break the music
        c.OPL_InitRegisters(0);

        self.aad.data = bytes;
        sfx_init();

        c.OPL_SetCallback(0, TimerCallback, @constCast(@ptrCast(self)));
        OPL_SDL_VOLUME = game.settings.volume_master;
    }

    pub fn deinit(self: *AudioEngine) void {
        self.allocator.free(self.aad.data);
        c.OPL_Shutdown();
        if (c.SDL_WasInit(c.SDL_INIT_AUDIO) == 0) {
            return;
        }
        c.SDL_CloseAudio();
    }
};

pub var audio_engine: AudioEngine = .{};

pub export fn music_get_last_song() u8 {
    return audio_engine.last_song;
}

pub export fn music_select_song(song_number: u8) void {
    var aad: *AdlibData = &(audio_engine.aad);
    var raw_data = aad.data;
    if (song_type[song_number] == 0) { //0: level music, 1: bonus
        audio_engine.last_song = song_number;
        audio_engine.playing_musical_sfx = false;
    } else {
        audio_engine.playing_musical_sfx = true;
    }
    aad.perc_stat = 0x20;

    //Load instruments
    var instrument_buffer = raw_data[INS_OFFSET..];
    c.SDL_LockAudio();

    for (0..song_number) |_| {
        while (true) {
            var temp = chomp_u16(&instrument_buffer);
            if (temp == 0xFFFF) {
                break;
            }
        }
    }
    all_vox_zero();

    for (0..AdlibData.InstrumentCount) |i| {
        //Init; instrument not in use
        aad.instrument_data[i].vox = 0xFF;
    }

    var previous: u16 = 0;
    var current = chomp_u16(&instrument_buffer);
    for (0..AdlibData.InstrumentCount) |i| {
        previous = current;
        current = chomp_u16(&instrument_buffer);

        if (current == 0xFFFF) //Terminate for loop
            break;

        if (previous == 0) //Instrument not in use
            continue;

        var read_buffer = raw_data[previous - audio_engine.seg_reduction ..];

        if (i > 14) {
            //Perc instrument (15-18) have an extra byte, melodic (0-14) have not
            aad.instrument_data[i].vox = chomp_u8(&read_buffer);
        } else {
            aad.instrument_data[i].vox = 0xFE;
        }

        for (0..5) |k| {
            aad.instrument_data[i].op[0][k] = chomp_u8(&read_buffer);
        }

        for (0..5) |k| {
            aad.instrument_data[i].op[1][k] = chomp_u8(&read_buffer);
        }

        aad.instrument_data[i].fb_alg = chomp_u8(&read_buffer);
    }

    //Set skip delay
    aad.skip_delay = @truncate(previous);
    aad.skip_delay_counter = @truncate(previous);

    //Load music
    var mus_buffer = raw_data[MUS_OFFSET..];

    for (0..song_number) |_| {
        while (true) {
            var offset = chomp_u16(&mus_buffer);
            if (offset == 0xFFFF) {
                break;
            }
        }
    }

    aad.active_channels = 0;
    for (0..AdlibData.ChannelCount) |i| {
        var offset = chomp_u16(&mus_buffer);
        if (offset == 0xFFFF) {
            break;
        }
        aad.active_channels += 1;
        aad.channels[i] = .{ .offset = offset - audio_engine.seg_reduction, .vox = @truncate(i) };
    }
    c.SDL_UnlockAudio();
    c.SDL_PauseAudio(0); //perhaps unneccessary
}

var song_nr: u8 = 0;
pub export fn music_cycle() void {
    if (!game.settings.music) {
        return;
    }
    if (song_nr > 15) {
        song_nr = 0;
    }
    std.log.info("Playing song {d}", .{song_nr});
    music_select_song(song_nr);
    song_nr += 1;
}

pub export fn music_toggle() bool {
    game.settings.music = !game.settings.music;
    return game.settings.music;
}

// FIXME: this is just weird
pub export fn music_wait_to_finish() void {
    var waiting: bool = true;
    if (!game.settings.music) {
        return;
    }
    while (waiting) {
        c.SDL_Delay(1);
        globals.keystate = c.SDL_GetKeyboardState(null);
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) { //Check all events
            if (event.type == c.SDL_QUIT) {
                // FIXME: handle this better
                //return TITUS_ERROR_QUIT;
                return;
            } else if (event.type == c.SDL_KEYDOWN) {
                if (event.key.keysym.scancode == c.KEY_ESC) {
                    // FIXME: handle this better
                    // return TITUS_ERROR_QUIT;
                    return;
                }
            }
        }
        if (audio_engine.aad.active_channels == 0) {
            waiting = false;
        }
    }
}

pub export fn music_restart_if_finished() void {
    if (game.settings.music) {
        if (audio_engine.aad.active_channels == 0) {
            music_select_song(audio_engine.last_song);
            audio_engine.playing_musical_sfx = false;
        }
    }
}

fn chomp_u8(bytes: *[]const u8) u8 {
    if (bytes.len > 0) {
        const result = bytes.*[0];
        bytes.len -= 1;
        bytes.ptr += 1;
        return result;
    }
    unreachable;
}

fn chomp_u16(bytes: *[]const u8) u16 {
    if (bytes.len > 1) {
        const result = @as(u16, bytes.*[0]) + (@as(u16, bytes.*[1]) << 8);
        bytes.*.len -= 2;
        bytes.*.ptr += 2;
        return result;
    }
    unreachable;
}

fn sfx_init() void {
    var aad: *AdlibData = &(audio_engine.aad);
    audio_engine.sfx_on = false;
    audio_engine.sfx_time = 0;

    var raw_data = aad.data[SFX_OFFSET..];

    for (0..AdlibData.SfxCount) |i| {
        for (0..5) |k| {
            aad.sfx[i].op[0][k] = chomp_u8(&raw_data);
        }

        for (0..5) |k| {
            aad.sfx[i].op[1][k] = chomp_u8(&raw_data);
        }

        aad.sfx[i].fb_alg = chomp_u8(&raw_data);
    }
}

pub export fn sfx_play(fx_number: c_int) void {
    var aad: *AdlibData = &(audio_engine.aad);
    audio_engine.sfx_time = 15;
    audio_engine.sfx_on = true;

    const index: usize = @intCast(fx_number);
    c.SDL_LockAudio();
    insmaker(&aad.sfx[index].op[0], 0x13); //Channel 6 operator 1
    insmaker(&aad.sfx[index].op[1], 0x10); //Channel 6 operator 2
    c.OPL_WriteRegister(0xC6, aad.sfx[index].fb_alg); //Channel 6 (Feedback/Algorithm)
    c.SDL_UnlockAudio();
}

fn sfx_driver() void {
    if (!audio_engine.sfx_on) {
        return;
    }
    const aad: *AdlibData = &(audio_engine.aad);
    c.OPL_WriteRegister(0xBD, 0xEF & aad.perc_stat);
    c.OPL_WriteRegister(0xA6, 0x57);
    c.OPL_WriteRegister(0xB6, 1);
    c.OPL_WriteRegister(0xB6, 5);
    c.OPL_WriteRegister(0xBD, 0x10 | aad.perc_stat);
    audio_engine.sfx_time -= 1;
    if (audio_engine.sfx_time == 0) {
        sfx_stop();
    }
}

fn sfx_stop() void {
    const tmpins1: []const u8 = &.{ 0xF5, 0x7F, 0x00, 0x11, 0x00 };
    const tmpins2: []const u8 = &.{ 0xF8, 0xFF, 0x04, 0x30, 0x00 };
    c.SDL_LockAudio();
    c.OPL_WriteRegister(0xB6, 32);
    insmaker(tmpins1, 0x13); //Channel 6 operator 1
    insmaker(tmpins2, 0x10); //Channel 6 operator 2
    c.OPL_WriteRegister(0xC6, 0x08); //Channel 6 (Feedback/Algorithm)
    c.SDL_UnlockAudio();
    audio_engine.sfx_on = false;
}

pub fn set_volume(volume: u8) void {
    var volume_clamp = volume;
    if (volume_clamp > 128) {
        volume_clamp = 128;
    }
    game.settings.volume_master = volume_clamp;
    OPL_SDL_VOLUME = volume_clamp;
}

pub fn get_volume() u8 {
    return OPL_SDL_VOLUME;
}
