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

fn UP_ANIMATION(arg_sprite: [*c]lvl.TITUS_sprite) void {
    var sprite = arg_sprite;
    _ = &sprite;
    while (true) {
        sprite.*.animation += 1;
        if (!(@as(c_int, @bitCast(@as(c_int, sprite.*.animation.*))) >= @as(c_int, 0))) break;
    }
    sprite.*.animation += 1;
}

fn DOWN_ANIMATION(arg_sprite: [*c]lvl.TITUS_sprite) void {
    var sprite = arg_sprite;
    _ = &sprite;
    while (true) {
        sprite.*.animation -= 1;
        if (!(@as(c_int, @bitCast(@as(c_int, sprite.*.animation.*))) >= @as(c_int, 0))) break;
    }
    sprite.*.animation -= 1;
}

pub fn moveEnemies(arg_level: [*c]lvl.TITUS_level) void {
    var level = arg_level;
    _ = &level;
    var bullet: [*c]lvl.TITUS_sprite = undefined;
    _ = &bullet;
    var j: c_int = undefined;
    _ = &j;
    for (&level.*.enemy) |*enemy| {
        var enemySprite: [*c]lvl.TITUS_sprite = &enemy.*.sprite;
        _ = &enemySprite;
        if (!enemySprite.*.enabled) {
            continue;
        }
        switch (enemy.type) {
            0, 1 => {
                //Noclip walk
                if (enemy.dying != 0) { //If true, the enemy is dying or dead, and have special movement
                    DEAD1(level, enemy);
                    continue;
                }
                enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))))))); //Move the enemy
                if (@as(c_uint, @bitCast(myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) - enemy.*.center_x))) > enemy.*.range_x) { //If the enemy is range_x from center, turn direction
                    if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) >= enemy.*.center_x) { //The enemy is at rightmost edge
                        enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))))))));
                    } else { //The enemy is at leftmost edge
                        enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))))))));
                    }
                }
            },
            2 => {
                //Shoot
                if (@as(c_int, @bitCast(@as(c_uint, enemy.*.dying))) != @as(c_int, 0)) {
                    DEAD1(level, enemy);
                    continue;
                }
                if (!enemy.*.visible) {
                    continue;
                }
                if (@as(c_int, @bitCast(@as(c_uint, enemy.*.direction))) == @as(c_int, 0)) {
                    enemySprite.*.speed_x = 0;
                    if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) < @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x)))) {
                        enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(-@as(c_int, 1)))));
                    }
                } else if (@as(c_int, @bitCast(@as(c_uint, enemy.*.direction))) == @as(c_int, 2)) {
                    enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(-@as(c_int, 1)))));
                } else {
                    enemySprite.*.speed_x = 0;
                }
                switch (@as(c_int, @bitCast(@as(c_uint, enemy.*.phase)))) {
                    0 => {
                        //Scans the horizon!
                        common.subto0(&enemy.*.counter);
                        if (@as(c_int, @bitCast(@as(c_uint, enemy.*.counter))) != @as(c_int, 0)) { //Decrease delay timer
                            continue;
                        }
                        if (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.y)))) > @as(c_int, 24)) {
                            continue;
                        }
                        if (enemy.*.range_x < @as(c_uint, @bitCast(myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.x))))))) {
                            continue;
                        }
                        if (@as(c_int, @bitCast(@as(c_uint, enemy.*.direction))) != @as(c_int, 0)) {
                            if (@as(c_int, @bitCast(@as(c_uint, enemy.*.direction))) == @as(c_int, 2)) {
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
                        enemySprite.*.animation += @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 2)))));
                        if ((blk: {
                            const tmp = FIND_TRASH(level);
                            bullet = tmp;
                            break :blk tmp;
                        }) != null) {
                            PUT_BULLET(level, enemy, bullet);
                            enemy.*.counter = @as(u8, @bitCast(@as(u8, @truncate(enemy.*.delay))));
                        }
                        enemy.*.phase = 0;
                    },
                }
            },
            @as(c_int, 3), @as(c_int, 4) => {
                if (@as(c_int, @bitCast(@as(c_uint, enemy.*.dying))) != @as(c_int, 0)) {
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
                                enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))))))));
                            }
                        }
                        if (!enemy.*.visible) {
                            continue;
                        }
                        if ((@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) < @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y)))) or (@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) >= (@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y))) + @as(c_int, 256)))) {
                            continue;
                        }
                        if (enemy.*.range_y < @as(c_uint, @bitCast(@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) - @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y)))))) {
                            continue;
                        }
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) > @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x)))) {
                            if (@as(c_int, @intFromBool(enemySprite.*.flipped)) == @as(c_int, 1)) {
                                continue;
                            }
                        } else {
                            if (@as(c_int, @intFromBool(enemySprite.*.flipped)) == @as(c_int, 0)) {
                                continue;
                            }
                        }
                        if (myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) - @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x)))) >= @as(c_int, 48)) {
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
                        enemySprite.*.speed_y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y)))))));
                        enemy.*.delay = @as(c_uint, @bitCast(@as(c_int, enemySprite.*.y)));
                        UP_ANIMATION(enemySprite);
                    },
                    1 => {
                        if (!enemy.*.visible) {
                            continue;
                        }
                        enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))) << @intCast(2)))));
                        enemySprite.*.y += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y)))))));
                        if ((@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y))) + @as(c_int, 1)) < @as(c_int, 0)) {
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
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))))))));
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
                        enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))))))));
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
                        if (myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) - @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x)))) > @as(c_int, 40)) {
                            continue;
                        }
                        enemy.*.delay = @as(c_uint, @bitCast(@as(c_int, enemySprite.*.y)));
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) < @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y)))) {
                            enemySprite.*.speed_y = 2;
                        } else {
                            enemySprite.*.speed_y = @as(i16, @bitCast(@as(c_short, @truncate(-@as(c_int, 2)))));
                        }
                        enemy.*.phase = 1;
                        UP_ANIMATION(enemySprite);
                    },
                    1 => {
                        enemySprite.*.y += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y)))))));
                        if (myabs(@as(c_long, @bitCast(@as(c_long, enemySprite.*.y))) - @as(c_long, @bitCast(@as(c_ulong, enemy.*.delay)))) < @as(c_long, @bitCast(@as(c_ulong, enemy.*.range_y)))) {
                            continue;
                        }
                        enemySprite.*.speed_y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y)))))));
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
            7 => {
                if (@as(c_int, @bitCast(@as(c_uint, enemy.*.dying))) != @as(c_int, 0)) {
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
                        if (myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) - @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y)))) > @as(c_int, 200)) {
                            continue;
                        }
                        enemy.*.phase = 1;
                        UP_ANIMATION(enemySprite);
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) > @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x)))) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_ushort, enemy.*.walkspeed_x)));
                        } else {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_uint, enemy.*.walkspeed_x)))))));
                        }
                    },
                    1 => {
                        if (@as(c_int, @bitCast(@as(c_uint, lvl.get_floorflag(level, @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) >> @intCast(4))))), @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) >> @intCast(4))))))))) == @as(c_int, @bitCast(@as(c_uint, .FFLAG_NOFLOOR)))) {
                            if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y))) < @as(c_int, 16)) {
                                enemySprite.*.speed_y += 1;
                            }
                            enemySprite.*.y += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y)))))));
                            continue;
                        }
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y))) != @as(c_int, 0)) {
                            if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) > @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x)))) {
                                enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_ushort, enemy.*.walkspeed_x)));
                            } else {
                                enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_uint, enemy.*.walkspeed_x)))))));
                            }
                        }
                        enemySprite.*.speed_y = 0;
                        enemySprite.*.y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) & @as(c_int, 65520)))));
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))) > @as(c_int, 0)) {
                            j = -@as(c_int, 1);
                        } else {
                            j = 1;
                        }
                        const hflag = lvl.get_horizflag(level, @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) >> @intCast(4)) - @as(c_int, 1))))), @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) >> @intCast(4)) + j)))));
                        if (((@as(c_int, @bitCast(@as(c_uint, hflag))) == @as(c_int, @bitCast(@as(c_uint, .HFLAG_WALL)))) or (@as(c_int, @bitCast(@as(c_uint, hflag))) == @as(c_int, @bitCast(@as(c_uint, .HFLAG_DEADLY))))) or (@as(c_int, @bitCast(@as(c_uint, hflag))) == @as(c_int, @bitCast(@as(c_uint, .HFLAG_PADLOCK))))) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        }
                        enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) < @as(c_int, 0)) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                            enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        }
                        if (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.x)))) > (@as(c_int, 320) * @as(c_int, 2))) {
                            enemy.*.phase = 2;
                            continue;
                        }
                        if (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.y)))) >= (@as(c_int, 200) * @as(c_int, 2))) {
                            enemy.*.phase = 2;
                            continue;
                        }
                        if (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.x)))) > (@as(c_int, @bitCast(@as(c_uint, enemySprite.*.spritedata.*.width))) + @as(c_int, 6))) {
                            continue;
                        }
                        if (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.y)))) > @as(c_int, 8)) {
                            continue;
                        }
                        enemy.*.phase = 3;
                        UP_ANIMATION(enemySprite);
                    },
                    2 => {
                        if ((((((enemy.*.init_y >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_Y)))) <= @as(c_int, 13)) and (((enemy.*.init_y >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_Y)))) >= @as(c_int, 0))) and (((enemy.*.init_x >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_X)))) < @as(c_int, 21))) and (((enemy.*.init_x >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_X)))) >= @as(c_int, 0))) {
                            continue;
                        }
                        enemySprite.*.y = @as(i16, @bitCast(@as(c_short, @truncate(enemy.*.init_y))));
                        enemySprite.*.x = @as(i16, @bitCast(@as(c_short, @truncate(enemy.*.init_x))));
                        enemy.*.phase = 0;
                        DOWN_ANIMATION(enemySprite);
                    },
                    3 => {
                        if (enemy.*.trigger) {
                            enemy.*.phase = 1;
                            continue;
                        }
                        if (@as(c_int, @bitCast(@as(c_uint, lvl.get_floorflag(level, @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) >> @intCast(4))))), @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) >> @intCast(4))))))))) == @as(c_int, @bitCast(@as(c_uint, .FFLAG_NOFLOOR)))) {
                            if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y))) < @as(c_int, 16)) {
                                enemySprite.*.speed_y += 1;
                            }
                            enemySprite.*.y += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y)))))));
                            continue;
                        }
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y))) != @as(c_int, 0)) {
                            if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) > @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x)))) {
                                enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_ushort, enemy.*.walkspeed_x)));
                            } else {
                                enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_uint, enemy.*.walkspeed_x)))))));
                            }
                        }
                        enemySprite.*.speed_y = 0;
                        enemySprite.*.y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) & @as(c_int, 65520)))));
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))) > @as(c_int, 0)) {
                            j = -@as(c_int, 1);
                        } else {
                            j = 1;
                        }
                        const hflag = lvl.get_horizflag(level, @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) >> @intCast(4)) - @as(c_int, 1))))), @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) >> @intCast(4)) + j)))));
                        if (((@as(c_int, @bitCast(@as(c_uint, hflag))) == @as(c_int, @bitCast(@as(c_uint, .HFLAG_WALL)))) or (@as(c_int, @bitCast(@as(c_uint, hflag))) == @as(c_int, @bitCast(@as(c_uint, .HFLAG_DEADLY))))) or (@as(c_int, @bitCast(@as(c_uint, hflag))) == @as(c_int, @bitCast(@as(c_uint, .HFLAG_PADLOCK))))) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        }
                        enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) < @as(c_int, 0)) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                            enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        }
                        if (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.x)))) > (@as(c_int, 320) * @as(c_int, 2))) {
                            enemy.*.phase = 2;
                            continue;
                        }
                        if (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.y)))) >= (@as(c_int, 200) * @as(c_int, 2))) {
                            enemy.*.phase = 2;
                            continue;
                        }
                    },
                    else => {},
                }
            },
            8, 14 => {
                if (@as(c_int, @bitCast(@as(c_uint, enemy.*.type))) == @as(c_int, 14)) {
                    enemy.*.dying = 0;
                } else if (@as(c_int, @bitCast(@as(c_uint, enemy.*.dying))) != @as(c_int, 0)) {
                    DEAD1(level, enemy);
                    continue;
                }
                switch (@as(c_int, @bitCast(@as(c_uint, enemy.*.phase)))) {
                    0 => {
                        if ((myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) - @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x)))) > @as(c_int, 340)) or (myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) - @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y)))) >= @as(c_int, 230))) {
                            enemy.*.phase = 1;
                            UP_ANIMATION(enemySprite);
                            if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) > @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x)))) {
                                enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_ushort, enemy.*.walkspeed_x)));
                            } else {
                                enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_uint, enemy.*.walkspeed_x)))))));
                            }
                        }
                    },
                    1 => {
                        if (@as(c_int, @bitCast(@as(c_uint, lvl.get_floorflag(level, @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) >> @intCast(4))))), @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) >> @intCast(4))))))))) == @as(c_int, @bitCast(@as(c_uint, .FFLAG_NOFLOOR)))) {
                            if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y))) < @as(c_int, 16)) {
                                enemySprite.*.speed_y += 1;
                            }
                            enemySprite.*.y += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y)))))));
                            continue;
                        }
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y))) != @as(c_int, 0)) {
                            if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) > @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x)))) {
                                enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_ushort, enemy.*.walkspeed_x)));
                            } else {
                                enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_uint, enemy.*.walkspeed_x)))))));
                            }
                        }
                        enemySprite.*.speed_y = 0;
                        enemySprite.*.y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) & @as(c_int, 65520)))));
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))) > @as(c_int, 0)) {
                            j = -@as(c_int, 1);
                        } else {
                            j = 1;
                        }
                        const hflag = lvl.get_horizflag(level, @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) >> @intCast(4)) - @as(c_int, 1))))), @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) >> @intCast(4)) + j)))));
                        if (((@as(c_int, @bitCast(@as(c_uint, hflag))) == @as(c_int, @bitCast(@as(c_uint, .HFLAG_WALL)))) or (@as(c_int, @bitCast(@as(c_uint, hflag))) == @as(c_int, @bitCast(@as(c_uint, .HFLAG_DEADLY))))) or (@as(c_int, @bitCast(@as(c_uint, hflag))) == @as(c_int, @bitCast(@as(c_uint, .HFLAG_PADLOCK))))) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        }
                        enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) < @as(c_int, 0)) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                            enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        }
                        if (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.x)))) < (@as(c_int, 320) * @as(c_int, 2))) {
                            continue;
                        }
                        enemy.*.phase = 2;
                    },
                    2 => {
                        if ((((((enemy.*.init_y >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_Y)))) < @as(c_int, 12)) and (((enemy.*.init_y >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_Y)))) >= @as(c_int, 0))) and (((enemy.*.init_x >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_X)))) < @as(c_int, 19))) and (((enemy.*.init_x >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_X)))) >= @as(c_int, 0))) {
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
            9 => {
                if (@as(c_int, @bitCast(@as(c_uint, enemy.*.dying))) != @as(c_int, 0)) {
                    DEAD1(level, enemy);
                    continue;
                }
                switch (@as(c_int, @bitCast(@as(c_uint, enemy.*.phase)))) {
                    0 => {
                        if (enemy.*.range_x < @as(c_uint, @bitCast(myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.x))))))) {
                            continue;
                        }
                        if (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.y)))) > @as(c_int, 60)) {
                            continue;
                        }
                        enemy.*.phase = 1;
                        UP_ANIMATION(enemySprite);
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) > @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x)))) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_ushort, enemy.*.walkspeed_x)));
                        } else {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_uint, enemy.*.walkspeed_x)))))));
                        }
                    },
                    1 => {
                        globals.TAUPE_FLAG +%= 1;
                        if (((@as(c_int, @bitCast(@as(c_uint, globals.TAUPE_FLAG))) & @as(c_int, 4)) == @as(c_int, 0)) and ((@as(c_int, @bitCast(@as(c_uint, globals.IMAGE_COUNTER))) & @as(c_int, 511)) == @as(c_int, 0))) {
                            UP_ANIMATION(enemySprite);
                        }
                        if ((@as(c_int, @bitCast(@as(c_uint, globals.IMAGE_COUNTER))) & @as(c_int, 127)) == @as(c_int, 0)) {
                            enemy.*.phase = 3;
                            UP_ANIMATION(enemySprite);
                            if (!enemy.*.visible) {
                                UP_ANIMATION(enemySprite);
                                enemySprite.*.animation -= 1;
                                GAL_FORM(level, enemy);
                                if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) > @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x)))) {
                                    enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_ushort, enemy.*.walkspeed_x)));
                                } else {
                                    enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_uint, enemy.*.walkspeed_x)))))));
                                }
                                enemy.*.phase = 1;
                            } else if (enemy.*.trigger) {
                                if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) > @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x)))) {
                                    enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_ushort, enemy.*.walkspeed_x)));
                                } else {
                                    enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_uint, enemy.*.walkspeed_x)))))));
                                }
                                enemy.*.phase = 1;
                            }
                            continue;
                        }
                        if (@as(c_int, @bitCast(@as(c_uint, lvl.get_floorflag(level, @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) >> @intCast(4))))), @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) >> @intCast(4))))))))) == @as(c_int, @bitCast(@as(c_uint, .FFLAG_NOFLOOR)))) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))))))));
                            if (enemy.*.init_x > @as(c_int, @bitCast(@as(c_int, enemySprite.*.x)))) {
                                enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                            }
                        }
                        enemySprite.*.y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) & @as(c_int, 65520)))));
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))) > @as(c_int, 0)) {
                            j = -@as(c_int, 1);
                        } else {
                            j = 1;
                        }
                        const hflag = lvl.get_horizflag(level, @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) >> @intCast(4)) - @as(c_int, 1))))), @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) >> @intCast(4)) + j)))));
                        if (((@as(c_int, @bitCast(@as(c_uint, hflag))) == @as(c_int, @bitCast(@as(c_uint, .HFLAG_WALL)))) or (@as(c_int, @bitCast(@as(c_uint, hflag))) == @as(c_int, @bitCast(@as(c_uint, .HFLAG_DEADLY))))) or (@as(c_int, @bitCast(@as(c_uint, hflag))) == @as(c_int, @bitCast(@as(c_uint, .HFLAG_PADLOCK))))) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        }
                        enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) < @as(c_int, 0)) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                            enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        }
                        if (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.x)))) < (@as(c_int, 320) * @as(c_int, 4))) {
                            continue;
                        }
                        enemy.*.phase = 2;
                    },
                    2 => {
                        if ((((((enemy.*.init_y >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_Y)))) <= @as(c_int, 12)) and (((enemy.*.init_y >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_Y)))) >= @as(c_int, 0))) and (((enemy.*.init_x >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_X)))) < @as(c_int, 25))) and (((enemy.*.init_x >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_X)))) >= @as(c_int, 0))) {
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
                                enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_uint, enemy.*.walkspeed_x)))))));
                            }
                            enemy.*.phase = 1;
                        } else if (enemy.*.trigger) {
                            if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) > @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x)))) {
                                enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_ushort, enemy.*.walkspeed_x)));
                            } else {
                                enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_uint, enemy.*.walkspeed_x)))))));
                            }
                            enemy.*.phase = 1;
                        }
                    },
                    else => {},
                }
            },
            10 => {
                if (@as(c_int, @bitCast(@as(c_uint, enemy.*.dying))) != @as(c_int, 0)) {
                    DEAD1(level, enemy);
                    continue;
                }
                switch (@as(c_int, @bitCast(@as(c_uint, enemy.*.phase)))) {
                    0 => {
                        if (@as(c_int, @bitCast(@as(c_uint, globals.FURTIF_FLAG))) != @as(c_int, 0)) {
                            continue;
                        }
                        if (enemy.*.range_x < @as(c_uint, @bitCast(myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.x))))))) {
                            continue;
                        }
                        if (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.y)))) > @as(c_int, 26)) {
                            continue;
                        }
                        enemy.*.phase = 1;
                        UP_ANIMATION(enemySprite);
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) > @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x)))) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_ushort, enemy.*.walkspeed_x)));
                        } else {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_uint, enemy.*.walkspeed_x)))))));
                        }
                        if (@as(c_int, @bitCast(@as(c_uint, globals.FURTIF_FLAG))) != @as(c_int, 0)) {
                            continue;
                        }
                        if (enemy.*.range_x < @as(c_uint, @bitCast(myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.x))))))) {
                            DOWN_ANIMATION(enemySprite);
                            enemy.*.phase = 0;
                            continue;
                        }
                        if (((enemy.*.range_x -% @as(c_uint, @bitCast(@as(c_int, 50)))) >= @as(c_uint, @bitCast(myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.x))))))) and (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.y)))) <= @as(c_int, 60))) {
                            enemy.*.phase = 2;
                            UP_ANIMATION(enemySprite);
                        }
                    },
                    1 => {
                        if (@as(c_int, @bitCast(@as(c_uint, globals.FURTIF_FLAG))) != @as(c_int, 0)) {
                            continue;
                        }
                        if (enemy.*.range_x < @as(c_uint, @bitCast(myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.x))))))) {
                            DOWN_ANIMATION(enemySprite);
                            enemy.*.phase = 0;
                            continue;
                        }
                        if (((enemy.*.range_x -% @as(c_uint, @bitCast(@as(c_int, 50)))) >= @as(c_uint, @bitCast(myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.x))))))) and (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.y)))) <= @as(c_int, 60))) {
                            enemy.*.phase = 2;
                            UP_ANIMATION(enemySprite);
                        }
                    },
                    2 => {
                        if (@as(c_int, @bitCast(@as(c_uint, lvl.get_floorflag(level, @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) >> @intCast(4))))), @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) >> @intCast(4))))))))) == @as(c_int, @bitCast(@as(c_uint, .FFLAG_NOFLOOR)))) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))))))));
                            if (enemy.*.init_x > @as(c_int, @bitCast(@as(c_int, enemySprite.*.x)))) {
                                enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                            }
                        }
                        enemySprite.*.y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) & @as(c_int, 65520)))));
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))) > @as(c_int, 0)) {
                            j = -@as(c_int, 1);
                        } else {
                            j = 1;
                        }
                        var hflag = lvl.get_horizflag(level, @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) >> @intCast(4)) - @as(c_int, 1))))), @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) >> @intCast(4)) + j)))));
                        _ = &hflag;
                        if (((@as(c_int, @bitCast(@as(c_uint, hflag))) == @as(c_int, @bitCast(@as(c_uint, .HFLAG_WALL)))) or (@as(c_int, @bitCast(@as(c_uint, hflag))) == @as(c_int, @bitCast(@as(c_uint, .HFLAG_DEADLY))))) or (@as(c_int, @bitCast(@as(c_uint, hflag))) == @as(c_int, @bitCast(@as(c_uint, .HFLAG_PADLOCK))))) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))))))));
                            if (enemy.*.init_x > @as(c_int, @bitCast(@as(c_int, enemySprite.*.x)))) {
                                enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                            }
                        }
                        enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) < @as(c_int, 0)) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                            enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        }
                        if (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.x)))) >= (@as(c_int, 320) * @as(c_int, 2))) {
                            enemy.*.phase = 3;
                        }
                    },
                    3 => {
                        if ((((((enemy.*.init_y >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_Y)))) <= @as(c_int, 13)) and (((enemy.*.init_y >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_Y)))) >= @as(c_int, 0))) and (((enemy.*.init_x >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_X)))) < @as(c_int, 21))) and (((enemy.*.init_x >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_X)))) >= @as(c_int, 0))) {
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
            11 => {
                if (@as(c_int, @bitCast(@as(c_uint, enemy.*.dying))) != @as(c_int, 0)) {
                    DEAD1(level, enemy);
                    continue;
                }
                switch (@as(c_int, @bitCast(@as(c_uint, enemy.*.phase)))) {
                    0 => {
                        if (enemy.*.range_x < @as(c_uint, @bitCast(myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.x))))))) {
                            continue;
                        }
                        if (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.y)))) > @as(c_int, 26)) {
                            continue;
                        }
                        enemy.*.phase = 1;
                        UP_ANIMATION(enemySprite);
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) > @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x)))) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_ushort, enemy.*.walkspeed_x)));
                        } else {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_uint, enemy.*.walkspeed_x)))))));
                        }
                    },
                    1 => {
                        if (@as(c_int, @bitCast(@as(c_uint, lvl.get_floorflag(level, @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) >> @intCast(4))))), @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) >> @intCast(4))))))))) == @as(c_int, @bitCast(@as(c_uint, .FFLAG_NOFLOOR)))) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))))))));
                            if (enemy.*.init_x > @as(c_int, @bitCast(@as(c_int, enemySprite.*.x)))) {
                                enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                            }
                        }
                        enemySprite.*.y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) & @as(c_int, 65520)))));
                        const hflag = lvl.get_horizflag(level, @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) >> @intCast(4)) - @as(c_int, 1))))), @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) >> @intCast(4))))));
                        if (((@as(c_int, @bitCast(@as(c_uint, hflag))) == @as(c_int, @bitCast(@as(c_uint, .HFLAG_WALL)))) or (@as(c_int, @bitCast(@as(c_uint, hflag))) == @as(c_int, @bitCast(@as(c_uint, .HFLAG_DEADLY))))) or (@as(c_int, @bitCast(@as(c_uint, hflag))) == @as(c_int, @bitCast(@as(c_uint, .HFLAG_PADLOCK))))) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        }
                        enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) < @as(c_int, 0)) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                            enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        }
                        if (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.x)))) >= (@as(c_int, 320) * @as(c_int, 2))) {
                            enemy.*.phase = 2;
                        }
                        common.subto0(&enemy.*.counter);
                        if (@as(c_int, @bitCast(@as(c_uint, enemy.*.counter))) != @as(c_int, 0)) {
                            continue;
                        }
                        if (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.x)))) > @as(c_int, 64)) {
                            continue;
                        }
                        if (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.y)))) > @as(c_int, 20)) {
                            continue;
                        }
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.x))) > @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x)))) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_ushort, enemy.*.walkspeed_x)));
                        } else {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_uint, enemy.*.walkspeed_x)))))));
                        }
                        enemy.*.phase = 3;
                        UP_ANIMATION(enemySprite);
                        enemy.*.counter = 20;
                    },
                    2 => {
                        if ((((((enemy.*.init_y >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_Y)))) > @as(c_int, 13)) or (((enemy.*.init_y >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_Y)))) < @as(c_int, 0))) or (((enemy.*.init_x >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_X)))) >= @as(c_int, 21))) or (((enemy.*.init_x >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_X)))) < @as(c_int, 0))) {
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
                        if ((blk: {
                            const tmp = FIND_TRASH(level);
                            bullet = tmp;
                            break :blk tmp;
                        }) != null) {
                            enemySprite.*.animation += @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 2)))));
                            PUT_BULLET(level, enemy, bullet);
                        }
                        DOWN_ANIMATION(enemySprite);
                        enemy.*.phase = 1;
                    },
                    else => {},
                }
            },
            12 => {
                enemy.*.dying = 0;
                switch (@as(c_int, @bitCast(@as(c_uint, enemy.*.phase)))) {
                    @as(c_int, 0) => {
                        UP_ANIMATION(enemySprite);
                        enemySprite.*.speed_y = @as(i16, @bitCast(@as(c_ushort, @truncate(enemy.*.range_y))));
                        enemy.*.init_y = @as(c_int, @bitCast(@as(c_int, enemySprite.*.y)));
                        enemy.*.phase = 1;
                    },
                    @as(c_int, 1) => {
                        enemySprite.*.y -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y)))))));
                        enemySprite.*.speed_y -= 1;
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y))) == @as(c_int, 0)) {
                            enemy.*.phase = 2;
                        }
                    },
                    @as(c_int, 2) => {
                        enemySprite.*.y += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y)))))));
                        enemySprite.*.speed_y += 1;
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.y))) >= enemy.*.init_y) {
                            enemySprite.*.y = @as(i16, @bitCast(@as(c_short, @truncate(enemy.*.init_y))));
                            enemy.*.counter = @as(u8, @bitCast(@as(u8, @truncate(enemy.*.delay))));
                            enemy.*.phase = 3;
                            DOWN_ANIMATION(enemySprite);
                        }
                    },
                    @as(c_int, 3) => {
                        enemy.*.counter -%= 1;
                        if (@as(c_int, @bitCast(@as(c_uint, enemy.*.counter))) == @as(c_int, 0)) {
                            enemy.*.phase = 0;
                        }
                    },
                    else => {},
                }
            },
            @as(c_int, 13) => {
                if (@as(c_int, @bitCast(@as(c_uint, enemy.*.dying))) != @as(c_int, 0)) {
                    DEAD1(level, enemy);
                    continue;
                }
                switch (@as(c_int, @bitCast(@as(c_uint, enemy.*.phase)))) {
                    @as(c_int, 0) => {
                        if (@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) >= @as(c_int, @bitCast(@as(c_int, enemySprite.*.x)))) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))))))));
                        } else {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))))))));
                        }
                        if ((@as(c_uint, @bitCast(myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.x)))))) <= enemy.*.range_x) and (myabs(@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y))) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.y)))) <= @as(c_int, 40))) {
                            UP_ANIMATION(enemySprite);
                            enemy.*.phase = 1;
                            enemySprite.*.speed_y = 10;
                        }
                    },
                    @as(c_int, 1) => {
                        enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        enemySprite.*.y -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y)))))));
                        enemySprite.*.speed_y -= 1;
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y))) == @as(c_int, 0)) {
                            UP_ANIMATION(enemySprite);
                            enemy.*.phase = 2;
                        }
                    },
                    @as(c_int, 2) => {
                        enemySprite.*.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
                        enemySprite.*.y += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y)))))));
                        enemySprite.*.speed_y += 1;
                        if (@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_y))) > @as(c_int, 10)) {
                            enemy.*.phase = 3;
                            UP_ANIMATION(enemySprite);
                            enemy.*.counter = @as(u8, @bitCast(@as(u8, @truncate(enemy.*.delay))));
                        }
                    },
                    @as(c_int, 3) => {
                        enemy.*.counter -%= 1;
                        if (@as(c_int, @bitCast(@as(c_uint, enemy.*.counter))) == @as(c_int, 0)) {
                            DOWN_ANIMATION(enemySprite);
                            DOWN_ANIMATION(enemySprite);
                            DOWN_ANIMATION(enemySprite);
                            enemy.*.phase = 0;
                        }
                    },
                    else => {},
                }
            },
            @as(c_int, 15) => {
                enemy.*.dying = 0;
            },
            @as(c_int, 16) => {
                if (@as(c_int, @bitCast(@as(c_uint, enemy.*.dying))) != @as(c_int, 0)) {
                    DEAD1(level, enemy);
                    continue;
                }
            },
            @as(c_int, 17) => {
                enemy.*.dying = 0;
                if (@as(c_uint, @bitCast(@as(c_int, @bitCast(@as(c_uint, enemy.*.counter))) + @as(c_int, 1))) < enemy.*.delay) {
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
                    if (j > @as(c_int, 40)) {
                        enemy.*.counter = 0;
                        continue;
                    }
                    if (!(@as(c_int, @intFromBool(level.*.object[@as(c_uint, @intCast(j))].sprite.enabled)) == @as(c_int, 1))) break;
                }
                UP_ANIMATION(enemySprite);
                objects.updateobjectsprite(level, &level.*.object[@as(c_uint, @intCast(j))], @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemySprite.*.animation.*))) & @as(c_int, 8191))))), @as(c_int, 1) != 0);
                level.*.object[@as(c_uint, @intCast(j))].sprite.flipped = @as(c_int, 1) != 0;
                level.*.object[@as(c_uint, @intCast(j))].sprite.x = enemySprite.*.x;
                level.*.object[@as(c_uint, @intCast(j))].sprite.y = enemySprite.*.y;
                level.*.object[@as(c_uint, @intCast(j))].sprite.droptobottom = @as(c_int, 1) != 0;
                level.*.object[@as(c_uint, @intCast(j))].sprite.killing = @as(c_int, 1) != 0;
                level.*.object[@as(c_uint, @intCast(j))].sprite.speed_y = 0;
                globals.GRAVITY_FLAG = 4;
                DOWN_ANIMATION(enemySprite);
                enemy.*.counter = 0;
            },
            @as(c_int, 18) => {
                if (@as(c_int, @bitCast(@as(c_uint, enemy.*.dying))) != @as(c_int, 0)) {
                    DEAD1(level, enemy);
                    continue;
                }
                if ((((@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) < @as(c_int, @bitCast(@as(c_int, @as(i16, @bitCast(@as(c_ushort, @truncate(@as(c_uint, @bitCast(enemy.*.init_x)) -% enemy.*.range_x)))))))) or (@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x))) > @as(c_int, @bitCast(@as(c_int, @as(i16, @bitCast(@as(c_ushort, @truncate(@as(c_uint, @bitCast(enemy.*.init_x)) +% enemy.*.range_x))))))))) or (@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y))) < @as(c_int, @bitCast(@as(c_int, @as(i16, @bitCast(@as(c_ushort, @truncate(@as(c_uint, @bitCast(enemy.*.init_y)) -% enemy.*.range_y))))))))) or (@as(c_int, @bitCast(@as(c_int, level.*.player.sprite.y))) > @as(c_int, @bitCast(@as(c_int, @as(i16, @bitCast(@as(c_ushort, @truncate(@as(c_uint, @bitCast(enemy.*.init_y)) +% enemy.*.range_y))))))))) {
                    if (enemy.*.init_x != @as(c_int, @bitCast(@as(c_int, enemySprite.*.x)))) {
                        enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(myabs(@as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x))))))));
                        if (enemy.*.init_x > @as(c_int, @bitCast(@as(c_int, enemySprite.*.x)))) {
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
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
                            enemySprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_int, enemySprite.*.speed_x)))))));
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

