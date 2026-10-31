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

const common = @import("common.zig");
const globals = @import("globals.zig");
const lvl = @import("level.zig");
const events = @import("events.zig");
const plr = @import("player.zig");
const sprites = @import("sprites.zig");

const ORIG_OBJECT_COUNT = 71;

/// Does this tile stop a falling object?
fn stopsFallingObject(floor: lvl.FloorType, wall: lvl.WallType) bool {
    return floor != .Ladder and (floor != .NoFloor or wall.isSolid());
}

pub fn move_objects(level: *lvl.Level) void {
    if (globals.GRAVITY_FLAG == 0) return;
    for (&level.object) |*object| {
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
        } else if ((object.sprite.number == globals.FIRST_OBJET + 19 or object.sprite.number == globals.FIRST_OBJET + 20) and
            (globals.IMAGE_COUNTER & 3) == 0 and
            object.sprite.speed_y > 0 and
            globals.TAPISWAIT_FLAG != 2)
        {
            // A falling carpet unfolds and gets ready to fly
            if (object.sprite.number == globals.FIRST_OBJET + 19) {
                object.sprite.speed_x >>= 1;
                updateobjectsprite(level, object, globals.FIRST_OBJET + 20, false);
            } else {
                object.sprite.speed_x = 0;
                updateobjectsprite(level, object, globals.FIRST_OBJET + 21, false);
            }
            globals.TAPISWAIT_FLAG = 1;
            globals.TAPISFLY_FLAG = 200;
        }

        // Does it move in X?
        if (object.sprite.speed_x != 0) {
            // Test for horizontal collision
            var tileX = object.sprite.x >> 4;
            var tileY = object.sprite.y >> 4;
            if (object.sprite.y & 0x000F == 0) {
                tileY -= 1;
            }
            if (level.getTileWall(tileX, tileY).isSolid()) {
                object.sprite.speed_x = -object.sprite.speed_x;
                object.sprite.x += object.sprite.speed_x >> 4;
            } else if (((object.sprite.speed_x >> 4) + object.sprite.x) >> 4 != tileX) {
                // Moving into the next tile
                if (object.sprite.speed_x < 0) {
                    tileX -= 1;
                } else {
                    tileX += 1;
                }
                if (tileX < level.width and tileX >= 0) {
                    if (level.getTileWall(tileX, tileY).isSolid()) {
                        object.sprite.speed_x = -object.sprite.speed_x;
                        object.sprite.x += object.sprite.speed_x >> 4;
                    }
                }
            }
            globals.GRAVITY_FLAG = 4;
            object.sprite.x += object.sprite.speed_x >> 4;

            // Friction, less of it in the air
            var reduction: i16 = if (@abs(object.sprite.speed_y) >= 16) 1 else 3;
            if (object.sprite.speed_x < 0) {
                reduction = -reduction;
            }
            object.sprite.speed_x -= reduction;
            if (@abs(object.sprite.speed_x) < 16) {
                object.sprite.speed_x = 0;
            }
        }

        if (object.sprite.speed_y < 0) {
            // Moving up: test for ceilings
            const tileX = object.sprite.x >> 4;
            var tileY = (object.sprite.y >> 4) - (@as(i16, object.sprite.spritedata.?.collheight) >> 4) - 1;
            if (level.getTileCeiling(tileX, tileY) != .NoCeiling) {
                hitCeiling(object);
                continue;
            }
            // NOTE: this compares a pixel position with a tile position, so it is (almost) always true.
            // It was probably meant to check if the object moves into the next tile up.
            if ((object.sprite.speed_y >> 4) + object.sprite.y != object.sprite.y >> 4) {
                tileY -= 1;
                if (level.getTileCeiling(tileX, tileY) != .NoCeiling) {
                    hitCeiling(object);
                    continue;
                }
            }
        } else if (object.sprite.droptobottom or (object.objectdata.droptobottom and object.sprite.speed_y >= 10 * 16)) {
            // Falls through everything, gone once off the screen
            if (!object.sprite.visible) {
                object.sprite.enabled = false;
                continue;
            }
        } else {
            // Falling or resting: test for floors and objects below
            const tileX = object.sprite.x >> 4;
            var tileY = object.sprite.y >> 4;
            var hflag = level.getTileWall(tileX, tileY);
            var fflag = level.getTileFloor(tileX, tileY);
            if (object.sprite.y <= 6 or object.sprite.y >= level.height << 4) {
                fflag = .NoFloor;
                if (object.sprite.y >= (level.height << 4) + 64) {
                    object.sprite.enabled = false;
                    continue;
                }
            }
            if (fflag == .Fire) {
                object.sprite.enabled = false;
                continue;
            }
            if (fflag == .Water) {
                if (object.sprite.number == globals.FIRST_OBJET + 9) {
                    // floats
                    object.sprite.speed_y = 0;
                } else {
                    object.sprite.enabled = false;
                }
                continue;
            }
            if (stopsFallingObject(fflag, hflag) and !insideOneWayPlatform(level, object, fflag, tileX, tileY)) {
                object.sprite.speed_y = 0;
                if (!object.objectdata.bounce) {
                    object.sprite.y = common.alignToTile(object.sprite.y);
                }
                continue;
            }

            // Test the tiles the object falls through in this frame
            var off_object: *lvl.Object = undefined;
            var obj_vs_sprite = false;
            const tile_count = ((object.sprite.y + (object.sprite.speed_y >> 4)) >> 4) - (object.sprite.y >> 4);
            if (tile_count != 0) {
                obj_vs_sprite = SPRITES_VS_SPRITES(level, &object.sprite, object.sprite.spritedata.?, &off_object);
            }
            var j: i16 = 0;
            while (j < tile_count) : (j += 1) {
                if (obj_vs_sprite) {
                    break;
                }
                tileY += 1;
                hflag = level.getTileWall(tileX, tileY);
                fflag = level.getTileFloor(tileX, tileY);
                if (fflag == .Fire) {
                    object.sprite.enabled = false;
                    break;
                }
                if (stopsFallingObject(fflag, hflag)) {
                    landOnTile(level, object);
                    break;
                }
            }
            if (!obj_vs_sprite and (j < tile_count or !object.sprite.enabled)) {
                continue;
            }

            if (!obj_vs_sprite) {
                obj_vs_sprite = SPRITES_VS_SPRITES(level, &object.sprite, object.sprite.spritedata.?, &off_object);
            }
            if (obj_vs_sprite) {
                // Landed on another object
                object.momentum = 0;
                const on_top_y = off_object.sprite.y - off_object.sprite.spritedata.?.collheight;
                if (off_object.objectdata.bounce) {
                    off_object.sprite.UNDER |= 1;
                    off_object.sprite.ONTOP = &object.sprite;
                    if (object.sprite.speed_y > 64) {
                        // Bounce off each other
                        off_object.sprite.speed_y = ((-object.sprite.speed_y) >> 1) + 32;
                        object.sprite.speed_y = ((-object.sprite.speed_y) >> 1) + 16;
                        off_object.sprite.speed_x = object.sprite.speed_x >> 1;
                    } else {
                        object.sprite.speed_y = 0;
                        object.sprite.y = on_top_y;
                        continue;
                    }
                } else if (object.objectdata.bounce) {
                    object.sprite.y = on_top_y;
                    if (object.sprite.speed_y >= 16 or object.sprite.speed_y < 0) {
                        globals.GRAVITY_FLAG = 4;
                        bounceUp(object);
                    } else {
                        object.sprite.speed_y = 0;
                    }
                    continue;
                } else {
                    object.sprite.y = on_top_y;
                    object.sprite.speed_y = 0;
                }
            }
        }

        // Gravity
        var max_speed: u8 = 15;
        if (object.sprite.number < globals.FIRST_NMI) {
            max_speed = object.objectdata.maxspeedY;
        }
        const speed = object.sprite.speed_y >> 4;
        if (speed != 0) {
            globals.GRAVITY_FLAG = 4;
        }
        object.sprite.y += speed;
        if (speed < max_speed) {
            object.sprite.speed_y += 16;
            if (object.sprite.speed_y > 0) {
                object.momentum +%= 1;
            }
        }
        shock(level, object);
    }
}

