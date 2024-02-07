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
const c = @import("../c.zig");
const SDL = @import("../SDL.zig");
const game = @import("../game.zig");
const data = @import("../data.zig");

const usecs_in_sec: u64 = 1000 * 1000;
const MAX_SOUND_SLICE_TIME = 100; // ms

const SampleType = i16;
const NumChannels = 2;
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
    adlib: Adlib = .{},
    backend: Backend = undefined,
    last_song: u8 = 0,
    volume: u8 = c.SDL_MIX_MAXVOLUME,

    // When the callback mutex is locked using OPL_Lock, callback functions are not invoked.
    callback_mutex: Mutex = Mutex{},

    // Queue of callbacks to call at future timestamps (tracked in usecs)
    callback_queue: CallbackQueue = undefined,
    callback_queue_mutex: Mutex = Mutex{},

    // Current time, in us since startup:
    current_time: u64 = 0,

    // Temporary mixing buffer used by the mixing callback.
    mix_buffer: []SampleType = &.{},

    // SDL parameters.
    mixing_freq: c_int = undefined,
    mixing_channels: c_int = undefined,
    mixing_format: u16 = undefined,

    initialized: bool = false,

    pub fn init(self: *AudioEngine, allocator: std.mem.Allocator) !void {
        self.allocator = allocator;
        self.last_song = 0;
        self.volume = game.settings.volume_master;
        self.backend = self.adlib.backend();

        // Check if SDL_mixer has been opened already
        // If not, we must initialize it now
        if (c.Mix_OpenAudioDevice(
            @intCast(44100),
            c.AUDIO_S16SYS,
            NumChannels,
            1024,
            null,
            c.SDL_AUDIO_ALLOW_FREQUENCY_CHANGE,
        ) < 0) {
            std.log.err("Error initialising SDL_mixer: {s}", .{c.Mix_GetError()});
            return error.OpenAudioDeviceFailed;
        }
        errdefer c.Mix_CloseAudio();

        c.SDL_PauseAudio(0);

        // Queue structure of callbacks to invoke.
        self.callback_queue = CallbackQueue.init(allocator, {});
        self.current_time = 0;

        // Get the mixer frequency, format and number of channels.
        _ = c.Mix_QuerySpec(&self.mixing_freq, &self.mixing_format, &self.mixing_channels);

        // Only supports AUDIO_S16SYS
        if (self.mixing_format != @as(u16, @intCast(c.AUDIO_S16SYS)) or self.mixing_channels != 2) {
            std.log.err("OpenTitus only supports native signed 16-bit SYS, stereo format!", .{});
            return error.UnexpectedMixerFormat;
        }

        // Mix buffer: four bytes per sample (16 bits * 2 channels):
        self.mix_buffer = try allocator.alloc(SampleType, @intCast(self.mixing_freq * NumChannels));
        errdefer allocator.free(self.mix_buffer);

        self.callback_mutex = Mutex{};
        self.callback_queue_mutex = Mutex{};

        // Set postmix that adds the OPL music. This is deliberately done
        // as a postmix and not using Mix_HookMusic() as the latter disables
        // normal SDL_mixer music mixing.
        c.Mix_SetPostMix(SDL_Mix_Callback, self);
        errdefer c.Mix_SetPostMix(null, null);

        try self.backend.init(self, allocator, 44100);
        self.initialized = true;
    }

    pub fn deinit(self: *AudioEngine) void {
        if (!self.initialized) {
            return;
        }
        self.backend.deinit();

        // FIXME: this looks like cargo cult madness. Make sure it's actually right?
        c.SDL_LockAudio();
        c.Mix_SetPostMix(null, null);
        c.SDL_UnlockAudio();

        c.Mix_CloseAudio();
        c.SDL_QuitSubSystem(c.SDL_INIT_AUDIO);

        self.callback_queue.deinit();
        self.allocator.free(self.mix_buffer);
        if (c.SDL_WasInit(c.SDL_INIT_AUDIO) == 0) {
            return;
        }
        c.SDL_CloseAudio();
    }

    // Advance time by the specified number of samples, invoking any
    // callback functions as appropriate.
    fn advanceTime(self: *AudioEngine, nsamples: u64) void {
        self.callback_queue_mutex.lock();

        // Advance time.
        var us: u64 = (nsamples * usecs_in_sec) / @as(u64, @intCast(self.mixing_freq));
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
        // This seems like a reasonable assumption.  mix_buffer is
        // 1 second long, which should always be much longer than the
        // SDL mix buffer.
        if (nsamples >= self.mixing_freq) {
            unreachable;
        }

        // OPL output is generated into temporary buffer and then mixed
        // (to avoid overflows etc.)
        self.backend.fillBuffer(self.mix_buffer, nsamples);
        c.SDL_MixAudioFormat(
            buffer,
            @ptrCast(&self.mix_buffer[0]),
            c.AUDIO_S16SYS,
            nsamples * @sizeOf(SampleType) * NumChannels,
            self.volume,
        );
    }

    // Callback function to fill a new sound buffer:
    fn SDL_Mix_Callback(udata: ?*anyopaque, buffer: [*c]u8, len: c_int) callconv(.C) void {
        var self: *AudioEngine = @alignCast(@ptrCast(udata));
        var filled: u64 = 0;
        var buffer_samples: c_uint = @as(c_uint, @intCast(len)) / Stride;

        // Repeatedly call the OPL emulator update function until the buffer is full.
        while (filled < buffer_samples) {
            var nsamples: u64 = 0;

            self.callback_queue_mutex.lock();

            // Work out the time until the next callback waiting in
            // the callback queue must be invoked.  We can then fill the
            // buffer with this many samples.

            if (self.callback_queue.count() == 0) {
                nsamples = buffer_samples - filled;
            } else {
                const next_callback_time = self.callback_queue.peek().?.time;

                nsamples = (next_callback_time - self.current_time) * @as(u32, @intCast(self.mixing_freq));
                nsamples = (nsamples + usecs_in_sec - 1) / usecs_in_sec;

                if (nsamples > buffer_samples - filled) {
                    nsamples = buffer_samples - filled;
                }
            }

            self.callback_queue_mutex.unlock();

            // Add emulator output to buffer.
            self.fillBuffer(buffer + filled * Stride, @truncate(nsamples));
            filled += nsamples;

            // Invoke callbacks for this point in time.
            self.advanceTime(nsamples);
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
    c.SDL_LockAudio();
    {
        audio_engine.backend.playTrack(song_number);
    }
    c.SDL_UnlockAudio();
}

pub fn music_select_song(song_number: u8) void {
    audio_engine.last_song = song_number;
    if (!game.settings.music) {
        return;
    }

    c.SDL_LockAudio();
    {
        audio_engine.backend.playTrack(song_number);
    }
    c.SDL_UnlockAudio();
}

pub export fn music_toggle_c() bool {
    game.settings.music = !game.settings.music;
    if (!game.settings.music) {
        c.SDL_LockAudio();
        {
            audio_engine.backend.stopTrack(audio_engine.last_song);
        }
        c.SDL_UnlockAudio();
    }
    return game.settings.music;
}

pub fn music_set_playing(playing: bool) void {
    game.settings.music = playing;
    if (!game.settings.music) {
        c.SDL_LockAudio();
        {
            audio_engine.backend.stopTrack(audio_engine.last_song);
        }
        c.SDL_UnlockAudio();
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
    c.SDL_LockAudio();
    backend.playSfx(fx_number);
    c.SDL_UnlockAudio();
}

pub fn set_volume(volume: u8) void {
    var volume_clamp = volume;
    if (volume_clamp > 128) {
        volume_clamp = 128;
    }
    game.settings.volume_master = volume_clamp;
    audio_engine.volume = volume_clamp;
}

pub fn get_volume() u8 {
    return audio_engine.volume;
}
