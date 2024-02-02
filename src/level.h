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

/* level.h
 * Contains the OpenTitus level format structure, and level functions
 */

#pragma once

#include "SDL2/SDL.h"
#include <stdbool.h>
#include <stdint.h>
#include "globals_old.h"

typedef struct _TITUS_tile TITUS_tile;
typedef struct _TITUS_sprite TITUS_sprite;
typedef struct _TITUS_spritedata TITUS_spritedata;
typedef struct _TITUS_objectdata TITUS_objectdata;
typedef struct _TITUS_object TITUS_object;
typedef struct _TITUS_enemy TITUS_enemy;
typedef struct _TITUS_bonus TITUS_bonus;
typedef struct _TITUS_gate TITUS_gate;
typedef struct _TITUS_elevator TITUS_elevator;
typedef struct _TITUS_player TITUS_player;
typedef struct _TITUS_level TITUS_level;

struct _TITUS_tile {
    SDL_Surface *tiledata; //Malloced
    uint8_t animation[3]; //Index to animation tiles
    enum HFLAG horizflag;
    enum FFLAG floorflag;
    enum CFLAG ceilflag;
};

struct _TITUS_sprite {
    int16_t x;
    int16_t y;
    int16_t speed_x;
    int16_t speed_y;
    int16_t number;
    bool visible; //On screen or not on screen (above/below/left/right)
    bool flash;
    bool flipped;
    bool enabled;
    const TITUS_spritedata *spritedata;
    uint8_t UNDER; //0: big spring, 1: small spring because of another object on top, 2: small spring because player on top
    TITUS_sprite *ONTOP; //Object on top of the spring
    const int16_t *animation;
    bool droptobottom;
    bool killing;
    bool invisible; //Set by "hidden" enemies
};

// NOTE: mirrored by 
struct _TITUS_spritedata {
    uint8_t height;
    uint8_t width;
    uint8_t collheight;
    uint8_t collwidth;
    uint8_t refheight;
    uint8_t refwidth;
};

struct _TITUS_objectdata {
    uint8_t maxspeedY;
    bool support; //not support/support
    bool bounce; //not bounce/bounce against floor + player bounces (ball, all spring, yellow stone, squeezed ball, skateboard)
    bool gravity; //no gravity on throw/gravity (ball, all carpet, trolley, squeezed ball, garbage, grey stone, scooter, yellow bricks between the statues, skateboard, cage)
    bool droptobottom; //on drop, lands on ground/continue below ground(cave spikes, rolling rock, ambolt, safe, dead man with helicopter)
    bool no_damage; //weapon/not weapon(cage)
};

struct _TITUS_object {
    TITUS_sprite sprite;
    uint8_t momentum; // must be >= 10 to cause a falling object to hit an enemy or the player

    bool init_enabled;
    uint16_t init_sprite;
    bool init_flash;
    bool init_visible;
    bool init_flipped;
    int init_x;
    int init_y;
    TITUS_objectdata *objectdata;
};

struct _TITUS_enemy {
    uint8_t dying; //00: alive, not 00: dying/dead
    uint8_t phase; //the current phase of the enemy
    TITUS_sprite sprite;
    uint16_t type; //What kind of enemy
    int16_t power;
    int center_x;
    unsigned int range_x;
    unsigned int delay;
    unsigned char direction;
    unsigned int range_y;

    bool init_enabled;
    uint16_t init_sprite;
    bool init_flipped;
    int init_x;
    int init_y;
    int init_speed_x;
    int init_speed_y;

    int16_t carry_sprite;
    int16_t dead_sprite;

    bool boss;
    bool trigger;
    bool visible;
    uint8_t counter;
    uint8_t walkspeed_x;
};

struct _TITUS_bonus {
    bool exists;
    unsigned char bonustile;
    unsigned char replacetile;
    uint8_t x;
    uint8_t y;
};

struct _TITUS_gate {
    bool exists;
    unsigned int entranceX;
    unsigned int entranceY;
    unsigned int exitX;
    unsigned int exitY;
    unsigned int screenX;
    unsigned int screenY;
    bool noscroll;
};

struct _TITUS_elevator {
    bool enabled;
    TITUS_sprite sprite;
    unsigned int counter;

    unsigned int range;

    unsigned char init_direction;
    bool init_enabled;
    int16_t init_speed_x;
    int16_t init_speed_y;
    uint16_t init_sprite;
    bool init_flash;
    bool init_visible;
    bool init_flipped;
    int init_x;
    int init_y;
};

struct _TITUS_player {
    TITUS_sprite sprite;
    TITUS_sprite sprite2;
    TITUS_sprite sprite3;
    unsigned char animcycle;
    int16_t cageX;
    int16_t cageY;
    uint16_t hp;
    int16_t initX;
    int16_t initY;
    unsigned char inithp;
    uint8_t GLISSE; //Friction (0-3). 0: full friction, 3: max sliding

    // Player input this frame
    int8_t x_axis;
    int8_t y_axis;
    bool action_pressed;
};

#define BONUS_CAPACITY 100
#define GATE_CAPACITY 20
#define ELEVATOR_CAPACITY 10
#define TRASH_CAPACITY 4
#define ENEMY_CAPACITY 50
#define OBJECT_CAPACITY 40

struct _TITUS_level {
    void * parent;
    uint16_t levelnumber;
    bool has_cage;
    bool is_finish;
    uint8_t music;
    uint8_t boss_power;

    int16_t height;
    int16_t width; // always 256
    TITUS_tile tile[256];
    const TITUS_spritedata *spritedata; // Pointer to a global spritedata variable
    const TITUS_objectdata *objectdata; // Pointer to a global objectdata variable
    int finishX, finishY;
    //TITUS_enemy *boss; //Pointer to the boss; NULL if there is no boss
    //TITUS_object *finish_object; // Pointer to the required object to carry to finish; NULL if there is no such object
    SDL_PixelFormat *pixelformat; // Pointer to a global pixelformat variabl

    TITUS_player player;

    TITUS_object object[OBJECT_CAPACITY];
    TITUS_enemy enemy[ENEMY_CAPACITY];
    TITUS_bonus bonus[BONUS_CAPACITY];
    TITUS_gate gate[GATE_CAPACITY];
    TITUS_elevator elevator[ELEVATOR_CAPACITY];
    TITUS_sprite trash[TRASH_CAPACITY];

    // FIXME: move this outside level...
    size_t bonuscount;
    size_t bonuscollected;
    int lives, extrabonus;
    size_t tickcount;
};

enum HFLAG get_horizflag(TITUS_level *level, int16_t tileY, int16_t tileX);
enum FFLAG get_floorflag(TITUS_level *level, int16_t tileY, int16_t tileX);
enum CFLAG get_ceilflag(TITUS_level *level, int16_t tileY, int16_t tileX);
void set_tile(TITUS_level *level, uint8_t tileY, uint8_t tileX, uint8_t tile);