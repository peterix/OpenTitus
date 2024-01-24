//
// Copyright(C) 2005-2014 Simon Howard
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// DESCRIPTION:
//     OPL interface.
//

// TODO: this should be the only remaining piece of C code we use in all of OpenTitus
const OPL3 = @cImport({
    @cInclude("./opl3.h");
});

// FIXME: remove
const SDL = @cImport({
    @cInclude("SDL.h");
    @cInclude("SDL_mixer.h");
});

const std = @import("std");
const Mutex = std.Thread.Mutex;
const Order = std.math.Order;

const OPL_REG_WAVEFORM_ENABLE = 0x01;
const OPL_REG_TIMER1 = 0x02;
const OPL_REG_TIMER2 = 0x03;
const OPL_REG_TIMER_CTRL = 0x04;
const OPL_REG_FM_MODE = 0x08;
const OPL_REG_NEW = 0x105;

const OPL_SECOND: u64 = 1000 * 1000;
const OPL_MS: u64 = 1000;
const OPL_US: u64 = 1;

const MAX_SOUND_SLICE_TIME = 100; // ms

pub const opl_callback_t = ?*const fn (?*anyopaque) callconv(.C) void;

pub var OPL_SDL_VOLUME = SDL.SDL_MIX_MAXVOLUME;

const opl_timer_t = struct {
    rate: c_uint, // Number of times the timer is advanced per sec.
    enabled: bool = false, // Non-zero if timer is enabled.
    value: c_uint = 0, // Last value that was set.
    expire_time: u64 = 0, // Calculated time that timer will expire.
};

// When the callback mutex is locked using OPL_Lock, callback functions are not invoked.
var callback_mutex = Mutex{};

// Queue of callbacks waiting to be invoked.
const opl_queue_entry_t = struct {
    callback: opl_callback_t = null,
    data: ?*anyopaque = null,
    time: u64 = 0,
};
fn timeOrder(context: void, a: opl_queue_entry_t, b: opl_queue_entry_t) Order {
    _ = context;
    return std.math.order(a.time, b.time);
}
const CallbackQueue = std.PriorityQueue(opl_queue_entry_t, void, timeOrder);
var callback_queue: CallbackQueue = undefined;

test "test queue priority" {
    var queue = CallbackQueue.init(std.testing.allocator, {});
    defer queue.deinit();
    try queue.add(opl_queue_entry_t{ .time = 0 });
    try queue.add(opl_queue_entry_t{ .time = 1 });
    try queue.add(opl_queue_entry_t{ .time = 2 });
    try std.testing.expectEqual(opl_queue_entry_t{ .time = 0 }, queue.remove());
    try std.testing.expectEqual(opl_queue_entry_t{ .time = 1 }, queue.remove());
    try std.testing.expectEqual(opl_queue_entry_t{ .time = 2 }, queue.remove());
}

// Mutex used to control access to the callback queue.
var callback_queue_mutex = Mutex{};

// Current time, in us since startup:
var current_time: u64 = 0;

// OPL software emulator structure.
var opl_chip: OPL3.opl3_chip = undefined;
var opl_opl3mode: c_int = undefined;

// Temporary mixing buffer used by the mixing callback.
var mix_buffer: []u8 = &.{};

// Timers; DBOPL does not do timer stuff itself.
var timer1 = opl_timer_t{ .rate = 12500 };
var timer2 = opl_timer_t{ .rate = 3125 };

// SDL parameters.
var mixing_freq: c_int = undefined;
var mixing_channels: c_int = undefined;
var mixing_format: u16 = undefined;

var initialized = false;

var opl_sample_rate: c_uint = 22050;

var allocator: std.mem.Allocator = undefined;

// Advance time by the specified number of samples, invoking any
// callback functions as appropriate.

