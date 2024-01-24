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

const usecs_in_sec: u64 = 1000 * 1000;
const MAX_SOUND_SLICE_TIME = 100; // ms

const SampleType = i16;
const NumChannels = 2;
const Stride = @sizeOf(SampleType) * NumChannels;

pub const opl_callback_t = ?*const fn (?*anyopaque) callconv(.C) void;

pub var OPL_SDL_VOLUME = SDL.SDL_MIX_MAXVOLUME;

// When the callback mutex is locked using OPL_Lock, callback functions are not invoked.
var callback_mutex = Mutex{};

// Queue of callbacks waiting to be invoked.
const QueuedCallback = struct {
    callback: opl_callback_t = null,
    data: ?*anyopaque = null,
    time: u64 = 0,
};
fn timeOrder(context: void, a: QueuedCallback, b: QueuedCallback) Order {
    _ = context;
    return std.math.order(a.time, b.time);
}
const CallbackQueue = std.PriorityQueue(QueuedCallback, void, timeOrder);
var callback_queue: CallbackQueue = undefined;

test "test queue priority" {
    var queue = CallbackQueue.init(std.testing.allocator, {});
    defer queue.deinit();
    try queue.add(QueuedCallback{ .time = 0 });
    try queue.add(QueuedCallback{ .time = 1 });
    try queue.add(QueuedCallback{ .time = 2 });
    try std.testing.expectEqual(QueuedCallback{ .time = 0 }, queue.remove());
    try std.testing.expectEqual(QueuedCallback{ .time = 1 }, queue.remove());
    try std.testing.expectEqual(QueuedCallback{ .time = 2 }, queue.remove());
}

// Mutex used to control access to the callback queue.
var callback_queue_mutex = Mutex{};

// Current time, in us since startup:
var current_time: u64 = 0;

// OPL software emulator structure.
var opl_chip: OPL3.opl3_chip = undefined;

// Temporary mixing buffer used by the mixing callback.
var mix_buffer: []SampleType = &.{};

// SDL parameters.
var mixing_freq: c_int = undefined;
var mixing_channels: c_int = undefined;
var mixing_format: u16 = undefined;

var initialized = false;

var sample_rate: c_uint = 22050;

var allocator: std.mem.Allocator = undefined;

// Advance time by the specified number of samples, invoking any
// callback functions as appropriate.

fn AdvanceTime(nsamples: u64) void {
    callback_queue_mutex.lock();

    // Advance time.
    var us: u64 = (nsamples * usecs_in_sec) / @as(u64, @intCast(mixing_freq));
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
    OPL3.OPL3_GenerateStream(&opl_chip, &mix_buffer[0], nsamples);
    SDL.SDL_MixAudioFormat(buffer, @ptrCast(&mix_buffer[0]), SDL.AUDIO_S16SYS, nsamples * @sizeOf(SampleType) * NumChannels, OPL_SDL_VOLUME);
}

// Callback function to fill a new sound buffer:
fn OPL_Mix_Callback(udata: ?*anyopaque, buffer: [*c]u8, len: c_int) callconv(.C) void {
    _ = udata;
    var filled: u64 = 0;
    var buffer_samples: c_uint = @as(c_uint, @intCast(len)) / Stride;

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
            nsamples = (nsamples + usecs_in_sec - 1) / usecs_in_sec;

            if (nsamples > buffer_samples - filled) {
                nsamples = buffer_samples - filled;
            }
        }

        callback_queue_mutex.unlock();

        // Add emulator output to buffer.
        FillBuffer(buffer + filled * Stride, @truncate(nsamples));
        filled += nsamples;

        // Invoke callbacks for this point in time.
        AdvanceTime(nsamples);
    }
}

fn GetSliceSize() c_uint {
    const limit: c_uint = (sample_rate * MAX_SOUND_SLICE_TIME) / 1000;

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
        @intCast(sample_rate),
        SDL.AUDIO_S16LSB,
        NumChannels,
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
    mix_buffer = try allocator.alloc(SampleType, @intCast(mixing_freq * NumChannels));
    errdefer allocator.free(mix_buffer);

    // Create the emulator structure:

    OPL3.OPL3_Reset(&opl_chip, @intCast(mixing_freq));

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
    sample_rate = rate;
}

pub fn writeRegister(reg_num: u16, value: u8) void {
    OPL3.OPL3_WriteRegBuffered(&opl_chip, reg_num, value);
}

pub fn setCallback(us: u64, callback: opl_callback_t, data: ?*anyopaque) void {
    if (!initialized) {
        return;
    }
    callback_queue_mutex.lock();
    // FIXME: actual error handling
    callback_queue.add(QueuedCallback{
        .callback = callback,
        .data = data,
        .time = current_time + us,
    }) catch {
        unreachable;
    };
    callback_queue_mutex.unlock();
}
