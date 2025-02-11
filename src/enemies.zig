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

// enemies.c
// Handles enemies.
//
// Global functions:
// void moveEnemies(TITUS_level *level): Move enemies, is called by main game loop
// void SET_NMI(TITUS_level *level): Collision detection, animation, is called by main game loop
// void moveTrash(TITUS_level *level): Move objects thrown by enemies
//

// TODO: side-by-side cleanup with enemies.c

const common = @import("common.zig");
const objects = @import("objects.zig");
const sprites = @import("sprites.zig");
const player = @import("player.zig");
const globals = @import("globals.zig");
const lvl = @import("level.zig");
const audio = @import("audio/audio.zig");

// FIXME: zig changes the type of the result when you call @abs. That's probably correct, but it's annoying. This keeps the type the same.
pub inline fn myabs(a: anytype) @TypeOf(a) {
    if (a < 0)
        return -a;
    return a;
}

fn UP_ANIMATION(sprite: *lvl.TITUS_sprite) void {
    while (true) {
        sprite.*.animation += 1;
        if (!(@as(c_int, @bitCast(@as(c_int, sprite.*.animation.*))) >= 0)) break;
    }
    sprite.*.animation += 1;
}

fn DOWN_ANIMATION(sprite: *lvl.TITUS_sprite) void {
    while (true) {
        sprite.*.animation -= 1;
        if (!(@as(c_int, @bitCast(@as(c_int, sprite.*.animation.*))) >= 0)) break;
    }
    sprite.*.animation -= 1;
}

