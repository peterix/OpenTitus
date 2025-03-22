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
const audio = @import("audio/audio.zig");
const AudioTrack = audio.AudioTrack;
const lvl = @import("level.zig");

pub const GameType = enum  {
    Titus,
    Moktar
};

pub var game: GameType = undefined;

const image = @import("ui/image.zig");
const ImageFile = image.ImageFile;

pub const LevelDescriptor = struct {
    filename: []const u8,
    title: []const u8,
    color: SDL.Color,
    has_cage: bool = false,
    is_finish: bool = false,
    boss_power: u8 = 10,
    music: AudioTrack,
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
            .music = .Play4,
        },
        .{
            .filename = "LEVELJ.SQZ",
            .title = "Looking For Clues",
            .color = .{ .r = 0 * 4, .g = 16 * 4, .b = 0 * 4, .a = 255 },
            .music = .Play3,
        },
        .{
            .filename = "LEVEL1.SQZ",
            .title = "Road Works Ahead",
            .color = .{ .r = 0 * 4, .g = 16 * 4, .b = 0 * 4, .a = 255 },
            .music = .Play4,
        },
        .{
            .filename = "LEVEL2.SQZ",
            .title = "Going Underground",
            .color = .{ .r = 20 * 4, .g = 12 * 4, .b = 12 * 4, .a = 255 },
            .music = .Play5,
        },
        .{
            .filename = "LEVEL3.SQZ",
            .title = "Flaming Catacombs",
            .color = .{ .r = 40 * 4, .g = 12 * 4, .b = 4 * 4, .a = 255 },
            .boss_power = 4,
            .music = .Play5,
        },
        .{
            .filename = "LEVEL4.SQZ",
            .title = "Coming To Town",
            .color = .{ .r = 20 * 4, .g = 12 * 4, .b = 12 * 4, .a = 255 },
            .music = .Play4,
        },
        .{
            .filename = "LEVEL5.SQZ",
            .title = "Foxy's Den",
            .color = .{ .r = 20 * 4, .g = 12 * 4, .b = 12 * 4, .a = 255 },
            .music = .Play3,
        },
        .{
            .filename = "LEVEL6.SQZ",
            .title = "On The Road To Marrakesh",
            .color = .{ .r = 0 * 4, .g = 16 * 4, .b = 0 * 4, .a = 255 },
            .music = .Play5,
        },
        .{
            .filename = "LEVEL7.SQZ",
            .title = "Home Of The Pharaohs",
            .color = .{ .r = 40 * 4, .g = 28 * 4, .b = 12 * 4, .a = 255 },
            .music = .Play2,
        },
        .{
            .filename = "LEVEL8.SQZ",
            .title = "Desert Experience",
            .color = .{ .r = 0 * 4, .g = 20 * 4, .b = 16 * 4, .a = 255 },
            .music = .Play1,
        },
        .{
            .filename = "LEVEL9.SQZ",
            .title = "Walls Of Sand",
            .color = .{ .r = 40 * 4, .g = 28 * 4, .b = 12 * 4, .a = 255 },
            .has_cage = true,
            .music = .Play2,
        },
        .{
            .filename = "LEVELB.SQZ",
            .title = "A Beacon Of Hope",
            .color = .{ .r = 40 * 4, .g = 28 * 4, .b = 12 * 4, .a = 255 },
            .music = .Play3,
        },
        .{
            .filename = "LEVELC.SQZ",
            .title = "A Pipe Dream",
            .color = .{ .r = 40 * 4, .g = 28 * 4, .b = 12 * 4, .a = 255 },
            .music = .Play5,
        },
        .{
            .filename = "LEVELE.SQZ",
            .title = "Going Home",
            .color = .{ .r = 40 * 4, .g = 28 * 4, .b = 12 * 4, .a = 255 },
            .music = .Play3,
        },
        .{
            .filename = "LEVELG.SQZ",
            .title = "Just Married",
            .color = .{ .r = 48 * 4, .g = 8 * 4, .b = 0 * 4, .a = 255 },
            .is_finish = true,
            .music = .Win,
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
            .music = .Play4,
        },
        .{
            .filename = "LEVELJ.SQZ",
            .title = "LES QUARTIERS CHICS",
            .color = .{ .r = 0 * 4, .g = 16 * 4, .b = 0 * 4, .a = 255 },
            .music = .Play3,
        },
        .{
            .filename = "LEVEL1.SQZ",
            .title = "ATTENTION TRAVAUX",
            .color = .{ .r = 0 * 4, .g = 16 * 4, .b = 0 * 4, .a = 255 },
            .music = .Play4,
        },
        .{
            .filename = "LEVEL2.SQZ",
            .title = "LES COULOIRS DU METRO", // MÉTRO?
            .color = .{ .r = 20 * 4, .g = 12 * 4, .b = 12 * 4, .a = 255 },
            .music = .Play5,
        },
        .{
            .filename = "LEVEL3.SQZ",
            .title = "LES CATACOMBES INFERNALES",
            .color = .{ .r = 40 * 4, .g = 12 * 4, .b = 4 * 4, .a = 255 },
            .boss_power = 4,
            .music = .Play5,
        },
        .{
            .filename = "LEVEL4.SQZ",
            .title = "ARRIVEE DANS LA CITE", // ARRIVÉE?
            .color = .{ .r = 20 * 4, .g = 12 * 4, .b = 12 * 4, .a = 255 },
            .music = .Play4,
        },
        .{
            .filename = "LEVEL5.SQZ",
            .title = "L IMMEUBLE DE LA ZOUBIDA",
            .color = .{ .r = 20 * 4, .g = 12 * 4, .b = 12 * 4, .a = 255 },
            .music = .Play3,
        },
        .{
            .filename = "LEVEL6.SQZ",
            .title = "SOUS LE CHEMIN DE MARRAKECH",
            .color = .{ .r = 0 * 4, .g = 16 * 4, .b = 0 * 4, .a = 255 },
            .music = .Play5,
        },
        .{
            .filename = "LEVEL7.SQZ",
            .title = "LA CITE ENFOUIE",
            .color = .{ .r = 40 * 4, .g = 28 * 4, .b = 12 * 4, .a = 255 },
            .music = .Play2,
        },
        .{
            .filename = "LEVEL8.SQZ",
            .title = "DESERT PRIVE", // DÉSERT PRIVÉ?
            .color = .{ .r = 0 * 4, .g = 20 * 4, .b = 16 * 4, .a = 255 },
            .music = .Play1,
        },
        .{
            .filename = "LEVEL9.SQZ",
            .title = "LA VILLE DES SABLES",
            .color = .{ .r = 40 * 4, .g = 28 * 4, .b = 12 * 4, .a = 255 },
            .has_cage = true,
            .music = .Play2,
        },
        .{
            .filename = "LEVELB.SQZ",
            .title = "LE PHARE OUEST", // LE PHARE DE L'OUEST?
            .color = .{ .r = 40 * 4, .g = 28 * 4, .b = 12 * 4, .a = 255 },
            .music = .Play3,
        },
        .{
            .filename = "LEVELC.SQZ",
            .title = "UN BON TUYAU",
            .color = .{ .r = 40 * 4, .g = 28 * 4, .b = 12 * 4, .a = 255 },
            .music = .Play5,
        },
        .{
            .filename = "LEVELE.SQZ",
            .title = "DE RETOUR AU PAYS",
            .color = .{ .r = 40 * 4, .g = 28 * 4, .b = 12 * 4, .a = 255 },
            .music = .Play3,
        },
        .{
            .filename = "LEVELF.SQZ",
            .title = "DIRECTION BARBES",
            .color = .{ .r = 40 * 4, .g = 28 * 4, .b = 12 * 4, .a = 255 },
            .music = .Play4,
        },
        .{
            .filename = "LEVELG.SQZ",
            .title = "BIG BISOUS",
            .color = .{ .r = 48 * 4, .g = 8 * 4, .b = 0 * 4, .a = 255 },
            .is_finish = true,
            .music = .Win,
        },
    },
    .logo = .{ .filename = "TITUS.SQZ", .format = .LinearPalette256 },
    .intro = .{ .filename = "TITRE.SQZ", .format = .LinearPalette256 },
    .menu = .{ .filename = "MENU.SQZ", .format = .LinearPalette256 },
    .finish = null,
    .sprites = "SPRITES.SQZ",
};