fn DEAD1(arg_level: [*c]lvl.TITUS_level, arg_enemy: [*c]lvl.TITUS_enemy) void {
    var level = arg_level;
    _ = &level;
    var enemy = arg_enemy;
    _ = &enemy;
    if (((@as(c_int, @bitCast(@as(c_uint, enemy.*.dying))) & @as(c_int, 1)) != @as(c_int, 0)) or (@as(c_int, @bitCast(@as(c_int, enemy.*.dead_sprite))) == -@as(c_int, 1))) {
        if ((@as(c_int, @bitCast(@as(c_uint, enemy.*.dying))) & @as(c_int, 1)) == @as(c_int, 0)) {
            enemy.*.dying = @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @bitCast(@as(c_uint, enemy.*.dying))) | @as(c_int, 1)))));
            enemy.*.sprite.speed_y = @as(i16, @bitCast(@as(c_short, @truncate(-@as(c_int, 10)))));
            enemy.*.phase = 0;
        }
        if (@as(c_int, @bitCast(@as(c_uint, enemy.*.phase))) != @as(c_int, 255)) {
            enemy.*.sprite.y += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemy.*.sprite.speed_y)))))));
            if (@as(c_int, @bitCast(@as(c_uint, globals.SEECHOC_FLAG))) != @as(c_int, 0)) {
                level.*.player.sprite2.y += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemy.*.sprite.speed_y)))))));
            }
            if (@as(c_int, @bitCast(@as(c_int, enemy.*.sprite.speed_y))) < @as(c_int, 20)) {
                enemy.*.sprite.speed_y += 1;
            }
        }
    } else {
        enemy.*.dying = @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @bitCast(@as(c_uint, enemy.*.dying))) | @as(c_int, 1)))));
        updateenemysprite(level, enemy, enemy.*.dead_sprite, @as(c_int, 0) != 0);
        enemy.*.sprite.flash = @as(c_int, 0) != 0;
        enemy.*.sprite.visible = @as(c_int, 0) != 0;
        enemy.*.sprite.speed_y = 0;
        enemy.*.phase = @as(u8, @bitCast(@as(i8, @truncate(-@as(c_int, 1)))));
    }
}

