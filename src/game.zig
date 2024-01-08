//
// Copyright (C) 2008 - 2011 The OpenTitus team
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
const view_password = @import("ui/view_password.zig");
comptime {
    refAllDecls(view_password);
}

const intro_text = @import("ui/intro_text.zig");
const menu = @import("ui/menu.zig");
const image = @import("ui/image.zig");
const fonts = @import("ui/fonts.zig");
const ImageFile = image.ImageFile;

const c = @import("c.zig");
const globals = @import("globals.zig");
const engine = @import("engine.zig");
const window = @import("window.zig");
const keyboard = @import("keyboard.zig");

const memory = @import("memory.zig");
const ManagedJSON = memory.ManagedJSON;

const TitusError = error{
    CannotDetermineGameType,
    CannotReadConfig,
    CannotInitSDL,
    CannotInitAudio,
    CannotInitFonts,
};

pub export var game: c.GameType = undefined;

const s = @import("settings.zig");
const Settings = s.Settings;
pub var settings_mem: ManagedJSON(Settings) = undefined;
pub export var settings: *Settings = undefined;

const GameState = s.GameState;
pub var game_state_mem: ManagedJSON(GameState) = undefined;
pub var game_state: *GameState = undefined;

pub const LevelDescriptor = struct {
    filename: []const u8,
    title: []const u8,
};

pub const TITUS_constants = struct {
    levelfiles: []const LevelDescriptor,
    logo: ImageFile,
    intro: ImageFile,
    menu: ImageFile,
    finish: ?ImageFile,
    sprites: []const u8,
};

const titus_consts: TITUS_constants = .{
    .levelfiles = &[15]LevelDescriptor{
        .{ .filename = "LEVEL0.SQZ", .title = "On The Foxy Trail" },
        .{ .filename = "LEVELJ.SQZ", .title = "Looking For Clues" },
        .{ .filename = "LEVEL1.SQZ", .title = "Road Works Ahead" },
        .{ .filename = "LEVEL2.SQZ", .title = "Going Underground" },
        .{ .filename = "LEVEL3.SQZ", .title = "Flaming Catacombs" },
        .{ .filename = "LEVEL4.SQZ", .title = "Coming To Town" },
        .{ .filename = "LEVEL5.SQZ", .title = "Foxy's Den" },
        .{ .filename = "LEVEL6.SQZ", .title = "On The Road To Marrakesh" },
        .{ .filename = "LEVEL7.SQZ", .title = "Home Of The Pharaohs" },
        .{ .filename = "LEVEL8.SQZ", .title = "Desert Experience" },
        .{ .filename = "LEVEL9.SQZ", .title = "Walls Of Sand" },
        .{ .filename = "LEVELB.SQZ", .title = "A Beacon Of Hope" },
        .{ .filename = "LEVELC.SQZ", .title = "A Pipe Dream" },
        .{ .filename = "LEVELE.SQZ", .title = "Going Home" },
        .{ .filename = "LEVELG.SQZ", .title = "Just Married" },
    },
    .logo = .{ .filename = "TITUS.SQZ", .format = .LinearPalette256 },
    .intro = .{ .filename = "TITRE.SQZ", .format = .LinearPalette256 },
    .menu = .{ .filename = "MENU.SQZ", .format = .LinearPalette256 },
    .finish = .{ .filename = "LEVELA.SQZ", .format = .PlanarGreyscale16 },
    .sprites = "SPREXP.SQZ",
};

