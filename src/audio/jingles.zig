//
// Copyright (C) 2026 The OpenTitus team
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

//! The DOS games play the jingles for collecting things as songs, which replaces the music. The game then restarts
//! the music from the beginning. The DOS backends instead play the jingles on a second player. The music pauses for
//! them and then continues on the nearest bar line (see `Backend.nearestBar`).

const std = @import("std");

/// How long the music takes to fade down and back up, so it doesn't click
const MusicFadeSeconds = 0.02;
/// The driver doesn't silence the notes at the end of a song, the jingle player fades them out
const JingleFadeSeconds = 0.1;

/// Mixes the music and jingle players of a backend.
/// The backends only need to render a player when its output is used, see `musicAudible` and `jingleAudible`.
pub const Mixer = struct {
    music_gain: f32 = 1,
    jingle_gain: f32 = 0,
    music_step: f32 = 1,
    jingle_step: f32 = 1,

    pub fn init(sample_rate: u32) Mixer {
        const rate: f32 = @floatFromInt(sample_rate);
        return .{
            .music_step = 1.0 / (MusicFadeSeconds * rate),
            .jingle_step = 1.0 / (JingleFadeSeconds * rate),
        };
    }

    /// A jingle started, it plays at full volume right away (its player starts from silence)
    pub fn startJingle(self: *Mixer) void {
        self.jingle_gain = 1;
    }

    /// Silence the jingle immediately (a new song replaces everything)
    pub fn stopJingle(self: *Mixer) void {
        self.jingle_gain = 0;
    }

    /// Whether the jingle (or the fading end of it) can be heard
    pub fn jingleAudible(self: *const Mixer, jingle_playing: bool) bool {
        return jingle_playing or self.jingle_gain > 0;
    }

    /// Whether the music driver should stop advancing
    pub fn musicPaused(self: *const Mixer, jingle_playing: bool) bool {
        return self.jingleAudible(jingle_playing);
    }

    /// Whether the music can be heard, now or once it fades in
    pub fn musicAudible(self: *const Mixer, jingle_playing: bool) bool {
        return self.music_gain > 0 or !self.musicPaused(jingle_playing);
    }

    /// Mix one sample of each player, and move the volumes towards where they should be
    pub fn mix(self: *Mixer, jingle_playing: bool, music: f32, jingle: f32) f32 {
        const result = music * self.music_gain + jingle * self.jingle_gain;
        self.advance(jingle_playing);
        return result;
    }

    /// Move the volumes one sample towards where they should be. For mixing several channels of a sample frame with
    /// `music_gain` and `jingle_gain` directly.
    pub fn advance(self: *Mixer, jingle_playing: bool) void {
        if (!jingle_playing) {
            self.jingle_gain = @max(0, self.jingle_gain - self.jingle_step);
        }
        if (self.musicPaused(jingle_playing)) {
            self.music_gain = @max(0, self.music_gain - self.music_step);
        } else {
            self.music_gain = @min(1, self.music_gain + self.music_step);
        }
    }
};

test "the music fades out for the jingle and back in after it" {
    var mixer = Mixer.init(1000);
    mixer.startJingle();
    try std.testing.expect(mixer.musicPaused(true));
    for (0..20) |_| _ = mixer.mix(true, 1, 0);
    try std.testing.expect(!mixer.musicAudible(true));
    // the jingle ends and fades out before the music comes back
    for (0..101) |_| _ = mixer.mix(false, 1, 1);
    try std.testing.expect(!mixer.jingleAudible(false));
    try std.testing.expect(!mixer.musicPaused(false));
    for (0..20) |_| _ = mixer.mix(false, 1, 0);
    try std.testing.expectEqual(@as(f32, 1), mixer.mix(false, 1, 0));
}
