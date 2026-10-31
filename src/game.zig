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

const std = @import("std");

const SDL = @import("SDL.zig");
const sqz = @import("sqz.zig");
const sqz_amiga = @import("sqz_amiga.zig");

// NOTE: force-imported modules
pub fn refAllDecls(comptime T: type) void {
    inline for (comptime std.meta.declarations(T)) |decl| {
        _ = &@field(T, decl.name);
    }
}
const credits = @import("ui/credits.zig");
comptime {
    refAllDecls(credits);
}

const pauseMenu = @import("ui/pause_menu.zig");
comptime {
    refAllDecls(pauseMenu);
}

const gameMenu = @import("ui/game_menu.zig");
comptime {
    refAllDecls(gameMenu);
}

const fonts = @import("ui/fonts.zig");
const image = @import("ui/image.zig");
const ImageFile = image.ImageFile;
const intro_text = @import("ui/intro_text.zig");
const input = @import("input.zig");
const main_menu = @import("ui/main_menu.zig");

const audio = @import("audio/audio.zig");
const replay = @import("replay.zig");
const data = @import("data.zig");
const globals = @import("globals.zig");
const engine = @import("engine.zig");
const window = @import("window.zig");

const json = @import("json.zig");
const ManagedJSON = json.ManagedJSON;

const TitusError = error{
    CannotReadConfig,
    CannotInitSDL,
    CannotInitInput,
    CannotInitAudio,
    CannotInitFonts,
};

const s = @import("settings.zig");
const Settings = s.Settings;
pub var settings_mem: ManagedJSON(Settings) = undefined;
pub var settings: *Settings = undefined;

const gs = @import("game_state.zig");
const GameState = gs.GameState;
pub var game_state_mem: ManagedJSON(GameState) = undefined;
pub var game_state: *GameState = undefined;

pub var allocator: std.mem.Allocator = undefined;
pub var io: std.Io = undefined;

const Options = struct {
    /// Run the deterministic replay with this many frames per level instead of the game
    replay_frames: ?usize = null,
    /// Which game to use when both are available
    game: ?data.GameType = null,
};

fn parseOptions(args: []const [:0]const u8) !Options {
    var options: Options = .{};
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--replay")) {
            options.replay_frames = replay.default_frames;
            if (i + 1 < args.len) {
                if (std.fmt.parseInt(usize, args[i + 1], 10)) |frames| {
                    options.replay_frames = frames;
                    i += 1;
                } else |_| {}
            }
        } else if (std.mem.eql(u8, arg, "--game") and i + 1 < args.len) {
            i += 1;
            if (std.ascii.eqlIgnoreCase(args[i], "titus")) {
                options.game = .Titus;
            } else if (std.ascii.eqlIgnoreCase(args[i], "moktar")) {
                options.game = .Moktar;
            } else {
                std.log.err("Unknown game '{s}', use 'titus' or 'moktar'", .{args[i]});
                return error.InvalidArguments;
            }
        } else {
            std.log.err("Unknown argument '{s}'. Usage: opentitus [--game titus|moktar] [--replay [frames per level]]", .{arg});
            return error.InvalidArguments;
        }
    }
    return options;
}

/// Pick the game from the command line, or the only one available
fn pickGame(available: data.GamesAvailable, requested: ?data.GameType) ?data.GameType {
    if (requested) |game| {
        const present = switch (game) {
            .Titus => available.titus,
            .Moktar => available.moktar,
            .None => false,
        };
        return if (present) game else null;
    }
    if (available.titus) return .Titus;
    if (available.moktar) return .Moktar;
    return null;
}