pub fn updateenemysprite(arg_level: [*c]lvl.TITUS_level, arg_enemy: [*c]lvl.TITUS_enemy, arg_number: i16, arg_clearflags: bool) void {
    var level = arg_level;
    _ = &level;
    var enemy = arg_enemy;
    _ = &enemy;
    var number = arg_number;
    _ = &number;
    var clearflags = arg_clearflags;
    _ = &clearflags;
    sprites.updatesprite(level, &enemy.*.sprite, number, clearflags);
    if ((@as(c_int, @bitCast(@as(c_int, number))) >= @as(c_int, 101)) and (@as(c_int, @bitCast(@as(c_int, number))) <= @as(c_int, 105))) {
        enemy.*.carry_sprite = 105;
    } else if ((@as(c_int, @bitCast(@as(c_int, number))) >= @as(c_int, 126)) and (@as(c_int, @bitCast(@as(c_int, number))) <= @as(c_int, 130))) {
        enemy.*.carry_sprite = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 130)))));
    } else if ((@as(c_int, @bitCast(@as(c_int, number))) >= @as(c_int, 149)) and (@as(c_int, @bitCast(@as(c_int, number))) <= @as(c_int, 153))) {
        enemy.*.carry_sprite = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 149)))));
    } else if ((@as(c_int, @bitCast(@as(c_int, number))) >= @as(c_int, 157)) and (@as(c_int, @bitCast(@as(c_int, number))) <= @as(c_int, 158))) {
        enemy.*.carry_sprite = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 158)))));
    } else if ((@as(c_int, @bitCast(@as(c_int, number))) >= @as(c_int, 159)) and (@as(c_int, @bitCast(@as(c_int, number))) <= @as(c_int, 167))) {
        enemy.*.carry_sprite = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 167)))));
    } else if ((@as(c_int, @bitCast(@as(c_int, number))) >= @as(c_int, 185)) and (@as(c_int, @bitCast(@as(c_int, number))) <= @as(c_int, 191))) {
        enemy.*.carry_sprite = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 186)))));
    } else if ((@as(c_int, @bitCast(@as(c_int, number))) >= @as(c_int, 197)) and (@as(c_int, @bitCast(@as(c_int, number))) <= @as(c_int, 203))) {
        enemy.*.carry_sprite = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 203)))));
    } else {
        enemy.*.carry_sprite = @as(i16, @bitCast(@as(c_short, @truncate(-@as(c_int, 1)))));
    }
    if ((@as(c_int, @bitCast(@as(c_int, number))) >= @as(c_int, 172)) and (@as(c_int, @bitCast(@as(c_int, number))) <= @as(c_int, 184))) {
        enemy.*.dead_sprite = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 184)))));
    } else if ((@as(c_int, @bitCast(@as(c_int, number))) >= @as(c_int, 192)) and (@as(c_int, @bitCast(@as(c_int, number))) <= @as(c_int, 196))) {
        enemy.*.dead_sprite = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 196)))));
    } else if ((@as(c_int, @bitCast(@as(c_int, number))) >= @as(c_int, 210)) and (@as(c_int, @bitCast(@as(c_int, number))) <= @as(c_int, 213))) {
        enemy.*.dead_sprite = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 213)))));
    } else if ((@as(c_int, @bitCast(@as(c_int, number))) >= @as(c_int, 214)) and (@as(c_int, @bitCast(@as(c_int, number))) <= @as(c_int, 220))) {
        enemy.*.dead_sprite = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 220)))));
    } else if ((@as(c_int, @bitCast(@as(c_int, number))) >= @as(c_int, 221)) and (@as(c_int, @bitCast(@as(c_int, number))) <= @as(c_int, 226))) {
        enemy.*.dead_sprite = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 226)))));
    } else if ((@as(c_int, @bitCast(@as(c_int, number))) >= @as(c_int, 242)) and (@as(c_int, @bitCast(@as(c_int, number))) <= @as(c_int, 247))) {
        enemy.*.dead_sprite = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 247)))));
    } else {
        enemy.*.dead_sprite = @as(i16, @bitCast(@as(c_short, @truncate(-@as(c_int, 1)))));
    }
    if (((((((@as(c_int, @bitCast(@as(c_int, number))) >= @as(c_int, 248)) and (@as(c_int, @bitCast(@as(c_int, number))) <= @as(c_int, 251))) or ((@as(c_int, @bitCast(@as(c_int, number))) >= @as(c_int, 252)) and (@as(c_int, @bitCast(@as(c_int, number))) <= @as(c_int, 256)))) or ((@as(c_int, @bitCast(@as(c_int, number))) >= @as(c_int, 257)) and (@as(c_int, @bitCast(@as(c_int, number))) <= @as(c_int, 261)))) or ((@as(c_int, @bitCast(@as(c_int, number))) >= @as(c_int, 263)) and (@as(c_int, @bitCast(@as(c_int, number))) <= @as(c_int, 267)))) or ((@as(c_int, @bitCast(@as(c_int, number))) >= @as(c_int, 284)) and (@as(c_int, @bitCast(@as(c_int, number))) <= @as(c_int, 288)))) or ((@as(c_int, @bitCast(@as(c_int, number))) >= @as(c_int, 329)) and (@as(c_int, @bitCast(@as(c_int, number))) <= @as(c_int, 332)))) {
        enemy.*.boss = @as(c_int, 1) != 0;
    } else {
        enemy.*.boss = @as(c_int, 0) != 0;
    }
}