pub fn moveEnemies(level: *lvl.TITUS_level) void {
    var j: c_int = undefined;
    _ = &j;
    for (&level.*.enemy) |*enemy| {
        var enemySprite: *lvl.TITUS_sprite = &enemy.*.sprite;
        _ = &enemySprite;
        if (!enemySprite.*.enabled) {
            continue;
        }
        switch (enemy.type) {
            //Noclip walk
            0, 1 => {
                if (enemy.dying != 0) { //If true, the enemy is dying or dead, and have special movement
                    DEAD1(level, enemy);
                    continue;
                }
                enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))))))); //Move the enemy
                if (@as(c_uint, @bitCast(myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) - enemy.*.center_x))) > enemy.*.range_x) { //If the enemy is range_x from center, turn direction
                    if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) >= enemy.*.center_x) { //The enemy is at rightmost edge
                        enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))))))));
                    } else { //The enemy is at leftmost edge
                        enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))))))));
                    }
                }
            },
            //Shoot
            2 => {
                if (@as(c_int, @bitCast(@as(c_uint, enemy.*.dying))) != 0) {
                    DEAD1(level, enemy);
                    continue;
                }
                if (!enemy.*.visible) {
                    continue;
                }
                if (@as(c_int, @bitCast(@as(c_uint, enemy.*.direction))) == 0) {
                    enemySprite.*.speed_x = 0;
                    if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) < @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x)))) {
                        enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(-1))));
                    }
                } else if (@as(c_int, @bitCast(@as(c_uint, enemy.*.direction))) == 2) {
                    enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(-1))));
                } else {
                    enemySprite.*.speed_x = 0;
                }
                switch (@as(c_int, @bitCast(@as(c_uint, enemy.*.phase)))) {
                    0 => {
                        //Scans the horizon!
                        common.subto0(&enemy.*.counter);
                        if (@as(c_int, @bitCast(@as(c_uint, enemy.*.counter))) != 0) { //Decrease delay timer
                            continue;
                        }
                        if (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.y)))) > 24) {
                            continue;
                        }
                        if (enemy.*.range_x < @as(c_uint, @bitCast(myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.x))))))) {
                            continue;
                        }
                        if (@as(c_int, @bitCast(@as(c_uint, enemy.*.direction))) != 0) {
                            if (@as(c_int, @bitCast(@as(c_uint, enemy.*.direction))) == 2) {
                                if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) > @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x)))) {
                                    continue;
                                }
                            } else {
                                if (@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) > @as(c_int, @bitCast(@as(c_int, enemySprite.*.x)))) {
                                    continue;
                                }
                            }
                        }
                        enemy.*.phase = 30;
                        UP_ANIMATION(enemySprite);
                    },
                    else => {
                        enemy.*.phase -%= 1;
                        if (!enemy.*.trigger) {
                            continue;
                        }
                        enemySprite.*.animation += @as(usize, @bitCast(@as(isize, @intCast(2))));
                        if (FIND_TRASH(level)) |bullet| {
                            PUT_BULLET(level, enemy, bullet);
                            enemy.*.counter = @as(u8, @bitCast(@as(u8, @truncate(enemy.*.delay))));
                        }
                        enemy.*.phase = 0;
                    },
                }
            },
            // Noclip walk, jump to player (fish)
            3, 4 => {
                if (@as(c_int, @bitCast(@as(c_uint, enemy.*.dying))) != 0) {
                    DEAD1(level, enemy);
                    continue;
                }
                switch (@as(c_int, @bitCast(@as(c_uint, enemy.*.phase)))) {
                    0 => {
                        enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        if (@as(c_uint, @bitCast(myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) - enemy.*.center_x))) > enemy.*.range_x) {
                            if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) >= enemy.*.center_x) {
                                enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))))))));
                            } else {
                                enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))))))));
                            }
                        }
                        if (!enemy.*.visible) {
                            continue;
                        }
                        if ((@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) < @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y)))) or (@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) >= (@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y))) + 256))) {
                            continue;
                        }
                        if (enemy.*.range_y < @as(c_uint, @bitCast(@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) - @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y)))))) {
                            continue;
                        }
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) > @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x)))) {
                            if (@as(c_int, @intFromBool(enemySprite.*.flipped)) == 1) {
                                continue;
                            }
                        } else {
                            if (@as(c_int, @intFromBool(enemySprite.*.flipped)) == 0) {
                                continue;
                            }
                        }
                        if (myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) - @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x)))) >= 48) {
                            continue;
                        }
                        if (@as(c_uint, @bitCast(myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) - enemy.*.center_x))) > enemy.*.range_x) {
                            continue;
                        }
                        enemy.*.phase = 1;
                        enemySprite.*.speed_y = 0;
                        j = 0;
                        while (true) {
                            enemySprite.*.speed_y += 1;
                            j += @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y)));
                            if (!((@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) - @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y)))) > j)) break;
                        }
                        enemySprite.*.speed_y = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y)))))));
                        enemy.*.delay = @as(c_uint, @bitCast(@as(c_int, enemySprite.*.y)));
                        UP_ANIMATION(enemySprite);
                    },
                    1 => {
                        if (!enemy.*.visible) {
                            continue;
                        }
                        enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))) << @intCast(2)))));
                        enemySprite.*.y += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y)))))));
                        if ((@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y))) + 1) < 0) {
                            enemySprite.*.speed_y += 1;
                            if (@as(c_uint, @bitCast(@as(c_int, enemySprite.*.y))) > (enemy.*.delay -% enemy.*.range_y)) {
                                continue;
                            }
                        }
                        UP_ANIMATION(enemySprite);
                        enemy.*.phase = 2;
                        enemySprite.*.speed_y = 0;
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) <= enemy.*.center_x) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))))))));
                        } else {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))))))));
                        }
                    },
                    2 => {
                        if (!enemy.*.visible) {
                            continue;
                        }
                        enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        enemySprite.*.y += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y)))))));
                        enemySprite.*.speed_y += 1;
                        if (@as(c_uint, @bitCast(@as(c_int, enemySprite.*.y))) < enemy.*.delay) {
                            continue;
                        }
                        enemySprite.*.y = @as(i16, @bitCast(@as(c_ushort, @truncate(enemy.*.delay))));
                        enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        enemy.*.phase = 0;
                        DOWN_ANIMATION(enemySprite);
                        DOWN_ANIMATION(enemySprite);
                    },
                    else => {},
                }
            },
            // Noclip walk, move to player (fly)
            5, 6 => {
                if (@as(c_int, @bitCast(@as(c_uint, enemy.*.dying))) != 0) {
                    DEAD1(level, enemy);
                    continue;
                }
                enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                if (@as(c_uint, @bitCast(myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) - enemy.*.center_x))) > enemy.*.range_x) {
                    if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) >= enemy.*.center_x) {
                        enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))))))));
                    } else {
                        enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))))))));
                    }
                }
                if (!enemy.*.visible) {
                    continue;
                }
                switch (@as(c_int, @bitCast(@as(c_uint, enemy.*.phase)))) {
                    0 => {
                        if (@as(c_uint, @bitCast(myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) - @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y)))))) > enemy.*.range_y) {
                            continue;
                        }
                        if (myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) - @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x)))) > 40) {
                            continue;
                        }
                        enemy.*.delay = @as(c_uint, @bitCast(@as(c_int, enemySprite.*.y)));
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) < @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y)))) {
                            enemySprite.*.speed_y = 2;
                        } else {
                            enemySprite.*.speed_y = @as(i16, @bitCast(@as(c_short, @truncate(-2))));
                        }
                        enemy.*.phase = 1;
                        UP_ANIMATION(enemySprite);
                    },
                    1 => {
                        enemySprite.*.y += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y)))))));
                        if (myabs(@as(c_long, @bitCast(@as(c_long, enemySprite.*.y))) - @as(c_long, @bitCast(@as(c_ulong, enemy.*.delay)))) < @as(c_long, @bitCast(@as(c_ulong, enemy.*.range_y)))) {
                            continue;
                        }
                        enemySprite.*.speed_y = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y)))))));
                        UP_ANIMATION(enemySprite);
                        enemy.*.phase = 2;
                    },
                    2 => {
                        enemySprite.*.y += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y)))))));
                        if (@as(c_uint, @bitCast(@as(c_int, enemySprite.*.y))) != enemy.*.delay) {
                            continue;
                        }
                        DOWN_ANIMATION(enemySprite);
                        DOWN_ANIMATION(enemySprite);
                        enemy.*.phase = 0;
                    },
                    else => {},
                }
            },
            // Gravity walk, hit when near
            7 => {
                if (@as(c_int, @bitCast(@as(c_uint, enemy.*.dying))) != 0) {
                    DEAD1(level, enemy);
                    continue;
                }
                switch (@as(c_int, @bitCast(@as(c_uint, enemy.*.phase)))) {
                    0 => {
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) > @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y)))) {
                            continue;
                        }
                        if (enemy.*.range_x < @as(c_uint, @bitCast(myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) - @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))))))) {
                            continue;
                        }
                        if (myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) - @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y)))) > 200) {
                            continue;
                        }
                        enemy.*.phase = 1;
                        UP_ANIMATION(enemySprite);
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) > @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x)))) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_ushort, enemy.*.walkspeed_x)));
                        } else {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_uint, enemy.*.walkspeed_x)))))));
                        }
                    },
                    1 => {
                        if (lvl.get_floorflag(level, (enemySprite.y >> 4), (enemySprite.x >> 4)) == .NoFloor) {
                            if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y))) < 16) {
                                enemySprite.*.speed_y += 1;
                            }
                            enemySprite.*.y += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y)))))));
                            continue;
                        }
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y))) != 0) {
                            if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) > @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x)))) {
                                enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_ushort, enemy.*.walkspeed_x)));
                            } else {
                                enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_uint, enemy.*.walkspeed_x)))))));
                            }
                        }
                        enemySprite.*.speed_y = 0;
                        enemySprite.*.y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) & @as(c_int, 0xFFF0)))));
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))) > 0) {
                            j = -1; // moving left
                        } else {
                            j = 1; // moving right
                        }
                        const hflag = lvl.get_horizflag(level, @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) >> @intCast(4)) - 1)))), @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) >> @intCast(4)) + j)))));
                        if (hflag == .Wall or hflag == .Deadly or hflag == .Padlock) { // Next tile is wall, change direction
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        }
                        enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) < 0) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                            enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        }
                        if (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.x)))) > (320 * 2)) {
                            enemy.*.phase = 2;
                            continue;
                        }
                        if (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.y)))) >= (200 * 2)) {
                            enemy.*.phase = 2;
                            continue;
                        }
                        if (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.x)))) > (@as(c_int, @bitCast(@as(c_uint, enemySprite.*.spritedata.?.width))) + 6)) {
                            continue;
                        }
                        if (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.y)))) > 8) {
                            continue;
                        }
                        enemy.*.phase = 3;
                        UP_ANIMATION(enemySprite);
                    },
                    2 => {
                        if ((((((enemy.*.init_y >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_Y)))) <= 13) and (((enemy.*.init_y >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_Y)))) >= 0)) and (((enemy.*.init_x >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_X)))) < 21)) and (((enemy.*.init_x >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_X)))) >= 0)) {
                            continue;
                        }
                        enemySprite.*.y = @as(i16, @bitCast(@as(c_short, @truncate(enemy.*.init_y))));
                        enemySprite.*.x = @as(i16, @bitCast(@as(c_short, @truncate(enemy.*.init_x))));
                        enemy.*.phase = 0;
                        DOWN_ANIMATION(enemySprite);
                    },
                    3 => {
                        // Strike!
                        if (enemy.*.trigger) { // End of strike animation (TODO: check if this will ever be executed)
                            enemy.*.phase = 1;
                            continue;
                        }
                        // Gravity walk (equal to the first part of "case 1:")
                        if (lvl.get_floorflag(level, (enemySprite.y >> 4), (enemySprite.x >> 4)) == .NoFloor) {
                            if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y))) < 16) { // 16 = Max yspeed
                                enemySprite.*.speed_y += 1;
                            }
                            enemySprite.*.y += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y)))))));
                            continue;
                        }
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y))) != 0) {
                            if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) > @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x)))) {
                                enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_ushort, enemy.*.walkspeed_x)));
                            } else {
                                enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_uint, enemy.*.walkspeed_x)))))));
                            }
                        }
                        enemySprite.*.speed_y = 0;
                        enemySprite.*.y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) & @as(c_int, 0xFFF0)))));
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))) > 0) {
                            j = -1; // moving left
                        } else {
                            j = 1; // moving right
                        }
                        const hflag = lvl.get_horizflag(level, @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) >> @intCast(4)) - 1)))), @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) >> @intCast(4)) + j)))));
                        if ((hflag == .Wall) or (hflag == .Deadly) or (hflag == .Padlock)) { // Next tile is wall, change direction
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        }
                        enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) < 0) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                            enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        }
                        if (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.x)))) > (320 * 2)) {
                            enemy.*.phase = 2;
                            continue;
                        }
                        if (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.y)))) >= (200 * 2)) {
                            enemy.*.phase = 2;
                            continue;
                        }
                    },
                    else => {},
                }
            },
            8, // Gravity walk when off-screen
            14 // Gravity walk when off-screen (immortal)
            => {
                if (@as(c_int, @bitCast(@as(c_uint, enemy.*.type))) == 14) {
                    enemy.*.dying = 0;
                } else if (@as(c_int, @bitCast(@as(c_uint, enemy.*.dying))) != 0) {
                    DEAD1(level, enemy);
                    continue;
                }
                switch (@as(c_int, @bitCast(@as(c_uint, enemy.*.phase)))) {
                    0 => {
                        if ((myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) - @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x)))) > 340) or (myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) - @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y)))) >= 230)) {
                            enemy.*.phase = 1;
                            UP_ANIMATION(enemySprite);
                            if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) > @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x)))) {
                                enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_ushort, enemy.*.walkspeed_x)));
                            } else {
                                enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_uint, enemy.*.walkspeed_x)))))));
                            }
                        }
                    },
                    1 => {
                        if (lvl.get_floorflag(level, (enemySprite.*.y >> 4), (enemySprite.*.x >> 4)) == .NoFloor) {
                            if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y))) < 16) {
                                enemySprite.*.speed_y += 1;
                            }
                            enemySprite.*.y += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y)))))));
                            continue;
                        }
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y))) != 0) {
                            if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) > @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x)))) {
                                enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_ushort, enemy.*.walkspeed_x)));
                            } else {
                                enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_uint, enemy.*.walkspeed_x)))))));
                            }
                        }
                        enemySprite.*.speed_y = 0;
                        enemySprite.*.y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) & @as(c_int, 0xFFF0)))));
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))) > 0) {
                            j = -1;
                        } else {
                            j = 1;
                        }
                        const hflag = lvl.get_horizflag(level, (enemySprite.*.y >> 4) - 1, (enemySprite.*.x >> 4) + @as(i16, @truncate(j)));
                        if (hflag == .Wall or hflag == .Deadly or hflag == .Padlock) { // Next tile is wall, change direction
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        }
                        enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) < 0) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                            enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        }
                        if (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.x)))) < (320 * 2)) {
                            continue;
                        }
                        enemy.*.phase = 2;
                    },
                    2 => {
                        if ((((((enemy.*.init_y >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_Y)))) < 12) and (((enemy.*.init_y >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_Y)))) >= 0)) and (((enemy.*.init_x >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_X)))) < 19)) and (((enemy.*.init_x >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_X)))) >= 0)) {
                            continue;
                        }
                        enemySprite.*.y = @as(i16, @bitCast(@as(c_short, @truncate(enemy.*.init_y))));
                        enemySprite.*.x = @as(i16, @bitCast(@as(c_short, @truncate(enemy.*.init_x))));
                        enemy.*.phase = 0;
                        DOWN_ANIMATION(enemySprite);
                    },
                    else => {},
                }
            },
            // Walk and periodically pop-up
            9 => {
                if (@as(c_int, @bitCast(@as(c_uint, enemy.*.dying))) != 0) {
                    DEAD1(level, enemy);
                    continue;
                }
                switch (@as(c_int, @bitCast(@as(c_uint, enemy.*.phase)))) {
                    0 => {
                        if (enemy.*.range_x < @as(c_uint, @bitCast(myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.x))))))) {
                            continue;
                        }
                        if (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.y)))) > 60) {
                            continue;
                        }
                        enemy.*.phase = 1;
                        UP_ANIMATION(enemySprite);
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) > @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x)))) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_ushort, enemy.*.walkspeed_x)));
                        } else {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_uint, enemy.*.walkspeed_x)))))));
                        }
                    },
                    1 => {
                        globals.TAUPE_FLAG +%= 1;
                        if (((@as(c_int, @bitCast(@as(c_uint, globals.TAUPE_FLAG))) & 4) == 0) and ((@as(c_int, @bitCast(@as(c_uint, globals.IMAGE_COUNTER))) & 511) == 0)) {
                            UP_ANIMATION(enemySprite);
                        }
                        if ((@as(c_int, @bitCast(@as(c_uint, globals.IMAGE_COUNTER))) & 127) == 0) {
                            enemy.*.phase = 3;
                            UP_ANIMATION(enemySprite);
                            if (!enemy.*.visible) {
                                UP_ANIMATION(enemySprite);
                                enemySprite.*.animation -= 1;
                                GAL_FORM(level, enemy);
                                if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) > @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x)))) {
                                    enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_ushort, enemy.*.walkspeed_x)));
                                } else {
                                    enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_uint, enemy.*.walkspeed_x)))))));
                                }
                                enemy.*.phase = 1;
                            } else if (enemy.*.trigger) {
                                if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) > @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x)))) {
                                    enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_ushort, enemy.*.walkspeed_x)));
                                } else {
                                    enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_uint, enemy.*.walkspeed_x)))))));
                                }
                                enemy.*.phase = 1;
                            }
                            continue;
                        }
                        if (lvl.get_floorflag(level, (enemySprite.y >> 4), (enemySprite.x >> 4)) == .NoFloor) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))))))));
                            if (enemy.*.init_x > @as(c_int, @bitCast(@as(c_int, enemySprite.*.x)))) {
                                enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                            }
                        }
                        enemySprite.*.y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) & @as(c_int, 0xFFF0)))));
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))) > 0) {
                            j = -1; // moving left
                        } else {
                            j = 1; // moving right
                        }
                        const hflag = lvl.get_horizflag(level, (enemySprite.y >> 4) - 1, (enemySprite.x >> 4) + @as(i16, @truncate(j)));
                        if (hflag == .Wall or hflag == .Deadly or hflag == .Padlock) { // Next tile is wall, change direction
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        }
                        enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) < 0) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                            enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        }
                        if (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.x)))) < (320 * 4)) {
                            continue;
                        }
                        enemy.*.phase = 2;
                    },
                    2 => {
                        if ((((((enemy.*.init_y >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_Y)))) <= 12) and (((enemy.*.init_y >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_Y)))) >= 0)) and (((enemy.*.init_x >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_X)))) < 25)) and (((enemy.*.init_x >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_X)))) >= 0)) {
                            continue;
                        }
                        enemySprite.*.y = @as(i16, @bitCast(@as(c_short, @truncate(enemy.*.init_y))));
                        enemySprite.*.x = @as(i16, @bitCast(@as(c_short, @truncate(enemy.*.init_x))));
                        enemy.*.phase = 0;
                        DOWN_ANIMATION(enemySprite);
                    },
                    3 => {
                        if (!enemy.*.visible) {
                            UP_ANIMATION(enemySprite);
                            enemySprite.*.animation -= 1;
                            GAL_FORM(level, enemy);
                            if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) > @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x)))) {
                                enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_ushort, enemy.*.walkspeed_x)));
                            } else {
                                enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_uint, enemy.*.walkspeed_x)))))));
                            }
                            enemy.*.phase = 1;
                        } else if (enemy.*.trigger) {
                            if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) > @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x)))) {
                                enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_ushort, enemy.*.walkspeed_x)));
                            } else {
                                enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_uint, enemy.*.walkspeed_x)))))));
                            }
                            enemy.*.phase = 1;
                        }
                    },
                    else => {},
                }
            },
            // Alert when near, walk when nearer
            10 => {
                if (@as(c_int, @bitCast(@as(c_uint, enemy.*.dying))) != 0) {
                    DEAD1(level, enemy);
                    continue;
                }
                switch (@as(c_int, @bitCast(@as(c_uint, enemy.*.phase)))) {
                    0 => {
                        if (@as(c_int, @bitCast(@as(c_uint, globals.FURTIF_FLAG))) != 0) {
                            continue;
                        }
                        if (enemy.*.range_x < @as(c_uint, @bitCast(myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.x))))))) {
                            continue;
                        }
                        if (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.y)))) > 26) {
                            continue;
                        }
                        enemy.*.phase = 1;
                        UP_ANIMATION(enemySprite);
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) > @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x)))) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_ushort, enemy.*.walkspeed_x)));
                        } else {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_uint, enemy.*.walkspeed_x)))))));
                        }
                        if (@as(c_int, @bitCast(@as(c_uint, globals.FURTIF_FLAG))) != 0) {
                            continue;
                        }
                        if (enemy.*.range_x < @as(c_uint, @bitCast(myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.x))))))) {
                            DOWN_ANIMATION(enemySprite);
                            enemy.*.phase = 0;
                            continue;
                        }
                        if (((enemy.*.range_x -% @as(c_uint, 50)) >= @as(c_uint, @bitCast(myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.x))))))) and (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.y)))) <= 60)) {
                            enemy.*.phase = 2;
                            UP_ANIMATION(enemySprite);
                        }
                    },
                    1 => {
                        // wait
                        if (@as(c_int, @bitCast(@as(c_uint, globals.FURTIF_FLAG))) != 0) {
                            continue;
                        }
                        if (enemy.*.range_x < @as(c_uint, @bitCast(myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.x))))))) {
                            DOWN_ANIMATION(enemySprite);
                            enemy.*.phase = 0;
                            continue;
                        }
                        if (((enemy.*.range_x -% @as(c_uint, 50)) >= @as(c_uint, @bitCast(myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.x))))))) and (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.y)))) <= 60)) {
                            enemy.*.phase = 2;
                            UP_ANIMATION(enemySprite);
                        }
                    },
                    2 => {
                        // run
                        if (lvl.get_floorflag(level, (enemySprite.*.y >> 4), (enemySprite.*.x >> 4)) == .NoFloor) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))))))));
                            if (enemy.*.init_x > @as(c_int, @bitCast(@as(c_int, enemySprite.*.x)))) {
                                enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                            }
                        }
                        enemySprite.*.y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) & @as(c_int, 0xFFF0)))));
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))) > 0) {
                            j = -1; // moving left
                        } else {
                            j = 1; // moving right
                        }
                        const hflag = lvl.get_horizflag(level, (enemySprite.*.y >> 4) - 1, (enemySprite.*.x >> 4) + @as(i16, @truncate(j)));
                        if (hflag == .Wall or hflag == .Deadly or hflag == .Padlock) { // Next tile is wall, change direction
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))))))));
                            if (enemy.*.init_x > @as(c_int, @bitCast(@as(c_int, enemySprite.*.x)))) {
                                enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                            }
                        }
                        enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) < 0) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                            enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        }
                        if (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.x)))) >= (320 * 2)) {
                            enemy.*.phase = 3;
                        }
                    },
                    3 => {
                        if ((((((enemy.*.init_y >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_Y)))) <= 13) and (((enemy.*.init_y >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_Y)))) >= 0)) and (((enemy.*.init_x >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_X)))) < 21)) and (((enemy.*.init_x >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_X)))) >= 0)) {
                            continue;
                        }
                        enemySprite.*.y = @as(i16, @bitCast(@as(c_short, @truncate(enemy.*.init_y))));
                        enemySprite.*.x = @as(i16, @bitCast(@as(c_short, @truncate(enemy.*.init_x))));
                        DOWN_ANIMATION(enemySprite);
                        DOWN_ANIMATION(enemySprite);
                        enemy.*.phase = 0;
                    },
                    else => {},
                }
            },
            // Walk and shoot
            11 => {
                if (@as(c_int, @bitCast(@as(c_uint, enemy.*.dying))) != 0) {
                    DEAD1(level, enemy);
                    continue;
                }
                switch (@as(c_int, @bitCast(@as(c_uint, enemy.*.phase)))) {
                    0 => {
                        if (enemy.*.range_x < @as(c_uint, @bitCast(myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.x))))))) {
                            continue;
                        }
                        if (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.y)))) > 26) {
                            continue;
                        }
                        enemy.*.phase = 1;
                        UP_ANIMATION(enemySprite);
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) > @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x)))) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_ushort, enemy.*.walkspeed_x)));
                        } else {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_uint, enemy.*.walkspeed_x)))))));
                        }
                    },
                    1 => {
                        if (lvl.get_floorflag(level, (enemySprite.*.y >> 4), (enemySprite.*.x >> 4)) == .NoFloor) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))))))));
                            if (enemy.*.init_x > @as(c_int, @bitCast(@as(c_int, enemySprite.*.x)))) {
                                enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                            }
                        }
                        enemySprite.*.y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) & @as(c_int, 0xFFF0)))));
                        const hflag = lvl.get_horizflag(level, (enemySprite.*.y >> 4) - 1, enemySprite.*.x >> 4);
                        if (hflag == .Wall or hflag == .Deadly or hflag == .Padlock) { // Next tile is wall, change direction
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        }
                        enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) < 0) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                            enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        }
                        if (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.x)))) >= (320 * 2)) {
                            enemy.*.phase = 2;
                        }
                        common.subto0(&enemy.*.counter);
                        if (@as(c_int, @bitCast(@as(c_uint, enemy.*.counter))) != 0) {
                            continue;
                        }
                        if (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.x)))) > 64) {
                            continue;
                        }
                        if (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.y)))) > 20) {
                            continue;
                        }
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) > @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x)))) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_ushort, enemy.*.walkspeed_x)));
                        } else {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_uint, enemy.*.walkspeed_x)))))));
                        }
                        enemy.*.phase = 3;
                        UP_ANIMATION(enemySprite);
                        enemy.*.counter = 20;
                    },
                    2 => {
                        if ((((((enemy.*.init_y >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_Y)))) > 13) or (((enemy.*.init_y >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_Y)))) < 0)) or (((enemy.*.init_x >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_X)))) >= 21)) or (((enemy.*.init_x >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_X)))) < 0)) {
                            enemySprite.*.x = @as(i16, @bitCast(@as(c_short, @truncate(enemy.*.init_x))));
                            enemySprite.*.y = @as(i16, @bitCast(@as(c_short, @truncate(enemy.*.init_y))));
                            DOWN_ANIMATION(enemySprite);
                            enemy.*.phase = 0;
                        }
                    },
                    3 => {
                        if (!enemy.*.trigger) {
                            continue;
                        }
                        if (FIND_TRASH(level)) |bullet| {
                            enemySprite.*.animation += @as(usize, @bitCast(@as(isize, @intCast(2))));
                            PUT_BULLET(level, enemy, bullet);
                        }
                        DOWN_ANIMATION(enemySprite);
                        enemy.*.phase = 1;
                    },
                    else => {},
                }
            },
            // Jump (fireball) (immortal)
            12 => {
                enemy.*.dying = 0;
                switch (@as(c_int, @bitCast(@as(c_uint, enemy.*.phase)))) {
                    0 => {
                        UP_ANIMATION(enemySprite);
                        enemySprite.*.speed_y = @as(i16, @bitCast(@as(c_ushort, @truncate(enemy.*.range_y))));
                        enemy.*.init_y = @as(c_int, @bitCast(@as(c_int, enemySprite.*.y)));
                        enemy.*.phase = 1;
                    },
                    1 => {
                        enemySprite.*.y -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y)))))));
                        enemySprite.*.speed_y -= 1;
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y))) == 0) {
                            enemy.*.phase = 2;
                        }
                    },
                    2 => {
                        enemySprite.*.y += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y)))))));
                        enemySprite.*.speed_y += 1;
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) >= enemy.*.init_y) {
                            enemySprite.*.y = @as(i16, @bitCast(@as(c_short, @truncate(enemy.*.init_y))));
                            enemy.*.counter = @as(u8, @bitCast(@as(u8, @truncate(enemy.*.delay))));
                            enemy.*.phase = 3;
                            DOWN_ANIMATION(enemySprite);
                        }
                    },
                    3 => {
                        enemy.*.counter -%= 1;
                        if (@as(c_int, @bitCast(@as(c_uint, enemy.*.counter))) == 0) {
                            enemy.*.phase = 0;
                        }
                    },
                    else => {},
                }
            },
            // Bounce (big baby)
            13 => {
                if (@as(c_int, @bitCast(@as(c_uint, enemy.*.dying))) != 0) {
                    DEAD1(level, enemy);
                    continue;
                }
                switch (@as(c_int, @bitCast(@as(c_uint, enemy.*.phase)))) {
                    0 => {
                        if (@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) >= @as(c_int, @bitCast(@as(c_int, enemySprite.*.x)))) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))))))));
                        } else {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))))))));
                        }
                        if ((@as(c_uint, @bitCast(myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.x)))))) <= enemy.*.range_x) and (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.y)))) <= 40)) {
                            UP_ANIMATION(enemySprite);
                            enemy.*.phase = 1;
                            enemySprite.*.speed_y = 10;
                        }
                    },
                    1 => {
                        enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        enemySprite.*.y -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y)))))));
                        enemySprite.*.speed_y -= 1;
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y))) == 0) {
                            UP_ANIMATION(enemySprite);
                            enemy.*.phase = 2;
                        }
                    },
                    2 => {
                        enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        enemySprite.*.y += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y)))))));
                        enemySprite.*.speed_y += 1;
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y))) > 10) {
                            enemy.*.phase = 3;
                            UP_ANIMATION(enemySprite);
                            enemy.*.counter = @as(u8, @bitCast(@as(u8, @truncate(enemy.*.delay))));
                        }
                    },
                    3 => {
                        enemy.*.counter -%= 1;
                        if (@as(c_int, @bitCast(@as(c_uint, enemy.*.counter))) == 0) {
                            DOWN_ANIMATION(enemySprite);
                            DOWN_ANIMATION(enemySprite);
                            DOWN_ANIMATION(enemySprite);
                            enemy.*.phase = 0;
                        }
                    },
                    else => {},
                }
            },
            // Nothing (immortal)
            15 => {
                enemy.*.dying = 0;
            },
            // Nothing
            16 => {
                if (@as(c_int, @bitCast(@as(c_uint, enemy.*.dying))) != 0) {
                    DEAD1(level, enemy);
                    continue;
                }
            },
            // Drop (immortal)
            17 => {
                enemy.*.dying = 0;
                if (@as(c_uint, @bitCast(@as(c_int, @bitCast(@as(c_uint, enemy.*.counter))) + 1)) < enemy.*.delay) {
                    enemy.*.counter +%= 1;
                    continue;
                }
                if (enemy.*.range_x < @as(c_uint, @bitCast(myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) - @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))))))) {
                    enemy.*.counter = 0;
                    continue;
                }
                if (enemy.*.range_y < @as(c_uint, @bitCast(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.y)))))) {
                    continue;
                }
                j = 0;
                while (true) {
                    j += 1;
                    if (j > 40) {
                        enemy.*.counter = 0;
                        continue;
                    }
                    if (!(@as(c_int, @intFromBool(level.*.object[@as(c_uint, @intCast(j))].sprite.enabled)) == 1)) break;
                }
                UP_ANIMATION(enemySprite);
                objects.updateobjectsprite(level, &level.*.object[@as(c_uint, @intCast(j))], @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.animation.*))) & 8191)))), true);
                level.*.object[@as(c_uint, @intCast(j))].sprite.flipped = true;
                level.*.object[@as(c_uint, @intCast(j))].sprite.x = enemySprite.*.x;
                level.*.object[@as(c_uint, @intCast(j))].sprite.y = enemySprite.*.y;
                level.*.object[@as(c_uint, @intCast(j))].sprite.droptobottom = true;
                level.*.object[@as(c_uint, @intCast(j))].sprite.killing = true;
                level.*.object[@as(c_uint, @intCast(j))].sprite.speed_y = 0;
                globals.GRAVITY_FLAG = 4;
                DOWN_ANIMATION(enemySprite);
                enemy.*.counter = 0;
            },
            // Guard (helicopter guy)
            18 => {
                if (@as(c_int, @bitCast(@as(c_uint, enemy.*.dying))) != 0) {
                    DEAD1(level, enemy);
                    continue;
                }
                if ((((@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) < @as(c_int, @bitCast(@as(c_int, @as(i16, @bitCast(@as(c_ushort, @truncate(@as(c_uint, @bitCast(enemy.*.init_x)) -% enemy.*.range_x)))))))) or (@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) > @as(c_int, @bitCast(@as(c_int, @as(i16, @bitCast(@as(c_ushort, @truncate(@as(c_uint, @bitCast(enemy.*.init_x)) +% enemy.*.range_x))))))))) or (@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y))) < @as(c_int, @bitCast(@as(c_int, @as(i16, @bitCast(@as(c_ushort, @truncate(@as(c_uint, @bitCast(enemy.*.init_y)) -% enemy.*.range_y))))))))) or (@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y))) > @as(c_int, @bitCast(@as(c_int, @as(i16, @bitCast(@as(c_ushort, @truncate(@as(c_uint, @bitCast(enemy.*.init_y)) +% enemy.*.range_y))))))))) {
                    if (enemy.*.init_x != @as(c_int, @bitCast(@as(c_int, enemySprite.*.x)))) {
                        enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))))))));
                        if (enemy.*.init_x > @as(c_int, @bitCast(@as(c_int, enemySprite.*.x)))) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        }
                        enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                    }
                    if (enemy.*.init_y != @as(c_int, @bitCast(@as(c_int, enemySprite.*.y)))) {
                        if (enemy.*.init_y > @as(c_int, @bitCast(@as(c_int, enemySprite.*.y)))) {
                            enemySprite.*.y += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y)))))));
                        } else {
                            enemySprite.*.y -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y)))))));
                        }
                    }
                } else {
                    if (@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) != @as(c_int, @bitCast(@as(c_int, enemySprite.*.x)))) {
                        enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))))))));
                        if (@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) > @as(c_int, @bitCast(@as(c_int, enemySprite.*.x)))) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        }
                        enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                    }
                    if (@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y))) != @as(c_int, @bitCast(@as(c_int, enemySprite.*.y)))) {
                        if (@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y))) > @as(c_int, @bitCast(@as(c_int, enemySprite.*.y)))) {
                            enemySprite.*.y += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y)))))));
                        } else {
                            enemySprite.*.y -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y)))))));
                        }
                    }
                }
            },
            else => {},
        }
    }
}

