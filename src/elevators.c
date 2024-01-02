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

/* elevators.c
 * Handles elevators.
 */

#include <stdio.h>
#include <stdlib.h>
#include "SDL2/SDL.h"
#include "level.h"
#include "globals_old.h"
#include "elevators.h"

void elevators_move(TITUS_level *level) {
    TITUS_elevator *elevators = level->elevator;
    uint8_t i;
    for (i = 0; i < level->elevatorcount; i++) {
        TITUS_elevator *elevator = &elevators[i];
        if (elevator->enabled == false) {
            continue;
        }

        // move all elevators
        elevator->sprite.x += elevator->sprite.speedX;
        elevator->sprite.y += elevator->sprite.speedY;
        elevator->counter++;
        if (elevator->counter >= elevator->range) {
            elevator->counter = 0;
            elevator->sprite.speedX = 0 - elevator->sprite.speedX;
            elevator->sprite.speedY = 0 - elevator->sprite.speedY;
        }

        // if elevators are out of the screen space, turn them invisible
        if (((elevator->sprite.x + 16 - (BITMAP_X << 4)) >= 0) && // +16: closer to center
          ((elevator->sprite.x - 16 - (BITMAP_X << 4)) <= screen_width * 16) && // -16: closer to center
          ((elevator->sprite.y - (BITMAP_Y << 4)) >= 0) &&
          ((elevator->sprite.y - (BITMAP_Y << 4)) - 16 <= screen_height * 16)) {
            elevator->sprite.invisible = false;
        } else {
            elevator->sprite.invisible = true; //Not necessary, but to mimic the original game
        }
    }
}