pub export fn SET_NMI(arg_level: [*c]lvl.TITUS_level) void {
    var level = arg_level;
    _ = &level;
    var i: i16 = undefined;
    _ = &i;
    var k: i16 = undefined;
    _ = &k;
    var hit: i16 = undefined;
    _ = &hit;
    {
        i = 0;
        while (@as(c_int, @bitCast(@as(c_int, i))) < @as(c_int, 50)) : (i += 1) {
            if (!level.*.enemy[@as(c_ushort, @intCast(i))].sprite.enabled) continue;
            level.*.enemy[@as(c_ushort, @intCast(i))].visible = @as(c_int, 0) != 0;
            if (((((@as(c_int, @bitCast(@as(c_int, level.*.enemy[@as(c_ushort, @intCast(i))].sprite.x))) + @as(c_int, 32)) < (@as(c_int, @bitCast(@as(c_int, globals.BITMAP_X))) << @intCast(4))) or ((@as(c_int, @bitCast(@as(c_int, level.*.enemy[@as(c_ushort, @intCast(i))].sprite.x))) - @as(c_int, 32)) > ((@as(c_int, @bitCast(@as(c_int, globals.BITMAP_X))) << @intCast(4)) + (@as(c_int, 20) * @as(c_int, 16))))) or (@as(c_int, @bitCast(@as(c_int, level.*.enemy[@as(c_ushort, @intCast(i))].sprite.y))) < (@as(c_int, @bitCast(@as(c_int, globals.BITMAP_Y))) << @intCast(4)))) or ((@as(c_int, @bitCast(@as(c_int, level.*.enemy[@as(c_ushort, @intCast(i))].sprite.y))) - @as(c_int, 32)) > ((@as(c_int, @bitCast(@as(c_int, globals.BITMAP_Y))) << @intCast(4)) + (@as(c_int, 12) * @as(c_int, 16))))) {
                if ((@as(c_int, @bitCast(@as(c_uint, level.*.enemy[@as(c_ushort, @intCast(i))].dying))) & @as(c_int, 3)) != @as(c_int, 0)) {
                    level.*.enemy[@as(c_ushort, @intCast(i))].sprite.enabled = @as(c_int, 0) != 0;
                }
                continue;
            }
            level.*.enemy[@as(c_ushort, @intCast(i))].visible = @as(c_int, 1) != 0;
            GAL_FORM(level, &level.*.enemy[@as(c_ushort, @intCast(i))]);
            if ((@as(c_int, @bitCast(@as(c_uint, level.*.enemy[@as(c_ushort, @intCast(i))].dying))) & @as(c_int, 3)) != @as(c_int, 0)) {
                continue;
            }
            if ((@as(c_int, @bitCast(@as(c_uint, globals.KICK_FLAG))) == @as(c_int, 0)) and !globals.GODMODE) {
                if (level.*.enemy[@as(c_ushort, @intCast(i))].sprite.invisible) {
                    continue;
                }
                ACTIONC_NMI(level, &level.*.enemy[@as(c_ushort, @intCast(i))]);
            }
            hit = 0;
            if (@as(c_int, @bitCast(@as(c_uint, globals.GRAVITY_FLAG))) != @as(c_int, 0)) {
                {
                    k = 0;
                    while (@as(c_int, @bitCast(@as(c_int, k))) < @as(c_int, 40)) : (k += 1) {
                        if (@as(c_int, @bitCast(@as(c_int, level.*.object[@as(c_ushort, @intCast(k))].sprite.speed_x))) == @as(c_int, 0)) {
                            if (@as(c_int, @bitCast(@as(c_int, level.*.object[@as(c_ushort, @intCast(k))].sprite.speed_y))) == @as(c_int, 0)) {
                                continue;
                            }
                            if (@as(c_int, @bitCast(@as(c_uint, level.*.object[@as(c_ushort, @intCast(k))].momentum))) < @as(c_int, 10)) {
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
            if ((((@as(c_int, @bitCast(@as(c_int, hit))) == @as(c_int, 0)) and (@as(c_int, @intFromBool(globals.DROP_FLAG)) != @as(c_int, 0))) and (@as(c_int, @intFromBool(globals.CARRY_FLAG)) == @as(c_int, 0))) and (@as(c_int, @intFromBool(level.*.player.sprite2.enabled)) != 0)) {
                if (NMI_VS_DROP(&level.*.enemy[@as(c_ushort, @intCast(i))].sprite, &level.*.player.sprite2)) {
                    globals.INVULNERABLE_FLAG = 0;
                    level.*.player.sprite2.enabled = @as(c_int, 0) != 0;
                    SEE_CHOC(level);
                    hit = 2;
                }
            }
            if (@as(c_int, @bitCast(@as(c_int, hit))) != @as(c_int, 0)) {
                if (@as(c_int, @bitCast(@as(c_int, hit))) == @as(c_int, 1)) {
                    if (@as(c_int, @bitCast(@as(c_int, level.*.object[@as(c_ushort, @intCast(k))].sprite.number))) != @as(c_int, 73)) {
                        level.*.object[@as(c_ushort, @intCast(k))].sprite.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_int, level.*.object[@as(c_ushort, @intCast(k))].sprite.speed_x)))))));
                    }
                }
                audio.playEvent(.Event_HitEnemy);
                globals.DROP_FLAG = @as(c_int, 0) != 0;
                if (level.*.enemy[@as(c_ushort, @intCast(i))].boss) {
                    if (@as(c_int, @bitCast(@as(c_uint, globals.INVULNERABLE_FLAG))) != @as(c_int, 0)) {
                        continue;
                    }
                    globals.INVULNERABLE_FLAG = 10;
                    level.*.enemy[@as(c_ushort, @intCast(i))].sprite.flash = @as(c_int, 1) != 0;
                    globals.boss_lives -%= 1;
                    if (@as(c_int, @bitCast(@as(c_uint, globals.boss_lives))) != @as(c_int, 0)) {
                        continue;
                    }
                    globals.boss_alive = @as(c_int, 0) != 0;
                }
                level.*.enemy[@as(c_ushort, @intCast(i))].dying = @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @bitCast(@as(c_uint, level.*.enemy[@as(c_ushort, @intCast(i))].dying))) | @as(c_int, 2)))));
            }
        }
    }
}