fn DEAD1(level: *lvl.TITUS_level, enemy: *lvl.TITUS_enemy) void {
    if (((@as(c_int, @bitCast(@as(c_uint, enemy.*.dying))) & 1) != 0) or (@as(c_int, @bitCast(@as(c_int, enemy.*.dead_sprite))) == -1)) {
        if ((@as(c_int, @bitCast(@as(c_uint, enemy.*.dying))) & 1) == 0) {
            enemy.*.dying = @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @bitCast(@as(c_uint, enemy.*.dying))) | 1))));
            enemy.*.sprite.speed_y = @as(i16, @bitCast(@as(c_short, @truncate(-10))));
            enemy.*.phase = 0;
        }
        if (@as(c_int, @bitCast(@as(c_uint, enemy.*.phase))) != 255) {
            enemy.*.sprite.y += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemy.*.sprite.speed_y)))))));
            if (@as(c_int, @bitCast(@as(c_uint, globals.SEECHOC_FLAG))) != 0) {
                level.*.player.sprite2.y += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemy.*.sprite.speed_y)))))));
            }
            if (@as(c_int, @bitCast(@as(c_int, enemy.*.sprite.speed_y))) < 20) {
                enemy.*.sprite.speed_y += 1;
            }
        }
    } else {
        enemy.*.dying = @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @bitCast(@as(c_uint, enemy.*.dying))) | 1))));
        updateenemysprite(level, enemy, enemy.*.dead_sprite, false);
        enemy.*.sprite.flash = false;
        enemy.*.sprite.visible = false;
        enemy.*.sprite.speed_y = 0;
        enemy.*.phase = @as(u8, @bitCast(@as(i8, @truncate(-1))));
    }
}

