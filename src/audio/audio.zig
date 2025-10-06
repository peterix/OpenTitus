pub const AudioTrack = enum {
    Play1,
    Play2,
    Play3,
    Play4,
    Play5,
    Win,
    LevelEnd,
    Bonus,
    MainTitle,
    GameOver,
    Death,
    Credits,
};

pub const AudioEngine = @import("AudioEngine.zig");
pub const BackendType = AudioEngine.BackendType;

const game = @import("../game.zig");
const SDL = @import("../SDL.zig");
const input = @import("../input.zig");
const window = @import("../window.zig");

const events = @import("../events.zig");
const GameEvent = events.GameEvent;

pub var engine: AudioEngine = .{};

pub fn music_get_last_song() ?AudioTrack {
    return engine.last_song;
}

pub fn music_set_playing(playing: bool) void {
    game.settings.music = playing;

    if (engine.backend == null) {
        return;
    }
    if (!game.settings.music) {
        engine.backend.?.lock();
        engine.backend.?.playTrack(null);
        engine.backend.?.unlock();
    }
}

pub fn music_is_playing() bool {
    return game.settings.music;
}

// FIXME: this is just weird
pub fn music_wait_to_finish() void {
    if (!game.settings.music) {
        return;
    }
    if (engine.backend == null) {
        return;
    }

    while (true) {
        SDL.delay(1);
        const input_state = input.processEvents();
        switch (input_state.action) {
            .Quit => {
                // FIXME: handle this better
                return;
            },
            .Escape, .Cancel => {
                return;
            },
            else => {},
        }
        if (input_state.should_redraw) {
            window.window_render();
        }
        if (!engine.backend.?.isPlayingATrack()) {
            return;
        }
    }
}

pub fn music_restart_if_finished() void {
    if (!game.settings.music) {
        return;
    }
    if (engine.backend == null) {
        return;
    }

    if (!engine.backend.?.isPlayingATrack()) {
        playTrack(engine.last_song);
    }
}

pub fn playTrack(track: ?AudioTrack) void {
    engine.last_song = track;

    if (!game.settings.music) {
        return;
    }
    if (engine.backend == null) {
        return;
    }
    engine.backend.?.lock();
    {
        engine.backend.?.playTrack(track);
    }
    engine.backend.?.unlock();
}

pub fn triggerEvent(event: GameEvent) void {
    if (engine.backend == null) {
        return;
    }
    var backend = &engine.backend.?;
    backend.lock();
    backend.triggerEvent(event);
    backend.unlock();
}

pub fn set_volume(volume: u8) void {
    var volume_clamp = volume;
    if (volume_clamp > 128) {
        volume_clamp = 128;
    }
    game.settings.volume_master = volume_clamp;
    engine.volume = volume_clamp;
    _ = AudioEngine.miniaudio.ma_device_set_master_volume(
        &engine.device,
        @as(f32, @floatFromInt(volume_clamp)) / 128.0,
    );
}

pub fn get_volume() u8 {
    return engine.volume;
}

pub fn getBackendType() BackendType {
    return engine.getBackendType();
}

pub fn setBackendType(backend_type: BackendType) void {
    engine.setBackendType(backend_type);
}
