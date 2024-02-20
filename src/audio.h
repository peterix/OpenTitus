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

#pragma once

#include <stdint.h>

// TODO: reduce this to nothing.
// TODO: add more audio events for Amiga (enemy throws, etc.)

enum AudioEvent {
    Event_HitEnemy, // sfx 1
    Event_HitPlayer, // sfx 4
    Event_PlayerHeadImpact, // sfx 5
    Event_PlayerPickup, // sfx 9
    Event_PlayerPickupEnemy, // sfx 9
    Event_PlayerThrow, // sfx 3
    Event_BallBounce, // sfx 12
    Event_PlayerCollectWaypoint, // jingle 5
    Event_PlayerCollectBonus, // jingle 6
    Event_PlayerCollectLamp, // jingle 7
};

void playEvent_c(enum AudioEvent event);
