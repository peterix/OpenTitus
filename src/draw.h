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

/* draw.h
 * Draw functions
 *
 * Global functions:
 * void DISPLAY_TILES(): Draw map tiles
 * int viewstatus(TITUS_level *level, bool countbonus): View status screen (F4)
 * void flip_screen(bool slow): Flips the screen and a short delay
 * void INIT_SCREENM(TITUS_level *level): Initialize screen
 * void draw_health_bars(TITUS_level *level): Draw energy
 * void fadeout(): Fade the screen to black
 * int view_password(TITUS_level *level, uint8_t level_index): Display the password
 */

#pragma once

#include "SDL2/SDL.h"
#include "level.h"

#include <stdbool.h>
#include <stdint.h>

struct _ScreenContext {
    bool started;
    uint32_t LAST_CLOCK;
    uint32_t TARGET_CLOCK;
};
typedef struct _ScreenContext ScreenContext;

void screencontext_reset(ScreenContext * context);
void screencontext_initial(ScreenContext * context);
void screencontext_advance_29(ScreenContext * context);
void flip_screen(ScreenContext *context, bool slow);

void DISPLAY_TILES(TITUS_level *level);
int viewstatus(TITUS_level *level, bool countbonus);

void INIT_SCREENM(ScreenContext *context, TITUS_level *level);
void draw_health_bars(TITUS_level *level);
void DISPLAY_SPRITES(TITUS_level *level);
void fadeout();
int view_password(ScreenContext *context, TITUS_level *level, uint8_t level_index);
int loadpixelformat(SDL_PixelFormat **pixelformat);
int loadpixelformat_font(SDL_PixelFormat **pixelformat);
void freepixelformat(SDL_PixelFormat **pixelformat);
