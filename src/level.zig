const std = @import("std");
const c = @import("c.zig");
const SDL = @import("SDL.zig");
const data = @import("data.zig");
const sprites = @import("sprites.zig");
const ObjectData = data.ObjectData;
const audio = @import("audio/audio.zig");
const AudioTrack = audio.AudioTrack;

// TODO: split the original level representation:
//  - from internal 'initialize level stuff this way' data types
//  - from runtime gameplay data types
//
// The idea is that we will have a new format for the levels that isn't this limited (bigger size, more objects)
// to do that, we have to split all of the data representations

// fully describe enemy data as an externally tagged union, then remove these
inline fn load_u16(high: u8, low: u8) u16 {
    return @as(u16, high) * 256 + low;
}

inline fn load_i16(high: u8, low: u8) i16 {
    return (@as(i16, @bitCast(@as(u16, high))) << 8) + low;
}

test "test i16 loading" {
    try std.testing.expect(load_i16(0xFF, 0xFF) == -1);
    try std.testing.expect(load_i16(0x00, 0x00) == 0);
    try std.testing.expect(load_i16(0x00, 0x01) == 1);
    try std.testing.expect(load_i16(0x7F, 0xFF) == 32767);
    try std.testing.expect(load_i16(0x80, 0x00) == -32768);
}

test "test u16 loading" {
    try std.testing.expect(load_u16(0xFF, 0xFF) == 65535);
    try std.testing.expect(load_u16(0x00, 0x00) == 0);
    try std.testing.expect(load_u16(0x00, 0x01) == 1);
    try std.testing.expect(load_u16(0x7F, 0xFF) == 32767);
    try std.testing.expect(load_u16(0x80, 0x00) == 32768);
}

pub const HFlag = enum(u8) {
    NoWall = 0,
    Wall = 1,
    Bonus = 2,
    Deadly = 3,
    Code = 4,
    Padlock = 5,
    CodeLevel14 = 6,
};

pub const FFlag = enum(u7) {
    NoFloor = 0,
    Floor = 1,
    SlightlySlipperyFloor = 2,
    SlipperyFloor = 3,
    VerySlipperyFloor = 4,
    Drop = 5,
    Ladder = 6,
    Bonus = 7,
    Water = 8,
    Fire = 9,
    Spikes = 10,
    Code = 11,
    Padlock = 12,
    CodeLevel14 = 13,
};

pub const CFlag = enum(u8) {
    NoCeiling = 0,
    Ceiling = 1,
    Ladder = 2,
    Padlock = 3,
    Deadly = 4,
};

pub const Tile = struct {
    tiledata: *SDL.Surface,
    animated: bool, // technically not even used
    animation: [3]u8,
    horizflag: HFlag,
    floorflag: FFlag,
    ceilflag: CFlag,
};

pub const Level = struct {
    c_level: c.TITUS_level,
    tilemap: []u8,
    width: usize = 0,
    height: usize = 0,
    tiles: [256]Tile,
    music: AudioTrack,
    pixelformat: *SDL.PixelFormat,

    pub fn getTile(self: *const Level, x: usize, y: usize) u8 {
        if (x >= self.width or y >= self.height) {
            unreachable;
        }
        return self.tilemap[y * self.width + x];
    }
    pub fn setTile(self: *const Level, x: usize, y: usize, tile: u8) void {
        if (x >= self.width or y >= self.height) {
            unreachable;
        }
        self.tilemap[y * self.width + x] = tile;
    }
};

const InitSprite = extern union {
    unpacked: packed struct {
        sprite: u13,
        visible: bool,
        flash: bool,
        flipped: bool,
    },
    value: u16,
};

