//
// Copyright (C) 2008 - 2024 The OpenTitus team
//
// Authors:
// Eirik Stople
// Petr Mrázek
//
// "Titus the Fox: To Marrakech and Back" (1992) and
// "Lagaf': Les Aventures de Moktar - Vol 1: La Zoubida" (1991)
// was developed by, and is probably copyrighted by Titus Software,
// which, according to Wikipedia, stopped buisness in 2005.
//
// OpenTitus is not affiliated with Titus Software.
//
// OpenTitus is  free software; you can redistribute  it and/or modify
// it under the  terms of the GNU General  Public License as published
// by the Free  Software Foundation; either version 3  of the License,
// or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful, but
// WITHOUT  ANY  WARRANTY;  without   even  the  implied  warranty  of
// MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.   See the GNU
// General Public License for more details.
//

const std = @import("std");

pub const screen_width = 20;
pub const screen_height = 12;

pub const TEST_ZONE = 4;
pub const MAX_X = 4;
pub const MAX_Y = 12;
pub const MAP_LIMIT_Y = -1;
pub const FIRST_OBJET = 30;
pub const FIRST_NMI = 101;
pub const MAXIMUM_BONUS = 100;
pub const MAXIMUM_ENERGY = 16;
pub const GESTION_X = 40;
pub const GESTION_Y = 20;
pub const MAX_SPEED_DEAD = 20;

pub const TileCoord = i16;
pub const PixelCoord = i16;

pub export var RESETLEVEL_FLAG: u8 = 0;
pub export var LOSELIFE_FLAG: bool = false;

// triggers a game over
pub export var GAMEOVER_FLAG: bool = false;

// timer for health bar
pub export var BAR_FLAG: u8 = 0;

// true if left or right key is pressed
pub export var X_FLAG: bool = false;

// true if up or down key is pressed
pub export var Y_FLAG: bool = false;

// headache timer
pub export var CHOC_FLAG: u8 = 0;

// hit/burn timer
pub export var KICK_FLAG: u8 = 0;

// If set, player will be "burned" when hit (fireballs)
pub export var GRANDBRULE_FLAG: bool = false;

// True if on a ladder
pub export var LADDER_FLAG: bool = false;

//True if player is forced into kneestanding because of low ceiling
pub export var PRIER_FLAG: bool = false;

//6 if free fall or in the middle of a jump, decremented if on solid surface. Must be 0 to initiate a jump.
pub export var SAUT_FLAG: u8 = 0;

//Last action (kneestand + jump = silent walk)
pub export var LAST_ORDER: u8 = 0;

//Silent walk timer
pub export var FURTIF_FLAG: u8 = 0;

//True if an object is throwed forward
pub export var DROP_FLAG: bool = false;

pub export var DROPREADY_FLAG: bool = false;

//true if carrying something (add 16 to player sprite)
pub export var CARRY_FLAG: bool = false;

pub export var POSEREADY_FLAG: bool = false;

//Frames since last action change
pub export var ACTION_TIMER: u8 = 0;

//When non-zero, boss is invulnerable
pub export var INVULNERABLE_FLAG: u8 = 0;

//When non-zero, fall through certain floors (after key down)
pub export var CROSS_FLAG: u8 = 0;

//When zero, skip object gravity function
pub export var GRAVITY_FLAG: u8 = 0;

//Smoke when object hits the floor
pub export var FUME_FLAG: u8 = 0;

pub export var YFALL: u8 = 0;

pub export var POCKET_FLAG: bool = false;

//Increased every loop in game loop
pub export var loop_cycle: u8 = 0;

//Current tile animation (0-1-2), changed every 4th game loop cycle
pub export var tile_anim: u8 = 0;

//Screen offset (X) in tiles
pub export var BITMAP_X: TileCoord = 0;

//Screen offset (Y) in tiles
pub export var BITMAP_Y: TileCoord = 0;

//If true, the screen will scroll in X
pub export var g_scroll_x: bool = false;

pub export var g_scroll_px_offset: PixelCoord = 0;

//The engine will not scroll past this tile before the player have crossed the line (X)
pub export var XLIMIT: TileCoord = 0;
pub export var XLIMIT_BREACHED: bool = false;

//If true, the screen will scroll in Y
pub export var g_scroll_y: bool = false;

//If scrolling: scroll until player is in this tile (Y)
pub export var g_scroll_y_target: TileCoord = 0;

//The engine will not scroll below this tile before the player have gone below (Y)
pub export var ALTITUDE_ZERO: TileCoord = 0;

//Increased every loop in game loop (0 to 0x0FFF)
pub export var IMAGE_COUNTER: u16 = 0;

//1: walk right, 0: stand still, -1: walk left, triggers the ACTION_TIMER if it changes
pub export var SENSX: i8 = 0;

//Incremented from 0 to 3 when accelerating while jumping, stop acceleration upwards if >= 3
pub export var SAUT_COUNT: u8 = 0;

pub export var NOSCROLL_FLAG: bool = false;

//Finish a level
pub export var NEWLEVEL_FLAG: bool = false;

//Skip a level without recording completion (cheat)
pub export var SKIPLEVEL_FLAG: bool = false;

//Used for enemies walking and popping up
pub export var TAUPE_FLAG: u8 = 0;

//When non-zero, the flying carpet is flying
pub export var TAPISFLY_FLAG: u8 = 0;

//Flying carpet state
pub export var TAPISWAIT_FLAG: u8 = 0;

//Counter when hit
pub export var SEECHOC_FLAG: u8 = 0;

//Lives of the boss
pub export var boss_lives: u8 = 0;

//True if the boss is alive
pub export var boss_alive: bool = false;

//If true, the player will not interfere with the enemies
pub export var GODMODE: bool = false;

//If true, the player will move noclip
pub export var NOCLIP: bool = false;

//If true, display loop time in milliseconds
pub export var DISPLAYLOOPTIME: bool = false;