fn runReplay(frames: usize, requested_game: ?data.GameType) !u8 {
    const game = pickGame(data.probeGameFiles(io), requested_game) orelse {
        std.log.err("Game files not found for the replay", .{});
        return error.GameDataNotAvailable;
    };
    data.init(game);

    // Start from a fresh game state, and don't save anything the replay does (like unlocking levels)
    gs.persist = false;
    game_state_mem = try GameState.make_new(io, allocator);
    game_state = &game_state_mem.value;
    defer game_state_mem.deinit();

    var buffer: [1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(io, &buffer);
    try replay.run(io, allocator, &stdout.interface, frames);
    try stdout.interface.flush();
    return 0;
}

pub fn run(init: std.process.Init) !u8 {
    allocator = init.gpa;
    io = init.io;

    const options = try parseOptions(try init.minimal.args.toSlice(init.arena.allocator()));

    settings_mem = try Settings.read(allocator, io);
    settings = &settings_mem.value;
    defer
    {
        settings_mem.deinit();
    }

    // NOTE: we want to allocate memory for gamepad state before we start up SDL
    if(!input.init(allocator)) {
        std.debug.print("Unable to initialize Input...\n", .{});
        return TitusError.CannotInitInput;
    }

    if (!SDL.init(allocator)) {
        std.debug.print("Unable to initialize SDL: {s}\n", .{SDL.getError()});
        return TitusError.CannotInitSDL;
    }
    defer SDL.deinit();
    // NOTE: we want to close the gamepads before SDL exits
    defer input.deinit();

    try window.window_init();
    defer window.window_deinit();

    try fonts.fonts_load();
    defer fonts.fonts_free();

    if (options.replay_frames) |frames| {
        return runReplay(frames, options.game);
    }

    // View the menu when the main loop starts
    var state: c_int = 1;
    var retval: c_int = 0;

    if (!settings.seen_intro) {
        retval = intro_text.viewintrotext(allocator) catch |err| VALUE: {
            std.debug.print("Unable to view intro screen: {}", .{err});
            break :VALUE -1;
        };
        if (retval < 0) {
            state = 0;
        } else {
            settings.seen_intro = true;
            try settings.write(io, allocator);
        }
    }

    const available_games = data.probeGameFiles(io);
    if (options.game != null) {
        data.init(pickGame(available_games, options.game) orelse return error.GameDataNotAvailable);
    }
    else if(available_games.moktar and available_games.titus)
    {
        switch(gameMenu.gameMenu()) {
            .Titus => {
                data.init(.Titus);
            },
            .Moktar => {
                data.init(.Moktar);
            },
            .None => {
                return 0;
            }
        }
    }
    else if(available_games.titus) {
        data.init(.Titus);
    }
    else if(available_games.moktar) {
        data.init(.Moktar);
    }
    else {
        // TODO: add some screen that shows the error to the user
        return error.GameDataNotAvailable;
    }

    game_state_mem = try GameState.read(io, allocator);
    game_state = &game_state_mem.value;
    defer {
        game_state_mem.deinit();
    }

    try audio.engine.init(io, allocator);
    defer audio.engine.deinit();

    if (data.constants.*.logo) |logo| {
        retval = try image.viewImageFile(
            io,
            logo,
            .FadeInFadeOut,
            4000,
            allocator,
        );
        if (retval < 0)
            return 0;
    }

    audio.playTrack(.MainTitle);

    if (data.constants.*.intro) |intro| {
        retval = try image.viewImageFile(
            io,
            intro,
            .FadeInFadeOut,
            6500,
            allocator,
        );
        if (retval < 0)
            return 0;
    }

    while (state != 0) {
        const curlevel = try main_menu.view_menu(
            io,
            data.constants.*.menu.?,
            allocator,
        );

        if (curlevel == null)
            state = 0;

        if (state != 0 and (curlevel.? < data.constants.*.levelfiles.len)) {
            retval = try engine.playtitus(
                io,
                @truncate(curlevel.?),
                allocator,
            );
            if (retval < 0)
                state = 0;
        }
    }

    try settings.write(io, allocator);
    try game_state.write(io, allocator);

    return 0;
}

fn amigaTest2() !void {
    const amiga_music: []const u8 = sqz_amiga.unSQZ("amiga/JEU1.PAT", allocator) catch foo: {
        std.debug.print("Too bad, Amiga file didn't uncompreess well...", .{});
        break :foo "";
    };
    if (amiga_music.len > 0) {
        try std.fs.cwd().writeFile("amiga/JEU1.PAT.UNSQZ", amiga_music);
    }

    allocator.free(amiga_music);
}

fn amigaTest1() !void {
    const amiga_huffman: []const u8 = sqz_amiga.unSQZ("amiga/fox.spr", allocator) catch foo: {
        std.debug.print("Too bad, Amiga file didn't uncompreess well...", .{});
        break :foo "";
    };
    if (amiga_huffman.len > 0) {
        try std.fs.cwd().writeFile("amiga/fox.spr.UNSQZ", amiga_huffman);
    }

    allocator.free(amiga_huffman);
}

fn amigaTest() !void {
    // try amigaTest1();
    // try amigaTest2();
}
