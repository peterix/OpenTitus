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

/* fonts.c
 * Font functions
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#include "SDL2/SDL.h"
#include "fonts.h"
#include "window.h"
#include "tituserror.h"

typedef struct _TITUS_font TITUS_font;

struct _TITUS_character {
    uint8_t x;
    uint8_t y;
    uint8_t w;
    uint8_t h;
};

struct _TITUS_font {
    SDL_Surface *sheet;
    struct _TITUS_character characters[256];
    struct _TITUS_character fallback;
};

// TODO: handle errors
// TODO: embed the assets in the binary...
// TODO: shave pixels off some characters so they can be used in menus
// TODO: add a 'character' for menu bullet
// TODO: maybe load the font from the original SQZ file again?
static TITUS_font font;
#define CHAR_QUESTION 63

static int loadfont(const char * fontfile, TITUS_font * font) {
    SDL_Surface *image = SDL_LoadBMP(fontfile);
    int surface_w = image->w;
    int surface_h = image->h;
    // assert(surface_w % 16 == 0);
    // assert(surface_h % 16 == 0);

    int character_w = surface_w / 16;
    int character_h = surface_h / 16;

    // initialize character coordinates
    for (int y = 0; y < 16; y++) {
        for (int x = 0; x < 16; x++) {
            int xx = x * character_w;
            int yy = y * character_h;
            struct _TITUS_character* character = &font->characters[y * 16 + x];
            character->x = xx;
            character->y = yy;
            character->w = character_w;
            character->h = character_h;
        }
    }
    font->fallback = font->characters[CHAR_QUESTION];
    font->sheet = SDL_ConvertSurfaceFormat(image, SDL_GetWindowPixelFormat(window), 0);
    SDL_FreeSurface(image);
    return 0;
}

static void freefont(TITUS_font * font) {
    if(font == NULL) {
        return;
    }
    SDL_FreeSurface(font->sheet);
    font->sheet = NULL;
}

int fonts_load(void) {
    return loadfont("FONT.BMP", &font);
}

void fonts_free(void) {
    freefont(&font);
}

void SDL_Print_Text(const char *text, int x, int y){
    SDL_Rect dest;
    dest.x = x + 16;
    dest.y = y;

    // Let's assume ASCII for now... original code was trying to do something with UTF-8, but had the font files have no support for that
    for (int i = 0; i < strlen(text); i++) {
        unsigned char c = (unsigned char) text[i];
        struct _TITUS_character* chardesc = &font.characters[c];
        SDL_Rect src;
        src.x = chardesc->x;
        src.y = chardesc->y;
        dest.w = src.w = chardesc->w;
        dest.h = src.h = chardesc->h;
        SDL_BlitSurface(font.sheet, &src, screen, &dest);
        dest.x += 8;
    }
    return;
}