fn GAL_FORM(arg_level: [*c]lvl.TITUS_level, arg_enemy: [*c]lvl.TITUS_enemy) void {
    var level = arg_level;
    _ = &level;
    var enemy = arg_enemy;
    _ = &enemy;
    enemy.*.sprite.invisible = @as(c_int, 0) != 0;
    if ((@as(c_int, @bitCast(@as(c_uint, enemy.*.dying))) & @as(c_int, 3)) != @as(c_int, 0)) {
        enemy.*.sprite.visible = @as(c_int, 0) != 0;
        enemy.*.visible = @as(c_int, 1) != 0;
        return;
    }
    enemy.*.trigger = @as(c_int, 0) != 0;
    var animation: [*c]const i16 = enemy.*.sprite.animation;
    _ = &animation;
    while (@as(c_int, @bitCast(@as(c_int, animation.*))) < @as(c_int, 0)) {
        animation += @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, @bitCast(@as(c_int, animation.*)))))));
    }
    if (@as(c_int, @bitCast(@as(c_int, animation.*))) == @as(c_int, 21930)) {
        enemy.*.sprite.invisible = @as(c_int, 1) != 0;
        return;
    }
    enemy.*.trigger = (@as(c_int, @bitCast(@as(c_int, animation.*))) & @as(c_int, 8192)) != 0;
    updateenemysprite(level, enemy, @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_int, animation.*))) & @as(c_int, 255)) + @as(c_int, 101))))), @as(c_int, 1) != 0);
    enemy.*.sprite.flipped = (if (@as(c_int, @bitCast(@as(c_int, enemy.*.sprite.speed_x))) < @as(c_int, 0)) @as(c_int, 1) else @as(c_int, 0)) != 0;
    animation += 1;
    if (@as(c_int, @bitCast(@as(c_int, animation.*))) < @as(c_int, 0)) {
        animation += @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, @bitCast(@as(c_int, animation.*)))))));
    }
    enemy.*.sprite.animation = animation;
    enemy.*.visible = @as(c_int, 1) != 0;
}

