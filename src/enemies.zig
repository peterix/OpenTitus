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

// enemies.zig
// Handles enemies.
//
// Global functions:
// void moveEnemies(Level *level): Move enemies, is called by main game loop
// void SET_NMI(Level *level): Collision detection, animation, is called by main game loop
// void moveTrash(Level *level): Move objects thrown by enemies
//

const common = @import("common.zig");
const objects = @import("objects.zig");
const sprites = @import("sprites.zig");
const player = @import("player.zig");
const globals = @import("globals.zig");
const lvl = @import("level.zig");
const audio = @import("audio/audio.zig");
const events = @import("events.zig");

// FIXME: zig changes the type of the result when you call @abs. That's probably correct, but it's annoying. This keeps the type the same.
pub inline fn abs(a: anytype) @TypeOf(a) {
    if (a < 0)
        return -a;
    return a;
}

fn UP_ANIMATION(sprite: *lvl.Sprite) void {
    while (true) {
        sprite.animation += 1;
        if (sprite.animation.* < 0)
            break;
    }
    sprite.animation += 1;
}

fn DOWN_ANIMATION(sprite: *lvl.Sprite) void {
    while (true) {
        sprite.animation -= 1;
        if (sprite.animation.* < 0)
            break;
    }
    sprite.animation -= 1;
}

fn ai_noclip_walk(level: *lvl.Level, enemy: *lvl.Enemy) void {
    const enemySprite = &enemy.sprite;
    if (enemy.dying != 0) { //If true, the enemy is dying or dead, and have special movement
        DEAD1(level, enemy);
        return;
    }
    enemySprite.x -= enemySprite.speed_x; //Move the enemy
    if (abs(enemySprite.x - enemy.center_x) > enemy.range_x) { //If the enemy is range_x from center, turn direction
        if (enemySprite.x >= enemy.center_x) { //The enemy is at rightmost edge
            enemySprite.speed_x = abs(enemySprite.speed_x);
        } else { //The enemy is at leftmost edge
            enemySprite.speed_x = -abs(enemySprite.speed_x);
        }
    }
}

fn ai_shoot(level: *lvl.Level, enemy: *lvl.Enemy) void {
    const enemySprite = &enemy.sprite;
    if (enemy.dying != 0) {
        DEAD1(level, enemy);
        return;
    }
    if (!enemy.visible) {
        return;
    }
    if (enemy.direction == 0) {
        enemySprite.speed_x = 0;
        if (enemySprite.x < level.player.sprite.x) {
            enemySprite.speed_x = -1;
        }
    } else if (enemy.direction == 2) {
        enemySprite.speed_x = -1;
    } else {
        enemySprite.speed_x = 0;
    }
    switch (enemy.phase) {
        0 => {
            //Scans the horizon!
            //Decrease delay timer
            common.subto0(&enemy.counter);
            if (enemy.counter != 0) {
                return;
            }
            if (abs(level.player.sprite.y - enemySprite.y) > 24) {
                return;
            }
            // if too far apart
            if (enemy.range_x < abs(level.player.sprite.x - enemySprite.x)) {
                return;
            }
            if (enemy.direction != 0) {
                // Skip shooting if player is in the opposite direction
                if (enemy.direction == 2) {
                    // Right only
                    if (enemySprite.x > level.player.sprite.x) {
                        return;
                    }
                } else {
                    // Left only
                    if (level.player.sprite.x > enemySprite.x) {
                        return;
                    }
                }
            }
            enemy.phase = 30; // change state
            UP_ANIMATION(enemySprite);
        },
        else => {
            enemy.phase -= 1;
            if (!enemy.trigger) {
                return;
            }
            enemySprite.animation += 2;
            if (FIND_TRASH(level)) |bullet| {
                PUT_BULLET(level, enemy, bullet);
                // enemy->counter = NMI_FREQ; //set delay timer
                enemy.counter = @truncate(enemy.delay); // set delay timer
            }
            enemy.phase = 0;
        },
    }
}