fn hitCeiling(object: *lvl.Object) void {
    object.sprite.speed_y = 0;
    if (!object.objectdata.bounce) {
        object.sprite.y = common.alignToTile(object.sprite.y);
    }
}

/// Bounce back up, losing some speed. Comes to rest when too slow.
fn bounceUp(object: *lvl.Object) void {
    object.sprite.speed_y = -object.sprite.speed_y + 16 * 3;
    if (object.sprite.speed_y > 0) {
        object.sprite.speed_y = 0;
    }
}

/// The falling object reached a floor in the next tile
fn landOnTile(level: *lvl.Level, object: *lvl.Object) void {
    object.sprite.y = common.alignToTile(object.sprite.y) + 16;
    if (object.objectdata.bounce) {
        globals.GRAVITY_FLAG = 4;
        object.momentum = 0;
        bounceUp(object);
        return;
    }
    object.sprite.speed_y = 0;
    if (object.sprite.number >= globals.FIRST_OBJET + 19 and object.sprite.number <= globals.FIRST_OBJET + 22) {
        // The carpet folds back up
        updateobjectsprite(level, object, globals.FIRST_OBJET + 19, false);
        globals.TAPISWAIT_FLAG = 0;
    }
    if (object.sprite.visible and !level.player.sprite2.enabled) {
        // Puff of smoke
        globals.FUME_FLAG = 32;
        level.player.sprite2.y = object.sprite.y;
        level.player.sprite2.x = object.sprite.x;
        sprites.updatesprite(level, &level.player.sprite2, globals.FIRST_OBJET + 16, true);
    }
}

