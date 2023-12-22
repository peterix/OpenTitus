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

/* scroll.c
 * Scroll functions
 */

#include <stdio.h>
#include <stdlib.h>
#include "SDL2/SDL.h"
#include "level.h"
#include "globals_old.h"
#include "window.h"
#include "scroll.h"

#include <stdbool.h>
#include <stdint.h>

static float clamp(float x, float lowerlimit, float upperlimit) {
    if (x < lowerlimit)
        x = lowerlimit;
    if (x > upperlimit)
        x = upperlimit;
    return x;
}

static uint16_t clampi16(uint16_t x, uint16_t lowerlimit, uint16_t upperlimit) {
    if (x < lowerlimit)
        x = lowerlimit;
    if (x > upperlimit)
        x = upperlimit;
    return x;
}

static float smootherstep(float edge0, float edge1, float x) {
    // Scale, and clamp x to 0..1 range
    x = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    // Evaluate polynomial
    return x * x * x * (x * (x * 6 - 15) + 10);
}

static void X_ADJUST(TITUS_level *level) {
    TITUS_player *player = &(level->player);
    g_scroll_x = true;

    int16_t player_position = player->sprite.x;

    // determine where we want the camera to be
    int16_t right_limit;
    if(player_position > XLIMIT * 16 || XLIMIT_BREACHED) {
        XLIMIT_BREACHED = true;
        right_limit = (level->width * 16 - 160);
    } else {
        right_limit = (XLIMIT * 16 - 160);
    }

    int16_t left_camera_limit = clampi16(player_position - 60, 160, right_limit) ;
    int16_t right_camera_limit = clampi16(player_position + 60, 160, right_limit) ;

    int16_t camera_target;
    if(level->player.sprite.flipped) {
        camera_target = left_camera_limit;
    } else {
        camera_target = right_camera_limit;
    }


    int16_t camera_position = camera_target;
    
    // un-breach XLIMIT if we go one screen to the left of it
    if(XLIMIT_BREACHED && camera_position < XLIMIT * 16 - 160) {
        XLIMIT_BREACHED = false;
    }

    /*
    static float camera_offset = 0.0f;
    float target_camera_offset;
    if (!level->player.sprite.flipped)  {
        target_camera_offset = 60.0f;
    }
    else {
        target_camera_offset = -60.0f;
    }
    if(camera_offset < target_camera_offset) {
        camera_offset += 3.0;
    }
    else if(camera_offset > target_camera_offset) {
        camera_offset -= 3.0;
    }

    int real_camera_offset = smootherstep(-60.0, 60.0, camera_offset) * 120 - 60;
    fprintf(stderr, "CAMERA %f, real %d\n", camera_offset, real_camera_offset);

    // clamp camera position to level bounds
    int16_t camera_position = player_position + real_camera_offset;

    // left side of the map
    if(camera_position < 160) {
        camera_position = 160;
    }

    if(camera_position > rlimit || player_position > rlimit) {
        camera_position = rlimit;
    }
    */

    int16_t camera_screen_px = camera_position - BITMAP_X * 16;
    int16_t scroll_px_target = 160;
    int16_t scroll_offset_x = scroll_px_target - camera_screen_px;
    int16_t tile_offset_x = scroll_offset_x / 16;
    int16_t px_offset_x = scroll_offset_x % 16;
    if(tile_offset_x < 0) {
        BITMAP_X ++;
        g_scroll_px_offset = px_offset_x;
        g_scroll_x = true;
    }
    else if (tile_offset_x > 0) {
        BITMAP_X --;
        g_scroll_px_offset = px_offset_x;
        g_scroll_x = true;
    }
    else {
        g_scroll_px_offset = scroll_offset_x;
        g_scroll_x = false;
    }
}

