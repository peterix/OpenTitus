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
const audio = @import("audio/audio.zig");
const plr = @import("player.zig");
const sprites = @import("sprites.zig");

pub const ORIG_OBJECT_COUNT = @as(c_int, 71);

pub fn move_objects(level: *lvl.TITUS_level) void {
    if (@as(c_int, @bitCast(@as(c_uint, globals.GRAVITY_FLAG))) == @as(c_int, 0)) return;
    var off_object: *lvl.TITUS_object = undefined;
    _ = &off_object;
    var hflag: lvl.HFlag = undefined;
    var fflag: lvl.FFlag = undefined;
    var i: u8 = undefined;
    _ = &i;
    var max_speed: u8 = undefined;
    _ = &max_speed;
    var tileX: i16 = undefined;
    _ = &tileX;
    var tileY: i16 = undefined;
    _ = &tileY;
    var j: i16 = undefined;
    _ = &j;
    var obj_vs_sprite: bool = undefined;
    _ = &obj_vs_sprite;
    var reduction: i8 = undefined;
    _ = &reduction;
    var tile_count: i8 = undefined;
    _ = &tile_count;
    {
        i = 0;
        while (@as(c_int, @bitCast(@as(c_uint, i))) < @as(c_int, 40)) : (i +%= 1) {
            obj_vs_sprite = @as(c_int, 0) != 0;
            if (!level.*.object[i].sprite.enabled) continue;
            if (@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.x))) <= @as(c_int, 8)) {
                level.*.object[i].sprite.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 2) * @as(c_int, 16)))));
                level.*.object[i].sprite.speed_y = 0;
            }
            if (@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.x))) >= ((@as(c_int, @bitCast(@as(c_int, level.*.width))) * @as(c_int, 16)) - @as(c_int, 8))) {
                level.*.object[i].sprite.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(-@as(c_int, 2) * @as(c_int, 16)))));
                level.*.object[i].sprite.speed_y = 0;
            }
            if ((@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.number))) == (@as(c_int, 30) + @as(c_int, 21))) or (@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.number))) == (@as(c_int, 30) + @as(c_int, 22)))) {
                globals.GRAVITY_FLAG = 4;
                if (@as(c_int, @bitCast(@as(c_uint, globals.TAPISWAIT_FLAG))) != @as(c_int, 0)) {
                    level.*.object[i].momentum = 0;
                    if (@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.y))) == (@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y))) - @as(c_int, 8))) {
                        level.*.object[i].sprite.speed_y = 0;
                    } else if (@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.y))) < (@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y))) - @as(c_int, 8))) {
                        level.*.object[i].sprite.speed_y = 16;
                    } else {
                        level.*.object[i].sprite.speed_y = @as(i16, @bitCast(@as(c_short, @truncate(-@as(c_int, 16)))));
                    }
                }
                if (@as(c_int, @bitCast(@as(c_uint, globals.TAPISFLY_FLAG))) == @as(c_int, 0)) {
                    updateobjectsprite(level, &level.*.object[i], @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 30) + @as(c_int, 19))))), @as(c_int, 1) != 0);
                    level.*.object[i].sprite.speed_x = 0;
                    globals.TAPISWAIT_FLAG = 2;
                }
            } else if (((((@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.number))) == (@as(c_int, 30) + @as(c_int, 19))) or (@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.number))) == (@as(c_int, 30) + @as(c_int, 20)))) and ((@as(c_int, @bitCast(@as(c_uint, globals.IMAGE_COUNTER))) & @as(c_int, 3)) == @as(c_int, 0))) and (@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.speed_y))) > @as(c_int, 0))) and (@as(c_int, @bitCast(@as(c_uint, globals.TAPISWAIT_FLAG))) != @as(c_int, 2))) {
                if (@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.number))) == (@as(c_int, 30) + @as(c_int, 19))) {
                    level.*.object[i].sprite.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.speed_x))) >> @intCast(1)))));
                    updateobjectsprite(level, &level.*.object[i], @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 30) + @as(c_int, 20))))), @as(c_int, 0) != 0);
                } else {
                    level.*.object[i].sprite.speed_x = 0;
                    updateobjectsprite(level, &level.*.object[i], @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 30) + @as(c_int, 21))))), @as(c_int, 0) != 0);
                }
                globals.TAPISWAIT_FLAG = 1;
                globals.TAPISFLY_FLAG = 200;
            }
            if (@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.speed_x))) != @as(c_int, 0)) {
                tileX = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.x))) >> @intCast(4)))));
                tileY = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.y))) >> @intCast(4)))));
                if ((@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.y))) & @as(c_int, 15)) == @as(c_int, 0)) {
                    tileY -= 1;
                }
                hflag = lvl.get_horizflag(level, tileY, tileX);
                if (hflag == .Wall or hflag == .Deadly or hflag == .Padlock) {
                    level.*.object[i].sprite.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.speed_x)))))));
                    level.*.object[i].sprite.x += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.speed_x))) >> @intCast(4)))));
                } else if ((((@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.speed_x))) >> @intCast(4)) + @as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.x)))) >> @intCast(4)) != @as(c_int, @bitCast(@as(c_int, tileX)))) {
                    if (@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.speed_x))) < @as(c_int, 0)) {
                        tileX -= 1;
                    } else {
                        tileX += 1;
                    }
                    if ((@as(c_int, @bitCast(@as(c_int, tileX))) < @as(c_int, @bitCast(@as(c_int, level.*.width)))) and (@as(c_int, @bitCast(@as(c_int, tileX))) >= @as(c_int, 0))) {
                        hflag = lvl.get_horizflag(level, tileY, tileX);
                        if (hflag == .Wall or hflag == .Deadly or hflag == .Padlock) {
                            level.*.object[i].sprite.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.speed_x)))))));
                            level.*.object[i].sprite.x += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.speed_x))) >> @intCast(4)))));
                        }
                    }
                }
                globals.GRAVITY_FLAG = 4;
                level.*.object[i].sprite.x += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.speed_x))) >> @intCast(4)))));
                if (@abs(@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.speed_y)))) >= @as(c_int, 16)) {
                    reduction = 1;
                } else {
                    reduction = 3;
                }
                if (@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.speed_x))) < @as(c_int, 0)) {
                    reduction = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_int, reduction)))))));
                }
                level.*.object[i].sprite.speed_x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, reduction)))))));
                if (@abs(@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.speed_x)))) < @as(c_int, 16)) {
                    level.*.object[i].sprite.speed_x = 0;
                }
            }
            if (@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.speed_y))) < @as(c_int, 0)) {
                tileX = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.x))) >> @intCast(4)))));
                tileY = @as(i16, @bitCast(@as(c_short, @truncate(((@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.y))) >> @intCast(4)) - (@as(c_int, @bitCast(@as(c_uint, level.*.object[i].sprite.spritedata.?.collheight))) >> @intCast(4))) - @as(c_int, 1)))));
                if (lvl.get_ceilflag(level, tileY, tileX) != .NoCeiling) {
                    level.*.object[i].sprite.speed_y = 0;
                    if (!level.*.object[i].objectdata.*.bounce) {
                        level.*.object[i].sprite.y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.y))) & @as(c_int, 65520)))));
                    }
                    continue;
                } else {
                    if (((@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.speed_y))) >> @intCast(4)) + @as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.y)))) != (@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.y))) >> @intCast(4))) {
                        tileY -= 1;
                        if (lvl.get_ceilflag(level, tileY, tileX) != .NoCeiling) {
                            level.*.object[i].sprite.speed_y = 0;
                            if (!level.*.object[i].objectdata.*.bounce) {
                                level.*.object[i].sprite.y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.y))) & @as(c_int, 65520)))));
                            }
                            continue;
                        }
                    }
                }
            } else if ((@as(c_int, @intFromBool(level.*.object[i].sprite.droptobottom)) != 0) or ((@as(c_int, @intFromBool(level.*.object[i].objectdata.*.droptobottom)) != 0) and (@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.speed_y))) >= (@as(c_int, 10) * @as(c_int, 16))))) {
                if (!level.*.object[i].sprite.visible) {
                    level.*.object[i].sprite.enabled = @as(c_int, 0) != 0;
                    continue;
                }
            } else {
                tileX = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.x))) >> @intCast(4)))));
                tileY = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.y))) >> @intCast(4)))));
                hflag = lvl.get_horizflag(level, tileY, tileX);
                fflag = lvl.get_floorflag(level, tileY, tileX);
                if ((@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.y))) <= @as(c_int, 6)) or (@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.y))) >= (@as(c_int, @bitCast(@as(c_int, level.*.height))) << @intCast(4)))) {
                    fflag = .NoFloor;
                    if (@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.y))) >= ((@as(c_int, @bitCast(@as(c_int, level.*.height))) << @intCast(4)) + @as(c_int, 64))) {
                        level.*.object[i].sprite.enabled = @as(c_int, 0) != 0;
                        continue;
                    }
                }
                if (fflag == .Fire) {
                    level.*.object[i].sprite.enabled = @as(c_int, 0) != 0;
                    continue;
                }
                if (fflag == .Water) {
                    if (@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.number))) == (@as(c_int, 30) + @as(c_int, 9))) {
                        level.*.object[i].sprite.speed_y = 0;
                        continue;
                    } else {
                        level.*.object[i].sprite.enabled = @as(c_int, 0) != 0;
                        continue;
                    }
                }
                if ((fflag != .Ladder) and ((fflag != .NoFloor) or (hflag == .Wall) or (hflag == .Deadly) or (hflag == .Padlock))) {
                    level.*.object[i].sprite.speed_y = 0;
                    if (!level.*.object[i].objectdata.*.bounce) {
                        level.*.object[i].sprite.y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.y))) & @as(c_int, 0xFFF0)))));
                    }
                    continue;
                }
                tile_count = @as(i8, @bitCast(@as(i8, @truncate(((@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.y))) + (@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.speed_y))) >> @intCast(4))) >> @intCast(4)) - (@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.y))) >> @intCast(4))))));
                if (@as(c_int, @bitCast(@as(c_int, tile_count))) != @as(c_int, 0)) {
                    obj_vs_sprite = SPRITES_VS_SPRITES(level, &level.*.object[i].sprite, level.*.object[i].sprite.spritedata.?, &off_object);
                }
                {
                    j = 0;
                    while (@as(c_int, @bitCast(@as(c_int, j))) < @as(c_int, @bitCast(@as(c_int, tile_count)))) : (j += 1) {
                        if (obj_vs_sprite) {
                            break;
                        }
                        tileY += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 1)))));
                        hflag = lvl.get_horizflag(level, tileY, tileX);
                        fflag = lvl.get_floorflag(level, tileY, tileX);
                        if (fflag == .Fire) {
                            level.*.object[i].sprite.enabled = @as(c_int, 0) != 0;
                            break;
                        }
                        if ((fflag != .Ladder) and ((fflag != .NoFloor) or (hflag == .Wall) or (hflag == .Deadly) or (hflag == .Padlock))) {
                            if (!level.*.object[i].objectdata.*.bounce) {
                                level.*.object[i].sprite.speed_y = 0;
                                level.*.object[i].sprite.y = @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.y))) & @as(c_int, 65520)) + @as(c_int, 16)))));
                                if ((@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.number))) >= (@as(c_int, 30) + @as(c_int, 19))) and (@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.number))) <= (@as(c_int, 30) + @as(c_int, 22)))) {
                                    updateobjectsprite(level, &level.*.object[i], @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 30) + @as(c_int, 19))))), @as(c_int, 0) != 0);
                                    globals.TAPISWAIT_FLAG = 0;
                                }
                                if ((@as(c_int, @intFromBool(level.*.object[i].sprite.visible)) != 0) and !level.*.player.sprite2.enabled) {
                                    globals.FUME_FLAG = 32;
                                    level.*.player.sprite2.y = level.*.object[i].sprite.y;
                                    level.*.player.sprite2.x = level.*.object[i].sprite.x;
                                    sprites.updatesprite(level, &level.*.player.sprite2, @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 30) + @as(c_int, 16))))), @as(c_int, 1) != 0);
                                }
                            } else {
                                level.*.object[i].sprite.y = @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.y))) & @as(c_int, 65520)) + @as(c_int, 16)))));
                                globals.GRAVITY_FLAG = 4;
                                level.*.object[i].momentum = 0;
                                level.*.object[i].sprite.speed_y = @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, 0) - @as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.speed_y)))) + (@as(c_int, 16) * @as(c_int, 3))))));
                                if (@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.speed_y))) > @as(c_int, 0)) {
                                    level.*.object[i].sprite.speed_y = 0;
                                }
                            }
                            break;
                        }
                    }
                }
                if (!obj_vs_sprite and ((@as(c_int, @bitCast(@as(c_int, j))) < @as(c_int, @bitCast(@as(c_int, tile_count)))) or !level.*.object[i].sprite.enabled)) {
                    continue;
                }
                if (!obj_vs_sprite) {
                    obj_vs_sprite = SPRITES_VS_SPRITES(level, &level.*.object[i].sprite, level.*.object[i].sprite.spritedata.?, &off_object);
                }
                if (obj_vs_sprite) {
                    level.*.object[i].momentum = 0;
                    if (off_object.*.objectdata.*.bounce) {
                        off_object.*.sprite.UNDER |= @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, 1)))));
                        off_object.*.sprite.ONTOP = &level.*.object[i].sprite;
                        if (@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.speed_y))) > @as(c_int, 64)) {
                            off_object.*.sprite.speed_y = @as(i16, @bitCast(@as(c_short, @truncate(((@as(c_int, 0) - @as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.speed_y)))) >> @intCast(1)) + @as(c_int, 32)))));
                            level.*.object[i].sprite.speed_y = @as(i16, @bitCast(@as(c_short, @truncate(((@as(c_int, 0) - @as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.speed_y)))) >> @intCast(1)) + @as(c_int, 16)))));
                            off_object.*.sprite.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.speed_x))) >> @intCast(1)))));
                        } else {
                            level.*.object[i].sprite.speed_y = 0;
                            level.*.object[i].sprite.y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, off_object.*.sprite.y))) - @as(c_int, @bitCast(@as(c_uint, off_object.*.sprite.spritedata.?.collheight)))))));
                            continue;
                        }
                    } else if (level.*.object[i].objectdata.*.bounce) {
                        level.*.object[i].sprite.y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, off_object.*.sprite.y))) - @as(c_int, @bitCast(@as(c_uint, off_object.*.sprite.spritedata.?.collheight)))))));
                        if ((@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.speed_y))) >= @as(c_int, 16)) or (@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.speed_y))) < @as(c_int, 0))) {
                            globals.GRAVITY_FLAG = 4;
                            level.*.object[i].sprite.speed_y = @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, 0) - @as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.speed_y)))) + (@as(c_int, 16) * @as(c_int, 3))))));
                            if (@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.speed_y))) > @as(c_int, 0)) {
                                level.*.object[i].sprite.speed_y = 0;
                            }
                        } else {
                            level.*.object[i].sprite.speed_y = 0;
                        }
                        continue;
                    } else {
                        level.*.object[i].sprite.y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, off_object.*.sprite.y))) - @as(c_int, @bitCast(@as(c_uint, off_object.*.sprite.spritedata.?.collheight)))))));
                        level.*.object[i].sprite.speed_y = 0;
                    }
                }
            }
            max_speed = 15;
            if (@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.number))) < @as(c_int, 101)) {
                max_speed = level.*.object[i].objectdata.*.maxspeedY;
            }
            const speed = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.speed_y))) >> @intCast(4)))));
            if (@as(c_int, @bitCast(@as(c_int, speed))) != @as(c_int, 0)) {
                globals.GRAVITY_FLAG = 4;
            }
            level.*.object[i].sprite.y += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, speed)))))));
            if (@as(c_int, @bitCast(@as(c_int, speed))) < @as(c_int, @bitCast(@as(c_uint, max_speed)))) {
                level.*.object[i].sprite.speed_y += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 16)))));
                if (@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.speed_y))) > @as(c_int, 0)) {
                    level.*.object[i].momentum +%= 1;
                }
            }
            shock(level, &level.*.object[i]);
        }
    }
}

