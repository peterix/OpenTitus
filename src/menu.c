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

/* menu.c
 * Handles the menu
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "SDL2/SDL.h"
#include "sqz.h"
#include "window.h"
#include "menu.h"
#include "fonts.h"
#include "audio.h"
#include "globals_old.h"
#include "keyboard.h"
#include "levelcodes.h"
#include "game.h"

// TODO: redo all UI
// - Add settings menu
// - Remove level code input and replace it with level select
// - Levels are unlocked by collecting the locks and the unlock state is persisted on disk instead of codes
// - Add pause menu
// - Esc opens pause menu instead of instant quit

int enterpassword(int levelcount);

int viewmenu(const char * menufile, int menuformat, int levelcount) {
    SDL_Surface *surface;
    SDL_Palette *palette;
    char *tmpchar;
    SDL_Surface *image;
    unsigned char *menudata;
    int retval;
    int menuloop = 1;
    int selection = 0;
    SDL_Event event;
    int curlevel = 1;

    unsigned int fade_time = 1000;
    unsigned int tick_start = 0;
    unsigned int image_alpha = 0;

    SDL_Rect src, dest;

    retval = unSQZ(menufile, &menudata);

    if (retval < 0) {
        free (menudata);
        return (retval);
    }

    switch (menuformat) {
    case 1: //Planar 16-color
        // FIXME: what is this supposed to do aside from crashing?
        break;

    case 2: //256 color
        surface = SDL_CreateRGBSurface(SDL_SWSURFACE, 320, 200, 8, 0, 0, 0, 0);
        palette = (surface->format)->palette;
        if (palette) {
            for (int i = 0; i < 256; i++) {
                palette->colors[i].r = (menudata[i * 3] & 0xFF) * 4;
                palette->colors[i].g = (menudata[i * 3 + 1] & 0xFF) * 4;
                palette->colors[i].b = (menudata[i * 3 + 2] & 0xFF) * 4;
            }
            palette->ncolors = 256;
        }

        tmpchar = (char *)surface->pixels;
        for (int i = 256 * 3; i < 256 * 3 + 320*200; i++) {
            *tmpchar = menudata[i];
            tmpchar++;
        }

        image = SDL_ConvertSurfaceFormat(surface, SDL_GetWindowPixelFormat(window), 0);
        palette = NULL;

        SDL_FreeSurface(surface);

        break;
    }

    free (menudata);

    src.x = 0;
    src.y = 0;
    src.w = image->w;
    src.h = image->h;

    dest.x = 16;
    dest.y = 0;
    dest.w = image->w;
    dest.h = image->h;

    SDL_Rect sel[2];
    SDL_Rect sel_dest[2];

    if (game == Titus) {

        sel[0].x = 120;
        sel[0].y = 160;
        sel[0].w = 8;
        sel[0].h = 8;

        sel[1].x = 120;
        sel[1].y = 173;
        sel[1].w = 8;
        sel[1].h = 8;

    } else if (game == Moktar) {

        sel[0].x = 130;
        sel[0].y = 167;
        sel[0].w = 8;
        sel[0].h = 8;

        sel[1].x = 130;
        sel[1].y = 180;
        sel[1].w = 8;
        sel[1].h = 8;
    }
    sel_dest[0] = sel[0];
    sel_dest[0].x += 16;
    sel_dest[1] = sel[1];
    sel_dest[1].x += 16;

    tick_start = SDL_GetTicks();

    while (image_alpha < 255) { //Fade in

        if (SDL_PollEvent(&event)) {
            if (event.type == SDL_QUIT) {
                SDL_FreeSurface(image);
                return (-1);
            }

            if (event.type == SDL_KEYDOWN) {
                if (event.key.keysym.scancode == SDL_SCANCODE_ESCAPE) {
                    SDL_FreeSurface(image);
                    return (-1);
                }
                if (event.key.keysym.scancode == KEY_MUSIC) {
                    music_toggle();
                } else if (event.key.keysym.scancode == KEY_FULLSCREEN) {
                    window_toggle_fullscreen();
                }
            }
        }

        image_alpha = (SDL_GetTicks() - tick_start) * 256 / fade_time;

        if (image_alpha > 255)
            image_alpha = 255;

        window_clear(NULL);
        SDL_SetSurfaceBlendMode(image, SDL_BLENDMODE_BLEND);
        SDL_SetSurfaceAlphaMod(image, image_alpha);
        SDL_BlitSurface(image, &src, screen, &dest);
        SDL_BlitSurface(image, &sel[1], screen, &sel_dest[0]);
        SDL_BlitSurface(image, &sel[0], screen, &sel_dest[selection]);
        window_render();
        SDL_Delay(1);

    }

    beforemenuloop:

    while (menuloop) { //View the menu

        if (SDL_PollEvent(&event)) {
            if (event.type == SDL_QUIT) {
                SDL_FreeSurface(image);
                return (-1);
            }

            if (event.type == SDL_KEYDOWN) {
                if (event.key.keysym.scancode == SDL_SCANCODE_ESCAPE) {
                    SDL_FreeSurface(image);
                    return (-1);
                }
                if (event.key.keysym.scancode == SDL_SCANCODE_UP)
                    selection = 0;
                if (event.key.keysym.scancode == SDL_SCANCODE_DOWN)
                    selection = 1;
                if (event.key.keysym.scancode == KEY_RETURN || event.key.keysym.scancode == KEY_ENTER || event.key.keysym.scancode == KEY_SPACE)
                    menuloop = 0;
                if (event.key.keysym.scancode == KEY_MUSIC) {
                    music_toggle();
                } else if (event.key.keysym.scancode == KEY_FULLSCREEN) {
                    window_toggle_fullscreen();
                }
            }
        }

        window_clear(NULL);
        SDL_BlitSurface(image, &src, screen, &dest);
        SDL_BlitSurface(image, &sel[1], screen, &sel_dest[0]);
        SDL_BlitSurface(image, &sel[0], screen, &sel_dest[selection]);
        window_render();
        SDL_Delay(1);
    }

    switch (selection) {
    case 0: //Start

        break;

    case 1: //Password
        retval = enterpassword(levelcount);

        if (retval < 0)
            return retval;

        if (retval > 0) {
            curlevel = retval;
        }
        selection = 0;
        menuloop = 1;
        goto beforemenuloop;
        break;

    default:
        return (-1);
        break;
    }

    tick_start = SDL_GetTicks();
    image_alpha = 0;
    while (image_alpha < 255) { //Fade out

        if (SDL_PollEvent(&event)) {
            if (event.type == SDL_QUIT) {
                SDL_FreeSurface(image);
                return (-1);
            }

            if (event.type == SDL_KEYDOWN) {
                if (event.key.keysym.scancode == SDL_SCANCODE_ESCAPE) {
                    SDL_FreeSurface(image);
                    return (-1);
                }
                if (event.key.keysym.scancode == KEY_MUSIC) {
                    music_toggle();
                } else if (event.key.keysym.scancode == KEY_FULLSCREEN) {
                    window_toggle_fullscreen();
                }
                // TODO: add a way to activate devmode from here (cheat code style using state machine)
            }
        }

        image_alpha = (SDL_GetTicks() - tick_start) * 256 / fade_time;

        if (image_alpha > 255)
            image_alpha = 255;

        window_clear(NULL);
        SDL_SetSurfaceBlendMode(image, SDL_BLENDMODE_BLEND);
        SDL_SetSurfaceAlphaMod(image, 255 - image_alpha);
        SDL_BlitSurface(image, &src, screen, &dest);
        SDL_FillRect(screen, &sel_dest[0], 0); //SDL_MapRGB(surface->format, 0, 0, 0));
        SDL_BlitSurface(image, &sel[0], screen, &sel_dest[selection]);
        window_render();
        SDL_Delay(1);
    }

    return (curlevel);

}

int enterpassword(int levelcount){
    int retval;
    char code[] = "____";
    int i = 0;

    window_clear(NULL);

    text_render("CODE", 111, 80, false);

    while (i < 4) {
        SDL_Event event;
        while(SDL_PollEvent(&event)) { //Check all events
            if (event.type == SDL_QUIT) {
                return (-1);
            }

            if (event.type == SDL_KEYDOWN) {
                switch (event.key.keysym.scancode) {
                    case SDL_SCANCODE_0:
                        code[i++] = '0';
                        break;
                    case SDL_SCANCODE_1:
                        code[i++] = '1';
                        break;
                    case SDL_SCANCODE_2:
                        code[i++] = '2';
                        break;
                    case SDL_SCANCODE_3:
                        code[i++] = '3';
                        break;
                    case SDL_SCANCODE_4:
                        code[i++] = '4';
                        break;
                    case SDL_SCANCODE_5:
                        code[i++] = '5';
                        break;
                    case SDL_SCANCODE_6:
                        code[i++] = '6';
                        break;
                    case SDL_SCANCODE_7:
                        code[i++] = '7';
                        break;
                    case SDL_SCANCODE_8:
                        code[i++] = '8';
                        break;
                    case SDL_SCANCODE_9:
                        code[i++] = '9';
                        break;
                    case SDL_SCANCODE_A:
                        code[i++] = 'A';
                        break;
                    case SDL_SCANCODE_B:
                        code[i++] = 'B';
                        break;
                    case SDL_SCANCODE_C:
                        code[i++] = 'C';
                        break;
                    case SDL_SCANCODE_D:
                        code[i++] = 'D';
                        break;
                    case SDL_SCANCODE_E:
                        code[i++] = 'E';
                        break;
                    case SDL_SCANCODE_F:
                        code[i++] = 'F';
                        break;
                    case SDL_SCANCODE_BACKSPACE:
                        if(i > 0) {
                            code[i--] = '\0';
                        }
                        break;
                    default:
                        break;
                }
                if (event.key.keysym.scancode == SDL_SCANCODE_ESCAPE) {
                    return (-1);
                }

                if (event.key.keysym.scancode == KEY_MUSIC) {
                    music_toggle();
                } else if (event.key.keysym.scancode == KEY_FULLSCREEN) {
                    window_toggle_fullscreen();
                }
            }
        }
        text_render(code, 159, 80, true);
        window_render();
        SDL_Delay(1);
    }

    i = levelForCode(code);
    if (i != -1 && i < levelcount) {
        if (game == Titus) {
            text_render("Level", 103, 104, false);
        } else if (game == Moktar) {
            text_render("Etape", 103, 104, false);
        }
        sprintf(code, "%d", i + 1);
        size_t code_width = text_width(code, false);
        text_render(code, 199 - code_width, 104, false);
        window_render();
        retval = waitforbutton();

        if (retval < 0)
            return retval;

        window_clear(NULL);
        window_render();

        return (i + 1);
    }

    text_render("!  WRONG CODE  !", 87, 104, false);
    window_render();
    retval = waitforbutton();

    window_clear(NULL);
    window_render();
    return (retval);
}