// FIXME: we need to @Swap all of the things that are multiple byte integers on .Big endian platforms
const StaticData = extern struct {
    // 0, planar 16 color images, 16x16
    tile_images: [256]extern struct {
        data: [128]u8,
    },
    // 32768
    horiz_flags: [256]u8,
    // 33024
    floor_flags: [256]u8,
    // 33280
    ceil_flags: [256]packed struct {
        ceil: u7 = 0,
        animated: u1 = 0,
    },
    // 33536
    objects: [40]extern struct {
        initSprite: InitSprite,
        initX: i16,
        initY: i16,
    },
    altitude_zero: i16,
    initX: i16,
    initY: i16,
    // 33782
    // It looks like a union based on enemy type, with some holes???
    // I guess we keep the old code for it and just give it 'data' for now
    enemies: [50]extern struct {
        init_x: i16, // 0, 1
        init_y: i16, // 2, 3
        init_sprite: InitSprite, // 4, 5, only the 'flipped' bit is used, flash and visible are ignored
        type: packed struct { // 6, 7
            value: u13,
            // TODO: what are those bits?
            unknown: u3,
        },
        init_speed_x: i16, // 8, 9
        unknown_10_11: u16, // 10, 11
        power: i16, // 12, 13
        // the rest varies based on type, TODO: make an union for it.
        varies: [12]u8,
    },
    // 35082
    bonuses: [100]extern struct {
        bonustile: u8,
        replacetile: u8,
        x: u8,
        y: u8,
    },
    // 35482
    xlimit: i16,
    // 35484
    gates: [20]extern struct {
        entranceX: u8,
        entranceY: u8,
        screenX: u8,
        screenY: u8,
        exitX: u8,
        exitY: u8,
        noscroll: u8,
    },
    // 35624
    // TODO: this is rather nebulous. what are all those unknown bytes for
    // TODO: support? flip? See: https://github.com/kaimitai/vtitus/raw/main/resources/elevators.PNG
    elevators: [10]extern struct {
        unknown0: u16,
        unknown2: u16,
        init_sprite: InitSprite,
        unknown6: u8,
        speed: i8,
        unknown8: u16, // 8, 9
        range: u16, // 10, 11
        init_x: i16, // 12, 13
        init_y: u16, // 14, 15
        init_direction: u8, // 16
        unknown17: u8, // 17
        unknown18: u16, // 18, 19
    },
    finishX: i16,
    finishY: i16,
};

// sanity checks for StaticData
comptime {
    if (@offsetOf(StaticData, "tile_images") != 0) {
        unreachable;
    }
    if (@offsetOf(StaticData, "horiz_flags") != 32768) {
        unreachable;
    }
    if (@offsetOf(StaticData, "floor_flags") != 33024) {
        unreachable;
    }
    if (@offsetOf(StaticData, "ceil_flags") != 33280) {
        unreachable;
    }
    if (@offsetOf(StaticData, "objects") != 33536) {
        unreachable;
    }
    if (@offsetOf(StaticData, "altitude_zero") != 33776) {
        unreachable;
    }
    if (@offsetOf(StaticData, "initX") != 33778) {
        unreachable;
    }
    if (@offsetOf(StaticData, "initY") != 33780) {
        unreachable;
    }
    if (@offsetOf(StaticData, "enemies") != 33782) {
        unreachable;
    }
    if (@offsetOf(StaticData, "bonuses") != 35082) {
        unreachable;
    }
    if (@offsetOf(StaticData, "xlimit") != 35482) {
        unreachable;
    }
    if (@offsetOf(StaticData, "gates") != 35484) {
        unreachable;
    }
    if (@offsetOf(StaticData, "elevators") != 35624) {
        unreachable;
    }
    if (@sizeOf(StaticData) != 35828) {
        unreachable;
    }
}