fn shock(arg_level: *lvl.TITUS_level, arg_object: *lvl.TITUS_object) void {
    var level = arg_level;
    _ = &level;
    var object = arg_object;
    _ = &object;
    const player = &level.player;
    if (@as(c_int, @bitCast(@as(c_uint, object.*.momentum))) < @as(c_int, 10)) return;
    if (@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_y))) >= (@as(c_int, 12) * @as(c_int, 16))) return;
    if (@abs(@as(c_int, @bitCast(@as(c_int, player.*.sprite.y))) - @as(c_int, @bitCast(@as(c_int, object.*.sprite.y)))) >= @as(c_int, 32)) {
        return;
    }
    if (@abs(@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) - @as(c_int, @bitCast(@as(c_int, object.*.sprite.x)))) >= @as(c_int, 32)) {
        return;
    }
    if (@as(c_int, @bitCast(@as(c_int, object.*.sprite.x))) > @as(c_int, @bitCast(@as(c_int, player.*.sprite.x)))) {
        if (@as(c_int, @bitCast(@as(c_int, object.*.sprite.x))) > (@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) + @as(c_int, 24))) return;
    } else {
        if ((@as(c_int, @bitCast(@as(c_int, object.*.sprite.x))) + @as(c_int, @bitCast(@as(c_uint, object.*.sprite.spritedata.?.collwidth)))) < @as(c_int, @bitCast(@as(c_int, player.*.sprite.x)))) return;
    }
    if (@as(c_int, @bitCast(@as(c_int, object.*.sprite.y))) < @as(c_int, @bitCast(@as(c_int, player.*.sprite.y)))) {
        if (@as(c_int, @bitCast(@as(c_int, object.*.sprite.y))) <= (@as(c_int, @bitCast(@as(c_int, player.*.sprite.y))) - @as(c_int, 32))) return;
    } else {
        if (((@as(c_int, @bitCast(@as(c_int, object.*.sprite.y))) - @as(c_int, @bitCast(@as(c_uint, object.*.sprite.spritedata.?.collheight)))) + @as(c_int, 1)) >= @as(c_int, @bitCast(@as(c_int, player.*.sprite.y)))) return;
    }
    audio.playEvent(.Event_PlayerHeadImpact);
    globals.CHOC_FLAG = 24;
    if (object.*.sprite.killing) {
        if (!globals.GODMODE) {
            plr.DEC_ENERGY(level);
        }
        object.*.sprite.killing = @as(c_int, 0) != 0;
    }
}