pub fn updateenemysprite(level: *lvl.TITUS_level, enemy: *lvl.TITUS_enemy, number: i16, clearflags: bool) void {
    sprites.updatesprite(level, &enemy.*.sprite, number, clearflags);
    if ((@as(c_int, @bitCast(@as(c_int, number))) >= 101) and (@as(c_int, @bitCast(@as(c_int, number))) <= 105)) {
        enemy.*.carry_sprite = 105;
    } else if ((@as(c_int, @bitCast(@as(c_int, number))) >= 126) and (@as(c_int, @bitCast(@as(c_int, number))) <= 130)) {
        enemy.*.carry_sprite = @as(i16, @bitCast(@as(c_short, @truncate(130))));
    } else if ((@as(c_int, @bitCast(@as(c_int, number))) >= 149) and (@as(c_int, @bitCast(@as(c_int, number))) <= 153)) {
        enemy.*.carry_sprite = @as(i16, @bitCast(@as(c_short, @truncate(149))));
    } else if ((@as(c_int, @bitCast(@as(c_int, number))) >= 157) and (@as(c_int, @bitCast(@as(c_int, number))) <= 158)) {
        enemy.*.carry_sprite = @as(i16, @bitCast(@as(c_short, @truncate(158))));
    } else if ((@as(c_int, @bitCast(@as(c_int, number))) >= 159) and (@as(c_int, @bitCast(@as(c_int, number))) <= 167)) {
        enemy.*.carry_sprite = @as(i16, @bitCast(@as(c_short, @truncate(167))));
    } else if ((@as(c_int, @bitCast(@as(c_int, number))) >= 185) and (@as(c_int, @bitCast(@as(c_int, number))) <= 191)) {
        enemy.*.carry_sprite = @as(i16, @bitCast(@as(c_short, @truncate(186))));
    } else if ((@as(c_int, @bitCast(@as(c_int, number))) >= 197) and (@as(c_int, @bitCast(@as(c_int, number))) <= 203)) {
        enemy.*.carry_sprite = @as(i16, @bitCast(@as(c_short, @truncate(203))));
    } else {
        enemy.*.carry_sprite = @as(i16, @bitCast(@as(c_short, @truncate(-1))));
    }
    if ((@as(c_int, @bitCast(@as(c_int, number))) >= 172) and (@as(c_int, @bitCast(@as(c_int, number))) <= 184)) {
        enemy.*.dead_sprite = @as(i16, @bitCast(@as(c_short, @truncate(184))));
    } else if ((@as(c_int, @bitCast(@as(c_int, number))) >= 192) and (@as(c_int, @bitCast(@as(c_int, number))) <= 196)) {
        enemy.*.dead_sprite = @as(i16, @bitCast(@as(c_short, @truncate(196))));
    } else if ((@as(c_int, @bitCast(@as(c_int, number))) >= 210) and (@as(c_int, @bitCast(@as(c_int, number))) <= 213)) {
        enemy.*.dead_sprite = @as(i16, @bitCast(@as(c_short, @truncate(213))));
    } else if ((@as(c_int, @bitCast(@as(c_int, number))) >= 214) and (@as(c_int, @bitCast(@as(c_int, number))) <= 220)) {
        enemy.*.dead_sprite = @as(i16, @bitCast(@as(c_short, @truncate(220))));
    } else if ((@as(c_int, @bitCast(@as(c_int, number))) >= 221) and (@as(c_int, @bitCast(@as(c_int, number))) <= 226)) {
        enemy.*.dead_sprite = @as(i16, @bitCast(@as(c_short, @truncate(226))));
    } else if ((@as(c_int, @bitCast(@as(c_int, number))) >= 242) and (@as(c_int, @bitCast(@as(c_int, number))) <= 247)) {
        enemy.*.dead_sprite = @as(i16, @bitCast(@as(c_short, @truncate(247))));
    } else {
        enemy.*.dead_sprite = @as(i16, @bitCast(@as(c_short, @truncate(-1))));
    }
    if (((((((@as(c_int, @bitCast(@as(c_int, number))) >= 248) and (@as(c_int, @bitCast(@as(c_int, number))) <= 251)) or ((@as(c_int, @bitCast(@as(c_int, number))) >= 252) and (@as(c_int, @bitCast(@as(c_int, number))) <= 256))) or ((@as(c_int, @bitCast(@as(c_int, number))) >= 257) and (@as(c_int, @bitCast(@as(c_int, number))) <= 261))) or ((@as(c_int, @bitCast(@as(c_int, number))) >= 263) and (@as(c_int, @bitCast(@as(c_int, number))) <= 267))) or ((@as(c_int, @bitCast(@as(c_int, number))) >= 284) and (@as(c_int, @bitCast(@as(c_int, number))) <= 288))) or ((@as(c_int, @bitCast(@as(c_int, number))) >= 329) and (@as(c_int, @bitCast(@as(c_int, number))) <= 332))) {
        enemy.*.boss = true;
    } else {
        enemy.*.boss = false;
    }
}

