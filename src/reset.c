/*   
 * Copyright (C) 2008 - 2011 The OpenTitus team
 *
 * Authors:
 * Eirik Stople
 *
 * "Titus the Fox: To Marrakech and Back" (1992) and
 * "Lagaf': Les Aventures de Moktar - Vol 1: La Zoubida" (1991)
 * was developed by, and is probably copyrighted by Titus Software,
 * which, according to Wikipedia, stopped buisness in 2005.
 *
 * OpenTitus is not affiliated with Titus Software.
 *
 * OpenTitus is  free software; you can redistribute  it and/or modify
 * it under the  terms of the GNU General  Public License as published
 * by the Free  Software Foundation; either version 3  of the License,
 * or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT  ANY  WARRANTY;  without   even  the  implied  warranty  of
 * MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.   See the GNU
 * General Public License for more details.
 */

/* reset.c
 * Reset level functions
 */

#include <stdio.h>
#include <stdlib.h>
#include "SDL2/SDL.h"
#include "globals_old.h"
#include "sprites.h"
#include "draw.h"
#include "reset.h"
#include "level.h"
#include "scroll.h"
#include "original.h"
#include "tituserror.h"
#include "game.h"
#include "player.h"
#include "objects.h"
#include "enemies.h"
#include "audio.h"
#include "keyboard.h"
#include "window.h"

static void MOVE_HIM(TITUS_level *level, TITUS_sprite *spr);
static void SET_ALL_SPRITES(TITUS_level *level);

//Possible return states:

//0 - No action
//1 - New level
//2 - Game over
//3 - Death


uint8_t RESET_LEVEL(ScreenContext *context, TITUS_level *level) {
    TITUS_player *player = &(level->player);
    bool pass;
    int16_t i;
    SDL_Event event;
    int retval;
    if (NEWLEVEL_FLAG) {
        return 1;
    }
    if (GAMEOVER_FLAG) {
        return 2;
    }
    if (RESETLEVEL_FLAG == 1) {
        return 3;
    }
    if (level->levelid == 16) {
        BITMAP_X = 0;
        NOSCROLL_FLAG = true;
        //Prepare Titus/Moktar
        updatesprite(level, &(player->sprite), 343, true);
        player->sprite.x = -100;
        player->sprite.y = 180;
        player->sprite.animation = anim_moktar;
        //Prepare Zoubida
        updatesprite(level, &(player->sprite2), 337, true);
        player->sprite2.x = 420;
        player->sprite2.y = 180;
        player->sprite2.animation = anim_zoubida;
        do {
            //Animate tiles
            scroll(level);
            //Move Titus/Moktar
            player->sprite.x += 3;
            MOVE_HIM(level, &(player->sprite));
            //Move Zoubida
            player->sprite2.x -= 3;
            MOVE_HIM(level, &(player->sprite2));
            //View all
            draw_tiles(level);
            draw_sprites(level);
            flip_screen(context, true);
        } while (player->sprite2.x > player->sprite.x + 28);
        //Lovers in one sprite
        updatesprite(level, &(player->sprite2), 346, true);

        player->sprite2.flipped = true;
        player->sprite2.x -= 24;
        //Smoke
        player->sprite.animation = anim_smoke;
        player->sprite.y -= 16;
        for (i = 0; i < 16; i++) {
            MOVE_HIM(level, &(player->sprite));
            scroll(level);
            draw_tiles(level);
            draw_sprites(level);
            flip_screen(context, true);
            player->sprite.y++;
        }
        //Display hearts
        updatesprite(level, &(player->sprite), 355, true);
        int16_t heart_animation[] = {
            153,142,153,142,153,142,
            139,148,139,148,139,148,
            139,162,139,162,139,162,
            152,171,152,171,152,171,
            171,165,171,165,171,165,
            170,147,170,147,170,147,
            -12*3
        };
        int16_t *heart = &heart_animation[0];
        pass = false;
        do {
            if (*heart < 0) {
                heart += *heart; //jump back
            }
            player->sprite.x = *heart;
            heart++;
            player->sprite.y = *heart;
            heart++;

            scroll(level);
            draw_tiles(level);
            draw_sprites(level);
            flip_screen(context, true);

            SDL_PumpEvents(); //Update keyboard state

            while(SDL_PollEvent(&event)) { //Check all events
                if (event.type == SDL_QUIT) {
                    return TITUS_ERROR_QUIT;
                } else if (event.type == SDL_KEYDOWN) {
                    if (event.key.keysym.scancode == KEY_ESC) {
                        return TITUS_ERROR_QUIT;
                    } else if (event.key.keysym.scancode == KEY_FULLSCREEN) {
                        window_toggle_fullscreen();
                    } else if (event.key.keysym.scancode == KEY_RETURN || event.key.keysym.scancode == KEY_ENTER || event.key.keysym.scancode == KEY_SPACE) {
                        pass = true;
                        break;
                    }
                }

            }

        } while (!pass);
        //Display THE END
        //THE
        updatesprite(level, &(player->sprite), 335, true);
        player->sprite.x = (BITMAP_X << 4) - (120-2);
        player->sprite.y = (BITMAP_Y << 4) + 100;
        //END
        updatesprite(level, &(player->sprite3), 336, true);
        player->sprite3.x = (BITMAP_X << 4) + (320+120-2);
        player->sprite3.y = (BITMAP_Y << 4) + 100;
        for (i = 0; i < 31; i++) {
            draw_tiles(level);
            draw_sprites(level);
            flip_screen(context, true);
            player->sprite.x += 8;
            player->sprite3.x -= 8;
        }
        retval = waitforbutton();
        if (retval < 0)
            return retval;
        NEWLEVEL_FLAG = true;
        return 3;
    }
    return 0;
}


