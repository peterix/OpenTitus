//
// Copyright (C) 2008 - 2024 The OpenTitus team
// Copyright (C) 2005 - 2014 Simon Howard (originally under GPL2 as part of the OPL library)
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

// TODO: implement a way to use music from the Amiga version of the game
// TODO: research how Amiga version does sound effects, use those too

const std = @import("std");
const Mutex = std.Thread.Mutex;
const Order = std.math.Order;

const Adlib = @import("Adlib.zig");
const Backend = @import("Backend.zig");
const miniaudio = @import("miniaudio.zig");
const SDL = @import("../SDL.zig");
const c = @import("../c.zig");
const game = @import("../game.zig");
const data = @import("../data.zig");

const usecs_in_sec: u64 = 1000 * 1000;
const MAX_SOUND_SLICE_TIME = 100; // ms

const SampleType = i16;
const NumChannels = 2;
const MixingFreq = 44100;
const Stride = @sizeOf(SampleType) * NumChannels;

// Queue of callbacks waiting to be invoked.
pub const BackendCallback = ?*const fn (?*anyopaque) void;
const QueuedCallback = struct {
    callback: BackendCallback = null,
    data: ?*anyopaque = null,
    time: u64 = 0,
};
fn timeOrder(context: void, a: QueuedCallback, b: QueuedCallback) Order {
    _ = context;
    return std.math.order(a.time, b.time);
}
const CallbackQueue = std.PriorityQueue(QueuedCallback, void, timeOrder);

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

pub const AudioEngine = struct {
    allocator: std.mem.Allocator = undefined,

    config: miniaudio.ma_device_config = undefined,
    device: miniaudio.ma_device = undefined,

    adlib: Adlib = .{},
    backend: Backend = undefined,
    last_song: u8 = 0,
    volume: u8 = 128,

    // When the callback mutex is locked using OPL_Lock, callback functions are not invoked.
    callback_mutex: Mutex = Mutex{},

    // Queue of callbacks to call at future timestamps (tracked in usecs)
    callback_queue: CallbackQueue = undefined,
    callback_queue_mutex: Mutex = Mutex{},

    // Current time, in us since startup:
    current_time: u64 = 0,

    // Temporary mixing buffer used by the mixing callback.
    mix_buffer: []SampleType = &.{},

    initialized: bool = false,

    pub fn init(self: *AudioEngine, allocator: std.mem.Allocator) !void {
        self.allocator = allocator;
        self.last_song = 0;
        self.volume = game.settings.volume_master;
        self.backend = self.adlib.backend();

        self.config = miniaudio.ma_device_config_init(miniaudio.ma_device_type_playback);
        self.config.playback.format = miniaudio.ma_format_s16;
        self.config.playback.channels = NumChannels;
        self.config.sampleRate = MixingFreq;
        self.config.dataCallback = data_callback;
        self.config.pUserData = self;

        if (miniaudio.ma_device_init(null, &self.config, &self.device) != miniaudio.MA_SUCCESS) {
            std.log.err("Error initialising miniaudio.", .{});
            return error.OpenAudioDeviceFailed;
        }
        errdefer miniaudio.ma_device_uninit(&self.device);

        _ = miniaudio.ma_device_set_master_volume(
            &self.device,
            @as(f32, @floatFromInt(self.volume)) / 128.0,
        );

        // Queue structure of callbacks to invoke.
        self.callback_queue = CallbackQueue.init(allocator, {});
        self.current_time = 0;

        self.callback_mutex = Mutex{};
        self.callback_queue_mutex = Mutex{};

        try self.backend.init(self, allocator, MixingFreq);

        _ = miniaudio.ma_device_start(&self.device);
        errdefer _ = miniaudio.ma_device_stop(&self.device);

        self.initialized = true;
    }

    pub fn deinit(self: *AudioEngine) void {
        if (!self.initialized) {
            return;
        }
        _ = miniaudio.ma_device_stop(&self.device);
        self.backend.deinit();
        miniaudio.ma_device_uninit(&self.device);

        self.callback_queue.deinit();
    }

    // Advance time by the specified number of samples, invoking any
    // callback functions as appropriate.
    fn advanceTime(self: *AudioEngine, nsamples: u64) void {
        self.callback_queue_mutex.lock();

        // Advance time.
        const us: u64 = (nsamples * usecs_in_sec) / @as(u64, @intCast(MixingFreq));
        self.current_time += us;

        // Are there callbacks to invoke now?  Keep invoking them
        // until there are no more left.
        while (self.callback_queue.count() > 0 and self.current_time >= self.callback_queue.peek().?.time) {
            // Pop the callback from the queue to invoke it.

            const entry = self.callback_queue.remove();

            // The mutex stuff here is a bit complicated.  We must
            // hold callback_mutex when we invoke the callback (so that
            // the control thread can use OPL_Lock() to prevent callbacks
            // from being invoked), but we must not be holding
            // callback_queue_mutex, as the callback must be able to
            // call setCallback to schedule new callbacks.

            self.callback_queue_mutex.unlock();
            self.callback_mutex.lock();
            entry.callback.?(entry.data);
            self.callback_mutex.unlock();
            self.callback_queue_mutex.lock();
        }

        self.callback_queue_mutex.unlock();
    }

    // Call the OPL emulator code to fill the specified buffer.
    fn fillBuffer(self: *AudioEngine, buffer: *u8, nsamples: u32) void {
        var result: []i16 = @as([*]i16, @alignCast(@ptrCast(buffer)))[0..nsamples];
        self.backend.fillBuffer(@ptrCast(result), nsamples);
    }

    fn data_callback(pDevice: ?*anyopaque, buffer: ?*anyopaque, pInput: ?*const anyopaque, frameCount: u32) callconv(.C) void {
        _ = pInput;
        var device: *miniaudio.ma_device = @alignCast(@ptrCast(pDevice.?));
        var self: *AudioEngine = @alignCast(@ptrCast(device.pUserData.?));
        var filled: u64 = 0;

        // Repeatedly call the OPL emulator update function until the buffer is full.
        while (filled < frameCount) {
            var nFrames: u64 = 0;

            self.callback_queue_mutex.lock();

            // Work out the time until the next callback waiting in
            // the callback queue must be invoked.  We can then fill the
            // buffer with this many frames.

            if (self.callback_queue.count() == 0) {
                nFrames = frameCount - filled;
            } else {
                const next_callback_time = self.callback_queue.peek().?.time;

                nFrames = (next_callback_time - self.current_time) * @as(u32, @intCast(MixingFreq));
                nFrames = (nFrames + usecs_in_sec - 1) / usecs_in_sec;

                if (nFrames > frameCount - filled) {
                    nFrames = frameCount - filled;
                }
            }

            self.callback_queue_mutex.unlock();

            // Add emulator output to buffer.
            self.fillBuffer(@as([*c]u8, @ptrCast(buffer)) + filled * Stride, @truncate(nFrames));
            filled += nFrames;

            // Invoke callbacks for this point in time.
            self.advanceTime(nFrames);
        }
    }

    pub fn setCallback(self: *AudioEngine, us: u64, callback: BackendCallback, callback_data: ?*anyopaque) void {
        self.callback_queue_mutex.lock();
        // FIXME: actual error handling
        self.callback_queue.add(QueuedCallback{
            .callback = callback,
            .data = callback_data,
            .time = self.current_time + us,
        }) catch {
            unreachable;
        };
        self.callback_queue_mutex.unlock();
    }
};