fn ai_jumping_fish(level: *lvl.Level, enemy: *lvl.Enemy) void {
    if (enemy.dying != 0) {
        DEAD1(level, enemy);
        return;
    }

    const enemySprite = &enemy.sprite;
    switch (enemy.phase) {
        0 => {
            // Move the enemy
            enemySprite.x -= enemySprite.speed_x;
            // If the enemy is range_x from center, turn direction
            if (abs(enemySprite.x - enemy.center_x) > enemy.range_x) {
                if (enemySprite.x >= enemy.center_x) {
                    enemySprite.speed_x = abs(enemySprite.speed_x);
                } else {
                    enemySprite.speed_x = -abs(enemySprite.speed_x);
                }
            }
            if (!enemy.visible) {
                return;
            }
            // Skip if player is below or >= 256 pixels above
            if (enemySprite.y < level.player.sprite.y or enemySprite.y >= level.player.sprite.y + 256) {
                return;
            }
            // Skip if player is above jump limit
            if (enemy.range_y < enemySprite.y - level.player.sprite.y) {
                return;
            }
            // see if the hero is in the direction of movement of fish
            if (enemySprite.x > level.player.sprite.x) {
                // The enemy is right for the player
                if (enemySprite.flipped) {
                    // The enemy looks right, skip
                    return;
                }
            } else {
                // The enemy is left for the player
                if (!enemySprite.flipped) {
                    // The enemy looks left, skip
                    return;
                }
            }
            // Fast calculation
            if (abs(enemySprite.x - level.player.sprite.x) >= 48) {
                return;
            }
            // See if the hero is outside the area of fish
            if (abs(level.player.sprite.x - enemy.center_x) > enemy.range_x) {
                return;
            }
            enemy.phase = 1; // Change state
            enemySprite.speed_y = 0;
            // Calculation speed to the desired height
            // Make sure the enemy will jump high enough to hit the player
            var j: i32 = 0;
            while (true) {
                enemySprite.speed_y += 1;
                j += enemySprite.speed_y;
                if ((enemySprite.y - level.player.sprite.y) <= j)
                    break;
            }
            // Init speed must be negative
            enemySprite.speed_y = -enemySprite.speed_y;
            enemy.saved_y = enemySprite.y;
            UP_ANIMATION(enemySprite);
        },
        1 => {
            // Is the enemy on the screen?
            if (!enemy.visible) {
                return;
            }
            enemySprite.x -= enemySprite.speed_x << 2;
            enemySprite.y += enemySprite.speed_y;
            if (enemySprite.speed_y + 1 < 0) {
                enemySprite.speed_y += 1;
                if (enemySprite.y > (enemy.saved_y -% @as(i16, @intCast(enemy.range_y)))) {
                    return;
                }
            }
            UP_ANIMATION(enemySprite);
            enemy.phase = 2;
            enemySprite.speed_y = 0;
            if (enemySprite.x <= enemy.center_x) {
                enemySprite.speed_x = abs(enemySprite.speed_x);
            } else {
                enemySprite.speed_x = -abs(enemySprite.speed_x);
            }
        },
        2 => {
            // Is the enemy on the screen?
            if (!enemy.visible) {
                return;
            }
            enemySprite.x -= enemySprite.speed_x;
            enemySprite.y += enemySprite.speed_y; // 2: fall!
            enemySprite.speed_y += 1;
            // 3: we hit bottom?
            if (enemySprite.y < enemy.saved_y) {
                return;
            }
            enemySprite.y = enemy.saved_y;
            enemySprite.x -= enemySprite.speed_x;
            enemy.phase = 0;
            DOWN_ANIMATION(enemySprite);
            DOWN_ANIMATION(enemySprite);
        },
        else => {},
    }
}

fn ai_swooping_fly(level: *lvl.Level, enemy: *lvl.Enemy) void {
    if (enemy.dying != 0) {
        DEAD1(level, enemy);
        return;
    }
    const enemySprite = &enemy.sprite;

    // Move the enemy
    enemySprite.x -= enemySprite.speed_x;

    // If the enemy is range_x from center, turn direction
    if (abs(enemySprite.x - enemy.center_x) > enemy.range_x) {
        if (enemySprite.x >= enemy.center_x) {
            enemySprite.speed_x = abs(enemySprite.speed_x);
        } else {
            enemySprite.speed_x = 0 - abs(enemySprite.speed_x);
        }
    }
    if (!enemy.visible) {
        return;
    }
    switch (enemy.phase) {
        0 => {
            // Forward
            if (abs(enemySprite.y - level.player.sprite.y) > enemy.range_y) { // Too far away
                return;
            }
            if (abs(enemySprite.x - level.player.sprite.x) > 40) { // Too far away
                return;
            }
            enemy.saved_y = enemySprite.y;
            if (enemySprite.y < level.player.sprite.y) { // Player is below the enemy
                enemySprite.speed_y = 2;
            } else { // Player is above the enemy
                enemySprite.speed_y = -2;
            }
            enemy.phase = 1; // Change state
            UP_ANIMATION(enemySprite);
        },
        1 => {
            // Attack
            enemySprite.y += enemySprite.speed_y;
            if (abs(enemySprite.y - enemy.saved_y) < enemy.range_y) {
                return;
            }
            enemySprite.speed_y = 0 - enemySprite.speed_y;
            UP_ANIMATION(enemySprite);
            enemy.phase = 2;
        },
        2 => {
            // Back up!
            enemySprite.y += enemySprite.speed_y;
            if (enemySprite.y != enemy.saved_y) {
                return;
            }
            DOWN_ANIMATION(enemySprite);
            DOWN_ANIMATION(enemySprite);
            enemy.phase = 0;
        },
        else => {},
    }
}

/// Walk towards the player
fn facePlayer(level: *const lvl.Level, enemy: *lvl.Enemy) void {
    if (enemy.sprite.x > level.player.sprite.x) {
        enemy.sprite.speed_x = enemy.walkspeed_x;
    } else {
        enemy.sprite.speed_x = -@as(i16, enemy.walkspeed_x);
    }
}

