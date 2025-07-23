//
// Copyright (C) 2008 - 2011 The OpenTitus team
//
// Authors:
// Eirik Stople
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

// objects.zig
// Handle objects

// TODO: side-by-side cleanup with objects.c

const globals = @import("globals.zig");
const lvl = @import("level.zig");
const events = @import("events.zig");
const plr = @import("player.zig");
const sprites = @import("sprites.zig");

const ORIG_OBJECT_COUNT = 71;

pub fn move_objects(level: *lvl.Level) void {
    if (@as(c_int, @bitCast(@as(c_uint, globals.GRAVITY_FLAG))) == @as(c_int, 0)) return;
    var off_object: *lvl.Object = undefined;
    _ = &off_object;
    var hflag: lvl.WallType = undefined;
    var fflag: lvl.FloorType = undefined;
    var max_speed: u8 = undefined;
    _ = &max_speed;
    var j: i16 = undefined;
    _ = &j;
    var obj_vs_sprite: bool = undefined;
    _ = &obj_vs_sprite;
    for (&level.object) |*object| {
        obj_vs_sprite = false;

        // Skip unused objects
        if (!object.sprite.enabled)
            continue;

        // Left edge of level
        if (object.sprite.x <= 8) {
            object.sprite.speed_x = 2 * 16;
            object.sprite.speed_y = 0;
        }

        // Right edge of level
        if (object.sprite.x >= level.width * 16 - 8) {
            object.sprite.speed_x = -2 * 16;
            object.sprite.speed_y = 0;
        }

        // Handle carpet
        if (object.sprite.number == globals.FIRST_OBJET + 21 or object.sprite.number == globals.FIRST_OBJET + 22) { // Flying
            globals.GRAVITY_FLAG = 4; // Keep doing gravity

            // (Adjust height after player)
            if (globals.TAPISWAIT_FLAG != 0) { // Flying ready
                object.momentum = 0;
                if (object.sprite.y == level.player.sprite.y - 8) {
                    object.sprite.speed_y = 0;
                } else if (object.sprite.y < level.player.sprite.y - 8) {
                    object.sprite.speed_y = 16;
                } else {
                    object.sprite.speed_y = -16;
                }
            }

            if (globals.TAPISFLY_FLAG == 0) { // Time's up! Stop flying
                updateobjectsprite(level, object, globals.FIRST_OBJET + 19, true);
                object.sprite.speed_x = 0;
                globals.TAPISWAIT_FLAG = 2;
            }
        } else if (((((@as(c_int, @bitCast(@as(c_int, object.sprite.number))) == (@as(c_int, 30) + @as(c_int, 19))) or (@as(c_int, @bitCast(@as(c_int, object.sprite.number))) == (@as(c_int, 30) + @as(c_int, 20)))) and ((@as(c_int, @bitCast(@as(c_uint, globals.IMAGE_COUNTER))) & @as(c_int, 3)) == @as(c_int, 0))) and (@as(c_int, @bitCast(@as(c_int, object.sprite.speed_y))) > @as(c_int, 0))) and (@as(c_int, @bitCast(@as(c_uint, globals.TAPISWAIT_FLAG))) != @as(c_int, 2))) {
            if (@as(c_int, @bitCast(@as(c_int, object.sprite.number))) == (@as(c_int, 30) + @as(c_int, 19))) {
                object.sprite.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, object.sprite.speed_x))) >> @intCast(1)))));
                updateobjectsprite(level, object, @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 30) + @as(c_int, 20))))), false);
            } else {
                object.sprite.speed_x = 0;
                updateobjectsprite(level, object, @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 30) + @as(c_int, 21))))), false);
            }
            globals.TAPISWAIT_FLAG = 1;
            globals.TAPISFLY_FLAG = 200;
        }

        // Does it move in X?
        if (@as(c_int, @bitCast(@as(c_int, object.sprite.speed_x))) != @as(c_int, 0)) {

            // Test for horizontal collision

            var tileX = object.sprite.x >> 4;
            var tileY = object.sprite.y >> 4;
            if (object.sprite.y & 0x000F == 0) {
                tileY -= 1;
            }
            hflag = level.getTileWall(tileX, tileY);
            if (hflag == .Wall or hflag == .Deadly or hflag == .Padlock) {
                object.sprite.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_int, object.sprite.speed_x)))))));
                object.sprite.x += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, object.sprite.speed_x))) >> @intCast(4)))));
            } else if ((((@as(c_int, @bitCast(@as(c_int, object.sprite.speed_x))) >> @intCast(4)) + @as(c_int, @bitCast(@as(c_int, object.sprite.x)))) >> @intCast(4)) != @as(c_int, @bitCast(@as(c_int, tileX)))) {
                if (@as(c_int, @bitCast(@as(c_int, object.sprite.speed_x))) < @as(c_int, 0)) {
                    tileX -= 1;
                } else {
                    tileX += 1;
                }
                if (tileX < level.width and tileX >= 0) {
                    hflag = level.getTileWall(tileX, tileY);
                    if (hflag == .Wall or hflag == .Deadly or hflag == .Padlock) {
                        object.sprite.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_int, object.sprite.speed_x)))))));
                        object.sprite.x += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, object.sprite.speed_x))) >> @intCast(4)))));
                    }
                }
            }
            globals.GRAVITY_FLAG = 4;
            object.sprite.x += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, object.sprite.speed_x))) >> @intCast(4)))));
            var reduction: i8 = 0;
            if (@abs(@as(c_int, @bitCast(@as(c_int, object.sprite.speed_y)))) >= @as(c_int, 16)) {
                reduction = 1;
            } else {
                reduction = 3;
            }
            if (@as(c_int, @bitCast(@as(c_int, object.sprite.speed_x))) < @as(c_int, 0)) {
                reduction = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_int, reduction)))))));
            }
            object.sprite.speed_x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, reduction)))))));
            if (@abs(@as(c_int, @bitCast(@as(c_int, object.sprite.speed_x)))) < @as(c_int, 16)) {
                object.sprite.speed_x = 0;
            }
        }
        if (@as(c_int, @bitCast(@as(c_int, object.sprite.speed_y))) < @as(c_int, 0)) {
            const tileX = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, object.sprite.x))) >> @intCast(4)))));
            var tileY = @as(i16, @bitCast(@as(c_short, @truncate(((@as(c_int, @bitCast(@as(c_int, object.sprite.y))) >> @intCast(4)) - (@as(c_int, @bitCast(@as(c_uint, object.sprite.spritedata.?.collheight))) >> @intCast(4))) - @as(c_int, 1)))));
            if (level.getTileCeiling(tileX, tileY) != .NoCeiling) {
                object.sprite.speed_y = 0;
                if (!object.objectdata.*.bounce) {
                    object.sprite.y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, object.sprite.y))) & @as(c_int, 65520)))));
                }
                continue;
            } else {
                if (((@as(c_int, @bitCast(@as(c_int, object.sprite.speed_y))) >> @intCast(4)) + @as(c_int, @bitCast(@as(c_int, object.sprite.y)))) != (@as(c_int, @bitCast(@as(c_int, object.sprite.y))) >> @intCast(4))) {
                    tileY -= 1;
                    if (level.getTileCeiling(tileX, tileY) != .NoCeiling) {
                        object.sprite.speed_y = 0;
                        if (!object.objectdata.*.bounce) {
                            object.sprite.y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, object.sprite.y))) & @as(c_int, 65520)))));
                        }
                        continue;
                    }
                }
            }
        } else if ((@as(c_int, @intFromBool(object.sprite.droptobottom)) != 0) or ((@as(c_int, @intFromBool(object.objectdata.*.droptobottom)) != 0) and (@as(c_int, @bitCast(@as(c_int, object.sprite.speed_y))) >= (@as(c_int, 10) * @as(c_int, 16))))) {
            if (!object.sprite.visible) {
                object.sprite.enabled = false;
                continue;
            }
        } else {
            const tileX = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, object.sprite.x))) >> @intCast(4)))));
            var tileY = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, object.sprite.y))) >> @intCast(4)))));
            hflag = level.getTileWall(tileX, tileY);
            fflag = level.getTileFloor(tileX, tileY);
            if (object.sprite.y <= 6 or object.sprite.y >= level.height << 4) {
                fflag = .NoFloor;
                if (object.sprite.y >= ((level.*.height << 4) + 64)) {
                    object.sprite.enabled = false;
                    continue;
                }
            }
            if (fflag == .Fire) {
                object.sprite.enabled = false;
                continue;
            }
            if (fflag == .Water) {
                if (@as(c_int, @bitCast(@as(c_int, object.sprite.number))) == (@as(c_int, 30) + @as(c_int, 9))) {
                    object.sprite.speed_y = 0;
                    continue;
                } else {
                    object.sprite.enabled = false;
                    continue;
                }
            }
            if ((fflag != .Ladder) and ((fflag != .NoFloor) or (hflag == .Wall) or (hflag == .Deadly) or (hflag == .Padlock))) {
                object.sprite.speed_y = 0;
                if (!object.objectdata.*.bounce) {
                    object.sprite.y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, object.sprite.y))) & @as(c_int, 0xFFF0)))));
                }
                continue;
            }
            const tile_count = @as(i8, @bitCast(@as(i8, @truncate(((@as(c_int, @bitCast(@as(c_int, object.sprite.y))) + (@as(c_int, @bitCast(@as(c_int, object.sprite.speed_y))) >> @intCast(4))) >> @intCast(4)) - (@as(c_int, @bitCast(@as(c_int, object.sprite.y))) >> @intCast(4))))));
            if (@as(c_int, @bitCast(@as(c_int, tile_count))) != @as(c_int, 0)) {
                obj_vs_sprite = SPRITES_VS_SPRITES(level, &object.sprite, object.sprite.spritedata.?, &off_object);
            }
            {
                j = 0;
                while (@as(c_int, @bitCast(@as(c_int, j))) < @as(c_int, @bitCast(@as(c_int, tile_count)))) : (j += 1) {
                    if (obj_vs_sprite) {
                        break;
                    }
                    tileY += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 1)))));
                    hflag = level.getTileWall(tileX, tileY);
                    fflag = level.getTileFloor(tileX, tileY);
                    if (fflag == .Fire) {
                        object.sprite.enabled = false;
                        break;
                    }
                    if ((fflag != .Ladder) and ((fflag != .NoFloor) or (hflag == .Wall) or (hflag == .Deadly) or (hflag == .Padlock))) {
                        if (!object.objectdata.*.bounce) {
                            object.sprite.speed_y = 0;
                            object.sprite.y = @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_int, object.sprite.y))) & @as(c_int, 65520)) + @as(c_int, 16)))));
                            if ((@as(c_int, @bitCast(@as(c_int, object.sprite.number))) >= (@as(c_int, 30) + @as(c_int, 19))) and (@as(c_int, @bitCast(@as(c_int, object.sprite.number))) <= (@as(c_int, 30) + @as(c_int, 22)))) {
                                updateobjectsprite(level, object, @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 30) + @as(c_int, 19))))), false);
                                globals.TAPISWAIT_FLAG = 0;
                            }
                            if ((@as(c_int, @intFromBool(object.sprite.visible)) != 0) and !level.*.player.sprite2.enabled) {
                                globals.FUME_FLAG = 32;
                                level.*.player.sprite2.y = object.sprite.y;
                                level.*.player.sprite2.x = object.sprite.x;
                                sprites.updatesprite(level, &level.*.player.sprite2, @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 30) + @as(c_int, 16))))), true);
                            }
                        } else {
                            object.sprite.y = @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_int, object.sprite.y))) & @as(c_int, 65520)) + @as(c_int, 16)))));
                            globals.GRAVITY_FLAG = 4;
                            object.momentum = 0;
                            object.sprite.speed_y = @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, 0) - @as(c_int, @bitCast(@as(c_int, object.sprite.speed_y)))) + (@as(c_int, 16) * @as(c_int, 3))))));
                            if (@as(c_int, @bitCast(@as(c_int, object.sprite.speed_y))) > @as(c_int, 0)) {
                                object.sprite.speed_y = 0;
                            }
                        }
                        break;
                    }
                }
            }
            if (!obj_vs_sprite and ((@as(c_int, @bitCast(@as(c_int, j))) < @as(c_int, @bitCast(@as(c_int, tile_count)))) or !object.sprite.enabled)) {
                continue;
            }
            if (!obj_vs_sprite) {
                obj_vs_sprite = SPRITES_VS_SPRITES(level, &object.sprite, object.sprite.spritedata.?, &off_object);
            }
            if (obj_vs_sprite) {
                object.momentum = 0;
                if (off_object.*.objectdata.*.bounce) {
                    off_object.*.sprite.UNDER |= @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, 1)))));
                    off_object.*.sprite.ONTOP = &object.sprite;
                    if (@as(c_int, @bitCast(@as(c_int, object.sprite.speed_y))) > @as(c_int, 64)) {
                        off_object.*.sprite.speed_y = @as(i16, @bitCast(@as(c_short, @truncate(((@as(c_int, 0) - @as(c_int, @bitCast(@as(c_int, object.sprite.speed_y)))) >> @intCast(1)) + @as(c_int, 32)))));
                        object.sprite.speed_y = @as(i16, @bitCast(@as(c_short, @truncate(((@as(c_int, 0) - @as(c_int, @bitCast(@as(c_int, object.sprite.speed_y)))) >> @intCast(1)) + @as(c_int, 16)))));
                        off_object.*.sprite.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, object.sprite.speed_x))) >> @intCast(1)))));
                    } else {
                        object.sprite.speed_y = 0;
                        object.sprite.y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, off_object.*.sprite.y))) - @as(c_int, @bitCast(@as(c_uint, off_object.*.sprite.spritedata.?.collheight)))))));
                        continue;
                    }
                } else if (object.objectdata.*.bounce) {
                    object.sprite.y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, off_object.*.sprite.y))) - @as(c_int, @bitCast(@as(c_uint, off_object.*.sprite.spritedata.?.collheight)))))));
                    if ((@as(c_int, @bitCast(@as(c_int, object.sprite.speed_y))) >= @as(c_int, 16)) or (@as(c_int, @bitCast(@as(c_int, object.sprite.speed_y))) < @as(c_int, 0))) {
                        globals.GRAVITY_FLAG = 4;
                        object.sprite.speed_y = @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, 0) - @as(c_int, @bitCast(@as(c_int, object.sprite.speed_y)))) + (@as(c_int, 16) * @as(c_int, 3))))));
                        if (@as(c_int, @bitCast(@as(c_int, object.sprite.speed_y))) > @as(c_int, 0)) {
                            object.sprite.speed_y = 0;
                        }
                    } else {
                        object.sprite.speed_y = 0;
                    }
                    continue;
                } else {
                    object.sprite.y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, off_object.*.sprite.y))) - @as(c_int, @bitCast(@as(c_uint, off_object.*.sprite.spritedata.?.collheight)))))));
                    object.sprite.speed_y = 0;
                }
            }
        }
        max_speed = 15;
        if (@as(c_int, @bitCast(@as(c_int, object.sprite.number))) < @as(c_int, 101)) {
            max_speed = object.objectdata.*.maxspeedY;
        }
        const speed = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, object.sprite.speed_y))) >> @intCast(4)))));
        if (@as(c_int, @bitCast(@as(c_int, speed))) != @as(c_int, 0)) {
            globals.GRAVITY_FLAG = 4;
        }
        object.sprite.y += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, speed)))))));
        if (@as(c_int, @bitCast(@as(c_int, speed))) < @as(c_int, @bitCast(@as(c_uint, max_speed)))) {
            object.sprite.speed_y += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 16)))));
            if (@as(c_int, @bitCast(@as(c_int, object.sprite.speed_y))) > @as(c_int, 0)) {
                object.momentum +%= 1;
            }
        }
        shock(level, object);
    }
}