pub fn loadlevel(
    level_wrap: *Level,
    level: *c.TITUS_level,
    allocator: std.mem.Allocator,
    leveldata: []const u8,
    objectdata: []const ObjectData,
    levelcolor: *SDL.Color,
) !c_int {
    level.player.inithp = 16;
    level.player.cageX = 0;
    level.player.cageY = 0;

    // read tilemap
    {
        const tilemap_data = leveldata[0 .. leveldata.len - 35828];
        level.height = @intCast(tilemap_data.len / 256);
        level.width = 256;

        const width: usize = @intCast(level.width);
        const height: usize = @intCast(level.height);
        level_wrap.width = width;
        level_wrap.height = height;

        level_wrap.tilemap = try allocator.alloc(u8, width * height);
        @memcpy(level_wrap.tilemap, leveldata[0 .. width * height]);
    }

    level_wrap.pixelformat.*.palette.*.colors[14].r = levelcolor.r;
    level_wrap.pixelformat.*.palette.*.colors[14].g = levelcolor.g;
    level_wrap.pixelformat.*.palette.*.colors[14].b = levelcolor.b;

    level.spritedata = @ptrCast(&sprites.sprites.definitions[0]);
    // NOTE: evil ptrCast from `*ObjectData` to `*struct _TITUS_objectdata`
    level.objectdata = @ptrCast(&objectdata[0]);

    const other_data: *const StaticData = @ptrCast(@alignCast(leveldata[leveldata.len - 35828 ..]));
    {
        var j: usize = 256; //j is used for "last tile with animation flag"
        for (0..256) |i| {
            level_wrap.tiles[i].tiledata = @ptrCast(try sprites.load_tile(&other_data.tile_images[i].data, level_wrap.pixelformat));
            level.tile[i].horizflag = other_data.horiz_flags[i];
            level.tile[i].floorflag = other_data.floor_flags[i];
            level.tile[i].ceilflag = other_data.ceil_flags[i].ceil;

            level.tile[i].animation[0] = @truncate(i);
            if (i > 0 and j == i - 1) { //Check if this is the second tile after animation flag
                level.tile[i].animation[1] = @truncate(i + 1);
                level.tile[i].animation[2] = @truncate(i - 1);
            } else if (i > 1 and j == i - 2) { //Check if this is the third tile after animation flag
                level.tile[i].animation[1] = @truncate(i - 2);
                level.tile[i].animation[2] = @truncate(i - 1);
            } else if (other_data.ceil_flags[i].animated == 1) { //Animation flag
                level.tile[i].animation[1] = @truncate(i + 1);
                level.tile[i].animation[2] = @truncate(i + 2);
                j = i;
            } else {
                level.tile[i].animation[1] = @truncate(i);
                level.tile[i].animation[2] = @truncate(i);
            }
        }
    }
    {
        for (0..c.OBJECT_CAPACITY) |i| {
            const initSprite = other_data.objects[i].initSprite;
            // TODO: use dynamic arrays for the actual loaded data
            // TODO: if it's not 'enabled', don't even load it, just skip entirely
            level.object[i].init_enabled = initSprite.value != 0xFFFF;
            level.object[i].init_sprite = initSprite.unpacked.sprite;
            level.object[i].init_visible = initSprite.unpacked.visible;
            level.object[i].init_flipped = initSprite.unpacked.flipped;
            level.object[i].init_flash = initSprite.unpacked.flash;
            level.object[i].init_x = other_data.objects[i].initX;
            level.object[i].init_y = other_data.objects[i].initY;
        }
    }

    c.ALTITUDE_ZERO = other_data.altitude_zero; // + 12;
    // 33778
    level.player.initX = other_data.initX;
    level.player.initY = other_data.initY;

    // 33782
    for (0..c.ENEMY_CAPACITY) |i| {
        const init_sprite = other_data.enemies[i].init_sprite;
        level.enemy[i].init_enabled = init_sprite.value != 0xFFFF;

        // TODO: use dynamic arrays for the actual loaded data
        // TODO: if it's not 'enabled', don't even load it, just skip entirely
        if (level.enemy[i].init_enabled) {
            // visible and flash are ignored
            level.enemy[i].init_flipped = init_sprite.unpacked.flipped;
            level.enemy[i].init_sprite = init_sprite.unpacked.sprite + 101;
            level.enemy[i].init_x = other_data.enemies[i].init_x;
            level.enemy[i].init_y = other_data.enemies[i].init_y;
            level.enemy[i].type = other_data.enemies[i].type.value;
            level.enemy[i].init_speed_x = other_data.enemies[i].init_speed_x;
            level.enemy[i].init_speed_y = 0;
            level.enemy[i].power = other_data.enemies[i].power;

            const enemy_orig = &other_data.enemies[i].varies;
            switch (level.enemy[i].type) {
                //Noclip walk
                0, 1 => {
                    level.enemy[i].center_x = load_i16(enemy_orig[2], enemy_orig[1]);
                    level.enemy[i].range_x = load_u16(enemy_orig[4], enemy_orig[3]);
                },
                //Shoot
                2 => {
                    level.enemy[i].delay = enemy_orig[2];
                    // really a u2 for direction and u14 for the range
                    level.enemy[i].range_x = load_u16(enemy_orig[4], enemy_orig[3]);
                    level.enemy[i].direction = @as(u2, @truncate((level.enemy[i].range_x >> 14) & 0x0003));
                    level.enemy[i].range_x = level.enemy[i].range_x & 0x3FFF;
                },
                //Noclip walk, jump to player
                3, 4 => {
                    level.enemy[i].center_x = load_i16(enemy_orig[2], enemy_orig[1]);
                    level.enemy[i].range_x = load_u16(enemy_orig[4], enemy_orig[3]);
                    level.enemy[i].range_y = enemy_orig[5];
                },
                //Noclip walk, move to player
                5, 6 => {
                    level.enemy[i].center_x = load_i16(enemy_orig[2], enemy_orig[1]);
                    level.enemy[i].range_x = load_u16(enemy_orig[4], enemy_orig[3]);
                    level.enemy[i].range_y = enemy_orig[5];
                },
                //Gravity walk, hit when near
                7 => {
                    level.enemy[i].walkspeed_x = enemy_orig[5];
                    level.enemy[i].range_x = load_u16(enemy_orig[10], enemy_orig[9]);
                },
                //Gravity walk when off-screen
                8 => {
                    level.enemy[i].walkspeed_x = enemy_orig[5];
                },
                9 => { //Walk and periodically pop-up
                    level.enemy[i].walkspeed_x = enemy_orig[5];
                    level.enemy[i].range_x = load_u16(enemy_orig[10], enemy_orig[9]);
                },
                10 => { //Alert when near, walk when nearer
                    level.enemy[i].walkspeed_x = enemy_orig[5];
                    level.enemy[i].range_x = load_u16(enemy_orig[10], enemy_orig[9]);
                },
                //Walk and shoot
                11 => {
                    level.enemy[i].walkspeed_x = enemy_orig[5];
                    level.enemy[i].range_x = load_u16(enemy_orig[10], enemy_orig[9]);
                },
                //Jump (immortal)
                12 => {
                    level.enemy[i].range_y = load_u16(enemy_orig[2], enemy_orig[1]);
                    level.enemy[i].delay = enemy_orig[5];
                },
                //Bounce
                13 => {
                    level.enemy[i].delay = enemy_orig[6];
                    level.enemy[i].range_x = load_u16(enemy_orig[10], enemy_orig[9]);
                },
                //Gravity walk when off-screen (immortal)
                14 => {
                    level.enemy[i].walkspeed_x = enemy_orig[5];
                },
                //Nothing (immortal)
                15 => {},
                //Nothing
                16 => {},
                //Drop (immortal)
                17 => {
                    level.enemy[i].range_x = load_u16(enemy_orig[2], enemy_orig[1]);
                    level.enemy[i].delay = load_u16(enemy_orig[4], enemy_orig[3]);
                    level.enemy[i].range_y = load_u16(enemy_orig[8], enemy_orig[7]);
                },
                //Drop (immortal)
                18 => {
                    level.enemy[i].range_x = load_u16(enemy_orig[2], enemy_orig[1]);
                    level.enemy[i].range_y = load_u16(enemy_orig[4], enemy_orig[3]);
                    level.enemy[i].init_speed_y = enemy_orig[5];
                },
                else => {
                    std.log.err("Unhandled enemy type in level: {d}", .{level.enemy[i].type});
                },
            }
        } else {
            level.enemy[i].sprite.enabled = false;
        }
    }
    // 35082

    level.bonuscount = 0;
    level.bonuscollected = 0;
    level.tickcount = 0;
    for (0..c.BONUS_CAPACITY) |i| {
        level.bonus[i].x = other_data.bonuses[i].x;
        level.bonus[i].y = other_data.bonuses[i].y;
        level.bonus[i].exists = ((level.bonus[i].x != 0xFF) and (level.bonus[i].y != 0xFF));
        if (level.bonus[i].exists) {
            level.bonus[i].bonustile = other_data.bonuses[i].bonustile;
            level.bonus[i].replacetile = other_data.bonuses[i].replacetile;
            if (level.bonus[i].bonustile >= 255 - 2) {
                level.bonuscount += 1;
            }
            level_wrap.setTile(level.bonus[i].x, level.bonus[i].y, level.bonus[i].bonustile);
        }
    }

    // FIXME, @Research: There seems to be no XLIMIT in some levels in the original game, where we have XLIMIT here
    //                   So find where it is in the file, read it and use it so we don't have weird XLIMIT issues
    //                   in levels where this problem doesn't belong...
    //
    //    Ok ... it's not in the file. At least not obviously. The weirdness must be coming from somewhere else.
    c.XLIMIT = other_data.xlimit; // + 20;
    // fprintf(stderr, "XLIMIT is set at %d\n", XLIMIT);
    c.XLIMIT_BREACHED = false;

    for (0..c.GATE_CAPACITY) |i| {
        level.gate[i].entranceY = other_data.gates[i].entranceY;
        level.gate[i].exists = (level.gate[i].entranceY != 0xFF);
        if (level.gate[i].exists) {
            level.gate[i].entranceX = other_data.gates[i].entranceX;
            level.gate[i].screenX = other_data.gates[i].screenX;
            level.gate[i].screenY = other_data.gates[i].screenY;
            level.gate[i].exitX = other_data.gates[i].exitX;
            level.gate[i].exitY = other_data.gates[i].exitY;
            level.gate[i].noscroll = other_data.gates[i].noscroll != 0;
        }
    }

    for (0..c.ELEVATOR_CAPACITY) |i| {
        const initSprite = other_data.elevators[i].init_sprite;
        level.elevator[i].init_x = other_data.elevators[i].init_x;
        level.elevator[i].init_y = other_data.elevators[i].init_y;
        var j: i16 = other_data.elevators[i].speed;

        const enabled = ((initSprite.value != 0xFFFF) and (j < 8) and (level.elevator[i].init_x >= -16) and (level.elevator[i].init_y >= 0));
        // This is so oddly specific...
        // Let's NOT have this in the new format
        level.elevator[i].init_enabled = enabled;
        level.elevator[i].enabled = enabled;
        if (!enabled) {
            continue;
        }

        level.elevator[i].init_sprite = initSprite.unpacked.sprite + 30;
        level.elevator[i].init_visible = initSprite.unpacked.visible;
        level.elevator[i].init_flipped = initSprite.unpacked.flipped;
        level.elevator[i].init_flash = initSprite.unpacked.flash;
        level.elevator[i].range = other_data.elevators[i].range;
        // FIXME: this should be an enum...
        level.elevator[i].init_direction = other_data.elevators[i].init_direction;
        if ((level.elevator[i].init_direction == 0) or (level.elevator[i].init_direction == 3)) { //Up or left
            j = 0 - j;
        }
        if ((level.elevator[i].init_direction == 0) or //up
            (level.elevator[i].init_direction == 2))
        { //down
            level.elevator[i].init_speed_x = 0;
            level.elevator[i].init_speed_y = j;
        } else {
            level.elevator[i].init_speed_x = j;
            level.elevator[i].init_speed_y = 0;
        }
    }

    level.finishX = other_data.finishX;
    level.finishY = other_data.finishY;

    sprites.sprites.setPixelFormat(level_wrap.pixelformat);
    sprites.sprite_cache.evictAll();

    for (0..4) |i| {
        level.trash[i].enabled = false;
    }
    return (0);
}