pub fn SET_NMI(level: *lvl.TITUS_level) void {
    var i: i16 = undefined;
    _ = &i;
    var k: i16 = undefined;
    _ = &k;
    var hit: i16 = undefined;
    _ = &hit;
    {
        i = 0;
        while (@as(c_int, @bitCast(@as(c_int, i))) < 50) : (i += 1) {
            if (!level.*.enemy[@as(c_ushort, @intCast(i))].sprite.enabled) continue;
            level.*.enemy[@as(c_ushort, @intCast(i))].visible = false;
            if (((((@as(c_int, @bitCast(@as(c_int, level.*.enemy[@as(c_ushort, @intCast(i))].sprite.x))) + 32) < (@as(c_int, @bitCast(@as(c_int, globals.BITMAP_X))) << @intCast(4))) or ((@as(c_int, @bitCast(@as(c_int, level.*.enemy[@as(c_ushort, @intCast(i))].sprite.x))) - 32) > ((@as(c_int, @bitCast(@as(c_int, globals.BITMAP_X))) << @intCast(4)) + (20 * 16)))) or (@as(c_int, @bitCast(@as(c_int, level.*.enemy[@as(c_ushort, @intCast(i))].sprite.y))) < (@as(c_int, @bitCast(@as(c_int, globals.BITMAP_Y))) << @intCast(4)))) or ((@as(c_int, @bitCast(@as(c_int, level.*.enemy[@as(c_ushort, @intCast(i))].sprite.y))) - 32) > ((@as(c_int, @bitCast(@as(c_int, globals.BITMAP_Y))) << @intCast(4)) + (12 * 16)))) {
                if ((@as(c_int, @bitCast(@as(c_uint, level.*.enemy[@as(c_ushort, @intCast(i))].dying))) & 3) != 0) {
                    level.*.enemy[@as(c_ushort, @intCast(i))].sprite.enabled = false;
                }
                continue;
            }
            level.*.enemy[@as(c_ushort, @intCast(i))].visible = true;
            GAL_FORM(level, &level.*.enemy[@as(c_ushort, @intCast(i))]);
            if ((@as(c_int, @bitCast(@as(c_uint, level.*.enemy[@as(c_ushort, @intCast(i))].dying))) & 3) != 0) {
                continue;
            }
            if ((@as(c_int, @bitCast(@as(c_uint, globals.KICK_FLAG))) == 0) and !globals.GODMODE) {
                if (level.*.enemy[@as(c_ushort, @intCast(i))].sprite.invisible) {
                    continue;
                }
                ACTIONC_NMI(level, &level.*.enemy[@as(c_ushort, @intCast(i))]);
            }
            hit = 0;
            if (@as(c_int, @bitCast(@as(c_uint, globals.GRAVITY_FLAG))) != 0) {
                {
                    k = 0;
                    while (@as(c_int, @bitCast(@as(c_int, k))) < 40) : (k += 1) {
                        if (@as(c_int, @bitCast(@as(c_int, level.*.object[@as(c_ushort, @intCast(k))].sprite.speed_x))) == 0) {
                            if (@as(c_int, @bitCast(@as(c_int, level.*.object[@as(c_ushort, @intCast(k))].sprite.speed_y))) == 0) {
                                continue;
                            }
                            if (@as(c_int, @bitCast(@as(c_uint, level.*.object[@as(c_ushort, @intCast(k))].momentum))) < 10) {
                                continue;
                            }
                        }
                        if (level.*.object[@as(c_ushort, @intCast(k))].objectdata.*.no_damage) {
                            continue;
                        }
                        if (NMI_VS_DROP(&level.*.enemy[@as(c_ushort, @intCast(i))].sprite, &level.*.object[@as(c_ushort, @intCast(k))].sprite)) {
                            hit = 1;
                            break;
                        }
                    }
                }
            }
            if ((((@as(c_int, @bitCast(@as(c_int, hit))) == 0) and (@as(c_int, @intFromBool(globals.DROP_FLAG)) != 0)) and (@as(c_int, @intFromBool(globals.CARRY_FLAG)) == 0)) and (@as(c_int, @intFromBool(level.*.player.sprite2.enabled)) != 0)) {
                if (NMI_VS_DROP(&level.*.enemy[@as(c_ushort, @intCast(i))].sprite, &level.*.player.sprite2)) {
                    globals.INVULNERABLE_FLAG = 0;
                    level.*.player.sprite2.enabled = false;
                    SEE_CHOC(level);
                    hit = 2;
                }
            }
            if (@as(c_int, @bitCast(@as(c_int, hit))) != 0) {
                if (@as(c_int, @bitCast(@as(c_int, hit))) == 1) {
                    if (@as(c_int, @bitCast(@as(c_int, level.*.object[@as(c_ushort, @intCast(k))].sprite.number))) != 73) {
                        level.*.object[@as(c_ushort, @intCast(k))].sprite.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_int, level.*.object[@as(c_ushort, @intCast(k))].sprite.speed_x)))))));
                    }
                }
                audio.playEvent(.Event_HitEnemy);
                globals.DROP_FLAG = false;
                if (level.*.enemy[@as(c_ushort, @intCast(i))].boss) {
                    if (@as(c_int, @bitCast(@as(c_uint, globals.INVULNERABLE_FLAG))) != 0) {
                        continue;
                    }
                    globals.INVULNERABLE_FLAG = 10;
                    level.*.enemy[@as(c_ushort, @intCast(i))].sprite.flash = true;
                    globals.boss_lives -%= 1;
                    if (@as(c_int, @bitCast(@as(c_uint, globals.boss_lives))) != 0) {
                        continue;
                    }
                    globals.boss_alive = false;
                }
                level.*.enemy[@as(c_ushort, @intCast(i))].dying = @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @bitCast(@as(c_uint, level.*.enemy[@as(c_ushort, @intCast(i))].dying))) | 2))));
            }
        }
    }
}