/// Walk back towards where the enemy started
fn faceStart(enemy: *lvl.Enemy) void {
    enemy.sprite.speed_x = abs(enemy.sprite.speed_x);
    if (enemy.init_x > enemy.sprite.x) {
        enemy.sprite.speed_x = -enemy.sprite.speed_x;
    }
}

/// Is there a wall in the next tile in the direction the enemy walks?
fn wallAhead(level: *const lvl.Level, sprite: *const lvl.Sprite) bool {
    // NOTE: positive speed moves left
    const direction: i16 = if (sprite.speed_x > 0) -1 else 1;
    return level.getTileWall((sprite.x >> 4) + direction, (sprite.y >> 4) - 1).isSolid();
}

/// Move horizontally, turning around at the left edge of the level
fn walk(sprite: *lvl.Sprite) void {
    sprite.x -= sprite.speed_x;
    if (sprite.x < 0) {
        sprite.speed_x = -sprite.speed_x;
        sprite.x -= sprite.speed_x;
    }
}

/// Walk, falling down when there is no floor. Returns true while falling.
fn gravityWalk(level: *const lvl.Level, enemy: *lvl.Enemy) bool {
    const sprite = &enemy.sprite;
    if (level.getTileFloor(sprite.x >> 4, sprite.y >> 4) == .NoFloor) {
        if (sprite.speed_y < 16) { // 16 = Max yspeed
            sprite.speed_y += 1;
        }
        sprite.y += sprite.speed_y;
        return true;
    }
    if (sprite.speed_y != 0) {
        // Just landed
        facePlayer(level, enemy);
    }
    sprite.speed_y = 0;
    sprite.y = common.alignToTile(sprite.y);
    if (wallAhead(level, sprite)) {
        sprite.speed_x = -sprite.speed_x;
    }
    walk(sprite);
    return false;
}

/// Is the place where the enemy started within the given number of tiles from the top left of the screen?
fn startOnScreen(enemy: *const lvl.Enemy, rows: i16, columns: i16) bool {
    const row = (enemy.init_y >> 4) - globals.BITMAP_Y;
    const column = (enemy.init_x >> 4) - globals.BITMAP_X;
    return row >= 0 and row < rows and column >= 0 and column < columns;
}

fn resetToStart(enemy: *lvl.Enemy) void {
    enemy.sprite.x = enemy.init_x;
    enemy.sprite.y = enemy.init_y;
}

/// Pop out of the ground (or attack) when the animation says so
fn popUp(level: *lvl.Level, enemy: *lvl.Enemy) void {
    if (!enemy.visible) {
        UP_ANIMATION(&enemy.sprite);
        enemy.sprite.animation -= 1;
        GAL_FORM(level, enemy);
        facePlayer(level, enemy);
        enemy.phase = 1;
    } else if (enemy.trigger) {
        facePlayer(level, enemy);
        enemy.phase = 1;
    }
}

