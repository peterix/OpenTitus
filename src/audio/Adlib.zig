//
// Copyright (C) 2008 - 2024 The OpenTitus team
// Copyright (C) 2005 - 2014 Simon Howard (originally under GPL2 as part of the OPL library)
//
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

const std = @import("std");
const Backend = @import("Backend.zig");
const _engine = @import("engine.zig");
const AudioEngine = _engine.AudioEngine;

const OPL3 = @cImport({
    @cInclude("./opl3.h");
});

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

const MUS_OFFSET = 0;
const INS_OFFSET = 352;
const SFX_OFFSET = 1950;

const opera: []const u8 = &.{ 0, 0, 1, 2, 3, 4, 5, 8, 9, 0xA, 0xB, 0xC, 0xD, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15 };
const voxp: []const u8 = &.{ 1, 2, 3, 7, 8, 9, 13, 17, 15, 18, 14 };
const gamme: []const c_uint = &.{ 343, 363, 385, 408, 432, 458, 485, 514, 544, 577, 611, 647, 0 };

const Instrument = struct {
    //Two operators and five data settings
    op: [2][5]u8 = .{
        .{ 0, 0, 0, 0, 0 },
        .{ 0, 0, 0, 0, 0 },
    },
    fb_alg: u8 = 0,
    //(only for perc instruments, 0xFE if this is melodic instrument, 0xFF if this instrument is disabled)
    vox: u8 = 0,
};

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

    fn mainCommand(self: *const Instruction) MainCommand {
        return @enumFromInt(self.oct);
    }

    fn subCommand(self: *const Instruction) SubCommand {
        return @enumFromInt(self.freq);
    }
};

allocator: std.mem.Allocator = undefined,
channels: [ChannelCount]Channel = [_]Channel{.{}} ** ChannelCount,
active_channels: c_int = 0,
perc_stat: u8 = 0,
skip_delay: u8 = 0,
skip_delay_counter: u8 = 0,
current_track: ?u8 = null,

seg_reduction: u16 = 0,
sfx_on: bool = false,
sfx_time: u16 = 0,

sfx: [SfxCount]Instrument = [_]Instrument{.{}} ** SfxCount,
instrument_data: [InstrumentCount]Instrument = [_]Instrument{.{}} ** InstrumentCount,
data: []const u8 = "",
engine: *AudioEngine = undefined,

// OPL software emulator structure.
opl_chip: OPL3.opl3_chip = undefined,

inline fn writeRegister(self: *Adlib, reg_num: u16, value: u8) void {
    OPL3.OPL3_WriteRegBuffered(&self.opl_chip, reg_num, value);
}

pub fn backend(self: *Adlib) Backend {
    return .{
        .name = "AdLib",
        .ptr = self,
        .vtable = &.{
            .init = init,
            .deinit = deinit,
            .fillBuffer = fillBuffer,
            .playTrack = play_track,
            .stopTrack = stop_track,
            .playSfx = play_sfx,
            .isPlayingATrack = is_playing_a_track,
        },
    };
}

fn init(ctx: *anyopaque, engine: *AudioEngine, allocator: std.mem.Allocator, sample_rate: u32) Backend.Error!void {
    const self: *Adlib = @ptrCast(@alignCast(ctx));
    self.engine = engine;
    self.allocator = allocator;
    const bytes = load_file(
        "music.bin",
        allocator,
    ) catch {
        return Backend.Error.InvalidData;
    };
    errdefer allocator.free(bytes);

    switch (bytes.len) {
        18749 => {
            self.seg_reduction = 1301;
        },
        18184 => {
            self.seg_reduction = 1345;
        },
        else => {
            std.log.err("music.bin has unexpected size!", .{});
            return Backend.Error.InvalidData;
        },
    }

    // Create the emulator structure:
    OPL3.OPL3_Reset(&self.opl_chip, sample_rate);

    self.data = bytes;
    self.sfx_init();

    self.engine.setCallback(0, TimerCallback, @constCast(@ptrCast(self)));
}

fn deinit(ctx: *anyopaque) void {
    const self: *Adlib = @ptrCast(@alignCast(ctx));
    self.allocator.free(self.data);
}

fn fillBuffer(ctx: *anyopaque, buffer: []i16, nsamples: u32) void {
    const self: *Adlib = @ptrCast(@alignCast(ctx));
    OPL3.OPL3_GenerateStream(&self.opl_chip, &buffer[0], nsamples);
}

fn is_playing_a_track(ctx: *anyopaque) bool {
    const self: *Adlib = @ptrCast(@alignCast(ctx));
    return self.active_channels != 0;
}

fn stop_track(ctx: *anyopaque, song_number: u8) void {
    const self: *Adlib = @ptrCast(@alignCast(ctx));
    if (self.current_track) |track| {
        if (track == song_number) {
            self.active_channels = 0;
            self.current_track = null;
        }
    }
}

