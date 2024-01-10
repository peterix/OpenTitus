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
const c = @import("c.zig");

pub export var game: c.GameType = undefined;

const image = @import("ui/image.zig");
const ImageFile = image.ImageFile;

pub const LevelDescriptor = struct {
    filename: []const u8,
    title: []const u8,
    color: c.SDL_Color,
};

// TODO: merge this with the 'original.{c,h}' stuff. It's basically the same kind of thing
pub const Constants = struct {
    levelfiles: []const LevelDescriptor,
    logo: ImageFile,
    intro: ImageFile,
    menu: ImageFile,
    finish: ?ImageFile,
    sprites: []const u8,
};

// FIXME: add a way to specify custom games? mods? levels?
const titus_consts: Constants = .{
    .levelfiles = &[15]LevelDescriptor{
        .{
            .filename = "LEVEL0.SQZ",
            .title = "On The Foxy Trail",
            .color = .{ .r = 0 * 4, .g = 16 * 4, .b = 0 * 4, .a = 255 },
        },
        .{
            .filename = "LEVELJ.SQZ",
            .title = "Looking For Clues",
            .color = .{ .r = 0 * 4, .g = 16 * 4, .b = 0 * 4, .a = 255 },
        },
        .{
            .filename = "LEVEL1.SQZ",
            .title = "Road Works Ahead",
            .color = .{ .r = 0 * 4, .g = 16 * 4, .b = 0 * 4, .a = 255 },
        },
        .{
            .filename = "LEVEL2.SQZ",
            .title = "Going Underground",
            .color = .{ .r = 20 * 4, .g = 12 * 4, .b = 12 * 4, .a = 255 },
        },
        .{
            .filename = "LEVEL3.SQZ",
            .title = "Flaming Catacombs",
            .color = .{ .r = 40 * 4, .g = 12 * 4, .b = 4 * 4, .a = 255 },
        },
        .{
            .filename = "LEVEL4.SQZ",
            .title = "Coming To Town",
            .color = .{ .r = 20 * 4, .g = 12 * 4, .b = 12 * 4, .a = 255 },
        },
        .{
            .filename = "LEVEL5.SQZ",
            .title = "Foxy's Den",
            .color = .{ .r = 20 * 4, .g = 12 * 4, .b = 12 * 4, .a = 255 },
        },
        .{
            .filename = "LEVEL6.SQZ",
            .title = "On The Road To Marrakesh",
            .color = .{ .r = 0 * 4, .g = 16 * 4, .b = 0 * 4, .a = 255 },
        },
        .{
            .filename = "LEVEL7.SQZ",
            .title = "Home Of The Pharaohs",
            .color = .{ .r = 40 * 4, .g = 28 * 4, .b = 12 * 4, .a = 255 },
        },
        .{
            .filename = "LEVEL8.SQZ",
            .title = "Desert Experience",
            .color = .{ .r = 0 * 4, .g = 20 * 4, .b = 16 * 4, .a = 255 },
        },
        .{
            .filename = "LEVEL9.SQZ",
            .title = "Walls Of Sand",
            .color = .{ .r = 40 * 4, .g = 28 * 4, .b = 12 * 4, .a = 255 },
        },
        .{
            .filename = "LEVELB.SQZ",
            .title = "A Beacon Of Hope",
            .color = .{ .r = 40 * 4, .g = 28 * 4, .b = 12 * 4, .a = 255 },
        },
        .{
            .filename = "LEVELC.SQZ",
            .title = "A Pipe Dream",
            .color = .{ .r = 40 * 4, .g = 28 * 4, .b = 12 * 4, .a = 255 },
        },
        .{
            .filename = "LEVELE.SQZ",
            .title = "Going Home",
            .color = .{ .r = 40 * 4, .g = 28 * 4, .b = 12 * 4, .a = 255 },
        },
        .{
            .filename = "LEVELG.SQZ",
            .title = "Just Married",
            .color = .{ .r = 48 * 4, .g = 8 * 4, .b = 0 * 4, .a = 255 },
        },
    },
    .logo = .{ .filename = "TITUS.SQZ", .format = .LinearPalette256 },
    .intro = .{ .filename = "TITRE.SQZ", .format = .LinearPalette256 },
    .menu = .{ .filename = "MENU.SQZ", .format = .LinearPalette256 },
    .finish = .{ .filename = "LEVELA.SQZ", .format = .PlanarGreyscale16 },
    .sprites = "SPREXP.SQZ",
};