fn AdvanceTime(nsamples: u64) void {
    callback_queue_mutex.lock();

    // Advance time.
    var us: u64 = (nsamples * OPL_SECOND) / @as(u64, @intCast(mixing_freq));
    current_time += us;

    // Are there callbacks to invoke now?  Keep invoking them
    // until there are no more left.
    while (callback_queue.count() > 0 and current_time >= callback_queue.peek().?.time) {
        // Pop the callback from the queue to invoke it.

        const entry = callback_queue.remove();

        // The mutex stuff here is a bit complicated.  We must
        // hold callback_mutex when we invoke the callback (so that
        // the control thread can use OPL_Lock() to prevent callbacks
        // from being invoked), but we must not be holding
        // callback_queue_mutex, as the callback must be able to
        // call setCallback to schedule new callbacks.

        callback_queue_mutex.unlock();
        callback_mutex.lock();
        entry.callback.?(entry.data);
        callback_mutex.unlock();
        callback_queue_mutex.lock();
    }

    callback_queue_mutex.unlock();
}

// Call the OPL emulator code to fill the specified buffer.
fn FillBuffer(buffer: *u8, nsamples: u32) void {
    // This seems like a reasonable assumption.  mix_buffer is
    // 1 second long, which should always be much longer than the
    // SDL mix buffer.
    if (nsamples >= mixing_freq) {
        unreachable;
    }

    // OPL output is generated into temporary buffer and then mixed
    // (to avoid overflows etc.)
    OPL3.OPL3_GenerateStream(&opl_chip, @alignCast(@ptrCast(&mix_buffer[0])), nsamples);
    SDL.SDL_MixAudioFormat(buffer, @ptrCast(&mix_buffer[0]), SDL.AUDIO_S16SYS, nsamples * 4, OPL_SDL_VOLUME);
}

// Callback function to fill a new sound buffer:
fn OPL_Mix_Callback(udata: ?*anyopaque, buffer: [*c]u8, len: c_int) callconv(.C) void {
    _ = udata;
    var filled: u64 = 0;
    var buffer_samples: c_uint = @as(c_uint, @intCast(len)) / 4;

    // Repeatedly call the OPL emulator update function until the buffer is full.
    while (filled < buffer_samples) {
        var nsamples: u64 = 0;

        callback_queue_mutex.lock();

        // Work out the time until the next callback waiting in
        // the callback queue must be invoked.  We can then fill the
        // buffer with this many samples.

        if (callback_queue.count() == 0) {
            nsamples = buffer_samples - filled;
        } else {
            const next_callback_time = callback_queue.peek().?.time;

            nsamples = (next_callback_time - current_time) * @as(u32, @intCast(mixing_freq));
            nsamples = (nsamples + OPL_SECOND - 1) / OPL_SECOND;

            if (nsamples > buffer_samples - filled) {
                nsamples = buffer_samples - filled;
            }
        }

        callback_queue_mutex.unlock();

        // Add emulator output to buffer.
        FillBuffer(buffer + filled * 4, @truncate(nsamples));
        filled += nsamples;

        // Invoke callbacks for this point in time.
        AdvanceTime(nsamples);
    }
}

fn GetSliceSize() c_uint {
    const limit: c_uint = (opl_sample_rate * MAX_SOUND_SLICE_TIME) / 1000;

    // Try all powers of two, not exceeding the limit.
    var n: c_uint = 1;
    while (true) {
        // 2^n <= limit < 2^n+1 ?
        if ((@as(c_uint, 1) << @truncate(n + 1)) > limit) {
            return (@as(c_uint, 1) << @truncate(n));
        }
        n += 1;
    }

    // Should never happen?
    return 1024;
}

fn OPLTimer_CalculateEndTime(timer: *opl_timer_t) void {
    // If the timer is enabled, calculate the time when the timer
    // will expire.

    if (timer.enabled) {
        var tics = 0x100 - timer.value;
        timer.expire_time = current_time + (@as(u64, tics) * OPL_SECOND) / timer.rate;
    }
}