fn play_track(ctx: *anyopaque, song_number: u8) void {
    const self: *Adlib = @ptrCast(@alignCast(ctx));
    self.current_track = song_number;

    var raw_data = self.data;
    self.perc_stat = 0x20;

    //Load instruments
    var instrument_buffer = raw_data[INS_OFFSET..];

    for (0..song_number) |_| {
        while (true) {
            var temp = chomp_u16(&instrument_buffer);
            if (temp == 0xFFFF) {
                break;
            }
        }
    }
    all_vox_zero(self);

    for (0..InstrumentCount) |i| {
        //Init; instrument not in use
        self.instrument_data[i].vox = 0xFF;
    }

    var previous: u16 = 0;
    var current = chomp_u16(&instrument_buffer);
    for (0..InstrumentCount) |i| {
        previous = current;
        current = chomp_u16(&instrument_buffer);

        if (current == 0xFFFF) //Terminate for loop
            break;

        if (previous == 0) //Instrument not in use
            continue;

        var read_buffer = raw_data[previous - self.seg_reduction ..];

        if (i > 14) {
            //Perc instrument (15-18) have an extra byte, melodic (0-14) have not
            self.instrument_data[i].vox = chomp_u8(&read_buffer);
        } else {
            self.instrument_data[i].vox = 0xFE;
        }

        for (0..5) |k| {
            self.instrument_data[i].op[0][k] = chomp_u8(&read_buffer);
        }

        for (0..5) |k| {
            self.instrument_data[i].op[1][k] = chomp_u8(&read_buffer);
        }

        self.instrument_data[i].fb_alg = chomp_u8(&read_buffer);
    }

    //Set skip delay
    self.skip_delay = @truncate(previous);
    self.skip_delay_counter = @truncate(previous);

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

    self.active_channels = 0;
    for (0..ChannelCount) |i| {
        var offset = chomp_u16(&mus_buffer);
        if (offset == 0xFFFF) {
            break;
        }
        self.active_channels += 1;
        self.channels[i] = .{
            .offset = offset - self.seg_reduction,
            .vox = @truncate(i),
        };
    }
}

fn play_sfx(ctx: *anyopaque, fx_number: u8) void {
    const self: *Adlib = @ptrCast(@alignCast(ctx));
    self.sfx_time = 15;
    self.sfx_on = true;
    const index: usize = @intCast(fx_number);
    Adlib.insmaker(self, &self.sfx[index].op[0], 0x13); //Channel 6 operator 1
    Adlib.insmaker(self, &self.sfx[index].op[1], 0x10); //Channel 6 operator 2
    self.writeRegister(0xC6, self.sfx[index].fb_alg); //Channel 6 (Feedback/Algorithm)
}

fn load_file(inputfile: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    var file = try std.fs.cwd().openFile(inputfile, .{});
    defer file.close();
    const bytes = file.readToEndAlloc(allocator, std.math.maxInt(usize)) catch |err| {
        std.log.err("Could not open {s}: {}", .{ inputfile, err });
        return err;
    };
    return bytes;
}

fn sfx_init(self: *Adlib) void {
    self.sfx_on = false;
    self.sfx_time = 0;

    var raw_data = self.data[SFX_OFFSET..];

    for (0..SfxCount) |i| {
        for (0..5) |k| {
            self.sfx[i].op[0][k] = chomp_u8(&raw_data);
        }

        for (0..5) |k| {
            self.sfx[i].op[1][k] = chomp_u8(&raw_data);
        }

        self.sfx[i].fb_alg = chomp_u8(&raw_data);
    }
}

fn sfx_driver(self: *Adlib) void {
    if (!self.sfx_on) {
        return;
    }
    self.writeRegister(0xBD, 0xEF & self.perc_stat);
    self.writeRegister(0xA6, 0x57);
    self.writeRegister(0xB6, 1);
    self.writeRegister(0xB6, 5);
    self.writeRegister(0xBD, 0x10 | self.perc_stat);
    self.sfx_time -= 1;
    if (self.sfx_time == 0) {
        self.sfx_stop();
    }
}

fn sfx_stop(self: *Adlib) void {
    const tmpins1: []const u8 = &.{ 0xF5, 0x7F, 0x00, 0x11, 0x00 };
    const tmpins2: []const u8 = &.{ 0xF8, 0xFF, 0x04, 0x30, 0x00 };
    self.writeRegister(0xB6, 32);
    insmaker(self, tmpins1, 0x13); //Channel 6 operator 1
    insmaker(self, tmpins2, 0x10); //Channel 6 operator 2
    self.writeRegister(0xC6, 0x08); //Channel 6 (Feedback/Algorithm)
    self.sfx_on = false;
}