fn GAL_FORM(level: *lvl.TITUS_level, enemy: *lvl.TITUS_enemy) void {
    enemy.*.sprite.invisible = false;
    if ((@as(c_int, @bitCast(@as(c_uint, enemy.*.dying))) & 0x03) != 0) {
        enemy.*.sprite.visible = false;
        enemy.*.visible = true;
        return;
    }
    enemy.*.trigger = false;
    var animation: [*c]const i16 = enemy.*.sprite.animation;
    _ = &animation;
    while (@as(c_int, @bitCast(@as(c_int, animation.*))) < 0) {
        animation += @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, @bitCast(@as(c_int, animation.*)))))));
    }
    if (@as(c_int, @bitCast(@as(c_int, animation.*))) == 0x55AA) {
        enemy.*.sprite.invisible = true;
        return;
    }
    enemy.*.trigger = (@as(c_int, @bitCast(@as(c_int, animation.*))) & 0x2000) != 0;
    updateenemysprite(level, enemy, @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_int, animation.*))) & 0x00FF) + 101)))), true);
    enemy.*.sprite.flipped = enemy.*.sprite.speed_x < 0;
    animation += 1;
    if (@as(c_int, @bitCast(@as(c_int, animation.*))) < 0) {
        animation += @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, @bitCast(@as(c_int, animation.*)))))));
    }
    enemy.*.sprite.animation = animation;
    enemy.*.visible = true;
}

