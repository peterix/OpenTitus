const std = @import("std");
const spr = @import("sprites.zig");
const c = @import("c.zig");

fn load_u16(high: u8, low: u8) u16 {
    return @as(u16, high) * 256 + low;
}

fn load_i16(high: u8, low: u8) i16 {
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

pub const Level = struct {
    c_level: c.TITUS_level,
    tilemap: [][]u8,
};

pub fn loadlevel(
    level_wrap: *Level,
    level: *c.TITUS_level,
    allocator: std.mem.Allocator,
    leveldata: []const u8,
    spritedata: *c.TITUS_spritedata,
    objectdata: [*c][*c]c.TITUS_objectdata,
    levelcolor: *c.SDL_Color,
) !c_int {
    var offset: usize = 0;

    level.player.inithp = 16;
    level.player.cageX = 0;
    level.player.cageY = 0;

    level.height = @intCast((leveldata.len - 35828) / 256);
    level.width = 256;
    const width: usize = @intCast(level.width);
    const height: usize = @intCast(level.height);

    level_wrap.tilemap = try allocator.alloc([]u8, height);
    for (0..height) |i| {
        level_wrap.tilemap[i] = try allocator.alloc(u8, width);
        for (0..width) |j| {
            level_wrap.tilemap[i][j] = leveldata[i * width + j];
        }
    }
    level.pixelformat.*.palette.*.colors[14].r = levelcolor.r;
    level.pixelformat.*.palette.*.colors[14].g = levelcolor.g;
    level.pixelformat.*.palette.*.colors[14].b = levelcolor.b;

    {
        offset = height * width;
        var j: usize = 256; //j is used for "last tile with animation flag"
        for (0..256) |i| {
            level.tile[i].tiledata = try spr.load_tile(leveldata[offset + i * 128 ..], level.pixelformat);
            level.tile[i].current = @truncate(i);
            level.tile[i].horizflag = leveldata[offset + 32768 + i] & 0xFF;
            level.tile[i].floorflag = leveldata[offset + 32768 + 256 + i] & 0xFF;
            level.tile[i].ceilflag = leveldata[offset + 32768 + 512 + i] & 0x7F;

            level.tile[i].animated = true;
            level.tile[i].animation[0] = @truncate(i);
            if (i > 0 and j == i - 1) { //Check if this is the second tile after animation flag
                level.tile[i].animation[1] = @truncate(i + 1);
                level.tile[i].animation[2] = @truncate(i - 1);
            } else if (i > 1 and j == i - 2) { //Check if this is the third tile after animation flag
                level.tile[i].animation[1] = @truncate(i - 2);
                level.tile[i].animation[2] = @truncate(i - 1);
            } else if ((leveldata[offset + 32768 + 512 + i] & 0x80) == 0x80) { //Animation flag
                level.tile[i].animation[1] = @truncate(i + 1);
                level.tile[i].animation[2] = @truncate(i + 2);
                j = i;
            } else {
                level.tile[i].animation[1] = @truncate(i);
                level.tile[i].animation[2] = @truncate(i);
                level.tile[i].animated = false;
            }
        }
        level.spritedata = spritedata;
        level.objectdata = objectdata;

        level.player.initX = load_i16(leveldata[height * width + 33779], leveldata[height * width + 33778]);
        level.player.initY = load_i16(leveldata[height * width + 33781], leveldata[height * width + 33780]);

        level.finishX = load_i16(leveldata[height * width + 35825], leveldata[height * width + 35824]);
        level.finishY = load_i16(leveldata[height * width + 35827], leveldata[height * width + 35826]);
    }

    {
        offset = height * width + 33536;
        for (0..c.OBJECT_CAPACITY) |i| {
            level.object[i].initsprite = load_u16(leveldata[offset + i * 6 + 1], leveldata[offset + i * 6 + 0]);
            level.object[i].init_enabled = (level.object[i].initsprite != 0xFFFF);
            if (level.object[i].init_enabled) {
                level.object[i].initX = load_i16(leveldata[offset + i * 6 + 3], leveldata[offset + i * 6 + 2]);
                level.object[i].initY = load_i16(leveldata[offset + i * 6 + 5], leveldata[offset + i * 6 + 4]);
            }
        }
    }

    offset = height * width + 33782;
    for (0..c.ENEMY_CAPACITY) |i| {
        level.enemy[i].initspeedY = 0;
        level.enemy[i].initsprite = load_u16(leveldata[offset + 5], leveldata[offset + 4]);
        level.enemy[i].init_enabled = (level.enemy[i].initsprite != 0xFFFF);
        level.enemy[i].power = 0;
        level.enemy[i].walkspeedX = 0;
        if (level.enemy[i].init_enabled) {
            level.enemy[i].initspeedY = 0;
            level.enemy[i].initX = load_i16(leveldata[offset + 1], leveldata[offset + 0]);
            level.enemy[i].initY = load_i16(leveldata[offset + 3], leveldata[offset + 2]);
            level.enemy[i].type = load_u16(leveldata[offset + 7], leveldata[offset + 6]) & 0x1FFF;
            level.enemy[i].initspeedX = load_i16(leveldata[offset + 9], leveldata[offset + 8]);
            level.enemy[i].power = load_i16(leveldata[offset + 13], leveldata[offset + 12]);

            switch (level.enemy[i].type) {
                //Noclip walk
                0, 1 => {
                    level.enemy[i].centerX = load_i16(leveldata[offset + 16], leveldata[offset + 15]);
                    level.enemy[i].rangeX = load_u16(leveldata[offset + 18], leveldata[offset + 17]);
                },
                //Shoot
                2 => {
                    level.enemy[i].delay = leveldata[offset + 16];
                    // really a u2 for direction and u14 for the range
                    level.enemy[i].rangeX = load_u16(leveldata[offset + 18], leveldata[offset + 17]);
                    level.enemy[i].direction = @as(u2, @truncate((level.enemy[i].rangeX >> 14) & 0x0003));
                    level.enemy[i].rangeX = level.enemy[i].rangeX & 0x3FFF;
                },
                //Noclip walk, jump to player
                3, 4 => {
                    level.enemy[i].centerX = load_i16(leveldata[offset + 16], leveldata[offset + 15]);
                    level.enemy[i].rangeX = load_u16(leveldata[offset + 18], leveldata[offset + 17]);
                    level.enemy[i].rangeY = leveldata[offset + 19];
                },
                //Noclip walk, move to player
                5, 6 => {
                    level.enemy[i].centerX = load_i16(leveldata[offset + 16], leveldata[offset + 15]);
                    level.enemy[i].rangeX = load_u16(leveldata[offset + 18], leveldata[offset + 17]);
                    level.enemy[i].rangeY = leveldata[offset + 19];
                },
                //Gravity walk, hit when near
                7 => {
                    level.enemy[i].walkspeedX = leveldata[offset + 19];
                    level.enemy[i].rangeX = load_u16(leveldata[offset + 24], leveldata[offset + 23]);
                },
                //Gravity walk when off-screen
                8 => {
                    level.enemy[i].walkspeedX = leveldata[offset + 19];
                },
                9 => { //Walk and periodically pop-up
                    level.enemy[i].walkspeedX = leveldata[offset + 19];
                    level.enemy[i].rangeX = load_u16(leveldata[offset + 24], leveldata[offset + 23]);
                },
                10 => { //Alert when near, walk when nearer
                    level.enemy[i].walkspeedX = leveldata[offset + 19];
                    level.enemy[i].rangeX = load_u16(leveldata[offset + 24], leveldata[offset + 23]);
                },
                //Walk and shoot
                11 => {
                    level.enemy[i].walkspeedX = leveldata[offset + 19];
                    level.enemy[i].rangeX = load_u16(leveldata[offset + 24], leveldata[offset + 23]);
                },
                //Jump (immortal)
                12 => {
                    level.enemy[i].rangeY = load_u16(leveldata[offset + 16], leveldata[offset + 15]);
                    level.enemy[i].delay = leveldata[offset + 19];
                },
                //Bounce
                13 => {
                    level.enemy[i].delay = leveldata[offset + 20];
                    level.enemy[i].rangeX = load_u16(leveldata[offset + 24], leveldata[offset + 23]);
                },
                //Gravity walk when off-screen (immortal)
                14 => {
                    level.enemy[i].walkspeedX = leveldata[offset + 19];
                },
                //Nothing (immortal)
                15 => {},
                //Nothing
                16 => {},
                //Drop (immortal)
                17 => {
                    level.enemy[i].rangeX = load_u16(leveldata[offset + 16], leveldata[offset + 15]);
                    level.enemy[i].delay = load_u16(leveldata[offset + 18], leveldata[offset + 17]);
                    level.enemy[i].rangeY = load_u16(leveldata[offset + 22], leveldata[offset + 21]);
                },
                //Drop (immortal)
                18 => {
                    level.enemy[i].rangeX = load_u16(leveldata[offset + 16], leveldata[offset + 15]);
                    level.enemy[i].rangeY = load_u16(leveldata[offset + 18], leveldata[offset + 17]);
                    level.enemy[i].initspeedY = leveldata[offset + 19];
                },
                else => {
                    std.log.err("Unhandled enemy type in level: {d}", .{level.enemy[i].type});
                },
            }
        } else {
            level.enemy[i].sprite.enabled = false;
        }
        offset += 26;
    }

    level.bonuscount = 0;
    level.bonuscollected = 0;
    level.tickcount = 0;

    offset = height * width + 35082;
    for (0..c.BONUS_CAPACITY) |i| {
        level.bonus[i].x = leveldata[offset + 2];
        level.bonus[i].y = leveldata[offset + 3];
        level.bonus[i].exists = ((level.bonus[i].x != 0xFF) and (level.bonus[i].y != 0xFF));
        if (level.bonus[i].exists) {
            level.bonus[i].bonustile = leveldata[offset];
            level.bonus[i].replacetile = leveldata[offset + 1];
            if (level.bonus[i].bonustile >= 255 - 2) {
                level.bonuscount += 1;
            }
            level_wrap.tilemap[level.bonus[i].y][level.bonus[i].x] = leveldata[offset + 0]; //Overwrite the actual tile
        }
        offset += 4;
    }

    offset = height * width + 35484;
    for (0..c.GATE_CAPACITY) |i| {
        level.gate[i].entranceY = leveldata[offset + 1];
        level.gate[i].exists = (level.gate[i].entranceY != 0xFF);
        if (level.gate[i].exists) {
            level.gate[i].entranceX = leveldata[offset + 0];
            level.gate[i].screenX = leveldata[offset + 2];
            level.gate[i].screenY = leveldata[offset + 3];
            level.gate[i].exitX = leveldata[offset + 4];
            level.gate[i].exitY = leveldata[offset + 5];
            level.gate[i].noscroll = leveldata[offset + 6] != 0;
        }
        offset += 7;
    }

    offset = height * width + 35624;
    for (0..c.ELEVATOR_CAPACITY) |i| {
        level.elevator[i].counter = 0;
        level.elevator[i].sprite.enabled = false;
        level.elevator[i].initsprite = load_u16(leveldata[offset + 5], leveldata[offset + 4]);
        level.elevator[i].initspeedX = 0;
        level.elevator[i].initspeedY = 0;
        level.elevator[i].initX = load_i16(leveldata[offset + 13], leveldata[offset + 12]);
        level.elevator[i].initY = load_i16(leveldata[offset + 15], leveldata[offset + 14]);
        var j: i16 = @intCast(leveldata[offset + 7]); //Speed
        level.elevator[i].init_enabled = ((level.elevator[i].initsprite != 0xFFFF) and (j < 8) and (level.elevator[i].initX >= -16) and (level.elevator[i].initY >= 0));
        level.elevator[i].enabled = level.elevator[i].init_enabled;

        if (level.elevator[i].enabled) {
            level.elevator[i].range = load_u16(leveldata[offset + 11], leveldata[offset + 10]);
            level.elevator[i].init_direction = leveldata[offset + 16];
            if ((level.elevator[i].init_direction == 0) or (level.elevator[i].init_direction == 3)) { //Up or left
                j = 0 - j;
            }
            if ((level.elevator[i].init_direction == 0) or //up
                (level.elevator[i].init_direction == 2))
            { //down
                level.elevator[i].initspeedY = j;
            } else {
                level.elevator[i].initspeedX = j;
            }
        }
        offset += 20;
    }

    offset = height * width + 33776;
    c.ALTITUDE_ZERO = load_i16(leveldata[offset + 1], leveldata[offset + 0]); // + 12;
    offset = height * width + 35482;
    // FIXME, @Research: There seems to be no XLIMIT in some levels in the original game, where we have XLIMIT here
    //                   So find where it is in the file, read it and use it so we don't have weird XLIMIT issues
    //                   in levels where this problem doesn't belong...
    c.XLIMIT = load_i16(leveldata[offset + 1], leveldata[offset + 0]); // + 20;
    // fprintf(stderr, "XLIMIT is set at %d\n", XLIMIT);
    c.XLIMIT_BREACHED = false;
    for (0..c.SPRITECOUNT) |i| {
        c.copypixelformat(level.spritedata[i].data.*.format, level.pixelformat);
    }
    // FIXME: replace with sprites.sprite_cache.evictAll();
    // Or just store the cache in the level again.
    c.flush_sprite_cache_c();

    for (0..4) |i| {
        level.trash[i].enabled = false;
    }
    return (0);
}

pub fn freelevel(level: *Level, allocator: std.mem.Allocator) void {
    for (0..level.tilemap.len) |i| {
        allocator.free(level.tilemap[i]);
    }

    allocator.free(level.tilemap);

    for (0..256) |i| {
        c.SDL_FreeSurface(level.c_level.tile[i].tiledata);
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
        return level.tile[parent_level.tilemap[@intCast(tileY)][@intCast(tileX)]].horizflag;
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
        return level.tile[parent_level.tilemap[@intCast(tileY)][@intCast(tileX)]].floorflag;
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
        return level.tile[parent_level.tilemap[@intCast(tileY)][@intCast(tileX)]].ceilflag;
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
    parent_level.tilemap[tileY][tileX] = tile;
}