void MOVE_HIM(TITUS_level *level, TITUS_sprite *spr) {
    int16_t *pointer = spr->animation + 1;
    while (*pointer < 0) {
        pointer += *pointer; //End of animation, jump back
    }
    updatesprite(level, spr, *pointer, true);
    spr->animation = pointer;
}

void SET_DATA_NMI(TITUS_level *level) {
    boss_alive = false;
    int i, anim;
    for (i = 0; i < ENEMY_CAPACITY; i++) {
        anim = -1;
        if (!level->enemy[i].init_enabled) continue;
        do {
            anim++;
        } while (anim_enemy[anim] + FIRST_NMI != level->enemy[i].sprite.number);
        level->enemy[i].sprite.animation = &(anim_enemy[anim]);
        if (level->enemy[i].boss) {
            boss_alive = true;
        }
    }
    boss_lives = NMI_POWER[level->levelid];
}

void CLEAR_DATA(TITUS_level *level) {
    loop_cycle = 0;
    tile_anim = 0;
    IMAGE_COUNTER = 0;
    TAUPE_FLAG = 0;
    GRANDBRULE_FLAG = 0;
    NOSCROLL_FLAG = 0;
    TAPISWAIT_FLAG = 0;
    TAPISFLY_FLAG = 0;
    FUME_FLAG = 0;
    BAR_FLAG = 0;
    X_FLAG = 0;
    Y_FLAG = 0;
    CARRY_FLAG = 0;
    DROP_FLAG = 0;
    DROPREADY_FLAG = 0;
    POSEREADY_FLAG = 0;
    LADDER_FLAG = false;
    PRIER_FLAG = 0;
    SAUT_FLAG = 0;
    CROSS_FLAG = 0;
    FURTIF_FLAG = 0;
    CHOC_FLAG = 0;
    KICK_FLAG = 0;
    SEECHOC_FLAG = 0;
    RESETLEVEL_FLAG = 0;
    LOSELIFE_FLAG = 0;
    GAMEOVER_FLAG = false;
    NEWLEVEL_FLAG = false;
    SKIPLEVEL_FLAG = false;
    INVULNERABLE_FLAG = 0;
    POCKET_FLAG = 0;
    SAUT_COUNT = 0;
    ACTION_TIMER = 0;
    g_scroll_x = 0;
    g_scroll_y = 0;
    g_scroll_y_target = 0;
    g_scroll_px_offset = 0;
    YFALL = 0;

    GRAVITY_FLAG = 4;
    SENSX = 0;
    LAST_ORDER = 0;

    SET_ALL_SPRITES(level);

    SET_DATA_NMI(level);

}

