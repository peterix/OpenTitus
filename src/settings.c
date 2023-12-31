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

// FIXME: make this a build option.
int devmode;

// FIXME: make a settings menu and make this persistent/changeable in the game
// along with music on/off and volume
int videomode;

int readconfig(const char *configfile) {
    char line[300], tmp[256];
    int retval, i, j = 0;
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

        if (strcmp (tmp, "devmode") == 0)
            sscanf (line, "%*s %255d", &devmode);
        else if (strcmp (tmp, "videomode") == 0)
            sscanf (line, "%*s %255d", &videomode);
        else
            printf("Warning: undefined command '%s' in titus.conf\n", tmp);

    }
    fclose(ifp);
    return 0;
}