const moktar_consts: Constants = .{
    .levelfiles = &[16]LevelDescriptor{
        // FIXME: get someone who knows French to do localization.
        // FIXME: separate 'game' from 'localization'. We can totally have Titus the Fox in French and Moktar in English.
        // FIXME: add actual support for accents and stuff...
        .{
            .filename = "LEVEL0.SQZ",
            .title = "A LA RECHERCHE DE LA ZOUBIDA",
            .color = .{ .r = 0 * 4, .g = 16 * 4, .b = 0 * 4, .a = 255 },
        },
        .{
            .filename = "LEVELJ.SQZ",
            .title = "LES QUARTIERS CHICS",
            .color = .{ .r = 0 * 4, .g = 16 * 4, .b = 0 * 4, .a = 255 },
        },
        .{
            .filename = "LEVEL1.SQZ",
            .title = "ATTENTION TRAVAUX",
            .color = .{ .r = 0 * 4, .g = 16 * 4, .b = 0 * 4, .a = 255 },
        },
        .{
            .filename = "LEVEL2.SQZ",
            .title = "LES COULOIRS DU METRO", // MÉTRO?
            .color = .{ .r = 20 * 4, .g = 12 * 4, .b = 12 * 4, .a = 255 },
        },
        .{
            .filename = "LEVEL3.SQZ",
            .title = "LES CATACOMBES INFERNALES",
            .color = .{ .r = 40 * 4, .g = 12 * 4, .b = 4 * 4, .a = 255 },
        },
        .{
            .filename = "LEVEL4.SQZ",
            .title = "ARRIVEE DANS LA CITE", // ARRIVÉE?
            .color = .{ .r = 20 * 4, .g = 12 * 4, .b = 12 * 4, .a = 255 },
        },
        .{
            .filename = "LEVEL5.SQZ",
            .title = "L IMMEUBLE DE LA ZOUBIDA",
            .color = .{ .r = 20 * 4, .g = 12 * 4, .b = 12 * 4, .a = 255 },
        },
        .{
            .filename = "LEVEL6.SQZ",
            .title = "SOUS LE CHEMIN DE MARRAKECH",
            .color = .{ .r = 0 * 4, .g = 16 * 4, .b = 0 * 4, .a = 255 },
        },
        .{
            .filename = "LEVEL7.SQZ",
            .title = "LA CITE ENFOUIE",
            .color = .{ .r = 40 * 4, .g = 28 * 4, .b = 12 * 4, .a = 255 },
        },
        .{
            .filename = "LEVEL8.SQZ",
            .title = "DESERT PRIVE", // DÉSERT PRIVÉ?
            .color = .{ .r = 0 * 4, .g = 20 * 4, .b = 16 * 4, .a = 255 },
        },
        .{
            .filename = "LEVEL9.SQZ",
            .title = "LA VILLE DES SABLES",
            .color = .{ .r = 40 * 4, .g = 28 * 4, .b = 12 * 4, .a = 255 },
        },
        .{
            .filename = "LEVELB.SQZ",
            .title = "LE PHARE OUEST", // LE PHARE DE L'OUEST?
            .color = .{ .r = 40 * 4, .g = 28 * 4, .b = 12 * 4, .a = 255 },
        },
        .{
            .filename = "LEVELC.SQZ",
            .title = "UN BON TUYAU",
            .color = .{ .r = 40 * 4, .g = 28 * 4, .b = 12 * 4, .a = 255 },
        },
        .{
            .filename = "LEVELE.SQZ",
            .title = "DE RETOUR AU PAYS",
            .color = .{ .r = 40 * 4, .g = 28 * 4, .b = 12 * 4, .a = 255 },
        },
        .{
            .filename = "LEVELF.SQZ",
            .title = "DIRECTION BARBES",
            .color = .{ .r = 40 * 4, .g = 28 * 4, .b = 12 * 4, .a = 255 },
        },
        .{
            .filename = "LEVELG.SQZ",
            .title = "BIG BISOUS",
            .color = .{ .r = 48 * 4, .g = 8 * 4, .b = 0 * 4, .a = 255 },
        },
    },
    .logo = .{ .filename = "TITUS.SQZ", .format = .LinearPalette256 },
    .intro = .{ .filename = "TITRE.SQZ", .format = .LinearPalette256 },
    .menu = .{ .filename = "MENU.SQZ", .format = .LinearPalette256 },
    .finish = null,
    .sprites = "SPRITES.SQZ",
};