pub fn freelevel(level: *Level, allocator: std.mem.Allocator) void {
    allocator.free(level.tilemap);

    for (0..256) |i| {
        SDL.freeSurface(@ptrCast(@alignCast(level.tiles[i].tiledata)));
    }
}

pub export fn get_horizflag(level: *c.TITUS_level, tileY: i16, tileX: i16) c.HFLAG {
    if ((tileX < 0) or
        (tileX >= level.width))
    {
        return c.HFLAG_WALL;
    } else if ((tileY < 0) or
        (tileY >= level.height))
    {
        return c.HFLAG_NOWALL;
    } else {
        var parent_level: *Level = @ptrCast(@alignCast(level.parent));
        const tile = parent_level.getTile(@intCast(tileX), @intCast(tileY));
        return level.tile[tile].horizflag;
    }
}

pub export fn get_floorflag(level: *c.TITUS_level, tileY: i16, tileX: i16) c.FFLAG {
    if ((tileX < 0) or
        (tileX >= level.width))
    {
        return c.FFLAG_FLOOR;
    } else if ((tileY < 0) or
        (tileY >= level.height))
    {
        return c.FFLAG_NOFLOOR;
    } else {
        var parent_level: *Level = @ptrCast(@alignCast(level.parent));
        const tile = parent_level.getTile(@intCast(tileX), @intCast(tileY));
        return level.tile[tile].floorflag;
    }
}

pub export fn get_ceilflag(level: *c.TITUS_level, tileY: i16, tileX: i16) c.CFLAG {
    if ((tileY < 0) or
        (tileY >= level.height) or
        (tileX < 0) or
        (tileX >= level.width))
    {
        return c.CFLAG_NOCEILING;
    } else {
        var parent_level: *Level = @ptrCast(@alignCast(level.parent));
        const tile = parent_level.getTile(@intCast(tileX), @intCast(tileY));
        return level.tile[tile].ceilflag;
    }
}

pub export fn set_tile(level: *c.TITUS_level, tileY: u8, tileX: u8, tile: u8) void {
    if ((tileY < 0) or
        (tileY >= level.height) or
        (tileX < 0) or
        (tileX >= level.width))
    {
        return;
    }
    var parent_level: *Level = @ptrCast(@alignCast(level.parent));
    parent_level.setTile(tileX, tileY, tile);
}
