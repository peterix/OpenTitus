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

const globals = @import("globals.zig");
const lvl = @import("level.zig");
const sprites = @import("sprites.zig");
const objects = @import("objects.zig");
const enemies = @import("enemies.zig");
const data = @import("data.zig");

fn SET_DATA_NMI(level: *lvl.Level) void {
    globals.boss_alive = false;
    for (0..lvl.ENEMY_CAPACITY) |i| {
        var anim: usize = 0;
        if (!level.enemy[i].init_enabled) {
            continue;
        }
        while (data.anim_enemy[anim] + globals.FIRST_NMI != level.enemy[i].sprite.number) {
            anim += 1;
        }
        level.enemy[i].sprite.animation = &(data.anim_enemy[anim]);
        if (level.enemy[i].boss) {
            globals.boss_alive = true;
        }
    }
    globals.boss_lives = level.boss_power;
}

pub fn CLEAR_DATA(level: *lvl.Level) void {
    globals.loop_cycle = 0;
    globals.tile_anim = 0;
    globals.IMAGE_COUNTER = 0;
    globals.TAUPE_FLAG = 0;
    globals.GRANDBRULE_FLAG = false;
    globals.NOSCROLL_FLAG = false;
    globals.TAPISWAIT_FLAG = 0;
    globals.TAPISFLY_FLAG = 0;
    globals.FUME_FLAG = 0;
    globals.BAR_FLAG = 0;
    globals.CARRY_FLAG = false;
    globals.DROP_FLAG = false;
    globals.DROPREADY_FLAG = false;
    globals.POSEREADY_FLAG = false;
    globals.LADDER_FLAG = false;
    globals.low_ceiling = false;
    globals.jump_timer = 0;
    globals.CROSS_FLAG = 0;
    globals.FURTIF_FLAG = 0;
    globals.CHOC_FLAG = 0;
    globals.KICK_FLAG = 0;
    globals.SEECHOC_FLAG = 0;
    globals.RESETLEVEL_FLAG = 0;
    globals.LOSELIFE_FLAG = false;
    globals.GAMEOVER_FLAG = false;
    globals.NEWLEVEL_FLAG = false;
    globals.SKIPLEVEL_FLAG = false;
    globals.INVULNERABLE_FLAG = 0;
    globals.POCKET_FLAG = false;
    globals.jump_acceleration_counter = 0;
    globals.ACTION_TIMER = 0;
    globals.g_scroll_x = false;
    globals.g_scroll_y = false;
    globals.g_scroll_y_target = 0;
    globals.g_scroll_px_offset = 0;
    globals.YFALL = 0;

    globals.GRAVITY_FLAG = 4;
    globals.SENSX = 0;
    globals.LAST_ORDER = .Rest;

    SET_ALL_SPRITES(level);

    SET_DATA_NMI(level);
}

fn clearsprite(spr: *lvl.Sprite) void {
    spr.enabled = false;
    spr.x = 0;
    spr.y = 0;
    spr.speed_x = 0;
    spr.speed_y = 0;
    spr.number = 0;
    spr.UNDER = 0;
    spr.ONTOP = null;
    spr.spritedata = null;
    spr.flipped = false;
    spr.invincibility_frames = 0;
    spr.flash = false;
    spr.visible = false;
    spr.animation = null;
    spr.droptobottom = false;
    spr.killing = false;
    spr.invisible = false;
}

fn SET_ALL_SPRITES(level: *lvl.Level) void {
    var player = &level.player;

    for (0..lvl.TRASH_CAPACITY) |i| {
        clearsprite(&(level.trash[i]));
    }

    for (0..lvl.ENEMY_CAPACITY) |i| {
        clearsprite(&(level.enemy[i].sprite));
        level.enemy[i].dying = 0;
        level.enemy[i].carry_sprite = -1;
        level.enemy[i].dead_sprite = -1;
        level.enemy[i].phase = 0;
        level.enemy[i].counter = 0;
        level.enemy[i].trigger = false;
        level.enemy[i].visible = false;
        if (level.enemy[i].init_enabled) {
            enemies.updateenemysprite(level, &(level.enemy[i]), @intCast(level.enemy[i].init_sprite), true);
            level.enemy[i].sprite.flipped = level.enemy[i].init_flipped;
            level.enemy[i].sprite.x = @truncate(level.enemy[i].init_x);
            level.enemy[i].sprite.y = @truncate(level.enemy[i].init_y);
            level.enemy[i].sprite.speed_x = @truncate(level.enemy[i].init_speed_x);
            level.enemy[i].sprite.speed_y = @truncate(level.enemy[i].init_speed_y);
        }
    }

    for (0..lvl.ELEVATOR_CAPACITY) |i| {
        clearsprite(&(level.elevator[i].sprite));
        if (level.elevator[i].init_enabled) {
            sprites.updatesprite(level, &(level.elevator[i].sprite), @intCast(level.elevator[i].init_sprite), true);
            level.elevator[i].sprite.visible = level.elevator[i].init_visible;
            level.elevator[i].sprite.flash = level.elevator[i].init_flash;
            level.elevator[i].sprite.flipped = level.elevator[i].init_flipped;
            level.elevator[i].sprite.x = @truncate(level.elevator[i].init_x);
            level.elevator[i].sprite.y = @truncate(level.elevator[i].init_y);
            level.elevator[i].counter = 0;
            level.elevator[i].sprite.speed_x = level.elevator[i].init_speed_x;
            level.elevator[i].sprite.speed_y = level.elevator[i].init_speed_y;
        }
    }

    for (0..lvl.OBJECT_CAPACITY) |i| {
        clearsprite(&(level.object[i].sprite));
        level.object[i].momentum = 0;
        if (level.object[i].init_enabled) {
            objects.updateobjectsprite(level, &(level.object[i]), @intCast(level.object[i].init_sprite), true);
            level.object[i].sprite.visible = level.object[i].init_visible;
            level.object[i].sprite.flash = level.object[i].init_flash;
            level.object[i].sprite.flipped = level.object[i].init_flipped;
            level.object[i].sprite.x = @truncate(level.object[i].init_x);
            level.object[i].sprite.y = @truncate(level.object[i].init_y);
            if ((player.cageY != 0) and
                ((level.object[i].sprite.number == globals.FIRST_OBJET + 26) or (level.object[i].sprite.number == globals.FIRST_OBJET + 27)))
            {
                level.object[i].sprite.x = player.cageX;
                level.object[i].sprite.y = player.cageY;
            }
        }
    }
    globals.GRAVITY_FLAG = 4;
    clearsprite(&(player.sprite));
    clearsprite(&(player.sprite2));
    clearsprite(&(player.sprite3));

    player.sprite.x = player.initX;
    player.sprite.y = player.initY;
    level.player.hp = level.player.inithp;
    level.player.animcycle = 0;
    sprites.updatesprite(level, &(level.player.sprite), 0, true);
}