fn ACTIONC_NMI(arg_level: [*c]lvl.TITUS_level, arg_enemy: [*c]lvl.TITUS_enemy) void {
    var level = arg_level;
    _ = &level;
    var enemy = arg_enemy;
    _ = &enemy;
    switch (@as(c_int, @bitCast(@as(c_uint, enemy.*.type)))) {
        @as(c_int, 0), @as(c_int, 1), @as(c_int, 2), @as(c_int, 3), @as(c_int, 4), @as(c_int, 5), @as(c_int, 6), @as(c_int, 7), @as(c_int, 8), @as(c_int, 9), @as(c_int, 10), @as(c_int, 11), @as(c_int, 12), @as(c_int, 13), @as(c_int, 14), @as(c_int, 18) => {
            if (NMI_VS_DROP(&enemy.*.sprite, &level.*.player.sprite)) {
                if (@as(c_int, @bitCast(@as(c_uint, enemy.*.type))) != @as(c_int, 11)) {
                    if (@as(c_int, @bitCast(@as(c_int, enemy.*.sprite.number))) != @as(c_int, 178)) {
                        enemy.*.sprite.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_int, enemy.*.sprite.speed_x)))))));
                    }
                }
                if ((@as(c_int, @bitCast(@as(c_int, enemy.*.sprite.number))) >= (@as(c_int, 101) + @as(c_int, 53))) and (@as(c_int, @bitCast(@as(c_int, enemy.*.sprite.number))) <= (@as(c_int, 101) + @as(c_int, 55)))) {
                    globals.GRANDBRULE_FLAG = @as(c_int, 1) != 0;
                }
                if (@as(c_int, @bitCast(@as(c_int, enemy.*.power))) != @as(c_int, 0)) {
                    KICK_ASH(level, &enemy.*.sprite, enemy.*.power);
                }
            }
        },
        else => {},
    }
}