void clearsprite(TITUS_sprite *spr){
    spr->enabled = false;
    spr->x = 0;
    spr->y = 0;
    spr->speed_x = 0;
    spr->speed_y = 0;
    spr->number = 0;
    spr->UNDER = 0;
    spr->ONTOP = NULL;
    spr->spritedata = NULL;
    spr->flipped = false;
    spr->flash = false;
    spr->visible = false;
    spr->animation = NULL;
    spr->droptobottom = false;
    spr->killing = false;
    spr->invisible = false;
}


void SET_ALL_SPRITES(TITUS_level *level) {
    int16_t i;
    TITUS_player *player = &(level->player);

    for (i = 0; i < TRASH_CAPACITY; i++) {
        clearsprite(&(level->trash[i]));
    }

    for (i = 0; i < ENEMY_CAPACITY; i++) {
        clearsprite(&(level->enemy[i].sprite));
        level->enemy[i].dying = 0;
        level->enemy[i].carry_sprite = -1;
        level->enemy[i].dead_sprite = -1;
        level->enemy[i].phase = 0;
        level->enemy[i].counter = 0;
        level->enemy[i].trigger = false;
        level->enemy[i].visible = false;
        if (level->enemy[i].init_enabled) {
            updateenemysprite(level, &(level->enemy[i]), level->enemy[i].init_sprite, true);
            level->enemy[i].sprite.flipped = level->enemy[i].init_flipped;
            level->enemy[i].sprite.x = level->enemy[i].init_x;
            level->enemy[i].sprite.y = level->enemy[i].init_y;
            level->enemy[i].sprite.speed_x = level->enemy[i].init_speed_x;
            level->enemy[i].sprite.speed_y = level->enemy[i].init_speed_y;
        }
    }

    for (i = 0; i < ELEVATOR_CAPACITY; i++) {
        clearsprite(&(level->elevator[i].sprite));
        if (level->elevator[i].init_enabled) {
            updatesprite(level, &(level->elevator[i].sprite), level->elevator[i].init_sprite, true);
            level->elevator[i].sprite.visible = level->elevator[i].init_visible;
            level->elevator[i].sprite.flash = level->elevator[i].init_flash;
            level->elevator[i].sprite.flipped = level->elevator[i].init_flipped;
            level->elevator[i].sprite.x = level->elevator[i].init_x;
            level->elevator[i].sprite.y = level->elevator[i].init_y;
            level->elevator[i].counter = 0;
            level->elevator[i].sprite.speed_x = level->elevator[i].init_speed_x;
            level->elevator[i].sprite.speed_y = level->elevator[i].init_speed_y;
        }
    }

    for (i = 0; i < OBJECT_CAPACITY; i++) {
        clearsprite(&(level->object[i].sprite));
        level->object[i].momentum = 0;
        if (level->object[i].init_enabled) {
            updateobjectsprite(level, &(level->object[i]), level->object[i].init_sprite, true);
            level->object[i].sprite.visible = level->object[i].init_visible;
            level->object[i].sprite.flash = level->object[i].init_flash;
            level->object[i].sprite.flipped = level->object[i].init_flipped;
            level->object[i].sprite.x = level->object[i].init_x;
            level->object[i].sprite.y = level->object[i].init_y;
            if ((player->cageY != 0) &&
              ((level->object[i].sprite.number == FIRST_OBJET + 26) || (level->object[i].sprite.number == FIRST_OBJET + 27))) {
                level->object[i].sprite.x = player->cageX;
                level->object[i].sprite.y = player->cageY;
            }
        }
    }
    GRAVITY_FLAG = 4;
    clearsprite(&(player->sprite));
    clearsprite(&(player->sprite2));
    clearsprite(&(player->sprite3));

    player->sprite.x = player->initX;
    player->sprite.y = player->initY;
    level->player.hp = level->player.inithp;
    level->player.animcycle = 0;
    updatesprite(level, &(level->player.sprite), 0, true);
}