pub var constants: *const Constants = undefined;

var titus_colors: [16]SDL.Color = .{
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

pub var titus_palette = SDL.Palette{
    .ncolors = 16,
    .version = 0,
    .refcount = 1,
    .colors = &titus_colors,
};

//Object flags:
// 1: not support/support
// 2: not bounce/bounce against floor + player bounces (ball, all spring, yellow stone, squeezed ball, skateboard)
// 4: no gravity on throw/gravity (ball, all carpet, trolley, squeezed ball, garbage, grey stone, scooter, yellow bricks between the statues, skateboard, cage)
// 8: on drop, lands on ground/continue below ground(cave spikes, rolling rock, ambolt, safe, dead man with helicopter)
// 16: weapon/not weapon(cage)
const NUM_ORIGINAL_OBJECTS = 71;
const tmpobjectflag: [NUM_ORIGINAL_OBJECTS]u8 = .{
    0, 0, 1, 1, 1, 0, 0, 0, 1, 7, 0,  0,  0, 0, 0, 0,
    0, 0, 0, 4, 5, 5, 5, 1, 3, 3, 20, 20, 1, 0, 3, 0,
    0, 1, 5, 0, 0, 0, 0, 0, 7, 0, 5,  5,  0, 0, 0, 0,
    0, 8, 8, 9, 9, 5, 0, 0, 4, 4, 4,  0,  0, 0, 0, 9,
    7, 0, 0, 8, 0, 0, 0,
};

const object_maxspeedY_data: [NUM_ORIGINAL_OBJECTS]u8 = .{
    15, 15, 14, 14, 15, 15, 10, 12, 13, 25, 12, 12, 10, 10, 10, 15,
    15, 15, 15, 15, 3,  1,  1,  15, 15, 15, 15, 15, 15, 15, 15, 15,
    15, 15, 20, 15, 10, 10, 15, 10, 15, 15, 20, 15, 15, 15, 15, 15,
    15, 24, 24, 24, 24, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 24,
    15, 15, 15, 15, 15, 15, 15,
};


const ObjectData = lvl.ObjectData;
pub const object_data: [NUM_ORIGINAL_OBJECTS]ObjectData = init_object_data: {
    var data: [NUM_ORIGINAL_OBJECTS]ObjectData = undefined;
    for (tmpobjectflag, object_maxspeedY_data, &data) |flag, maxspeedY, *object| {
        object.maxspeedY = maxspeedY;
        object.support = flag & 0x01 != 0;
        object.bounce = flag & 0x02 != 0;
        object.gravity = flag & 0x04 != 0;
        object.droptobottom = flag & 0x08 != 0;
        object.no_damage = flag & 0x10 != 0;
    }
    break :init_object_data data;
};

// 21930 = turn invisible (set the invisible flag)
// negative number = walk that many animation frames back
// positive number = a mishmash of some flags and 0x1FFF masked sprite number to change the sprite to
// 8192 = 'trigger', which means 'shoot bullet using the next 2 animation frames for y position of the bullet and its sprite'
// there seem to be stretches of 3 adjacent values with this bit set
// but there are also single values ... maybe 'trigger' isn't always 'shoot'
pub const anim_enemy: []const i16 = &.{
    53,    54,    55,    21930, -1,
    53,    54,    55,    -3,    141,
    -1,    142,   142,   142,   143,
    143,   143,   144,   144,   144,
    145,   145,   145,   -14,   0,
    0,     0,     1,     1,     1,
    2,     2,     2,     3,     3,
    3,     -12,   34,    34,    35,
    35,    36,    36,    -6,    5,
    -1,    6,     6,     6,     7,
    7,     7,     8200,  8204,  8203,
    8,     8,     -13,   16,    -1,
    17,    17,    17,    18,    18,
    18,    8211,  8206,  8217,  19,
    -12,   44,    -1,    45,    45,
    45,    46,    46,    46,    8239,
    8203,  8203,  47,    47,    -13,
    20,    -1,    21,    21,    21,
    22,    22,    22,    23,    23,
    23,    24,    24,    24,    -14,
    30,    30,    30,    31,    31,
    31,    -6,    32,    -1,    33,
    -1,    25,    25,    25,    26,
    26,    26,    -6,    27,    27,
    27,    28,    28,    28,    -6,
    25,    25,    25,    26,    26,
    26,    -6,    48,    -1,    49,
    49,    49,    49,    50,    50,
    50,    51,    51,    51,    52,
    52,    52,    -9,    50,    50,
    50,    51,    51,    51,    52,
    52,    8244,  -11,   58,    -1,
    59,    59,    59,    60,    60,
    60,    61,    61,    61,    62,
    62,    62,    -12,   63,    63,
    64,    64,    65,    8257,  -8,
    56,    57,    21930, -1,    56,
    56,    56,    57,    57,    57,
    -6,    67,    68,    21930, -1,
    67,    67,    67,    68,    68,
    68,    -6,    71,    -1,    71,
    71,    71,    72,    72,    72,
    -6,    73,    73,    74,    74,
    74,    75,    75,    75,    76,
    76,    76,    77,    77,    77,
    78,    78,    78,    77,    77,
    77,    76,    76,    76,    75,
    75,    75,    74,    74,    8266,
    -36,   79,    79,    79,    80,
    80,    80,    81,    81,    81,
    82,    82,    82,    82,    82,
    82,    82,    81,    81,    81,
    80,    80,    80,    79,    79,
    8271,  -62,   -63,   -64,   37,
    -1,    38,    -1,    39,    39,
    39,    40,    40,    40,    41,
    41,    41,    42,    42,    42,
    43,    43,    43,    -12,   84,
    21930, -1,    84,    84,    84,
    85,    85,    85,    86,    86,
    86,    87,    87,    87,    88,
    88,    88,    89,    89,    89,
    90,    90,    90,    -12,   87,
    87,    8279,  -13,   131,   132,
    133,   134,   130,   -1,    131,
    -1,    132,   132,   133,   133,
    134,   134,   -6,    126,   -1,
    128,   128,   173,   173,   129,
    129,   -6,    128,   128,   173,
    173,   129,   8321,  -8,    127,
    126,   -1,    127,   -1,    128,
    128,   173,   173,   129,   129,
    -6,    128,   128,   173,   173,
    129,   129,   -6,    120,   -1,
    120,   120,   120,   120,   121,
    121,   121,   121,   122,   122,
    122,   122,   123,   123,   123,
    123,   124,   8316,  8205,  8192,
    124,   124,   -24,   161,   -1,
    9,     9,     9,     10,    10,
    10,    11,    11,    11,    12,
    12,    12,    -12,   15,    15,
    15,    13,    13,    13,    8206,
    8221,  8208,  14,    14,    -24,
    103,   103,   103,   104,   104,
    104,   105,   105,   105,   -9,
    106,   106,   106,   107,   107,
    107,   108,   108,   108,   -9,
    171,   171,   172,   172,   -4,
    113,   -1,    114,   114,   115,
    115,   116,   116,   117,   117,
    118,   118,   -12,   167,   167,
    167,   167,   167,   167,   168,
    168,   168,   168,   168,   168,
    169,   169,   169,   169,   169,
    169,   168,   168,   168,   168,
    168,   168,   -24,   170,   170,
    8362,  8205,  8212,  170,   170,
    -32,   174,   -1,    175,   8367,
    8260,  8204,  175,   175,   -8,
    176,   -1,    177,   177,   8369,
    8206,  8208,  177,   177,   -9,
    178,   21930, -1,    178,   -1,
    179,   179,   179,   180,   180,
    180,   -6,    180,   -1,    180,
    -1,    188,   188,   188,   189,
    189,   189,   190,   190,   190,
    191,   191,   191,   -12,   192,
    192,   192,   193,   193,   193,
    194,   194,   194,   195,   195,
    195,   196,   196,   196,   -15,
    91,    91,    91,    93,    93,
    93,    -6,    94,    94,    8286,
    8222,  8200,  94,    94,    94,
    94,    94,    94,    94,    94,
    94,    94,    92,    92,    92,
    92,    92,    -23,   211,   -1,
    212,   212,   213,   213,   213,
    214,   214,   214,   215,   215,
    215,   216,   216,   216,   -12,
    213,   213,   213,   214,   214,
    214,   215,   215,   215,   216,
    216,   8408,  -14,   69,    69,
    69,    70,    70,    70,    -6,
    69,    69,    69,    70,    70,
    70,    -6,    69,    69,    69,
    70,    70,    70,    -6,    109,
    110,   111,   -1,    111,   111,
    111,   110,   109,   109,   109,
    8302,  8220,  8208,  110,   110,
    111,   111,   111,   111,   -18,
    223,   -1,    135,   135,   135,
    136,   136,   136,   137,   137,
    137,   -9,    8273,  -8,    138,
    138,   138,   139,   139,   139,
    140,   140,   140,   139,   139,
    139,   -12,   8273,  -7,    181,
    181,   181,   182,   182,   182,
    -6,    8274,  -7,    224,   -1,
    8271,  -4,    225,   -1,    8272,
    -4,    226,   -1,    8251,  -4,
    227,   -1,    217,   218,   219,
    21930, -1,    217,   217,   218,
    218,   219,   219,   -6,    220,
    221,   222,   21930, -1,    220,
    220,   221,   221,   222,   222,
    -6,    208,   208,   208,   209,
    209,   209,   210,   210,   210,
    -9,    147,   -1,    148,   148,
    148,   148,   149,   149,   149,
    149,   149,   149,   8342,  8221,
    8212,  150,   150,   -17,   156,
    -1,    157,   157,   157,   157,
    157,   158,   158,   158,   158,
    158,   159,   159,   159,   8352,
    8253,  8196,  160,   160,   160,
    160,   -22,   183,   183,   183,
    -3,    183,   183,   183,   -3,
    184,   184,   184,   185,   185,
    185,   186,   186,   186,   187,
    187,   187,   -12,   162,   -1,
    162,   162,   162,   163,   163,
    163,   164,   164,   164,   165,
    165,   165,   -12,   162,   162,
    162,   163,   163,   163,   164,
    164,   164,   165,   165,   165,
    166,   166,   8358,  -17,   151,
    -1,    152,   152,   152,   153,
    -1,    154,   -1,    155,   -1,
    228,   -1,    228,   228,   229,
    229,   -4,    230,   230,   231,
    231,   230,   8422,  -8,    99,
    99,    99,    100,   100,   100,
    101,   101,   101,   -9,    96,
    96,    96,    97,    97,    97,
    98,    98,    98,    -9,
};

pub var anim_player: [30][]const i16 = .{
    &.{ 0, -2 },
    &.{-1},
    &.{ 9, 8, -4 },
    &.{ 5, 6, 6, 7, 7, -8 },
    &.{ 4, -2 },
    &.{ 5, -2 },
    &.{ 11, 11, 12, 12, -8 },
    &.{ 22, -2 },
    &.{ 22, -2 },
    &.{ 9, -2 },
    &.{ 8, 8, 9, 9, -8 },
    &.{ 25, 26, 27, -6 },
    &.{ 15, 15, 15, 15, 15, 15, 15, 15, 10, -2 },
    &.{ 28, 28, 28, 28, 28, 28, 28, 28, 10, -2 },
    &.{-1},
    &.{-1},
    &.{ 16, -2 },
    &.{ 17, 17, 17, 18, 18, 18, 18, 19, 19, 19, 18, 18, 18, 18, -28 },
    &.{ 20, 21, -4 },
    &.{ 17, 17, 17, 18, 18, 18, 18, 19, 19, 19, 18, 18, 18, 18, -28 },
    &.{ 16, -2 },
    &.{ 22, -2 },
    &.{ 23, 23, 24, 24, -8 },
    &.{ 22, -2 },
    &.{ 22, -2 },
    &.{-1},
    &.{-1},
    &.{ 25, 26, 27, -6 },
    &.{ 15, 15, 15, 15, 15, 15, 15, 15, 10, -2 },
    &.{ 28, 28, 28, 28, 28, 28, 28, 28, 10, -2 },
};

pub fn get_anim_player(action: u8) [*c]const i16 {
    return &anim_player[action][0];
}

pub fn init_anim_player() void {
    if (game == .Titus) {
        anim_player[1] = &.{ 2, 2, 2, 1, 1, 1, 1, 2, 2, 2, 3, 3, 3, 3, -14 * 2 };
    } else if (game == .Moktar) {
        anim_player[1] = &.{ 2, 2, 2, 1, 1, 1, 2, 2, 3, 3, 3, -11 * 2 };
    }
}

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
        game = .Titus;
        return &titus_consts;
    } else if (isFileOpenable(moktar_consts.sprites)) {
        game = .Moktar;
        return &moktar_consts;
    } else {
        return error.CannotDetermineGameType;
    }
}

pub fn init() !void {
    constants = try initGameType();
}