fn KICK_ASH(arg_level: [*c]lvl.TITUS_level, arg_enemysprite: [*c]lvl.TITUS_sprite, arg_power: i16) void {
    var level = arg_level;
    _ = &level;
    var enemysprite = arg_enemysprite;
    _ = &enemysprite;
    var power = arg_power;
    _ = &power;
    audio.playEvent(.Event_HitPlayer);
    var p_sprite: [*c]lvl.TITUS_sprite = &level.*.player.sprite;
    _ = &p_sprite;
    player.DEC_ENERGY(level);
    player.DEC_ENERGY(level);
    globals.KICK_FLAG = 24;
    globals.CHOC_FLAG = 0;
    globals.LAST_ORDER = 0;
    p_sprite.*.speed_x = power;
    if (@as(c_int, @bitCast(@as(c_int, p_sprite.*.x))) <= @as(c_int, @bitCast(@as(c_int, enemysprite.*.x)))) {
        p_sprite.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 0) - @as(c_int, @bitCast(@as(c_int, p_sprite.*.speed_x)))))));
    }
    p_sprite.*.speed_y = @as(i16, @bitCast(@as(c_short, @truncate(-@as(c_int, 8) * @as(c_int, 16)))));
    _ = player.player_drop_carried(level);
}

fn NMI_VS_DROP(enemysprite: *lvl.TITUS_sprite, arg_sprite: *lvl.TITUS_sprite) bool {
    var sprite = arg_sprite;
    _ = &sprite;
    if (myabs(@as(c_int, @bitCast(@as(c_int, sprite.*.x))) - @as(c_int, @bitCast(@as(c_int, enemysprite.*.x)))) >= @as(c_int, 64)) {
        return @as(c_int, 0) != 0;
    }
    if (myabs(@as(c_int, @bitCast(@as(c_int, sprite.*.y))) - @as(c_int, @bitCast(@as(c_int, enemysprite.*.y)))) >= @as(c_int, 70)) {
        return @as(c_int, 0) != 0;
    }
    if (@as(c_int, @bitCast(@as(c_int, sprite.*.y))) < @as(c_int, @bitCast(@as(c_int, enemysprite.*.y)))) {
        if (@as(c_int, @bitCast(@as(c_int, sprite.*.y))) <= ((@as(c_int, @bitCast(@as(c_int, enemysprite.*.y))) - @as(c_int, @bitCast(@as(c_uint, enemysprite.*.spritedata.*.collheight)))) + @as(c_int, 3))) return @as(c_int, 0) != 0;
    } else {
        if (@as(c_int, @bitCast(@as(c_int, enemysprite.*.y))) <= ((@as(c_int, @bitCast(@as(c_int, sprite.*.y))) - @as(c_int, @bitCast(@as(c_uint, sprite.*.spritedata.*.collheight)))) + @as(c_int, 3))) return @as(c_int, 0) != 0;
    }
    var enemyleft: i16 = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemysprite.*.x))) - @as(c_int, @bitCast(@as(c_uint, enemysprite.*.spritedata.*.refwidth)))))));
    _ = &enemyleft;
    var objectleft: i16 = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, sprite.*.x))) - @as(c_int, @bitCast(@as(c_uint, sprite.*.spritedata.*.refwidth)))))));
    _ = &objectleft;
    if (@as(c_int, @bitCast(@as(c_int, enemyleft))) >= @as(c_int, @bitCast(@as(c_int, objectleft)))) {
        if ((@as(c_int, @bitCast(@as(c_int, objectleft))) + (@as(c_int, @bitCast(@as(c_uint, sprite.*.spritedata.*.collwidth))) >> @intCast(1))) <= @as(c_int, @bitCast(@as(c_int, enemyleft)))) {
            return @as(c_int, 0) != 0;
        }
    } else {
        if ((@as(c_int, @bitCast(@as(c_int, enemyleft))) + (@as(c_int, @bitCast(@as(c_uint, enemysprite.*.spritedata.*.collwidth))) >> @intCast(1))) <= @as(c_int, @bitCast(@as(c_int, objectleft)))) {
            return @as(c_int, 0) != 0;
        }
    }
    return @as(c_int, 1) != 0;
}