const moktar_consts: TITUS_constants = .{
    .levelfiles = &[16]LevelDescriptor{
        // FIXME: get someone who knows French to do localization.
        // FIXME: separate 'game' from 'localization'. We can totally have Titus the Fox in French and Moktar in English.
        // FIXME: add actual support for accents and stuff...
        .{ .filename = "LEVEL0.SQZ", .title = "A LA RECHERCHE DE LA ZOUBIDA" },
        .{ .filename = "LEVELJ.SQZ", .title = "LES QUARTIERS CHICS" },
        .{ .filename = "LEVEL1.SQZ", .title = "ATTENTION TRAVAUX" },
        .{ .filename = "LEVEL2.SQZ", .title = "LES COULOIRS DU METRO" }, // MÉTRO?
        .{ .filename = "LEVEL3.SQZ", .title = "LES CATACOMBES INFERNALES" },
        .{ .filename = "LEVEL4.SQZ", .title = "ARRIVEE DANS LA CITE" }, // ARRIVÉE?
        .{ .filename = "LEVEL5.SQZ", .title = "L IMMEUBLE DE LA ZOUBIDA" },
        .{ .filename = "LEVEL6.SQZ", .title = "SOUS LE CHEMIN DE MARRAKECH" },
        .{ .filename = "LEVEL7.SQZ", .title = "LA CITE ENFOUIE" },
        .{ .filename = "LEVEL8.SQZ", .title = "DESERT PRIVE" }, // DÉSERT PRIVÉ?
        .{ .filename = "LEVEL9.SQZ", .title = "LA VILLE DES SABLES" },
        .{ .filename = "LEVELB.SQZ", .title = "LE PHARE OUEST" }, // LE PHARE DE L'OUEST?
        .{ .filename = "LEVELC.SQZ", .title = "UN BON TUYAU" },
        .{ .filename = "LEVELE.SQZ", .title = "DE RETOUR AU PAYS" },
        .{ .filename = "LEVELF.SQZ", .title = "DIRECTION BARBES" },
        .{ .filename = "LEVELG.SQZ", .title = "BIG BISOUS" },
    },
    .logo = .{ .filename = "TITUS.SQZ", .format = .LinearPalette256 },
    .intro = .{ .filename = "TITRE.SQZ", .format = .LinearPalette256 },
    .menu = .{ .filename = "MENU.SQZ", .format = .LinearPalette256 },
    .finish = null,
    .sprites = "SPRITES.SQZ",
};

pub var constants: *const TITUS_constants = undefined;

fn isFileOpenable(path: []const u8) bool {
    if (std.fs.cwd().openFile(path, .{})) |file| {
        file.close();
        return true;
    } else |_| {
        // NOTE: we assume that any issue opening the file means it's not present
        // TODO: catch all the other errors that aren't 'FileNotFound' and report them?
        return false;
    }
}

fn initGameType() !*const TITUS_constants {
    if (isFileOpenable(titus_consts.sprites)) {
        game = c.Titus;
        return &titus_consts;
    } else if (isFileOpenable(moktar_consts.sprites)) {
        game = c.Moktar;
        return &moktar_consts;
    } else {
        return TitusError.CannotDetermineGameType;
    }
}

pub fn run() !u8 {
    // FIXME: report the missing files to the user in a better way than erroring into a terminal? dialog box if available?
    constants = try initGameType();

    globals.reset();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) @panic("Memory leaked!");
    }

    settings_mem = try Settings.read(allocator);
    settings = &settings_mem.value;
    defer settings_mem.deinit();

    game_state_mem = try GameState.read(allocator);
    game_state = &game_state_mem.value;
    defer game_state_mem.deinit();

    if (c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_TIMER | c.SDL_INIT_AUDIO) != 0) {
        std.debug.print("Unable to initialize SDL: {s}\n", .{std.mem.span(c.SDL_GetError())});
        return TitusError.CannotInitSDL;
    }
    defer c.SDL_Quit();

    try window.window_init();

    if (c.audio_init() != 0) {
        std.debug.print("Unable to initialize Audio...\n", .{});
        return TitusError.CannotInitAudio;
    }
    defer c.audio_free();

    c.initoriginal();

    if (fonts.fonts_load() != 0) {
        return TitusError.CannotInitFonts;
    }
    defer fonts.fonts_free();

    // View the menu when the main loop starts
    var state: c_int = 1;
    var retval: c_int = 0;

    if (!game_state.seen_intro) {
        if (state != 0) {
            retval = intro_text.viewintrotext();
            if (retval < 0)
                state = 0;
            game_state.seen_intro = true;
        }
    }

    if (state != 0) {
        retval = try image.viewImageFile(
            constants.*.logo,
            .FadeInFadeOut,
            4000,
            allocator,
        );
        if (retval < 0)
            state = 0;
    }

    c.music_select_song(15);

    if (state != 0) {
        retval = try image.viewImageFile(
            constants.*.intro,
            .FadeInFadeOut,
            6500,
            allocator,
        );
        if (retval < 0)
            state = 0;
    }

    while (state != 0) {
        retval = try menu.viewMenu(
            constants.*.menu,
            allocator,
        );

        if (retval <= 0)
            state = 0;

        if (state != 0 and (retval <= constants.*.levelfiles.len)) {
            retval = engine.playtitus(
                @as(u16, @intCast(retval - 1)),
                allocator,
            );
            if (retval < 0)
                state = 0;
        }
    }

    try settings.write(allocator);
    try game_state.write(allocator);

    return 0;
}
