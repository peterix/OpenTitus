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
   * void flip_screen(bool slow): Flips the screen and a short delay
  * void fadeout(): Fade the screen to black
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

void draw_tiles(TITUS_level *level);
void draw_sprites(TITUS_level *level);

void fadeout();
int loadpixelformat(SDL_PixelFormat **pixelformat);
void freepixelformat(SDL_PixelFormat **pixelformat);