pub fn SPRITES_VS_SPRITES(arg_level: *lvl.TITUS_level, arg_sprite1: *lvl.TITUS_sprite, arg_sprite1data: *const lvl.TITUS_spritedata, arg_object2: [*c]*lvl.TITUS_object) bool {
    var level = arg_level;
    _ = &level;
    var sprite1 = arg_sprite1;
    _ = &sprite1;
    var sprite1data = arg_sprite1data;
    _ = &sprite1data;
    var object2 = arg_object2;
    _ = &object2;
    var i: u8 = undefined;
    _ = &i;
    var obj1left: i16 = undefined;
    _ = &obj1left;
    var obj2left: i16 = undefined;
    _ = &obj2left;
    obj1left = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, sprite1.*.x))) - (@as(c_int, @bitCast(@as(c_uint, sprite1data.*.width))) >> @intCast(1))))));
    {
        i = 0;
        while (@as(c_int, @bitCast(@as(c_uint, i))) < @as(c_int, 40)) : (i +%= 1) {
            if ((((&level.*.object[i].sprite) == sprite1) or !level.*.object[i].sprite.enabled) or !level.*.object[i].objectdata.*.support) continue;
            if (@abs(@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.x))) - @as(c_int, @bitCast(@as(c_int, obj1left)))) > @as(c_int, 64)) continue;
            if (@abs(@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.y))) - @as(c_int, @bitCast(@as(c_int, sprite1.*.y)))) > @as(c_int, 70)) continue;
            obj2left = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.x))) - (@as(c_int, @bitCast(@as(c_uint, level.*.object[i].sprite.spritedata.?.collwidth))) >> @intCast(1))))));
            if (@as(c_int, @bitCast(@as(c_int, obj2left))) > @as(c_int, @bitCast(@as(c_int, obj1left)))) {
                if ((@as(c_int, @bitCast(@as(c_int, obj1left))) + @as(c_int, @bitCast(@as(c_uint, sprite1data.*.collwidth)))) <= @as(c_int, @bitCast(@as(c_int, obj2left)))) continue;
            } else {
                if ((@as(c_int, @bitCast(@as(c_int, obj2left))) + @as(c_int, @bitCast(@as(c_uint, level.*.object[i].sprite.spritedata.?.collwidth)))) <= @as(c_int, @bitCast(@as(c_int, obj1left)))) continue;
            }
            if ((@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.y))) - (@as(c_int, @bitCast(@as(c_uint, level.*.object[i].sprite.spritedata.?.collheight))) >> @intCast(3))) >= @as(c_int, @bitCast(@as(c_int, sprite1.*.y)))) {
                if ((@as(c_int, @bitCast(@as(c_int, level.*.object[i].sprite.y))) - @as(c_int, @bitCast(@as(c_uint, level.*.object[i].sprite.spritedata.?.collheight)))) <= @as(c_int, @bitCast(@as(c_int, sprite1.*.y)))) {
                    object2.* = &level.*.object[i];
                    return @as(c_int, 1) != 0;
                }
            }
        }
    }
    return @as(c_int, 0) != 0;
}

pub fn updateobjectsprite(level: *lvl.TITUS_level, obj: *lvl.TITUS_object, number: i16, clearflags: bool) void {
    var index = number - globals.FIRST_OBJET;
    sprites.updatesprite(level, &obj.*.sprite, number, clearflags);
    if (index < 0 or index >= ORIG_OBJECT_COUNT) {
        index = 0;
    }
    obj.*.objectdata = @constCast(@ptrCast(&level.*.objectdata[@intCast(index)]));
}