fn ACTIONC_NMI(level: *lvl.TITUS_level, enemy: *lvl.TITUS_enemy) void {
    switch (enemy.type) {
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 18 => {
            if (NMI_VS_DROP(&enemy.sprite, &level.player.sprite)) {
                if (enemy.type != 11) { // Walk and shoot
                    if (enemy.sprite.number != 178) { // Periscope
                        enemy.sprite.speed_x = enemy.sprite.speed_x;
                    }
                }

                // Fireball
                if (enemy.sprite.number >= (globals.FIRST_NMI + 53) and enemy.sprite.number <= (globals.FIRST_NMI + 55)) {
                    globals.GRANDBRULE_FLAG = true;
                }
                if (enemy.power != 0) {
                    KICK_ASH(level, &enemy.sprite, enemy.power);
                }
            }
        },
        else => {},
    }
}

fn KICK_ASH(level: *lvl.TITUS_level, enemysprite: *lvl.TITUS_sprite, power: i16) void {
    audio.playEvent(.Event_HitPlayer);
    const p_sprite = &level.player.sprite;

    player.DEC_ENERGY(level);
    player.DEC_ENERGY(level);
    globals.KICK_FLAG = 24;
    globals.CHOC_FLAG = 0;
    globals.LAST_ORDER = 0;
    p_sprite.*.speed_x = power;

    if (@as(c_int, @bitCast(@as(c_int, p_sprite.*.x))) <= @as(c_int, @bitCast(@as(c_int, enemysprite.*.x)))) {
        p_sprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_int, p_sprite.*.speed_x)))))));
    }
    p_sprite.*.speed_y = @as(i16, @bitCast(@as(c_short, @truncate(-8 * 16))));
    _ = player.player_drop_carried(level);
}