pub fn moveEnemies(level: *lvl.Level) void {
    enemy_loop: for (&level.enemy) |*enemy| {
        const enemySprite = &enemy.sprite;
        if (!enemySprite.enabled) {
            continue :enemy_loop;
        }
        const player_dx = abs(level.player.sprite.x - enemySprite.x);
        const player_dy = abs(level.player.sprite.y - enemySprite.y);
        switch (enemy.type) {
            0, 1 => ai_noclip_walk(level, enemy),
            2 => ai_shoot(level, enemy),
            3, 4 => ai_jumping_fish(level, enemy),
            5, 6 => ai_swooping_fly(level, enemy),
            // Gravity walk, hit when near
            7 => {
                if (enemy.dying != 0) {
                    DEAD1(level, enemy);
                    continue :enemy_loop;
                }
                switch (enemy.phase) {
                    0 => {
                        if (enemySprite.y > level.player.sprite.y) {
                            continue :enemy_loop;
                        }
                        if (enemy.range_x < player_dx) {
                            continue :enemy_loop;
                        }
                        if (player_dy > 200) {
                            continue :enemy_loop;
                        }
                        enemy.phase = 1;
                        UP_ANIMATION(enemySprite);
                        facePlayer(level, enemy);
                    },
                    1 => {
                        if (gravityWalk(level, enemy)) {
                            continue :enemy_loop;
                        }
                        const dx = abs(level.player.sprite.x - enemySprite.x);
                        const dy = abs(level.player.sprite.y - enemySprite.y);
                        if (dx > 320 * 2 or dy >= 200 * 2) {
                            enemy.phase = 2;
                            continue :enemy_loop;
                        }
                        if (dx > @as(i16, enemySprite.spritedata.?.width) + 6) {
                            continue :enemy_loop;
                        }
                        if (dy > 8) {
                            continue :enemy_loop;
                        }
                        enemy.phase = 3;
                        UP_ANIMATION(enemySprite);
                    },
                    2 => {
                        if (startOnScreen(enemy, 14, 21)) {
                            continue :enemy_loop;
                        }
                        resetToStart(enemy);
                        enemy.phase = 0;
                        DOWN_ANIMATION(enemySprite);
                    },
                    3 => {
                        // Strike!
                        if (enemy.trigger) { // End of strike animation (TODO: check if this will ever be executed)
                            enemy.phase = 1;
                            continue :enemy_loop;
                        }
                        if (gravityWalk(level, enemy)) {
                            continue :enemy_loop;
                        }
                        const dx = abs(level.player.sprite.x - enemySprite.x);
                        const dy = abs(level.player.sprite.y - enemySprite.y);
                        if (dx > 320 * 2 or dy >= 200 * 2) {
                            enemy.phase = 2;
                            continue :enemy_loop;
                        }
                    },
                    else => {},
                }
            },
            8, // Gravity walk when off-screen
            14, // Gravity walk when off-screen (immortal)
            => {
                if (enemy.type == 14) {
                    enemy.dying = 0;
                } else if (enemy.dying != 0) {
                    DEAD1(level, enemy);
                    continue :enemy_loop;
                }
                switch (enemy.phase) {
                    0 => {
                        if (player_dx > 340 or player_dy >= 230) {
                            enemy.phase = 1;
                            UP_ANIMATION(enemySprite);
                            facePlayer(level, enemy);
                        }
                    },
                    1 => {
                        if (gravityWalk(level, enemy)) {
                            continue :enemy_loop;
                        }
                        if (abs(level.player.sprite.x - enemySprite.x) < 320 * 2) {
                            continue :enemy_loop;
                        }
                        enemy.phase = 2;
                    },
                    2 => {
                        if (startOnScreen(enemy, 12, 19)) {
                            continue :enemy_loop;
                        }
                        resetToStart(enemy);
                        enemy.phase = 0;
                        DOWN_ANIMATION(enemySprite);
                    },
                    else => {},
                }
            },
            // Walk and periodically pop-up
            9 => {
                if (enemy.dying != 0) {
                    DEAD1(level, enemy);
                    continue :enemy_loop;
                }
                switch (enemy.phase) {
                    0 => {
                        if (enemy.range_x < player_dx) {
                            continue :enemy_loop;
                        }
                        if (player_dy > 60) {
                            continue :enemy_loop;
                        }
                        enemy.phase = 1;
                        UP_ANIMATION(enemySprite);
                        facePlayer(level, enemy);
                    },
                    1 => {
                        globals.TAUPE_FLAG +%= 1;
                        if ((globals.TAUPE_FLAG & 4) == 0 and (globals.IMAGE_COUNTER & 511) == 0) {
                            UP_ANIMATION(enemySprite);
                        }
                        if ((globals.IMAGE_COUNTER & 127) == 0) {
                            enemy.phase = 3;
                            UP_ANIMATION(enemySprite);
                            popUp(level, enemy);
                            continue :enemy_loop;
                        }
                        // Walk back at the edge of a platform
                        if (level.getTileFloor(enemySprite.x >> 4, enemySprite.y >> 4) == .NoFloor) {
                            faceStart(enemy);
                        }
                        enemySprite.y = common.alignToTile(enemySprite.y);
                        if (wallAhead(level, enemySprite)) {
                            enemySprite.speed_x = -enemySprite.speed_x;
                        }
                        walk(enemySprite);
                        if (abs(level.player.sprite.x - enemySprite.x) < 320 * 4) {
                            continue :enemy_loop;
                        }
                        enemy.phase = 2;
                    },
                    2 => {
                        if (startOnScreen(enemy, 13, 25)) {
                            continue :enemy_loop;
                        }
                        resetToStart(enemy);
                        enemy.phase = 0;
                        DOWN_ANIMATION(enemySprite);
                    },
                    3 => popUp(level, enemy),
                    else => {},
                }
            },
            // Alert when near, walk when nearer
            10 => {
                if (enemy.dying != 0) {
                    DEAD1(level, enemy);
                    continue :enemy_loop;
                }
                switch (enemy.phase) {
                    0 => {
                        if (globals.FURTIF_FLAG != 0) {
                            continue :enemy_loop;
                        }
                        if (enemy.range_x < player_dx) {
                            continue :enemy_loop;
                        }
                        if (player_dy > 26) {
                            continue :enemy_loop;
                        }
                        enemy.phase = 1;
                        UP_ANIMATION(enemySprite);
                        facePlayer(level, enemy);
                        if (globals.FURTIF_FLAG != 0) {
                            continue :enemy_loop;
                        }
                        if (enemy.range_x < player_dx) {
                            DOWN_ANIMATION(enemySprite);
                            enemy.phase = 0;
                            continue :enemy_loop;
                        }
                        // NOTE: wraps around for ranges under 50, which makes the enemy run whenever it is alerted
                        if (enemy.range_x -% 50 >= player_dx and player_dy <= 60) {
                            enemy.phase = 2;
                            UP_ANIMATION(enemySprite);
                        }
                    },
                    1 => {
                        // wait
                        if (globals.FURTIF_FLAG != 0) {
                            continue :enemy_loop;
                        }
                        if (enemy.range_x < player_dx) {
                            DOWN_ANIMATION(enemySprite);
                            enemy.phase = 0;
                            continue :enemy_loop;
                        }
                        if (enemy.range_x -% 50 >= player_dx and player_dy <= 60) {
                            enemy.phase = 2;
                            UP_ANIMATION(enemySprite);
                        }
                    },
                    2 => {
                        // run
                        if (level.getTileFloor(enemySprite.x >> 4, enemySprite.y >> 4) == .NoFloor) {
                            faceStart(enemy);
                        }
                        enemySprite.y = common.alignToTile(enemySprite.y);
                        if (wallAhead(level, enemySprite)) {
                            faceStart(enemy);
                        }
                        walk(enemySprite);
                        if (abs(level.player.sprite.x - enemySprite.x) >= 320 * 2) {
                            enemy.phase = 3;
                        }
                    },
                    3 => {
                        if (startOnScreen(enemy, 14, 21)) {
                            continue :enemy_loop;
                        }
                        resetToStart(enemy);
                        DOWN_ANIMATION(enemySprite);
                        DOWN_ANIMATION(enemySprite);
                        enemy.phase = 0;
                    },
                    else => {},
                }
            },
            // Walk and shoot
            11 => {
                if (enemy.dying != 0) {
                    DEAD1(level, enemy);
                    continue :enemy_loop;
                }
                switch (enemy.phase) {
                    0 => {
                        if (enemy.range_x < player_dx) {
                            continue :enemy_loop;
                        }
                        if (player_dy > 26) {
                            continue :enemy_loop;
                        }
                        enemy.phase = 1;
                        UP_ANIMATION(enemySprite);
                        facePlayer(level, enemy);
                    },
                    1 => {
                        if (level.getTileFloor(enemySprite.x >> 4, enemySprite.y >> 4) == .NoFloor) {
                            faceStart(enemy);
                        }
                        enemySprite.y = common.alignToTile(enemySprite.y);
                        // NOTE: unlike the other walking enemies, this one checks for walls in its own tile
                        if (level.getTileWall(enemySprite.x >> 4, (enemySprite.y >> 4) - 1).isSolid()) {
                            enemySprite.speed_x = -enemySprite.speed_x;
                        }
                        walk(enemySprite);
                        const dx = abs(level.player.sprite.x - enemySprite.x);
                        if (dx >= 320 * 2) {
                            enemy.phase = 2;
                        }
                        common.subto0(&enemy.counter);
                        if (enemy.counter != 0) {
                            continue :enemy_loop;
                        }
                        if (dx > 64) {
                            continue :enemy_loop;
                        }
                        if (abs(level.player.sprite.y - enemySprite.y) > 20) {
                            continue :enemy_loop;
                        }
                        facePlayer(level, enemy);
                        enemy.phase = 3;
                        UP_ANIMATION(enemySprite);
                        enemy.counter = 20;
                    },
                    2 => {
                        if (!startOnScreen(enemy, 14, 21)) {
                            resetToStart(enemy);
                            DOWN_ANIMATION(enemySprite);
                            enemy.phase = 0;
                        }
                    },
                    3 => {
                        if (!enemy.trigger) {
                            continue :enemy_loop;
                        }
                        if (FIND_TRASH(level)) |bullet| {
                            enemySprite.animation += 2;
                            PUT_BULLET(level, enemy, bullet);
                        }
                        DOWN_ANIMATION(enemySprite);
                        enemy.phase = 1;
                    },
                    else => {},
                }
            },
            // Jump (fireball) (immortal)
            12 => {
                enemy.dying = 0;
                switch (enemy.phase) {
                    0 => {
                        UP_ANIMATION(enemySprite);
                        enemySprite.speed_y = @bitCast(enemy.range_y);
                        enemy.init_y = enemySprite.y;
                        enemy.phase = 1;
                    },
                    1 => {
                        enemySprite.y -= enemySprite.speed_y;
                        enemySprite.speed_y -= 1;
                        if (enemySprite.speed_y == 0) {
                            enemy.phase = 2;
                        }
                    },
                    2 => {
                        enemySprite.y += enemySprite.speed_y;
                        enemySprite.speed_y += 1;
                        if (enemySprite.y >= enemy.init_y) {
                            enemySprite.y = enemy.init_y;
                            enemy.counter = @truncate(enemy.delay);
                            enemy.phase = 3;
                            DOWN_ANIMATION(enemySprite);
                        }
                    },
                    3 => {
                        enemy.counter -%= 1;
                        if (enemy.counter == 0) {
                            enemy.phase = 0;
                        }
                    },
                    else => {},
                }
            },
            // Bounce (big baby)
            13 => {
                if (enemy.dying != 0) {
                    DEAD1(level, enemy);
                    continue :enemy_loop;
                }
                switch (enemy.phase) {
                    0 => {
                        if (level.player.sprite.x >= enemySprite.x) {
                            enemySprite.speed_x = -abs(enemySprite.speed_x);
                        } else {
                            enemySprite.speed_x = abs(enemySprite.speed_x);
                        }
                        if (player_dx <= enemy.range_x and player_dy <= 40) {
                            UP_ANIMATION(enemySprite);
                            enemy.phase = 1;
                            enemySprite.speed_y = 10;
                        }
                    },
                    1 => {
                        enemySprite.x -= enemySprite.speed_x;
                        enemySprite.y -= enemySprite.speed_y;
                        enemySprite.speed_y -= 1;
                        if (enemySprite.speed_y == 0) {
                            UP_ANIMATION(enemySprite);
                            enemy.phase = 2;
                        }
                    },
                    2 => {
                        enemySprite.x -= enemySprite.speed_x;
                        enemySprite.y += enemySprite.speed_y;
                        enemySprite.speed_y += 1;
                        if (enemySprite.speed_y > 10) {
                            enemy.phase = 3;
                            UP_ANIMATION(enemySprite);
                            enemy.counter = @truncate(enemy.delay);
                        }
                    },
                    3 => {
                        enemy.counter -%= 1;
                        if (enemy.counter == 0) {
                            DOWN_ANIMATION(enemySprite);
                            DOWN_ANIMATION(enemySprite);
                            DOWN_ANIMATION(enemySprite);
                            enemy.phase = 0;
                        }
                    },
                    else => {},
                }
            },
            // Nothing (immortal)
            15 => {
                enemy.dying = 0;
            },
            // Nothing
            16 => {
                if (enemy.dying != 0) {
                    DEAD1(level, enemy);
                    continue :enemy_loop;
                }
            },
            // Drop (immortal)
            17 => {
                enemy.dying = 0;
                // Delay
                if (@as(u32, enemy.counter) + 1 < enemy.delay) {
                    enemy.counter +%= 1;
                    continue :enemy_loop;
                }
                if (enemy.range_x < player_dx) { // hero too far! at x
                    enemy.counter = 0;
                    continue :enemy_loop;
                }
                // hero too far! at y (or above the enemy)
                const below = level.player.sprite.y - enemySprite.y;
                if (below < 0 or enemy.range_y < below) {
                    continue :enemy_loop;
                }
                // Find a free object to drop
                // NOTE: the original never uses the first object and reads past the end of the list when it's full
                const dropped = for (level.object[1..]) |*object| {
                    if (!object.sprite.enabled) {
                        break object;
                    }
                } else {
                    enemy.counter = 0;
                    continue :enemy_loop;
                };
                UP_ANIMATION(enemySprite);
                objects.updateobjectsprite(level, dropped, enemySprite.animation.* & 0x1FFF, true);
                dropped.sprite.flipped = true;
                dropped.sprite.x = enemySprite.x;
                dropped.sprite.y = enemySprite.y;
                dropped.sprite.droptobottom = true;
                dropped.sprite.killing = true;
                dropped.sprite.speed_y = 0;
                globals.GRAVITY_FLAG = 4;
                DOWN_ANIMATION(enemySprite);
                enemy.counter = 0;
            },
            // Guard (helicopter guy)
            18 => {
                if (enemy.dying != 0) {
                    DEAD1(level, enemy);
                    continue :enemy_loop;
                }
                if (abs(enemy.init_x - level.player.sprite.x) > enemy.range_x or
                    abs(enemy.init_y - level.player.sprite.y) > enemy.range_y)
                {
                    // The player is too far away, move enemy to center
                    if (enemy.init_x != enemySprite.x) {
                        enemySprite.speed_x = abs(enemySprite.speed_x);
                        if (enemy.init_x > enemySprite.x) {
                            enemySprite.speed_x = -enemySprite.speed_x;
                        }
                        enemySprite.x -= enemySprite.speed_x;
                    }
                    if (enemy.init_y != enemySprite.y) {
                        if (enemy.init_y > enemySprite.y) {
                            enemySprite.y += enemySprite.speed_y;
                        } else {
                            enemySprite.y -= enemySprite.speed_y;
                        }
                    }
                } else {
                    // The player is inside the guarded area, move enemy to player
                    if (level.player.sprite.x != enemySprite.x) {
                        enemySprite.speed_x = abs(enemySprite.speed_x);
                        if (level.player.sprite.x > enemySprite.x) {
                            enemySprite.speed_x = -enemySprite.speed_x;
                        }
                        enemySprite.x -= enemySprite.speed_x;
                    }
                    if (level.player.sprite.y != enemySprite.y) {
                        if (level.player.sprite.y > enemySprite.y) {
                            enemySprite.y += enemySprite.speed_y;
                        } else {
                            enemySprite.y -= enemySprite.speed_y;
                        }
                    }
                }
            },
            else => {},
        }
    }
}

