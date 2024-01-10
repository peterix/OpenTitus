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

/* globals_old.h
 * Global variables
 */

#pragma once

#include "SDL2/SDL.h"
#include <stdbool.h>

#define KEY_F1 SDL_SCANCODE_F1 // Loose a life
#define KEY_F2 SDL_SCANCODE_F2 // Game over
#define KEY_F3 SDL_SCANCODE_F3 // Next level
#define KEY_E SDL_SCANCODE_E   // Display energy
#define KEY_F4 SDL_SCANCODE_F4 // Status page

#define KEY_LEFT SDL_SCANCODE_LEFT
#define KEY_A SDL_SCANCODE_A

#define KEY_RIGHT SDL_SCANCODE_RIGHT
#define KEY_D SDL_SCANCODE_D

#define KEY_UP SDL_SCANCODE_UP
#define KEY_JUMP SDL_SCANCODE_UP
#define KEY_W SDL_SCANCODE_W

#define KEY_DOWN SDL_SCANCODE_DOWN
#define KEY_S SDL_SCANCODE_S


#define KEY_SPACE SDL_SCANCODE_SPACE //Space
#define KEY_ENTER SDL_SCANCODE_KP_ENTER //Enter
#define KEY_RETURN SDL_SCANCODE_RETURN //Return
#define KEY_ESC SDL_SCANCODE_ESCAPE //Quit
#define KEY_P SDL_SCANCODE_P //Toggle pause
#define KEY_Q SDL_SCANCODE_Q //Credits madness
#define KEY_M SDL_SCANCODE_M //Cycle through all the music
#define KEY_NOCLIP SDL_SCANCODE_N //Toggle noclip
#define KEY_GODMODE SDL_SCANCODE_G //Toggle godmode
#define KEY_DEBUG SDL_SCANCODE_D //Toggle debug mode
#define KEY_FULLSCREEN SDL_SCANCODE_F11 //Toggle fullscreen

#define TEST_ZONE 4
#define MAX_X 4
#define MAX_Y 12
#define MAP_LIMIT_Y -1
#define screen_width 20
#define screen_height 12
#define FIRST_OBJET 30
#define FIRST_NMI 101
#define MAXIMUM_BONUS 100
#define MAXIMUM_ENERGY 16
#define GESTION_X 40
#define GESTION_Y 20
#define MAX_SPEED_DEAD 20

enum HFLAG : uint8_t {
    HFLAG_NOWALL = 0,
    HFLAG_WALL = 1,
    HFLAG_BONUS = 2,
    HFLAG_DEADLY = 3,
    HFLAG_CODE = 4,
    HFLAG_PADLOCK = 5,
    HFLAG_LEVEL14 = 6
};

enum FFLAG : uint8_t {
    FFLAG_NOFLOOR = 0,
    FFLAG_FLOOR = 1,
    FFLAG_SSFLOOR = 2,
    FFLAG_SFLOOR = 3,
    FFLAG_VSFLOOR = 4,
    FFLAG_DROP = 5,
    FFLAG_LADDER = 6,
    FFLAG_BONUS = 7,
    FFLAG_WATER = 8,
    FFLAG_FIRE = 9,
    FFLAG_SPIKES = 10,
    FFLAG_CODE = 11,
    FFLAG_PADLOCK = 12,
    FFLAG_LEVEL14 = 13
};

enum CFLAG : uint8_t {
    CFLAG_NOCEILING = 0,
    CFLAG_CEILING = 1,
    CFLAG_LADDER = 2,
    CFLAG_PADLOCK = 3,
    CFLAG_DEADLY = 4
};


typedef struct {
    bool enabled;
    uint16_t NUM;
} SPRITE;

typedef struct {
    bool enabled;
    uint16_t NUM;
} SPRITEDATA;

extern uint8_t RESETLEVEL_FLAG;
extern bool LOSELIFE_FLAG;

