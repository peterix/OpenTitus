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

/* draw.c
 * Draw functions
 *
 * Global functions:
  * void flip_screen(bool slow): Flips the screen and a short delay
  * void fadeout(): Fade the screen to black
 */

#include <stdio.h>
#include <stdlib.h>
#include "SDL2/SDL.h"
#include "globals_old.h"
#include "window.h"
#include "sprites.h"
#include "draw.h"
#include "game.h"
#include "common.h"
#include "tituserror.h"
#include "original.h"
#include "keyboard.h"
#include "gates.h"
#include "scroll.h"
#include "audio.h"

static const int tick_delay = 29;

void screencontext_reset(ScreenContext * context) {
    memset(context, 0, sizeof(ScreenContext));
}

void screencontext_initial(ScreenContext * context) {
    uint32_t initial_clock = SDL_GetTicks();
    context->TARGET_CLOCK = initial_clock + tick_delay;
    context->started = true;
    SDL_Delay(tick_delay);
    context->LAST_CLOCK = SDL_GetTicks();
    context->TARGET_CLOCK += tick_delay;
}

void screencontext_advance_29(ScreenContext * context) {
    if(!context->started) {
        screencontext_initial(context);
        return;
    }
    uint32_t now = SDL_GetTicks();
    if (context->TARGET_CLOCK > now) {
        SDL_Delay(context->TARGET_CLOCK - now);
    }
    context->LAST_CLOCK = SDL_GetTicks();
    context->TARGET_CLOCK = context->LAST_CLOCK + tick_delay;
}

void flip_screen(ScreenContext * context, bool slow) {
    window_render();
    if(slow) {
        screencontext_advance_29(context);
    }
    else {
        SDL_Delay(10);
        screencontext_reset(context);
    }
}

int loadpixelformat(SDL_PixelFormat **pixelformat){
    int i;

    *pixelformat = (SDL_PixelFormat *)SDL_malloc(sizeof(SDL_PixelFormat));
    if (*pixelformat == NULL) {
        fprintf(stderr, "Error: Not enough memory to initialize palette!\n");
        return (TITUS_ERROR_NOT_ENOUGH_MEMORY);
    }

    (*pixelformat)->palette = (SDL_Palette *)SDL_malloc(sizeof(SDL_Palette));
    if ((*pixelformat)->palette == NULL) {
        fprintf(stderr, "Error: Not enough memory to initialize palette!\n");
        return (TITUS_ERROR_NOT_ENOUGH_MEMORY);
    }

    (*pixelformat)->palette->ncolors = 16;

    (*pixelformat)->palette->colors = (SDL_Color *)SDL_malloc(sizeof(SDL_Color) * (*pixelformat)->palette->ncolors);
    if ((*pixelformat)->palette->colors == NULL) {
        fprintf(stderr, "Error: Not enough memory to initialize palette!\n");
        return (TITUS_ERROR_NOT_ENOUGH_MEMORY);
    }

    for (i = 0; i < (*pixelformat)->palette->ncolors; i++) {
        (*pixelformat)->palette->colors[i].r = orig_palette_colour[i].r;
        (*pixelformat)->palette->colors[i].g = orig_palette_colour[i].g;
        (*pixelformat)->palette->colors[i].b = orig_palette_colour[i].b;
    }

    (*pixelformat)->BitsPerPixel = 8;
    (*pixelformat)->BytesPerPixel = 1;

    (*pixelformat)->Rloss = 0;
    (*pixelformat)->Gloss = 0;
    (*pixelformat)->Bloss = 0;
    (*pixelformat)->Aloss = 0;

    (*pixelformat)->Rshift = 0;
    (*pixelformat)->Gshift = 0;
    (*pixelformat)->Bshift = 0;
    (*pixelformat)->Ashift = 0;

    (*pixelformat)->Rmask = 0;
    (*pixelformat)->Gmask = 0;
    (*pixelformat)->Bmask = 0;
    (*pixelformat)->Amask = 0;

    return (0);
}

void freepixelformat(SDL_PixelFormat **pixelformat){
    free ((*pixelformat)->palette->colors);
    free ((*pixelformat)->palette);
    free (*pixelformat);
}