fn shock(level: *lvl.Level, object: *lvl.Object) void {
    const player = &level.player;
    if (@as(c_int, @bitCast(@as(c_uint, object.momentum))) < @as(c_int, 10)) return;
    if (@as(c_int, @bitCast(@as(c_int, player.sprite.speed_y))) >= (@as(c_int, 12) * @as(c_int, 16))) return;
    if (@abs(@as(c_int, @bitCast(@as(c_int, player.sprite.y))) - @as(c_int, @bitCast(@as(c_int, object.sprite.y)))) >= @as(c_int, 32)) {
        return;
    }
    if (@abs(@as(c_int, @bitCast(@as(c_int, player.sprite.x))) - @as(c_int, @bitCast(@as(c_int, object.sprite.x)))) >= @as(c_int, 32)) {
        return;
    }
    if (@as(c_int, @bitCast(@as(c_int, object.sprite.x))) > @as(c_int, @bitCast(@as(c_int, player.sprite.x)))) {
        if (@as(c_int, @bitCast(@as(c_int, object.sprite.x))) > (@as(c_int, @bitCast(@as(c_int, player.sprite.x))) + @as(c_int, 24))) return;
    } else {
        if ((@as(c_int, @bitCast(@as(c_int, object.sprite.x))) + @as(c_int, @bitCast(@as(c_uint, object.sprite.spritedata.?.collwidth)))) < @as(c_int, @bitCast(@as(c_int, player.*.sprite.x)))) return;
    }
    if (@as(c_int, @bitCast(@as(c_int, object.sprite.y))) < @as(c_int, @bitCast(@as(c_int, player.*.sprite.y)))) {
        if (@as(c_int, @bitCast(@as(c_int, object.sprite.y))) <= (@as(c_int, @bitCast(@as(c_int, player.sprite.y))) - @as(c_int, 32))) return;
    } else {
        if (((@as(c_int, @bitCast(@as(c_int, object.sprite.y))) - @as(c_int, @bitCast(@as(c_uint, object.sprite.spritedata.?.collheight)))) + @as(c_int, 1)) >= @as(c_int, @bitCast(@as(c_int, player.sprite.y)))) return;
    }
    events.triggerEvent(.PlayerHeadImpact);
    globals.CHOC_FLAG = 24;
    if (object.*.sprite.killing) {
        if (!globals.GODMODE) {
            plr.DEC_ENERGY(level);
        }
        object.*.sprite.killing = false;
    }
}