extern bool GAMEOVER_FLAG; //triggers a game over
extern uint8_t BAR_FLAG; //timer for health bar
extern bool X_FLAG; //true if left or right key is pressed
extern bool Y_FLAG; //true if up or down key is pressed
extern uint8_t CHOC_FLAG; //headache timer
extern uint8_t action; //player sprite array
extern uint8_t KICK_FLAG; //hit/burn timer
extern bool GRANDBRULE_FLAG; //If set, player will be "burned" when hit (fireballs)
extern bool LADDER_FLAG; //True if in a ladder
extern bool PRIER_FLAG; //True if player is forced into kneestanding because of low ceiling
extern uint8_t SAUT_FLAG; //6 if free fall or in the middle of a jump, decremented if on solid surface. Must be 0 to initiate a jump.
extern uint8_t LAST_ORDER; //Last action (kneestand + jump = silent walk)
extern uint8_t FURTIF_FLAG; //Silent walk timer
extern bool DROP_FLAG; //True if an object is throwed forward
extern bool DROPREADY_FLAG;
extern bool CARRY_FLAG; //true if carrying something (add 16 to player sprite)
extern bool POSEREADY_FLAG;
extern uint8_t ACTION_TIMER; //Frames since last action change
extern uint8_t INVULNERABLE_FLAG; //When non-zero, boss is invulnerable
extern uint8_t TAPISFLY_FLAG; //When non-zero, the flying carpet is flying
extern uint8_t CROSS_FLAG; //When non-zero, fall through certain floors (after key down)
extern uint8_t GRAVITY_FLAG; //When zero, skip object gravity function
extern uint8_t FUME_FLAG; //Smoke when object hits the floor
extern const uint8_t *keystate; //Keyboard state
extern uint8_t YFALL;
extern bool POCKET_FLAG;
extern bool PERMUT_FLAG; //If false, there are no animated tiles on the screen?
extern uint8_t loop_cycle; //Increased every loop in game loop
extern uint8_t tile_anim; //Current tile animation (0-1-2), changed every 4th game loop cycle

// scrolling madness
extern int16_t BITMAP_X; //Screen offset (X) in tiles
extern int16_t BITMAP_Y; //Screen offset (Y) in tiles
extern bool g_scroll_x; //If true, the screen will scroll in X
extern int16_t g_scroll_px_offset;
extern int16_t XLIMIT; //The engine will not scroll past this tile before the player have crossed the line (X)
extern bool XLIMIT_BREACHED;
extern bool g_scroll_y; //If true, the screen will scroll in Y
extern uint8_t g_scroll_y_target; //If scrolling: scroll until player is in this tile (Y)
extern int16_t ALTITUDE_ZERO; //The engine will not scroll below this tile before the player have gone below (Y)

extern uint16_t IMAGE_COUNTER; //Increased every loop in game loop (0 to 0x0FFF)
extern int8_t SENSX; //1: walk right, 0: stand still, -1: walk left, triggers the ACTION_TIMER if it changes
extern uint8_t SAUT_COUNT; //Incremented from 0 to 3 when accelerating while jumping, stop acceleration upwards if >= 3
extern bool NOSCROLL_FLAG;
extern bool NEWLEVEL_FLAG; //Finish a level
extern bool SKIPLEVEL_FLAG; //Finish a level
extern uint8_t TAUPE_FLAG; //Used for enemies walking and popping up
extern uint8_t TAPISWAIT_FLAG; //Flying carpet state
extern uint8_t SEECHOC_FLAG; //Counter when hit


extern bool boss_alive;
extern uint8_t boss_lives;

extern bool GODMODE; //If true, the player will not interfere with the enemies
extern bool NOCLIP; //If true, the player will move noclip
extern bool DISPLAYLOOPTIME; //If true, display loop time in milliseconds

extern SPRITE sprites[256];

extern SPRITEDATA spritedata[256];