fn NMI_VS_DROP(enemysprite: *lvl.TITUS_sprite, sprite: *lvl.TITUS_sprite) bool {
    if (myabs(sprite.x) - enemysprite.x >= 64) {
        return false;
    }
    if (myabs(sprite.y) - enemysprite.y >= 70) {
        return false;
    }
    if (sprite.y < enemysprite.y) {
        // Enemy is below the offending object
        if (sprite.y <= enemysprite.y - enemysprite.*.spritedata.?.collheight + 3)
            return false;
    } else {
        // Offending object is below the enemy
        if (enemysprite.y <= sprite.y - sprite.*.spritedata.?.collheight + 3)
            return false;
    }
    const enemyleft: i16 = enemysprite.x - enemysprite.spritedata.?.refwidth;
    const objectleft: i16 = sprite.x - sprite.spritedata.?.refwidth;
    if (enemyleft >= objectleft) {
        // The object is left for the enemy
        if ((objectleft + (sprite.spritedata.?.collwidth >> 1)) <= enemyleft) {
            return false; // The object is too far left
        }
    } else {
        if ((enemyleft + (enemysprite.spritedata.?.collwidth >> 1)) <= objectleft) {
            return false; // The enemy is too far left
        }
    }
    return true; // Collision!
}

pub fn SEE_CHOC(level: *lvl.TITUS_level) void {
    sprites.updatesprite(level, &level.*.player.sprite2, globals.FIRST_OBJET + 15, true); // Hit (a throw hits an enemy)
    level.player.sprite2.speed_x = 0;
    level.player.sprite2.speed_y = 0;
    globals.SEECHOC_FLAG = 5;
}

pub fn moveTrash(level: *lvl.TITUS_level) void {
    for (&level.trash) |*trash| {
        if (!trash.enabled)
            continue;
        if (trash.speed_x != 0) {
            trash.x += trash.speed_x >> 4;
            const trash_screen_x = (trash.x >> 4) - globals.BITMAP_X;
            if (trash_screen_x < 0 or trash_screen_x > globals.screen_width) {
                trash.enabled = false;
                continue;
            }

            // NOTE: this had these comments about bugs before I touched it and it does look unintended
            // But it might just be how the game is 'supposed to' work.
            if (trash_screen_x != 0) { // Bug in the code
                trash.y += trash.speed_y >> 4;
                const trash_screen_y = (trash.y >> 4) - globals.BITMAP_Y;
                if (trash_screen_y < 0 or trash_screen_y > globals.screen_height * 16) { // Bug?
                    trash.enabled = false;
                    continue;
                }
            }
        }

        // Trash vs player
        if (!globals.GODMODE and NMI_VS_DROP(trash, &level.player.sprite)) {
            trash.x -= trash.speed_x;
            KICK_ASH(level, trash, 70);
            trash.enabled = false;
            continue;
        }
    }
}

fn FIND_TRASH(level: *lvl.TITUS_level) ?*lvl.TITUS_sprite {
    for (&level.trash) |*trash| {
        if (!trash.enabled) {
            return trash;
        }
    }
    return null;
}

fn PUT_BULLET(level: *lvl.TITUS_level, enemy: *lvl.TITUS_enemy, bullet: *lvl.TITUS_sprite) void {
    bullet.x = enemy.sprite.x;
    bullet.y = enemy.sprite.y - ((enemy.sprite.animation - 1).* & 0x00FF);
    sprites.updatesprite(level, bullet, ((enemy.sprite.animation - 2).* & 0x1FFF) + globals.FIRST_OBJET, true);
    if (enemy.sprite.x < level.player.sprite.x) {
        bullet.speed_x = 16 * 11;
        bullet.flipped = true;
    } else {
        bullet.speed_x = -16 * 11;
        bullet.flipped = false;
    }
    bullet.speed_y = 0;
    bullet.x += bullet.speed_x >> 4;
}