fn processInstruction(self: *Adlib, channel: *Channel, instruction: Instruction) void {
    switch (instruction.mainCommand()) {
        .Duration => {
            channel.duration = instruction.freq;
        },

        .Volume => {
            channel.volume = instruction.freq;
            var tmpC = self.instrument_data[channel.instrument.?].op[0][2];
            // What the F is going on here?
            tmpC = @subWithOverflow(tmpC & 0x3F, 63)[0];

            var tmp1 = (((256 - @as(u16, tmpC)) << 4) & 0x0FF0) * (@as(u8, instruction.freq) + 1);
            tmp1 = 63 - ((tmp1 >> 8) & 0xFF);
            var tmp2 = voxp[channel.vox];
            if (tmp2 <= 13)
                tmp2 += 3;
            tmp2 = opera[@intCast(tmp2)];
            self.writeRegister(0x40 + tmp2, @truncate(tmp1));
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
                var freq = instruction.freq;
                if (freq > 1) {
                    freq -= 1;
                }
                channel.instrument = freq;
                const percussion_bit = @as(c_int, channel.vox) - 6;
                if (percussion_bit >= 0) {
                    // turn off a percussion instrument ?
                    // clear a bit from perc_stat
                    var temp: u8 = @as(u8, 0x10) << @intCast(percussion_bit);
                    self.perc_stat = self.perc_stat | temp;
                    temp = ~(temp) & 0xFF;
                    self.perc_stat = self.perc_stat & temp;
                    self.writeRegister(0xBD, self.perc_stat);
                }
            }
            var tmp2 = voxp[channel.vox];
            if (channel.vox <= 6)
                tmp2 += 3;
            tmp2 = opera[@intCast(tmp2)]; //Adlib channel
            const instrument = &self.instrument_data[channel.instrument.?];
            insmaker(self, &instrument.op[0], tmp2);
            if (channel.vox < 7) {
                insmaker(self, &instrument.op[1], tmp2 - 3);
                self.writeRegister(0xC0 + channel.vox, instrument.fb_alg);
            }
        },
        .SubCommand => {
            switch (instruction.subCommand()) {
                .CallSub => {
                    channel.return_offset = channel.offset.? + 2;
                    var temp = (@as(c_uint, self.data[channel.offset.? + 1]) << 8) & 0xFF00;
                    temp += @as(c_uint, self.data[channel.offset.?]) & 0xFF;
                    channel.offset = temp - self.seg_reduction;
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
                        channel.offset = temp - self.seg_reduction;
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
                    channel.offset = temp - self.seg_reduction;
                },

                .Finish => {
                    channel.offset = null;
                    self.active_channels -= 1;
                },
            }
        },
    }
}