static void Y_ADJUST(TITUS_level *level) {
    TITUS_player *player = &(level->player);
    if (player->sprite.speedY == 0) {
        g_scroll_y = false;
    }
    int16_t pstileY = (player->sprite.y >> 4) - BITMAP_Y; //Player screen tile Y (0 to 11)
    if (!g_scroll_y) {
        if ((player->sprite.speedY == 0) &&
          (LADDER_FLAG == 0)) {
            if (pstileY >= screen_height - 1) {
                g_scroll_y_target = screen_height - 2;
                g_scroll_y = true;
            } else if (pstileY <= 2) {
                g_scroll_y_target = screen_height - 3;
                g_scroll_y = true;
            }
        } else {
            if (pstileY >= screen_height - 2) { //The player is at the bottom of the screen, scroll down!
                g_scroll_y_target = 3;
                g_scroll_y = true;
            } else if (pstileY <= 2) { //The player is at the top of the screen, scroll up!
                g_scroll_y_target = screen_height - 3;
                g_scroll_y = true;
            }
        }
    }

    if ((player->sprite.y <= ((ALTITUDE_ZERO + screen_height) << 4)) && //If the player is above the horizontal limit
      (BITMAP_Y > ALTITUDE_ZERO + 1)) { //... and the screen have scrolled below the the horizontal limit
        if (U_SCROLL(level)) { //Scroll up
            g_scroll_y = false;
        }
    } else if ((BITMAP_Y > ALTITUDE_ZERO - 5) && //If the screen is less than 5 tiles above the horizontal limit
      (BITMAP_Y <= ALTITUDE_ZERO) && //... and still above the horizontal limit
      (player->sprite.y + (7 * 16) > ((ALTITUDE_ZERO + screen_height) << 4))) {
        if (D_SCROLL(level)) { //Scroll down
            g_scroll_y = false;
        }
    } else if (g_scroll_y) {
        if (g_scroll_y_target == pstileY) {
            g_scroll_y = false;
        } else if (g_scroll_y_target > pstileY) {
            if (U_SCROLL(level)) {
                g_scroll_y = false;
            }
        } else if ((player->sprite.y <= ((ALTITUDE_ZERO + screen_height) << 4)) && //If the player is above the horizontal limit
          (BITMAP_Y > ALTITUDE_ZERO)) { //... and the screen is below the horizontal limit
            g_scroll_y = false; //Stop scrolling
        } else {
            if (D_SCROLL(level)) { //Scroll down
                g_scroll_y = false;
            }
        }
    }
}

void scroll(TITUS_level *level) {
    //Scroll screen and update tile animation
    loop_cycle++; //Cycle from 0 to 3
    if (loop_cycle > 3) {
        loop_cycle = 0;
    }
    if (loop_cycle == 0) { //Every 4th call
        tile_anim++; //Cycle tile animation (0-1-2)
        if (tile_anim > 2) {
            tile_anim = 0;
        }
    }
    //Scroll
    if (!NOSCROLL_FLAG) {
        X_ADJUST(level);
        Y_ADJUST(level);
    }
}

bool L_SCROLL(TITUS_level *level) {
    //Scroll left
    if (BITMAP_X == 0) {
        return true; //Stop scrolling
    }
    BITMAP_X--; //Scroll 1 tile left
    return false; //Continue scrolling
}


bool R_SCROLL(TITUS_level *level) {
    //Scroll right
    uint8_t maxX;
    if (((level->player.sprite.x >> 4) - screen_width) > XLIMIT) { //Scroll limit
        maxX = level->width - screen_width; //256 - 20
    } else {
        maxX = XLIMIT;
    }
    if (BITMAP_X >= maxX) {
        return true; //Stop scrolling
    }
    BITMAP_X++; //Increase pointer
    return false;
}


bool U_SCROLL(TITUS_level *level) {
    //Scroll up
    if (BITMAP_Y == 0) {
        return true;
    }
    BITMAP_Y--; //Scroll 1 tile up
    return false;
}


bool D_SCROLL(TITUS_level *level) {
    //Scroll down
    if (BITMAP_Y >= (level->height - screen_height)) { //The screen is already at the bottom
        return true; //Stop scrolling
    }
    BITMAP_Y++; //Increase pointer
    return false;
}
