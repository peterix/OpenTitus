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
 * int view_password(TITUS_level *level, uint8 level_index): Display the password
 */

#pragma once

#include "SDL2/SDL.h"
#include "level.h"
#include "definitions.h"

struct ScreenContext {
    void reset() {
        *this = ScreenContext();
    }

    void initial() {
        auto initial_clock = SDL_GetTicks();
        TARGET_CLOCK = initial_clock + tick_delay;
        started = true;
        SDL_Delay(tick_delay);
        LAST_CLOCK = SDL_GetTicks();
        TARGET_CLOCK += tick_delay;
    }

    void advance_29() {
        if(!started) {
            initial();
            return;
        }
        auto now = SDL_GetTicks();
        auto delay = TARGET_CLOCK - now;
        if(delay < 0) {
            delay = 29;
        }
        else {
            SDL_Delay(delay);
        }
        LAST_CLOCK = SDL_GetTicks();
        TARGET_CLOCK += tick_delay;
    }

    constexpr static int tick_delay = 29;

    bool started = false;
    int LAST_CLOCK = 0;
    int TARGET_CLOCK = 0;
};
void flip_screen(ScreenContext & context, bool slow);

void DISPLAY_TILES(TITUS_level *level);
int viewstatus(TITUS_level *level, bool countbonus);

void INIT_SCREENM(ScreenContext &context, TITUS_level *level);
void draw_health_bars(TITUS_level *level);
void DISPLAY_SPRITES(TITUS_level *level);
void fadeout();
int view_password(ScreenContext &context, TITUS_level *level, uint8 level_index);
int loadpixelformat(SDL_PixelFormat **pixelformat);
int loadpixelformat_font(SDL_PixelFormat **pixelformat);
int freepixelformat(SDL_PixelFormat **pixelformat);