/// A falling object (with enough momentum) hits the player on the head
fn shock(level: *lvl.Level, object: *lvl.Object) void {
    const player = &level.player;
    if (object.momentum < 10) return;
    if (player.sprite.speed_y >= 12 * 16) return;
    if (@abs(player.sprite.y - object.sprite.y) >= 32) return;
    if (@abs(player.sprite.x - object.sprite.x) >= 32) return;
    if (object.sprite.x > player.sprite.x) {
        if (object.sprite.x > player.sprite.x + 24) return;
    } else {
        if (object.sprite.x + object.sprite.spritedata.?.collwidth < player.sprite.x) return;
    }
    if (object.sprite.y < player.sprite.y) {
        if (object.sprite.y <= player.sprite.y - 32) return;
    } else {
        if (object.sprite.y - object.sprite.spritedata.?.collheight + 1 >= player.sprite.y) return;
    }
    events.triggerEvent(.PlayerHeadImpact);
    globals.CHOC_FLAG = 24;
    if (object.sprite.killing) {
        if (!globals.GODMODE) {
            plr.DEC_ENERGY(level);
        }
        object.sprite.killing = false;
    }
}

/// Platforms without a ceiling only hold up what lands on top of them.
///
/// Objects that end up inside one, by being thrown up through it or into it from the side, would otherwise rest inside
/// the platform: bouncing objects (like the ball) aren't snapped on top, so they slide along inside it and eventually
/// get stuck for good. Let them fall through instead, like they would through any other one-way platform.
fn insideOneWayPlatform(level: *lvl.Level, object: *const lvl.Object, floor: lvl.FloorType, tileX: i16, tileY: i16) bool {
    if (floor == .NoFloor) {
        return false;
    }
    if (object.sprite.y & 0x000F == 0) {
        // Resting on the top edge
        return false;
    }
    return level.getTileCeiling(tileX, tileY) == .NoCeiling;
}

// check if there is an object below that can support the input object
pub fn SPRITES_VS_SPRITES(level: *lvl.Level, sprite1: *lvl.Sprite, sprite1data: *const lvl.SpriteData, object2_out: **lvl.Object) bool {
    return SPRITES_VS_SPRITES_EXCEPT(level, sprite1, sprite1data, null, object2_out);
}

/// Same as SPRITES_VS_SPRITES, but never reports `ignored`
pub fn SPRITES_VS_SPRITES_EXCEPT(level: *lvl.Level, sprite1: *lvl.Sprite, sprite1data: *const lvl.SpriteData, ignored: ?*const lvl.Object, object2_out: **lvl.Object) bool {
    for (&level.object) |*object2| {
        if (ignored == object2)
            continue;
        if (spriteStandsOn(sprite1, sprite1data, object2)) {
            object2_out.* = object2;
            return true;
        }
    }
    return false;
}

/// Is the bottom of `sprite1` in the top part of `object2`, so it would stand on it?
///
/// sprite1data is equal to sprite1's data, except when sprite1 is the player, then it is level.spritedata[0] (first player sprite)
pub fn spriteStandsOn(sprite1: *const lvl.Sprite, sprite1data: *const lvl.SpriteData, object2: *const lvl.Object) bool {
    const sprite2 = &object2.sprite;
    if (sprite2 == sprite1 or !sprite2.enabled or !object2.objectdata.*.support)
        return false;
    const obj1left = sprite1.x - (sprite1data.width >> 1);
    if (@abs(sprite2.x - obj1left) > 64)
        return false;
    if (@abs(sprite2.y - sprite1.y) > 70)
        return false;
    const obj2left = sprite2.x - (sprite2.spritedata.?.collwidth >> 1);
    if (obj2left > obj1left) {
        if (obj1left + sprite1data.collwidth <= obj2left)
            return false;
    } else {
        if (obj2left + sprite2.spritedata.?.collwidth <= obj1left)
            return false;
    }
    const collheight: i16 = sprite2.spritedata.?.collheight;
    return (sprite2.y - (collheight >> 3) >= sprite1.y) and (sprite2.y - collheight <= sprite1.y);
}

pub fn updateobjectsprite(level: *lvl.Level, obj: *lvl.Object, number: i16, clearflags: bool) void {
    var index = number - globals.FIRST_OBJET;
    sprites.updatesprite(level, &obj.sprite, number, clearflags);
    if (index < 0 or index >= ORIG_OBJECT_COUNT) {
        index = 0;
    }
    obj.*.objectdata = @constCast(@ptrCast(&level.objectdata[@intCast(index)]));
}
