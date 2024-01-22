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

// TODO: bring in SDL logic from the OPL lib and divorce it from OPL
// TODO: implement a way to use music from the Amiga version of the game
// TODO: research how Amiga version does sound effects, use those too

const std = @import("std");
const Adlib = @import("Adlib.zig");
const c = @import("../c.zig");
const game = @import("../game.zig");
const data = @import("../data.zig");

extern var OPL_SDL_VOLUME: u8;

pub const AudioEngine = struct {
    allocator: std.mem.Allocator = undefined,
    aad: Adlib = .{},
    last_song: u8 = 0,

    pub fn init(self: *AudioEngine, allocator: std.mem.Allocator) !void {
        self.allocator = allocator;
        self.last_song = 0;
        OPL_SDL_VOLUME = game.settings.volume_master;

        try self.aad.init(allocator);
    }

    pub fn deinit(self: *AudioEngine) void {
        self.aad.deinit();
        if (c.SDL_WasInit(c.SDL_INIT_AUDIO) == 0) {
            return;
        }
        c.SDL_CloseAudio();
    }
};

pub var audio_engine: AudioEngine = .{};

pub fn music_get_last_song() u8 {
    return audio_engine.last_song;
}

pub export fn music_play_jingle_c(song_number: u8) void {
    var aad: *Adlib = &(audio_engine.aad);
    c.SDL_LockAudio();
    {
        aad.play_track(song_number);
    }
    c.SDL_UnlockAudio();
}

pub export fn music_select_song_c(song_number: u8) void {
    var aad: *Adlib = &(audio_engine.aad);
    audio_engine.last_song = song_number;
    if (!game.settings.music) {
        return;
    }

    c.SDL_LockAudio();
    {
        aad.play_track(song_number);
    }
    c.SDL_UnlockAudio();
}

pub export fn music_toggle_c() bool {
    game.settings.music = !game.settings.music;
    if (!game.settings.music) {
        c.SDL_LockAudio();
        {
            var aad: *Adlib = &(audio_engine.aad);
            aad.stop_track(audio_engine.last_song);
        }
        c.SDL_UnlockAudio();
    }
    return game.settings.music;
}

// FIXME: this is just weird
pub fn music_wait_to_finish() void {
    var waiting: bool = true;
    if (!game.settings.music) {
        return;
    }
    while (waiting) {
        c.SDL_Delay(1);
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

pub fn music_restart_if_finished() void {
    if (!game.settings.music) {
        return;
    }
    if (audio_engine.aad.active_channels == 0) {
        music_select_song_c(audio_engine.last_song);
    }
}

pub export fn sfx_play_c(fx_number: u8) void {
    var aad: *Adlib = &(audio_engine.aad);
    c.SDL_LockAudio();
    aad.sfx_play(fx_number);
    c.SDL_UnlockAudio();
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