// check if there is an object below that can support the input object
pub fn SPRITES_VS_SPRITES(level: *lvl.Level, sprite1: *lvl.Sprite, sprite1data: *const lvl.SpriteData, object2_out: **lvl.Object) bool {
    var i: u8 = undefined;
    _ = &i;
    // sprite1ref is equal to sprite1, except when sprite1 is the player, then
    // sprite1ref is level->spritedata[0] (first player sprite)
    const obj1left = sprite1.x - (sprite1data.width >> 1);
    i = 0;
    for (&level.object) |*object2| {
        const sprite2 = &object2.sprite;
        if (sprite2 == sprite1 or !sprite2.enabled or !object2.objectdata.*.support)
            continue;
        if (@abs(@as(c_int, @bitCast(@as(c_int, sprite2.x))) - @as(c_int, @bitCast(@as(c_int, obj1left)))) > @as(c_int, 64))
            continue;
        if (@abs(@as(c_int, @bitCast(@as(c_int, sprite2.y))) - @as(c_int, @bitCast(@as(c_int, sprite1.y)))) > @as(c_int, 70))
            continue;
        const obj2left = sprite2.x - (sprite2.spritedata.?.collwidth >> 1);
        if (@as(c_int, @bitCast(@as(c_int, obj2left))) > @as(c_int, @bitCast(@as(c_int, obj1left)))) {
            if ((@as(c_int, @bitCast(@as(c_int, obj1left))) + @as(c_int, @bitCast(@as(c_uint, sprite1data.*.collwidth)))) <= @as(c_int, @bitCast(@as(c_int, obj2left))))
                continue;
        } else {
            if ((@as(c_int, @bitCast(@as(c_int, obj2left))) + @as(c_int, @bitCast(@as(c_uint, sprite2.spritedata.?.collwidth)))) <= @as(c_int, @bitCast(@as(c_int, obj1left))))
                continue;
        }
        if ((@as(c_int, @bitCast(@as(c_int, sprite2.y))) - (@as(c_int, @bitCast(@as(c_uint, sprite2.spritedata.?.collheight))) >> @intCast(3))) >= @as(c_int, @bitCast(@as(c_int, sprite1.*.y)))) {
            if ((@as(c_int, @bitCast(@as(c_int, sprite2.y))) - @as(c_int, @bitCast(@as(c_uint, sprite2.spritedata.?.collheight)))) <= @as(c_int, @bitCast(@as(c_int, sprite1.y)))) {
                object2_out.* = object2;
                return true;
            }
        }
    }
    return false;
}

pub fn updateobjectsprite(level: *lvl.Level, obj: *lvl.Object, number: i16, clearflags: bool) void {
    var index = number - globals.FIRST_OBJET;
    sprites.updatesprite(level, &obj.sprite, number, clearflags);
    if (index < 0 or index >= ORIG_OBJECT_COUNT) {
        index = 0;
    }
    obj.*.objectdata = @constCast(@ptrCast(&level.objectdata[@intCast(index)]));
}