// Initialize the OPL library. Return value indicates type of OPL chip
// detected, if any.
pub fn init(alloc: std.mem.Allocator) !void {
    allocator = alloc;
    // Check if SDL_mixer has been opened already
    // If not, we must initialize it now
    if (SDL.SDL_Init(SDL.SDL_INIT_AUDIO) < 0) {
        std.log.err("Unable to set up sound.", .{});
        return error.SDLInitFailed;
    }
    errdefer SDL.SDL_QuitSubSystem(SDL.SDL_INIT_AUDIO);

    if (SDL.Mix_OpenAudioDevice(
        @intCast(opl_sample_rate),
        SDL.AUDIO_S16LSB,
        2,
        @intCast(GetSliceSize()),
        null,
        SDL.SDL_AUDIO_ALLOW_FREQUENCY_CHANGE,
    ) < 0) {
        std.log.err("Error initialising SDL_mixer: {s}", .{SDL.Mix_GetError()});
        return error.OpenAudioDeviceFailed;
    }
    errdefer SDL.Mix_CloseAudio();

    SDL.SDL_PauseAudio(0);

    // Queue structure of callbacks to invoke.
    callback_queue = CallbackQueue.init(allocator, {});
    current_time = 0;

    // Get the mixer frequency, format and number of channels.
    _ = SDL.Mix_QuerySpec(&mixing_freq, &mixing_format, &mixing_channels);

    // Only supports AUDIO_S16SYS
    if (mixing_format != @as(u16, @intCast(SDL.AUDIO_S16LSB)) or mixing_channels != 2) {
        std.log.err("OpenTitus only supports native signed 16-bit LSB, stereo format!", .{});
        return error.UnexpectedMixerFormat;
    }

    // Mix buffer: four bytes per sample (16 bits * 2 channels):
    mix_buffer = try allocator.alloc(u8, @intCast(mixing_freq * 4));
    errdefer allocator.free(mix_buffer);

    // Create the emulator structure:

    OPL3.OPL3_Reset(&opl_chip, @intCast(mixing_freq));
    opl_opl3mode = 0;

    callback_mutex = Mutex{};
    callback_queue_mutex = Mutex{};

    // Set postmix that adds the OPL music. This is deliberately done
    // as a postmix and not using Mix_HookMusic() as the latter disables
    // normal SDL_mixer music mixing.
    SDL.Mix_SetPostMix(OPL_Mix_Callback, null);

    initialized = true;
}

// Shut down the OPL library.
pub fn deinit() void {
    if (!initialized) {
        return;
    }
    SDL.SDL_LockAudio();
    SDL.Mix_SetPostMix(null, null);
    SDL.SDL_UnlockAudio();

    SDL.Mix_CloseAudio();
    SDL.SDL_QuitSubSystem(SDL.SDL_INIT_AUDIO);

    callback_queue.deinit();
    allocator.free(mix_buffer);
}

// Set the sample rate used for software OPL emulation.
pub fn setSampleRate(rate: c_uint) void {
    opl_sample_rate = rate;
}

pub fn writeRegister(reg_num: u16, value: u8) void {
    switch (reg_num) {
        OPL_REG_TIMER1 => {
            timer1.value = value;
            OPLTimer_CalculateEndTime(&timer1);
        },

        OPL_REG_TIMER2 => {
            timer2.value = value;
            OPLTimer_CalculateEndTime(&timer2);
        },

        OPL_REG_TIMER_CTRL => {
            if ((value & 0x80) != 0) {
                timer1.enabled = false;
                timer2.enabled = false;
            } else {
                if ((value & 0x40) == 0) {
                    timer1.enabled = (value & 0x01) != 0;
                    OPLTimer_CalculateEndTime(&timer1);
                }

                if ((value & 0x20) == 0) {
                    timer1.enabled = (value & 0x02) != 0;
                    OPLTimer_CalculateEndTime(&timer2);
                }
            }
        },

        OPL_REG_NEW => {
            opl_opl3mode = value & 0x01;
        },

        else => {
            OPL3.OPL3_WriteRegBuffered(&opl_chip, reg_num, value);
        },
    }
}

//
// Timer functions.
//
pub fn setCallback(us: u64, callback: opl_callback_t, data: ?*anyopaque) void {
    if (!initialized) {
        return;
    }
    callback_queue_mutex.lock();
    // FIXME: actual error handling
    callback_queue.add(opl_queue_entry_t{ .callback = callback, .data = data, .time = current_time + us }) catch {
        unreachable;
    };
    callback_queue_mutex.unlock();
}