fn DEAD1(level: *lvl.Level, enemy: *lvl.Enemy) void {
    if (enemy.dying & 0x01 != 0 or enemy.dead_sprite == -1) {
        if (enemy.dying & 0x01 == 0) {
            enemy.dying = enemy.dying | 0x01;
            enemy.sprite.speed_y = -10;
            enemy.phase = 0;
        }
        if (enemy.phase != 0xFF) {
            enemy.sprite.y += enemy.sprite.speed_y;
            if (globals.SEECHOC_FLAG != 0) {
                level.player.sprite2.y += enemy.sprite.speed_y;
            }
            if (enemy.sprite.speed_y < globals.MAX_SPEED_DEAD) {
                enemy.sprite.speed_y += 1;
            }
        }
    } else {
        enemy.dying = enemy.dying | 0x01;
        updateenemysprite(level, enemy, enemy.dead_sprite, false);
        enemy.sprite.flash = false;
        enemy.sprite.visible = false;
        enemy.sprite.speed_y = 0;
        enemy.phase = 0xFF;
    }
}

pub fn updateenemysprite(level: *lvl.Level, enemy: *lvl.Enemy, number: i16, clearflags: bool) void {
    sprites.updatesprite(level, &enemy.sprite, number, clearflags);
    if ((number >= 101) and (number <= 105)) { // Walking man
        enemy.carry_sprite = 105;
    } else if ((number >= 126) and (number <= 130)) { // Fly
        enemy.carry_sprite = 130;
    } else if ((number >= 149) and (number <= 153)) { // Skeleton
        enemy.carry_sprite = 149;
    } else if ((number >= 157) and (number <= 158)) { // Worm
        enemy.carry_sprite = 158;
    } else if ((number >= 159) and (number <= 167)) { // Guy with sword
        enemy.carry_sprite = 167;
    } else if ((number >= 185) and (number <= 191)) { // Zombie
        enemy.carry_sprite = 186;
    } else if ((number >= 197) and (number <= 203)) { // Woman with pot
        enemy.carry_sprite = 203;
    } else {
        enemy.carry_sprite = -1;
    }
    if ((number >= 172) and (number <= 184)) { // Periscope
        enemy.dead_sprite = 184;
    } else if ((number >= 192) and (number <= 196)) { // Camel
        enemy.dead_sprite = 196;
    } else if ((number >= 210) and (number <= 213)) { // Old man with TV
        enemy.dead_sprite = 213;
    } else if ((number >= 214) and (number <= 220)) { // Snake in pot
        enemy.dead_sprite = 220;
    } else if ((number >= 221) and (number <= 226)) { // Man throwing knives
        enemy.dead_sprite = 226;
    } else if ((number >= 242) and (number <= 247)) { // Carnivorous plant in pot
        enemy.dead_sprite = 247;
    } else {
        enemy.dead_sprite = -1;
    }
    if (((number >= 248) and (number <= 251)) or // Man throwing rocks (3rd level)
        ((number >= 252) and (number <= 256)) or // Big baby (11th level)
        ((number >= 257) and (number <= 261)) or // Big woman (7th level)
        ((number >= 263) and (number <= 267)) or // Big man (15th level on Moktar only)
        ((number >= 284) and (number <= 288)) or // Mummy (9th level)
        ((number >= 329) and (number <= 332))) { // Ax man (5th level)
        enemy.boss = true;
    } else {
        enemy.boss = false;
    }
}