pub var audio_engine: AudioEngine = .{};

pub fn music_get_last_song() u8 {
    return audio_engine.last_song;
}

pub export fn music_play_jingle_c(song_number: u8) void {
    audio_engine.backend.lock();
    {
        audio_engine.backend.playTrack(song_number);
    }
    audio_engine.backend.unlock();
}

pub fn music_select_song(song_number: u8) void {
    audio_engine.last_song = song_number;
    if (!game.settings.music) {
        return;
    }

    audio_engine.backend.lock();
    {
        audio_engine.backend.playTrack(song_number);
    }
    audio_engine.backend.unlock();
}

pub export fn music_toggle_c() bool {
    game.settings.music = !game.settings.music;
    if (!game.settings.music) {
        audio_engine.backend.lock();
        {
            audio_engine.backend.stopTrack(audio_engine.last_song);
        }
        audio_engine.backend.unlock();
    }
    return game.settings.music;
}

pub fn music_set_playing(playing: bool) void {
    game.settings.music = playing;
    if (!game.settings.music) {
        audio_engine.backend.lock();
        {
            audio_engine.backend.stopTrack(audio_engine.last_song);
        }
        audio_engine.backend.unlock();
    }
}

pub fn music_is_playing() bool {
    return game.settings.music;
}

// FIXME: this is just weird
pub fn music_wait_to_finish() void {
    var waiting: bool = true;
    if (!game.settings.music) {
        return;
    }
    while (waiting) {
        SDL.delay(1);
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) { //Check all events
            if (event.type == c.SDL_QUIT) {
                // FIXME: handle this better
                //return TITUS_ERROR_QUIT;
                return;
            } else if (event.type == c.SDL_KEYDOWN) {
                if (event.key.keysym.scancode == c.SDL_SCANCODE_ESCAPE) {
                    // FIXME: handle this better
                    // return TITUS_ERROR_QUIT;
                    return;
                }
            }
        }
        if (!audio_engine.backend.isPlayingATrack()) {
            waiting = false;
        }
    }
}

pub fn music_restart_if_finished() void {
    if (!game.settings.music) {
        return;
    }
    if (!audio_engine.backend.isPlayingATrack()) {
        music_select_song(audio_engine.last_song);
    }
}

pub export fn sfx_play_c(fx_number: u8) void {
    var backend = audio_engine.backend;
    audio_engine.backend.lock();
    backend.playSfx(fx_number);
    audio_engine.backend.unlock();
}

pub fn set_volume(volume: u8) void {
    var volume_clamp = volume;
    if (volume_clamp > 128) {
        volume_clamp = 128;
    }
    game.settings.volume_master = volume_clamp;
    audio_engine.volume = volume_clamp;
    _ = miniaudio.ma_device_set_master_volume(
        &audio_engine.device,
        @as(f32, @floatFromInt(volume_clamp)) / 128.0,
    );
}

pub fn get_volume() u8 {
    return audio_engine.volume;
}
