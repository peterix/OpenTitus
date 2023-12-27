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

/* settings.c
 * Handles settings loaded from titus.conf
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "settings.h"

// FIXME: hardcode to moktar and titus, move to 'original.c'
char spritefile[256];
char levelfiles[16][256]; //16 levels in moktar, 15 levels in titus
char tituslogofile[256];
int tituslogoformat;
char titusintrofile[256];
int titusintroformat;
char titusmenufile[256];
int titusmenuformat;
char titusfinishfile[256];
int titusfinishformat;
char fontfile[256];
uint16_t levelcount;
int resheight;

// FIXME: deduce this from the files found next to the binary?
enum GameType game;

// FIXME: make this a build option.
int devmode;

// FIXME: make a settings menu and make this persistent/changeable in the game
// along with music on/off and volume
int videomode;

int readconfig(const char *configfile) {
    char line[300], tmp[256];
    int retval, i, j, tmpcount = 0;
    levelcount = 0;
    spritefile[0] = 0;
    devmode = 0;
    FILE *ifp = fopen (configfile, "rt");
    if (ifp == NULL) {
        fprintf(stderr, "Error: Can't open config file: %s!\n", configfile);
        return(-1);
    }

    while(fgets(line, 299, ifp) != NULL)
    {
        if (sscanf (line, "%50s", tmp) == EOF)
            continue;

        if ((line[0] == 0) || (tmp[0] == *"#"))
            continue;

        else if (strcmp (tmp, "sprites") == 0)
            sscanf (line, "%*s %255s", spritefile);

        else if (strcmp (tmp, "levelcount") == 0) {
            if (tmpcount > 0) {
                printf("Error: You may only specify one 'levelcount', check config file: %s!\n", configfile);
                fclose(ifp);
                return(-1);
            }
            sscanf (line, "%*s %hu", &levelcount);
            if ((levelcount < 1) || (levelcount > 16)) {
                printf("Error: 'levelcount' (%hu) must be between 1 and 16, check config file: %s!\n", levelcount, configfile);
                fclose(ifp);
                return(-1);
            }
        }

        else if (strcmp (tmp, "level") == 0) {
            if (levelcount == 0) {
                printf("Error: 'levelcount' must be set before level files, check config file: %s!\n", configfile);
                fclose(ifp);
                return(-1);
            }
            if (sscanf (line, "%*s %2d", &i) <= 0) {
                printf("Error: Invalid numbering on the individual levels, check config file: %s!\n", configfile);
                fclose(ifp);
                return(-1);
            }
            if ((retval = sscanf (line, "%*s %*2d %255s", tmp)) <= 0) {
                printf("Error: You have not specified level file number %d, check config file: %s!\n", i, configfile);
                fclose(ifp);
                return(-1);
            }
            if ((i < 1) || (i > levelcount) || (tmpcount >= levelcount)) {
                printf("Error: Invalid numbering on the individual levels, check config file: %s!\n", configfile);
                fclose(ifp);
                return(-1);
            }
            strcpy (levelfiles[i - 1], tmp);
            tmpcount++;
        } else if (strcmp (tmp, "devmode") == 0)
            sscanf (line, "%*s %255d", &devmode);
        else if (strcmp (tmp, "videomode") == 0)
            sscanf (line, "%*s %255d", &videomode);
        else if (strcmp (tmp, "game") == 0) {
            sscanf (line, "%*s %255d", (int *)&game);
            switch(game) {
                case Moktar:
                case Titus:
                    break;
                default: {
                    printf("Error: You have specified invalid game type: %d, check config file: %s!\n", game, configfile);
                    fclose(ifp);
                    return(-1);
                }
            }
        }
        else if (strcmp (tmp, "logo") == 0)
            sscanf (line, "%*s %255s", tituslogofile);
        else if (strcmp (tmp, "logoformat") == 0)
            sscanf (line, "%*s %255d", &tituslogoformat);
        else if (strcmp (tmp, "intro") == 0)
            sscanf (line, "%*s %255s", titusintrofile);
        else if (strcmp (tmp, "introformat") == 0)
            sscanf (line, "%*s %255d", &titusintroformat);
        else if (strcmp (tmp, "menu") == 0)
            sscanf (line, "%*s %255s", titusmenufile);
        else if (strcmp (tmp, "menuformat") == 0)
            sscanf (line, "%*s %255d", &titusmenuformat);
        else if (strcmp (tmp, "finish") == 0)
            sscanf (line, "%*s %255s", titusfinishfile);
        else if (strcmp (tmp, "finishformat") == 0)
            sscanf (line, "%*s %255d", &titusfinishformat);
        else if (strcmp (tmp, "font") == 0)
            sscanf (line, "%*s %255s", fontfile);
        else
            printf("Warning: undefined command '%s' in titus.conf\n", tmp);

    }
    fclose(ifp);

    if (tmpcount == 0) { // No levels
        printf("Error: You must specify at least one level, check config file: %s!\n", configfile);
        return(-1);
    }

    if (tmpcount < levelcount) { // No levels
        printf("Error: 'levelcount' (%d) and the number of specified levels (%d) does not match, check config file: %s!\n", levelcount, tmpcount, configfile);
        return(-1);
    }

    for (i = 1; i <= levelcount; i++) {
        if (levelfiles[i - 1][0] == 0) {
            fprintf(stderr, "Error: You have not specified level file number %d, check config file: %s!\n", i, configfile);
            return(-1);
        }
        if ((ifp = fopen (levelfiles[i - 1], "r")) != NULL )
            fclose(ifp);
        else {
            fprintf(stderr, "Error: Level file number %d (%s) does not exist, check config file: %s!\n", i, levelfiles[i - 1], configfile);
            return(-1);
        }
    }

    if ((ifp = fopen (spritefile, "r")) != NULL )
        fclose(ifp);
    else {
        fprintf(stderr, "Error: Sprite file does not exist, check config file: %s!\n", configfile);
        return(-1);
    }

    return 0;
}