pub fn SET_NMI(level: *lvl.Level) void {
    // Clear enemy sprites
    // If an enemy is on the screen
    //  - Set bit 13
    //  - Animate
    //  - Collision with player
    //    - Lose life and fly
    //  - Collision with object
    //    - Decrease enemy's life
    for (&level.enemy) |*enemy| {
        // Skip unused enemies
        if (!enemy.sprite.enabled)
            continue;
        enemy.visible = false;

        // Is the enemy on the screen?
        const screen_left = globals.BITMAP_X << 4;
        const screen_top = globals.BITMAP_Y << 4;
        if (enemy.sprite.x + 32 < screen_left or
            enemy.sprite.x - 32 > screen_left + 20 * 16 or
            enemy.sprite.y < screen_top or
            enemy.sprite.y - 32 > screen_top + 12 * 16)
        {
            // If the enemy is dying or dead and not on the screen, remove from the list!
            if ((enemy.dying & 3) != 0) {
                enemy.sprite.enabled = false;
            }
            continue;
        }
        enemy.visible = true;
        // Animation
        GAL_FORM(level, enemy);
        if ((enemy.dying & 3) != 0) {
            continue;
        }
        if (globals.KICK_FLAG == 0 and level.player.sprite.invincibility_frames == 0 and !globals.GODMODE) {
            if (enemy.sprite.invisible) {
                continue;
            }
            ACTIONC_NMI(level, enemy);
        }

        // Hit by a falling or moving object?
        var hit_object: ?*lvl.Object = null;
        if (globals.GRAVITY_FLAG != 0) {
            // NOTE: this doesn't skip disabled objects
            for (&level.object) |*object| {
                if (object.sprite.speed_x == 0) {
                    if (object.sprite.speed_y == 0) {
                        continue;
                    }
                    if (object.momentum < 10) {
                        continue;
                    }
                }
                if (object.objectdata.no_damage) {
                    continue;
                }
                if (NMI_VS_DROP(&enemy.sprite, &object.sprite)) {
                    hit_object = object;
                    break;
                }
            }
        }
        // Hit by a thrown object?
        var hit_by_throw = false;
        if (hit_object == null and globals.DROP_FLAG and !globals.CARRY_FLAG and level.player.sprite2.enabled) {
            if (NMI_VS_DROP(&enemy.sprite, &level.player.sprite2)) {
                globals.INVULNERABLE_FLAG = 0;
                level.player.sprite2.enabled = false;
                SEE_CHOC(level);
                hit_by_throw = true;
            }
        }
        if (hit_object == null and !hit_by_throw) {
            continue;
        }
        if (hit_object) |object| {
            if (object.sprite.number != 73) {
                object.sprite.speed_x = -object.sprite.speed_x;
            }
        }
        events.triggerEvent(.HitEnemy);
        globals.DROP_FLAG = false;
        if (enemy.boss) {
            if (globals.INVULNERABLE_FLAG != 0) {
                continue;
            }
            globals.INVULNERABLE_FLAG = 10;
            enemy.sprite.flash = true;
            globals.boss_lives -%= 1;
            if (globals.boss_lives != 0) {
                continue;
            }
            globals.boss_alive = false;
        }
        enemy.dying |= 2;
    }
}