fn fillchip_channel(self: *Adlib, i: usize) void {
    var channel = &self.channels[i];
    if (channel.offset == null) {
        return;
    }
    if (channel.delay_counter > 1) {
        channel.delay_counter -= 1;
        return;
    }
    var instruction: Instruction = undefined;

    // first, process any pending command instructions
    while (true) {
        instruction = @bitCast(self.data[channel.offset.?]);
        channel.offset.? += 1;

        //Escape the loop and play some notes based on oct and freq
        if (!instruction.is_command) {
            break;
        }

        self.processInstruction(channel, instruction);

        // if we have no more data to read, stop processing the channel
        if (channel.offset == null) {
            return;
        }
    }

    // if we didn't exit, we have some note(s) to play
    channel.octave = instruction.oct;
    channel.freq = instruction.freq;

    //Play note
    if (gamme[channel.freq] != 0) {
        if (self.instrument_data[channel.instrument.?].vox == 0xFE) {
            //Play a frequence
            //Output lower 8 bits of frequence
            self.writeRegister(0xA0 + channel.vox, @as(u8, @truncate(gamme[channel.freq] & 0xFF)));
            if (channel.lie_late != 1) {
                self.writeRegister(0xB0 + channel.vox, 0); //Silence the channel
            }
            var tmp1 = (channel.octave + 2) & 0x07; //Octave (3 bits)
            var tmp2 = @as(u8, @truncate((gamme[channel.freq] >> 8) & 0x03)); //Frequency (higher 2 bits)
            self.writeRegister(0xB0 + channel.vox, 0x20 + (tmp1 << 2) + tmp2); //Voices the channel, and output octave and last bits of frequency
            channel.lie_late = channel.lie;
        } else {
            //Play a perc instrument
            if (channel.instrument != channel.octave + 15) {
                //New instrument
                //Similar to Instrument command, oct = 6
                channel.instrument = channel.octave + 15; //(1st perc instrument is the 16th instrument)
                const instrument = &(self.instrument_data[channel.instrument.?]);
                channel.vox = instrument.vox;
                const percussion_bit = @as(c_int, channel.vox) - 6;
                self.perc_stat = self.perc_stat | (@as(u8, 0x10) >> @intCast(percussion_bit)); //set a bit in perc_stat
                var tmp2 = voxp[channel.vox];
                if (channel.vox <= 6) {
                    tmp2 += 3;
                }
                tmp2 = opera[@intCast(tmp2)]; //Adlib channel
                insmaker(self, &instrument.op[0], tmp2);
                if (channel.vox < 7) {
                    insmaker(self, &instrument.op[1], tmp2 - 3);
                    self.writeRegister(0xC0 + channel.vox, instrument.fb_alg);
                }

                //Similar to Volume command, oct = 1
                var tmpC = instrument.op[0][2];
                tmpC = @subWithOverflow(tmpC & 0x3F, 63)[0];
                var tmp1 = (((256 - @as(u16, tmpC)) << 4) & 0x0FF0) * (channel.volume + 1);
                tmp1 = 63 - ((tmp1 >> 8) & 0xFF);
                tmp2 = voxp[channel.vox];
                if (tmp2 <= 13) {
                    tmp2 += 3;
                }
                tmp2 = opera[@intCast(tmp2)];
                self.writeRegister(0x40 + tmp2, @truncate(tmp1));
            }
            const percussion_bit = @as(c_int, channel.vox) - 6;
            var tmpC = @as(u8, 0x10) >> @intCast(percussion_bit);
            self.writeRegister(0xBD, self.perc_stat & ~tmpC); //Output perc_stat with one bit removed
            if (channel.vox == 6) {
                self.writeRegister(0xA6, 0x57); //
                self.writeRegister(0xB6, 0); // Output the perc sound
                self.writeRegister(0xB6, 5); //
            }
            self.writeRegister(0xBD, self.perc_stat); //Output perc_stat
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

fn fillchip(self: *Adlib) void {
    self.sfx_driver();

    if (self.active_channels == 0) {
        return;
    }

    // FIXME: what is the overflow for? or was it just a buggy C mess?
    self.skip_delay_counter = @subWithOverflow(self.skip_delay_counter, 1)[0];

    if (self.skip_delay_counter == 0) {
        self.skip_delay_counter = self.skip_delay;
        return; //Skip (for modifying tempo)
    }
    for (0..ChannelCount) |i| {
        self.fillchip_channel(i);
    }
    if (self.active_channels == 0) {
        self.current_track = null;
    }
}

fn insmaker(self: *Adlib, insdata: []const u8, channel: u8) void {
    self.writeRegister(0x60 + channel, insdata[0]); //Attack Rate / Decay Rate
    self.writeRegister(0x80 + channel, insdata[1]); //Sustain Level / Release Rate
    self.writeRegister(0x40 + channel, insdata[2]); //Key scaling level / Operator output level
    self.writeRegister(0x20 + channel, insdata[3]); //Amp Mod / Vibrato / EG type / Key Scaling / Multiple
    self.writeRegister(0xE0 + channel, insdata[4]); //Wave type
}

fn all_vox_zero(self: *Adlib) void {
    for (0xB0..0xB9) |i|
        self.writeRegister(@intCast(i), 0); //Clear voice, octave and upper bits of frequence
    for (0xA0..0xB9) |i|
        self.writeRegister(@intCast(i), 0); //Clear lower byte of frequence

    self.writeRegister(0x08, 0x00);
    self.writeRegister(0xBD, 0x00);
    self.writeRegister(0x40, 0x3F);
    self.writeRegister(0x41, 0x3F);
    self.writeRegister(0x42, 0x3F);
    self.writeRegister(0x43, 0x3F);
    self.writeRegister(0x44, 0x3F);
    self.writeRegister(0x45, 0x3F);
    self.writeRegister(0x48, 0x3F);
    self.writeRegister(0x49, 0x3F);
    self.writeRegister(0x4A, 0x3F);
    self.writeRegister(0x4B, 0x3F);
    self.writeRegister(0x4C, 0x3F);
    self.writeRegister(0x4D, 0x3F);
    self.writeRegister(0x50, 0x3F);
    self.writeRegister(0x51, 0x3F);
    self.writeRegister(0x52, 0x3F);
    self.writeRegister(0x53, 0x3F);
    self.writeRegister(0x54, 0x3F);
    self.writeRegister(0x55, 0x3F);
}

fn TimerCallback(callback_data: ?*anyopaque) callconv(.C) void {
    var self: *Adlib = @alignCast(@ptrCast(callback_data));
    // Read data until we must make a delay.
    self.fillchip();

    // Schedule the next timer callback.
    // Delay is original 13.75 ms
    self.engine.setCallback(13750, TimerCallback, callback_data);
}
