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

/* sprites.c
 * Sprite functions
 */

#include <stdio.h>
//#include <stdlib.h>
#include "SDL2/SDL.h"
#include "sprites.h"
#include "game.h"
#include "original.h"
#include "tituserror.h"
#include "globals_old.h"
#include "window.h"

// FIXME: maybe we can have one big tile map surface just like we have one big font surface
SDL_Surface * SDL_LoadTile(unsigned char * first, int i, SDL_PixelFormat * pixelformat){
    SDL_Surface *surface = NULL;
    SDL_Surface *surface2 = NULL;
    char *tmpchar;
    int j, k;
    surface = SDL_CreateRGBSurface(SDL_SWSURFACE, 16, 16, 8, 0, 0, 0, 0);

    copypixelformat(surface->format, pixelformat);

    tmpchar = (char *)surface->pixels;
    // Planar 16 color loading here, see uiimage.zig for example of it working.
    for (j = i; j < i + 0x20; j++) {
        for (k = 7; k >= 0; k--) {
            *tmpchar = (first[j] >> k) & 0x01;
            *tmpchar += (first[j + 0x20] >> k << 1) & 0x02;
            *tmpchar += (first[j + 0x40] >> k << 2) & 0x04;
            *tmpchar += (first[j + 0x60] >> k << 3) & 0x08;
            tmpchar++;
        }
    }
    surface2 = SDL_ConvertSurfaceFormat(surface, SDL_GetWindowPixelFormat(window), 0);
    SDL_FreeSurface(surface);
    return(surface2);
}

int copypixelformat(SDL_PixelFormat * destformat, SDL_PixelFormat * srcformat) {
    if (srcformat->palette != NULL) {
        destformat->palette->ncolors = srcformat->palette->ncolors;
        for (int i = 0; i < destformat->palette->ncolors; i++) {
            destformat->palette->colors[i].r = srcformat->palette->colors[i].r;
            destformat->palette->colors[i].g = srcformat->palette->colors[i].g;
            destformat->palette->colors[i].b = srcformat->palette->colors[i].b;
        }
    }

    destformat->BitsPerPixel = srcformat->BitsPerPixel;
    destformat->BytesPerPixel = srcformat->BytesPerPixel;

    destformat->Rloss = srcformat->Rloss;
    destformat->Gloss = srcformat->Gloss;
    destformat->Bloss = srcformat->Bloss;
    destformat->Aloss = srcformat->Aloss;

    destformat->Rshift = srcformat->Rshift;
    destformat->Gshift = srcformat->Gshift;
    destformat->Bshift = srcformat->Bshift;
    destformat->Ashift = srcformat->Ashift;

    destformat->Rmask = srcformat->Rmask;
    destformat->Gmask = srcformat->Gmask;
    destformat->Bmask = srcformat->Bmask;
    destformat->Amask = srcformat->Amask;

    //destformat->colorkey = srcformat->colorkey;
    //destformat->alpha = srcformat->alpha;
}

static void animate_sprite(TITUS_level *level, TITUS_sprite *spr) {
    if (!spr->visible) return; //Not on screen?
    if (!spr->enabled) return;
    if (spr->number == (FIRST_OBJET+26)) { //Cage
        if ((IMAGE_COUNTER & 0x0007) == 0) { //Every 8
            updatesprite(level, spr, FIRST_OBJET+27, false); //Cage, 2nd sprite
        }
    } else if (spr->number == (FIRST_OBJET+27)) { //Cage, 2nd sprite
        if ((IMAGE_COUNTER & 0x003F) == 0) { //Every 64
            updatesprite(level, spr, FIRST_OBJET+26, false); //Cage, 1st sprite
        }
    } else if (spr->number == (FIRST_OBJET+21)) { //Flying carpet
        if ((IMAGE_COUNTER & 0x0007) == 0) { //Every 8
            updatesprite(level, spr, FIRST_OBJET+22, false); //Flying carpet, 2nd sprite
        }
    } else if (spr->number == (FIRST_OBJET+22)) { //Flying carpet, 2nd sprite
        if ((IMAGE_COUNTER & 0x0007) == 0) { //Every 8
            updatesprite(level, spr, FIRST_OBJET+21, false); //Flying carpet, 1st sprite
        }
    } else if (spr->number == (FIRST_OBJET+24)) { //Small spring
        if ((IMAGE_COUNTER & 0x0001) == 0) { //Every 2
            if (spr->UNDER == 0) { //Spring is not loaded
                updatesprite(level, spr, FIRST_OBJET+25, false); //Spring is not loaded; convert into big spring
            } else if (GRAVITY_FLAG > 1) { //if not gravity, not clear
                spr->UNDER = 0;
            } else {
                spr->UNDER = spr->UNDER & 0x01; //Keep eventually object load, remove player load
            }
        }
    } else if (spr->number == (FIRST_OBJET+25)) { //Big spring
        if ((IMAGE_COUNTER & 0x0001) == 0) { //Every 2
            if (spr->UNDER == 0) {
                return; //Spring is not loaded; remain big
            } else if (GRAVITY_FLAG > 1) { //if not gravity, not clear
                spr->UNDER = 0;
            } else {
                spr->UNDER = spr->UNDER & 0x01; //Keep eventually object load, remove player load
            }
            spr->ONTOP->y += 5;
            GRAVITY_FLAG = 3;
            updatesprite(level, spr, FIRST_OBJET+24, false); //Small spring
        }
    }
}

void SPRITES_ANIMATION(TITUS_level *level) {
    int16_t i;
    //Animate player
    if ((LAST_ORDER == 0) &&
      (POCKET_FLAG) &&
      (ACTION_TIMER >= 35*4)) {
        updatesprite(level, &(level->player.sprite), 29, false); //"Pause"-sprite
        if (ACTION_TIMER >= 35*5) {
            updatesprite(level, &(level->player.sprite), 0, false); //Normal player sprite
            ACTION_TIMER = 0;
        }
    }
    //Animate other objects

    animate_sprite(level, &(level->player.sprite2));
    animate_sprite(level, &(level->player.sprite3));

    for (i = 0; i < level->objectcount; i++) {
        animate_sprite(level, &(level->object[i].sprite));
    }

    for (i = 0; i < level->enemycount; i++) {
        animate_sprite(level, &(level->enemy[i].sprite));
    }

    for (i = 0; i < level->elevatorcount; i++) {
        animate_sprite(level, &(level->elevator[i].sprite));
    }
}

void updatesprite(TITUS_level *level, TITUS_sprite *spr, int16_t number, bool clearflags){
    spr->number = number;
    spr->spritedata = &level->spritedata[number];
    spr->enabled = true;
    if (clearflags) {
        spr->flipped = false;
        spr->flash = false;
        spr->visible = false;
        spr->droptobottom = false;
        spr->killing = false;
    }
    spr->invisible = false;
}

void copysprite(TITUS_level *level, TITUS_sprite *dest, TITUS_sprite *src){
    dest->number = src->number;
    dest->spritedata = &level->spritedata[src->number];
    dest->enabled = src->enabled;
    dest->flipped = src->flipped;
    dest->flash = src->flash;
    dest->visible = src->visible;
    dest->invisible = false;
}