/// Follow the enemy's animation script: set its sprite, and find out if it's invisible or triggers an attack
fn GAL_FORM(level: *lvl.Level, enemy: *lvl.Enemy) void {
    enemy.sprite.invisible = false;
    if ((enemy.dying & 0x03) != 0) {
        enemy.sprite.visible = false;
        enemy.visible = true;
        return;
    }
    enemy.trigger = false;
    // Negative values in the script jump back
    var animation = enemy.sprite.animation;
    while (animation.* < 0) {
        animation -= @as(usize, @intCast(-animation.*));
    }
    if (animation.* == 0x55AA) {
        enemy.sprite.invisible = true;
        return;
    }
    enemy.trigger = (animation.* & 0x2000) != 0;
    updateenemysprite(level, enemy, (animation.* & 0x00FF) + globals.FIRST_NMI, true);
    enemy.sprite.flipped = enemy.sprite.speed_x < 0;
    animation += 1;
    if (animation.* < 0) {
        animation -= @as(usize, @intCast(-animation.*));
    }
    enemy.sprite.animation = animation;
    enemy.visible = true;
}

// Player <-> Enemy collision
fn ACTIONC_NMI(level: *lvl.Level, enemy: *lvl.Enemy) void {
    switch (enemy.type) {
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 18 => {
            if (NMI_VS_DROP(&enemy.sprite, &level.player.sprite)) {
                if (enemy.type != 11) { // Walk and shoot
                    if (enemy.sprite.number != 178) { // Periscope
                        enemy.sprite.speed_x = -enemy.sprite.speed_x;
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

/// The player gets hit and knocked back
fn KICK_ASH(level: *lvl.Level, enemysprite: *lvl.Sprite, power: i16) void {
    events.triggerEvent(.HitPlayer);
    const p_sprite = &level.player.sprite;

    // about 2 seconds worth of invulnereability frames
    p_sprite.invincibility_frames = 69;

    player.DEC_ENERGY(level);
    player.DEC_ENERGY(level);
    globals.KICK_FLAG = 24;
    globals.CHOC_FLAG = 0;
    globals.LAST_ORDER = .Rest;
    p_sprite.speed_x = power;

    if (p_sprite.x <= enemysprite.x) {
        p_sprite.speed_x = -p_sprite.speed_x;
    }
    p_sprite.speed_y = -8 * 16;
    _ = player.player_drop_carried(level);
}

fn NMI_VS_DROP(enemysprite: *lvl.Sprite, sprite: *lvl.Sprite) bool {
    if (abs(sprite.x - enemysprite.x) >= 64) {
        return false;
    }
    if (abs(sprite.y - enemysprite.y) >= 70) {
        return false;
    }
    if (sprite.y < enemysprite.y) {
        // Enemy is below the offending object
        if (sprite.y <= enemysprite.y - enemysprite.spritedata.?.collheight + 3)
            return false;
    } else {
        // Offending object is below the enemy
        if (enemysprite.y <= sprite.y - sprite.spritedata.?.collheight + 3)
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

pub fn SEE_CHOC(level: *lvl.Level) void {
    sprites.updatesprite(level, &level.player.sprite2, globals.FIRST_OBJET + 15, true); // Hit (a throw hits an enemy)
    level.player.sprite2.speed_x = 0;
    level.player.sprite2.speed_y = 0;
    globals.SEECHOC_FLAG = 5;
}

pub fn moveTrash(level: *lvl.Level) void {
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
        if (!globals.GODMODE and level.player.sprite.invincibility_frames == 0 and NMI_VS_DROP(trash, &level.player.sprite)) {
            trash.x -= trash.speed_x;
            KICK_ASH(level, trash, 70);
            trash.enabled = false;
            continue;
        }
    }
}

fn FIND_TRASH(level: *lvl.Level) ?*lvl.Sprite {
    for (&level.trash) |*trash| {
        if (!trash.enabled) {
            return trash;
        }
    }
    return null;
}

fn PUT_BULLET(level: *lvl.Level, enemy: *lvl.Enemy, bullet: *lvl.Sprite) void {
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
    events.triggerEvent(.EnemyShoot);
}