pub var constants: *const Constants = undefined;

var titus_colors: [16]c.SDL_Color = .{
    // Transparent color, needs to be different from the others
    .{ .r = 1 * 4, .g = 1 * 4, .b = 1 * 4, .a = 0 },
    .{ .r = 60 * 4, .g = 60 * 4, .b = 60 * 4, .a = 255 },
    .{ .r = 0 * 4, .g = 0 * 4, .b = 0 * 4, .a = 255 },
    .{ .r = 24 * 4, .g = 8 * 4, .b = 0 * 4, .a = 255 },
    .{ .r = 28 * 4, .g = 16 * 4, .b = 0 * 4, .a = 255 },
    .{ .r = 40 * 4, .g = 24 * 4, .b = 16 * 4, .a = 255 },
    .{ .r = 48 * 4, .g = 40 * 4, .b = 24 * 4, .a = 255 },
    .{ .r = 60 * 4, .g = 48 * 4, .b = 32 * 4, .a = 255 },
    .{ .r = 16 * 4, .g = 8 * 4, .b = 0 * 4, .a = 255 },
    .{ .r = 28 * 4, .g = 20 * 4, .b = 20 * 4, .a = 255 },
    .{ .r = 40 * 4, .g = 32 * 4, .b = 32 * 4, .a = 255 },
    .{ .r = 12 * 4, .g = 12 * 4, .b = 28 * 4, .a = 255 },
    .{ .r = 24 * 4, .g = 24 * 4, .b = 40 * 4, .a = 255 },
    .{ .r = 32 * 4, .g = 32 * 4, .b = 48 * 4, .a = 255 },
    // on levels this color is replaced with a level specific color
    // FIXME: @RESEARCH it's not clear how is this original color supposed to be used...
    .{ .r = 0 * 4, .g = 16 * 4, .b = 0 * 4, .a = 255 },
    .{ .r = 8 * 4, .g = 8 * 4, .b = 24 * 4, .a = 255 },
};

var titus_palette = c.SDL_Palette{
    .ncolors = 16,
    .version = 0,
    .refcount = 1,
    .colors = &titus_colors,
};

pub var titus_pixelformat = c.SDL_PixelFormat{
    .format = 0,
    .palette = &titus_palette,
    .padding = .{ 0, 0 },

    .BitsPerPixel = 8,
    .BytesPerPixel = 1,

    .Rloss = 0,
    .Gloss = 0,
    .Bloss = 0,
    .Aloss = 0,

    .Rshift = 0,
    .Gshift = 0,
    .Bshift = 0,
    .Ashift = 0,

    .Rmask = 0,
    .Gmask = 0,
    .Bmask = 0,
    .Amask = 0,

    .refcount = 0,
    .next = null,
};

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

fn initGameType() !*const Constants {
    if (isFileOpenable(titus_consts.sprites)) {
        game = c.Titus;
        return &titus_consts;
    } else if (isFileOpenable(moktar_consts.sprites)) {
        game = c.Moktar;
        return &moktar_consts;
    } else {
        return error.CannotDetermineGameType;
    }
}

pub fn init() !void {
    constants = try initGameType();
}