pub fn SEE_CHOC(arg_level: [*c]lvl.TITUS_level) void {
    var level = arg_level;
    _ = &level;
    sprites.updatesprite(level, &level.*.player.sprite2, @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 30) + @as(c_int, 15))))), @as(c_int, 1) != 0);
    level.*.player.sprite2.speed_x = 0;
    level.*.player.sprite2.speed_y = 0;
    globals.SEECHOC_FLAG = 5;
}

pub fn moveTrash(arg_level: *lvl.TITUS_level) void {
    var level = arg_level;
    _ = &level;
    var tmp: i16 = undefined;
    _ = &tmp;
    {
        for (&level.trash) |*trash| {
            if (!trash.enabled) continue;
            if (@as(c_int, @bitCast(@as(c_int, trash.speed_x))) != @as(c_int, 0)) {
                trash.x += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, trash.speed_x))) >> @intCast(4)))));
                tmp = @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_int, trash.x))) >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_X)))))));
                if ((@as(c_int, @bitCast(@as(c_int, tmp))) < @as(c_int, 0)) or (@as(c_int, @bitCast(@as(c_int, tmp))) > @as(c_int, 20))) {
                    trash.enabled = @as(c_int, 0) != 0;
                    continue;
                }
                if (@as(c_int, @bitCast(@as(c_int, tmp))) != @as(c_int, 0)) {
                    trash.y += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, trash.speed_y))) >> @intCast(4)))));
                    tmp = @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_int, trash.y))) >> @intCast(4)) - @as(c_int, @bitCast(@as(c_int, globals.BITMAP_Y)))))));
                    if ((@as(c_int, @bitCast(@as(c_int, tmp))) < @as(c_int, 0)) or (@as(c_int, @bitCast(@as(c_int, tmp))) > (@as(c_int, 12) * @as(c_int, 16)))) {
                        trash.enabled = @as(c_int, 0) != 0;
                        continue;
                    }
                }
            }
            if (!globals.GODMODE and (@as(c_int, @intFromBool(NMI_VS_DROP(trash, &level.*.player.sprite))) != 0)) {
                trash.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, trash.speed_x)))))));
                KICK_ASH(level, trash, @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 70))))));
                trash.enabled = @as(c_int, 0) != 0;
                continue;
            }
        }
    }
}

fn FIND_TRASH(arg_level: [*c]lvl.TITUS_level) [*c]lvl.TITUS_sprite {
    var level = arg_level;
    _ = &level;
    var i: c_int = undefined;
    _ = &i;
    {
        i = 0;
        while (i < @as(c_int, 4)) : (i += 1) {
            if (@as(c_int, @intFromBool(level.*.trash[@as(c_uint, @intCast(i))].enabled)) == @as(c_int, 0)) {
                return &level.*.trash[@as(c_uint, @intCast(i))];
            }
        }
    }
    return null;
}

fn PUT_BULLET(arg_level: [*c]lvl.TITUS_level, arg_enemy: [*c]lvl.TITUS_enemy, arg_bullet: [*c]lvl.TITUS_sprite) void {
    var level = arg_level;
    _ = &level;
    var enemy = arg_enemy;
    _ = &enemy;
    var bullet = arg_bullet;
    _ = &bullet;
    bullet.*.x = enemy.*.sprite.x;
    bullet.*.y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, enemy.*.sprite.y))) - @as(c_int, @bitCast(@as(c_int, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, @bitCast(@as(c_int, (enemy.*.sprite.animation - @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 1)))))).*))) & @as(c_int, 255))))))))))));
    sprites.updatesprite(level, bullet, @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_int, (enemy.*.sprite.animation - @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 2)))))).*))) & @as(c_int, 8191)) + @as(c_int, 30))))), @as(c_int, 1) != 0);
    if (@as(c_int, @bitCast(@as(c_int, enemy.*.sprite.x))) < @as(c_int, @bitCast(@as(c_int, level.*.player.sprite.x)))) {
        bullet.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 16) * @as(c_int, 11)))));
        bullet.*.flipped = @as(c_int, 1) != 0;
    } else {
        bullet.*.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(-@as(c_int, 16) * @as(c_int, 11)))));
        bullet.*.flipped = @as(c_int, 0) != 0;
    }
    bullet.*.speed_y = 0;
    bullet.*.x += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, bullet.*.speed_x))) >> @intCast(4)))));
}
