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

/* enemies.c
 * Handles enemies.
 *
 * Global functions:
 * void moveEnemies(TITUS_level *level): Move enemies, is called by main game
 * loop void SET_NMI(TITUS_level *level): Collision detection, animation, is
 * called by main game loop void moveTrash(TITUS_level *level): Move objects
 * thrown by enemies
 */

#include "audio.h"
#include "common.h"
#include "game.h"
#include "globals_old.h"
#include "level.h"
#include "objects.h"
#include "player.h"
#include "sprites.h"
#include <stdlib.h>

static bool NMI_VS_DROP(TITUS_sprite *enemysprite, TITUS_sprite *sprite);
static void KICK_ASH(TITUS_level *level, TITUS_sprite *enemysprite,
                     int16_t power);
static TITUS_sprite *FIND_TRASH(TITUS_level *level);
static void DEAD1(TITUS_level *level, TITUS_enemy *enemy);
static void PUT_BULLET(TITUS_level *level, TITUS_enemy *enemy,
                       TITUS_sprite *bullet);
static void GAL_FORM(TITUS_level *level, TITUS_enemy *enemy);
static void SEE_CHOC(TITUS_level *level);
static void ACTIONC_NMI(TITUS_level *level, TITUS_enemy *enemy);

static void UP_ANIMATION(TITUS_sprite *sprite) {
  do {
    sprite->animation++;
  } while (*sprite->animation >= 0);
  sprite->animation++;
}

static void DOWN_ANIMATION(TITUS_sprite *sprite) {
  do {
    sprite->animation--;
  } while (*sprite->animation >= 0);
  sprite->animation--;
}

void moveEnemies(TITUS_level *level) {
  TITUS_sprite *bullet;
  int j;
  for (int i = 0; i < ENEMY_CAPACITY; i++) {

    TITUS_enemy *enemy = &level->enemy[i];
    TITUS_sprite *enemySprite = &enemy->sprite;
    // Skip unused enemies
    if (!(enemySprite->enabled)) {
      continue;
    }
    switch (enemy->type) {
    case 0:
    case 1:
      // Noclip walk
      if (enemy->dying != 0) { // If not 0, the enemy is dying or dead, and have
                               // special movement
        DEAD1(level, enemy);
        continue;
      }
      enemySprite->x -= enemySprite->speed_x; // Move the enemy
      if (abs(enemySprite->x - enemy->center_x) >
          enemy->range_x) { // If the enemy is range_x from center, turn
                            // direction
        if (enemySprite->x >=
            enemy->center_x) { // The enemy is at rightmost edge
          enemySprite->speed_x = abs(enemySprite->speed_x);
        } else { // The enemy is at leftmost edge
          enemySprite->speed_x = 0 - abs(enemySprite->speed_x);
        }
      }
      break;

    case 2:
      // Shoot
      if (enemy->dying != 0) { // If not 0, the enemy is dying or dead, and have
                               // special movement
        DEAD1(level, enemy);
        continue;
      }
      if (!enemy->visible) { // Skip if not on screen
        continue;
      }
      // Give directions!
      if (enemy->direction == 0) { // Both ways
        enemySprite->speed_x = 0;
        if (enemySprite->x < level->player.sprite.x) {
          enemySprite->speed_x = -1;
        }
      } else if (enemy->direction == 2) { // Right only
        enemySprite->speed_x = -1;        // Flip the sprite
      } else {                            // Left only
        enemySprite->speed_x = 0;         // Not flipped (facing left)
      }
      switch (enemy->phase) { // State dependent actions
      case 0:
        // Scans the horizon!
        subto0(&(enemy->counter));
        if (enemy->counter != 0) { // Decrease delay timer
          continue;
        }
        if (abs(level->player.sprite.y - enemySprite->y) > 24) {
          continue;
        }
        if (enemy->range_x <
            abs(level->player.sprite.x - enemySprite->x)) { // if too far apart
          continue;
        }
        if (enemy->direction != 0) {
          if (enemy->direction == 2) { // Right only
            if (enemySprite->x >
                level->player.sprite
                    .x) { // Skip shooting if player is in opposite direction
              continue;
            }
          } else {
            if (level->player.sprite.x >
                enemySprite
                    ->x) { // Skip shooting if player is in opposite direction
              continue;
            }
          }
        }
        enemy->phase = 30; // change state
        UP_ANIMATION(enemySprite);
        break;
      default:
        enemy->phase--;
        if (!enemy->trigger) {
          continue;
        }
        enemySprite->animation += 2;
        if ((bullet = FIND_TRASH(level))) {
          PUT_BULLET(level, enemy, bullet);
          // enemy->counter = NMI_FREQ; //set delay timer
          enemy->counter = enemy->delay; // set delay timer
        }
        enemy->phase = 0;
        break;
      }
      break;

    case 3:
    case 4:
      // Noclip walk, jump to player (fish)
      if (enemy->dying != 0) { // If not 0, the enemy is dying or dead, and have
                               // special movement
        DEAD1(level, enemy);
        continue;
      }
      switch (enemy->phase) { // State dependent actions
      case 0:
        enemySprite->x -= enemySprite->speed_x; // Move the enemy
        if (abs(enemySprite->x - enemy->center_x) >
            enemy->range_x) { // If the enemy is range_x from center, turn
                              // direction
          if (enemySprite->x >=
              enemy->center_x) { // The enemy is at rightmost edge
            enemySprite->speed_x = abs(enemySprite->speed_x);
          } else { // The enemy is at leftmost edge
            enemySprite->speed_x = 0 - abs(enemySprite->speed_x);
          }
        }
        if (!enemy->visible) { // Is the enemy on the screen?
          continue;
        }
        if ((enemySprite->y < level->player.sprite.y) ||
            (enemySprite->y >=
             (level->player.sprite.y +
              256))) { // Skip if player is below or >= 256 pixels above
          continue;
        }
        if (enemy->range_y <
            (enemySprite->y -
             level->player.sprite.y)) { // Skip if player is above jump limit
          continue;
        }
        // see if the hero is in the direction of movement of fish
        if (enemySprite->x >
            level->player.sprite.x) { // The enemy is right for the player
          if (enemySprite->flipped == true) { // The enemy looks right, skip
            continue;
          }
        } else { // The enemy is left for the player
          if (enemySprite->flipped == false) { // The enemy looks left, skip
            continue;
          }
        }
        if (abs(enemySprite->x - level->player.sprite.x) >=
            48) { // Fast calculation
          continue;
        }
        // See if the hero is above the area of fish
        if (abs(level->player.sprite.x - enemy->center_x) > enemy->range_x) {
          continue;
        }
        enemy->phase = 1; // Change state
        // Calculation speed to the desired height
        enemySprite->speed_y = 0;
        j = 0;
        do {
          enemySprite->speed_y++; // Set init jump speed
          j += enemySprite->speed_y;
        } while (
            (enemySprite->y - level->player.sprite.y) >
            j); // Make sure the enemy will jump high enough to hit the player
        enemySprite->speed_y =
            0 - enemySprite->speed_y; // Init speed must be negative
        enemy->delay =
            enemySprite
                ->y; // Delay: Last _y position, reuse of the delay variable
        UP_ANIMATION(enemySprite);
        break;
      case 1:
        if (!enemy->visible) { // Is the enemy on the screen?
          continue;
        }
        enemySprite->x -= enemySprite->speed_x << 2;
        enemySprite->y += enemySprite->speed_y;
        if (enemySprite->speed_y + 1 < 0) {
          enemySprite->speed_y++;
          if (enemySprite->y >
              (enemy->delay - enemy->range_y)) { // Delay: Last _y position,
                                                 // reuse of the delay variable
            continue;
          }
        }
        UP_ANIMATION(enemySprite);
        enemy->phase = 2;
        enemySprite->speed_y = 0;
        if (enemySprite->x <= enemy->center_x) {
          enemySprite->speed_x = abs(enemySprite->speed_x);
        } else {
          enemySprite->speed_x = 0 - abs(enemySprite->speed_x);
        }
        break;
      case 2:
        if (!enemy->visible) { // Is the enemy on the screen?
          continue;
        }
        enemySprite->x -= enemySprite->speed_x;
        enemySprite->y += enemySprite->speed_y; // 2: fall!
        enemySprite->speed_y++;
        if (enemySprite->y <
            enemy->delay) { // 3: we hit bottom? //Delay: Last Y position, reuse
                            // of the delay variable
          continue;
        }
        enemySprite->y =
            enemy->delay; // Delay: Last Y position, reuse of the delay variable
        enemySprite->x -= enemySprite->speed_x;
        enemy->phase = 0;
        DOWN_ANIMATION(enemySprite);
        DOWN_ANIMATION(enemySprite);
        break;
      }
      break;

    case 5:
    case 6:
      // Noclip walk, move to player (fly)
      if (enemy->dying != 0) { // If not 0, the enemy is dying or dead, and have
                               // special movement
        DEAD1(level, enemy);
        continue;
      }
      enemySprite->x -= enemySprite->speed_x; // Move the enemy
      if (abs(enemySprite->x - enemy->center_x) >
          enemy->range_x) { // If the enemy is range_x from center, turn
                            // direction
        if (enemySprite->x >=
            enemy->center_x) { // The enemy is at rightmost edge
          enemySprite->speed_x = abs(enemySprite->speed_x);
        } else { // The enemy is at leftmost edge
          enemySprite->speed_x = 0 - abs(enemySprite->speed_x);
        }
      }
      if (!enemy->visible) { // Is the enemy on the screen?
        continue;
      }
      switch (enemy->phase) { // State dependent actions
      case 0:
        // Forward
        if (abs(enemySprite->y - level->player.sprite.y) >
            enemy->range_y) { // Too far away
          continue;
        }
        if (abs(enemySprite->x - level->player.sprite.x) > 40) { // Too far away
          continue;
        }
        enemy->delay =
            enemySprite
                ->y; // Delay: Last Y position, reuse of the delay variable
        if (enemySprite->y <
            level->player.sprite.y) { // Player is below the enemy
          enemySprite->speed_y = 2;
        } else { // Player is above the enemy
          enemySprite->speed_y = -2;
        }
        enemy->phase = 1; // Change state
        UP_ANIMATION(enemySprite);
        break;
      case 1:
        // Attack
        enemySprite->y += enemySprite->speed_y;
        if (labs((long)(enemySprite->y) - (long)(enemy->delay)) <
            enemy->range_y) { // Delay: Last Y position, reuse of the delay
                              // variable
          continue;
        }
        enemySprite->speed_y = 0 - enemySprite->speed_y;
        UP_ANIMATION(enemySprite);
        enemy->phase = 2;
        break;
      case 2:
        // Back up!
        enemySprite->y += enemySprite->speed_y;
        if (enemySprite->y != enemy->delay) { // Delay: Last Y position, reuse
                                              // of the delay variable
          continue;
        }
        DOWN_ANIMATION(enemySprite);
        DOWN_ANIMATION(enemySprite);
        enemy->phase = 0;
        break;
      }
      break;

    case 7:
      // Gravity walk, hit when near
      if (enemy->dying != 0) { // If not 0, the enemy is dying or dead, and have
                               // special movement
        DEAD1(level, enemy);
        continue;
      }
      switch (enemy->phase) { // State dependent actions
      case 0:
        // Waiting
        if (enemySprite->y > level->player.sprite.y) {
          continue;
        }
        if (enemy->range_x < abs(enemySprite->x - level->player.sprite.x)) {
          continue;
        }
        if (abs(enemySprite->y - level->player.sprite.y) > 200) {
          continue;
        }
        enemy->phase = 1;
        UP_ANIMATION(enemySprite);
        if (enemySprite->x >
            level->player.sprite.x) { // Enemy is right for the player
          enemySprite->speed_x = enemy->walkspeed_x; // Move left
        } else { // Enemy is left for the player
          enemySprite->speed_x = 0 - enemy->walkspeed_x; // Move right
        }
        break;
      case 1:
        // Gravity walk
        if (get_floorflag(level, (enemySprite->y >> 4),
                          (enemySprite->x >> 4)) == FFLAG_NOFLOOR) {
          if (enemySprite->speed_y < 16) { // 16 = Max yspeed
            enemySprite->speed_y++;
          }
          enemySprite->y += enemySprite->speed_y;
          continue;
        }
        if (enemySprite->speed_y != 0) {
          if (enemySprite->x >
              level->player.sprite.x) { // Enemy is right for the player
            enemySprite->speed_x = enemy->walkspeed_x; // Move left
          } else { // Enemy is left for the player
            enemySprite->speed_x = 0 - enemy->walkspeed_x; // Move right
          }
        }
        enemySprite->speed_y = 0;
        enemySprite->y = enemySprite->y & 0xFFF0;
        if (enemySprite->speed_x > 0) {
          j = -1; // moving left
        } else {
          j = 1; // moving right
        }
        enum HFLAG hflag = get_horizflag(level, (enemySprite->y >> 4) - 1,
                                         (enemySprite->x >> 4) + j);
        if ((hflag == HFLAG_WALL) || (hflag == HFLAG_DEADLY) ||
            (hflag == HFLAG_PADLOCK)) { // Next tile is wall, change direction
          enemySprite->speed_x = 0 - enemySprite->speed_x;
        }
        enemySprite->x -= enemySprite->speed_x;
        if (enemySprite->x < 0) {
          enemySprite->speed_x = 0 - enemySprite->speed_x;
          enemySprite->x -= enemySprite->speed_x;
        }
        if (abs(level->player.sprite.x - enemySprite->x) >
            320 * 2) { // Too far away from the player in X, reset
          enemy->phase = 2;
          continue;
        }
        if (abs(level->player.sprite.y - enemySprite->y) >=
            200 * 2) { // Too far away from the player in Y, reset
          enemy->phase = 2;
          continue;
        }
        if (abs(level->player.sprite.x - enemySprite->x) >
            enemySprite->spritedata->width + 6) {
          continue;
        }
        if (abs(level->player.sprite.y - enemySprite->y) > 8) {
          continue;
        }
        enemy->phase = 3; // The player is close to the enemy, strike!
        UP_ANIMATION(enemySprite);
        break;
      case 2:
        // Reset the enemy
        if (((enemy->init_y >> 4) - BITMAP_Y <= 13) && // 13 tiles in Y
            ((enemy->init_y >> 4) - BITMAP_Y >= 0) &&
            ((enemy->init_x >> 4) - BITMAP_X < 21) && // 21 tiles in X
            ((enemy->init_x >> 4) - BITMAP_X >= 0)) {
          continue; // Player is too close to the enemy's spawning point
        }
        enemySprite->y = enemy->init_y;
        enemySprite->x = enemy->init_x;
        enemy->phase = 0;
        DOWN_ANIMATION(enemySprite);
        break;
      case 3:
        // Strike!
        if (enemy->trigger) { // End of strike animation (TODO: check if this
                              // will ever be executed)
          enemy->phase = 1;
          continue;
        }
        // Gravity walk (equal to the first part of "case 1:")
        if (get_floorflag(level, (enemySprite->y >> 4),
                          (enemySprite->x >> 4)) == FFLAG_NOFLOOR) {
          if (enemySprite->speed_y < 16) { // 16 = Max yspeed
            enemySprite->speed_y++;
          }
          enemySprite->y += enemySprite->speed_y;
          continue;
        }
        if (enemySprite->speed_y != 0) {
          if (enemySprite->x >
              level->player.sprite.x) { // Enemy is right for the player
            enemySprite->speed_x = enemy->walkspeed_x; // Move left
          } else { // Enemy is left for the player
            enemySprite->speed_x = 0 - enemy->walkspeed_x; // Move right
          }
        }
        enemySprite->speed_y = 0;
        enemySprite->y = enemySprite->y & 0xFFF0;
        if (enemySprite->speed_x > 0) {
          j = -1; // moving left
        } else {
          j = 1; // moving right
        }
        hflag = get_horizflag(level, (enemySprite->y >> 4) - 1,
                              (enemySprite->x >> 4) + j);
        if ((hflag == HFLAG_WALL) || (hflag == HFLAG_DEADLY) ||
            (hflag == HFLAG_PADLOCK)) { // Next tile is wall, change direction
          enemySprite->speed_x = 0 - enemySprite->speed_x;
        }
        enemySprite->x -= enemySprite->speed_x;
        if (enemySprite->x < 0) {
          enemySprite->speed_x = 0 - enemySprite->speed_x;
          enemySprite->x -= enemySprite->speed_x;
        }
        if (abs(level->player.sprite.x - enemySprite->x) >
            320 * 2) { // Too far away from the player in X, reset
          enemy->phase = 2;
          continue;
        }
        if (abs(level->player.sprite.y - enemySprite->y) >=
            200 * 2) { // Too far away from the player in Y, reset
          enemy->phase = 2;
          continue;
        }
        break;
      }
      break;

    case 8:  // Gravity walk when off-screen
    case 14: // Gravity walk when off-screen (immortal)
      if (enemy->type == 14) {
        enemy->dying = 0;             // Immortal
      } else if (enemy->dying != 0) { // If not 0, the enemy is dying or dead,
                                      // and have special movement
        DEAD1(level, enemy);
        continue;
      }
      switch (enemy->phase) { // State dependent actions
      case 0:
        // waiting
        if ((abs(enemySprite->x - level->player.sprite.x) > 340) ||
            (abs(enemySprite->y - level->player.sprite.y) >= 230)) {
          enemy->phase = 1;
          UP_ANIMATION(enemySprite);
          if (enemySprite->x >
              level->player.sprite.x) { // Enemy is right for the player
            enemySprite->speed_x = enemy->walkspeed_x; // Move left
          } else { // Enemy is left for the player
            enemySprite->speed_x = 0 - enemy->walkspeed_x; // Move right
          }
        }
        break;
      case 1:
        if (get_floorflag(level, (enemySprite->y >> 4),
                          (enemySprite->x >> 4)) == FFLAG_NOFLOOR) {
          if (enemySprite->speed_y < 16) { // 16 = Max yspeed
            enemySprite->speed_y++;
          }
          enemySprite->y += enemySprite->speed_y;
          continue;
        }
        if (enemySprite->speed_y != 0) {
          if (enemySprite->x >
              level->player.sprite.x) { // Enemy is right for the player
            enemySprite->speed_x = enemy->walkspeed_x; // Move left
          } else { // Enemy is left for the player
            enemySprite->speed_x = 0 - enemy->walkspeed_x; // Move right
          }
        }
        enemySprite->speed_y = 0;
        enemySprite->y = enemySprite->y & 0xFFF0;
        if (enemySprite->speed_x > 0) {
          j = -1; // moving left
        } else {
          j = 1; // moving right
        }
        enum HFLAG hflag = get_horizflag(level, (enemySprite->y >> 4) - 1,
                                         (enemySprite->x >> 4) + j);
        if ((hflag == HFLAG_WALL) || (hflag == HFLAG_DEADLY) ||
            (hflag == HFLAG_PADLOCK)) { // Next tile is wall, change direction
          enemySprite->speed_x = 0 - enemySprite->speed_x;
        }
        enemySprite->x -= enemySprite->speed_x;
        if (enemySprite->x < 0) {
          enemySprite->speed_x = 0 - enemySprite->speed_x;
          enemySprite->x -= enemySprite->speed_x;
        }
        if (abs(level->player.sprite.x - enemySprite->x) < 320 * 2) {
          continue;
        }
        enemy->phase = 2;
        break;
      case 2:
        // Reset the enemy
        if (((enemy->init_y >> 4) - BITMAP_Y < 12) && // 12 tiles in Y
            ((enemy->init_y >> 4) - BITMAP_Y >= 0) &&
            ((enemy->init_x >> 4) - BITMAP_X < 19) && // 19 tiles in X
            ((enemy->init_x >> 4) - BITMAP_X >= 0)) {
          continue; // Player is too close to the enemy's spawning point
        }
        enemySprite->y = enemy->init_y;
        enemySprite->x = enemy->init_x;
        enemy->phase = 0;
        DOWN_ANIMATION(enemySprite);
        break;
      }
      break;

    case 9:
      // Walk and periodically pop-up
      if (enemy->dying != 0) { // If not 0, the enemy is dying or dead, and have
                               // special movement
        DEAD1(level, enemy);
        continue;
      }
      switch (enemy->phase) { // State dependent actions
      case 0:
        // wait for its prey!
        if (enemy->range_x < abs(level->player.sprite.x - enemySprite->x)) {
          continue;
        }
        if (abs(level->player.sprite.y - enemySprite->y) > 60) {
          continue;
        }
        enemy->phase = 1;
        UP_ANIMATION(enemySprite);
        if (enemySprite->x >
            level->player.sprite.x) { // Enemy is right for the player
          enemySprite->speed_x = enemy->walkspeed_x; // Move left
        } else { // Enemy is left for the player
          enemySprite->speed_x = 0 - enemy->walkspeed_x; // Move right
        }
        break;
      case 1:
        // Special animation?
        TAUPE_FLAG++;
        if (((TAUPE_FLAG & 0x04) ==
             0) && // xxxxx0xx //true 4 times, false 4 times,
            ((IMAGE_COUNTER & 0x01FF) ==
             0)) { // xxxxxxx0 00000000 //true 1 time, false 511 times
          UP_ANIMATION(enemySprite);
        }
        if ((IMAGE_COUNTER & 0x007F) ==
            0) { // xxxxxxxx x0000000 //true 1 time, false 127 times
          enemy->phase = 3;
          UP_ANIMATION(enemySprite);
          // Same as "case 3:"
          // Remove the head or Periskop!
          if (!enemy->visible) { // Is it on the screen?
            // Give the sequence # 2 and Phase # 1
            UP_ANIMATION(enemySprite);
            enemySprite->animation--; // Previous animation frame
            GAL_FORM(level, enemy);
            if (enemySprite->x >
                level->player.sprite.x) { // Enemy is right for the player
              enemySprite->speed_x = enemy->walkspeed_x; // Move left
            } else { // Enemy is left for the player
              enemySprite->speed_x = 0 - enemy->walkspeed_x; // Move right
            }
            enemy->phase = 1;
          } else if (enemy->trigger) {
            if (enemySprite->x >
                level->player.sprite.x) { // Enemy is right for the player
              enemySprite->speed_x = enemy->walkspeed_x; // Move left
            } else { // Enemy is left for the player
              enemySprite->speed_x = 0 - enemy->walkspeed_x; // Move right
            }
            enemy->phase = 1;
          }
          continue;
        }
        if (get_floorflag(level, (enemySprite->y >> 4),
                          (enemySprite->x >> 4)) == FFLAG_NOFLOOR) {
          enemySprite->speed_x = abs(enemySprite->speed_x);
          if (enemy->init_x > enemySprite->x) {
            enemySprite->speed_x = 0 - enemySprite->speed_x;
          }
        }
        enemySprite->y = enemySprite->y & 0xFFF0;
        if (enemySprite->speed_x > 0) {
          j = -1; // moving left
        } else {
          j = 1; // moving right
        }
        enum HFLAG hflag = get_horizflag(level, (enemySprite->y >> 4) - 1,
                                         (enemySprite->x >> 4) + j);
        if ((hflag == HFLAG_WALL) || (hflag == HFLAG_DEADLY) ||
            (hflag == HFLAG_PADLOCK)) { // Next tile is wall, change direction
          enemySprite->speed_x = 0 - enemySprite->speed_x;
        }
        enemySprite->x -= enemySprite->speed_x;
        if (enemySprite->x < 0) {
          enemySprite->speed_x = 0 - enemySprite->speed_x;
          enemySprite->x -= enemySprite->speed_x;
        }
        if (abs(level->player.sprite.x - enemySprite->x) < 320 * 4) {
          continue;
        }
        enemy->phase = 2;
        break;
      case 2:
        // Reset, if not visible on the screen
        if (((enemy->init_y >> 4) - BITMAP_Y <= 12) && // 12 tiles in Y
            ((enemy->init_y >> 4) - BITMAP_Y >= 0) &&
            ((enemy->init_x >> 4) - BITMAP_X < 25) && // 25 tiles in X
            ((enemy->init_x >> 4) - BITMAP_X >= 0)) {
          continue; // Player is too close to the enemy's spawning point
        }
        enemySprite->y = enemy->init_y;
        enemySprite->x = enemy->init_x;
        enemy->phase = 0;
        DOWN_ANIMATION(enemySprite);
        break;
      case 3:
        // Remove the head or Periskop!
        if (!enemy->visible) { // Is it on the screen?
          UP_ANIMATION(enemySprite);
          enemySprite->animation--; // Previous animation frame
          GAL_FORM(level, enemy);
          if (enemySprite->x >
              level->player.sprite.x) { // Enemy is right for the player
            enemySprite->speed_x = enemy->walkspeed_x; // Move left
          } else { // Enemy is left for the player
            enemySprite->speed_x = 0 - enemy->walkspeed_x; // Move right
          }
          enemy->phase = 1;
        } else if (enemy->trigger) {
          if (enemySprite->x >
              level->player.sprite.x) { // Enemy is right for the player
            enemySprite->speed_x = enemy->walkspeed_x; // Move left
          } else { // Enemy is left for the player
            enemySprite->speed_x = 0 - enemy->walkspeed_x; // Move right
          }
          enemy->phase = 1;
        }
        break;
      }
      break;

    case 10:
      // Alert when near, walk when nearer
      if (enemy->dying != 0) { // If not 0, the enemy is dying or dead, and have
                               // special movement
        DEAD1(level, enemy);
        continue;
      }
      switch (enemy->phase) { // State dependent actions
      case 0:
        if (FURTIF_FLAG != 0) {
          continue;
        }
        if (enemy->range_x < abs(level->player.sprite.x - enemySprite->x)) {
          continue;
        }
        if (abs(level->player.sprite.y - enemySprite->y) > 26) {
          continue;
        }
        enemy->phase = 1;
        UP_ANIMATION(enemySprite);
        if (enemySprite->x >
            level->player.sprite.x) { // Enemy is right for the player
          enemySprite->speed_x = enemy->walkspeed_x; // Move left
        } else { // Enemy is left for the player
          enemySprite->speed_x = 0 - enemy->walkspeed_x; // Move right
        }
      case 1:
        // wait
        if (FURTIF_FLAG != 0) {
          continue;
        }
        if (enemy->range_x < abs(level->player.sprite.x - enemySprite->x)) {
          // Switch back to state 0
          DOWN_ANIMATION(enemySprite);
          enemy->phase = 0;
          continue;
        }
        if ((enemy->range_x - 50 >=
             abs(level->player.sprite.x - enemySprite->x)) &&
            (abs(level->player.sprite.y - enemySprite->y) <= 60)) {
          enemy->phase = 2;
          UP_ANIMATION(enemySprite);
        }
        break;
      case 2:
        // run
        if (get_floorflag(level, (enemySprite->y >> 4),
                          (enemySprite->x >> 4)) == FFLAG_NOFLOOR) {
          enemySprite->speed_x = abs(enemySprite->speed_x);
          if (enemy->init_x > enemySprite->x) {
            enemySprite->speed_x = 0 - enemySprite->speed_x;
          }
        }
        enemySprite->y = enemySprite->y & 0xFFF0;
        if (enemySprite->speed_x > 0) {
          j = -1; // moving left
        } else {
          j = 1; // moving right
        }
        enum HFLAG hflag = get_horizflag(level, (enemySprite->y >> 4) - 1,
                                         (enemySprite->x >> 4) + j);
        if ((hflag == HFLAG_WALL) || (hflag == HFLAG_DEADLY) ||
            (hflag == HFLAG_PADLOCK)) { // Next tile is wall, change direction
          enemySprite->speed_x = abs(enemySprite->speed_x);
          if (enemy->init_x > enemySprite->x) {
            enemySprite->speed_x = 0 - enemySprite->speed_x;
          }
        }
        enemySprite->x -= enemySprite->speed_x;
        if (enemySprite->x < 0) {
          enemySprite->speed_x = 0 - enemySprite->speed_x;
          enemySprite->x -= enemySprite->speed_x;
        }
        if (abs(level->player.sprite.x - enemySprite->x) >= 320 * 2) {
          enemy->phase = 3;
        }
        break;
      case 3:
        // Reset, if not visible on the screen
        if (((enemy->init_y >> 4) - BITMAP_Y <= 13) && // 13 tiles in Y
            ((enemy->init_y >> 4) - BITMAP_Y >= 0) &&
            ((enemy->init_x >> 4) - BITMAP_X < 21) && // 21 tiles in X
            ((enemy->init_x >> 4) - BITMAP_X >= 0)) {
          continue; // Spawning point is visible on screen
        }
        enemySprite->y = enemy->init_y;
        enemySprite->x = enemy->init_x;
        DOWN_ANIMATION(enemySprite);
        DOWN_ANIMATION(enemySprite);
        enemy->phase = 0;
        break;
      }
      break;

    case 11:
      // Walk and shoot
      if (enemy->dying != 0) { // If not 0, the enemy is dying or dead, and have
                               // special movement
        DEAD1(level, enemy);
        continue;
      }
      switch (enemy->phase) { // State dependent actions
      case 0:
        // wait
        if (enemy->range_x < abs(level->player.sprite.x - enemySprite->x)) {
          continue;
        }
        if (abs(level->player.sprite.y - enemySprite->y) > 26) {
          continue;
        }
        enemy->phase = 1;
        UP_ANIMATION(enemySprite);
        if (enemySprite->x >
            level->player.sprite.x) { // Enemy is right for the player
          enemySprite->speed_x = enemy->walkspeed_x; // Move left
        } else { // Enemy is left for the player
          enemySprite->speed_x = 0 - enemy->walkspeed_x; // Move right
        }
        break;
      case 1:
        if (get_floorflag(level, (enemySprite->y >> 4),
                          (enemySprite->x >> 4)) == FFLAG_NOFLOOR) {
          enemySprite->speed_x = abs(enemySprite->speed_x);
          if (enemy->init_x > enemySprite->x) {
            enemySprite->speed_x = 0 - enemySprite->speed_x;
          }
        }
        enemySprite->y = enemySprite->y & 0xFFF0;
        enum HFLAG hflag = get_horizflag(level, (enemySprite->y >> 4) - 1,
                                         enemySprite->x >> 4);
        if ((hflag == HFLAG_WALL) || (hflag == HFLAG_DEADLY) ||
            (hflag == HFLAG_PADLOCK)) { // Next tile is wall, change direction
          enemySprite->speed_x = 0 - enemySprite->speed_x;
        }
        enemySprite->x -= enemySprite->speed_x;
        if (enemySprite->x < 0) {
          enemySprite->speed_x = 0 - enemySprite->speed_x;
          enemySprite->x -= enemySprite->speed_x;
        }
        if (abs(level->player.sprite.x - enemySprite->x) >= 320 * 2) {
          enemy->phase = 2;
        }
        subto0(&(enemy->counter));
        if (enemy->counter != 0) {
          continue;
        }
        if (abs(level->player.sprite.x - enemySprite->x) > 64) {
          continue;
        }
        if (abs(level->player.sprite.y - enemySprite->y) > 20) {
          continue;
        }
        if (enemySprite->x >
            level->player.sprite.x) { // Enemy is right for the player
          enemySprite->speed_x = enemy->walkspeed_x; // Move left
        } else { // Enemy is left for the player
          enemySprite->speed_x = 0 - enemy->walkspeed_x; // Move right
        }
        enemy->phase = 3; // phase started!
        UP_ANIMATION(enemySprite);
        enemy->counter = 20;
        break;
      case 2:
        // Reset enemy when spawn point isn't visible for the player
        if (((enemy->init_y >> 4) - BITMAP_Y >
             13) || // 13 tiles in Y (Spawn is below)
            ((enemy->init_y >> 4) - BITMAP_Y < 0) || // (Spawn is above)
            ((enemy->init_x >> 4) - BITMAP_X >=
             21) || // 21 tiles in X (Spawn is to the right)
            ((enemy->init_x >> 4) - BITMAP_X < 0)) { //(Spawn is to the right)
          enemySprite->x = enemy->init_x;
          enemySprite->y = enemy->init_y;
          DOWN_ANIMATION(enemySprite);
          enemy->phase = 0;
        }
        break;
      case 3:
        // Shoot
        if (!enemy->trigger) {
          continue;
        }
        if ((bullet = FIND_TRASH(level))) {
          enemySprite->animation += 2;
          PUT_BULLET(level, enemy, bullet);
        }
        DOWN_ANIMATION(enemySprite);
        enemy->phase = 1;
        break;
      }
      break;

    case 12:
      // Jump (fireball) (immortal)
      enemy->dying = 0;       // Immortal
      switch (enemy->phase) { // State dependent actions
      case 0:
        // init
        UP_ANIMATION(enemySprite);
        enemySprite->speed_y = enemy->range_y;
        enemy->init_y = enemySprite->y;
        enemy->phase = 1;
        break;
      case 1:
        // Fireball moving up
        enemySprite->y -= enemySprite->speed_y;
        enemySprite->speed_y--;
        if (enemySprite->speed_y == 0) {
          enemy->phase = 2;
        }
        break;
      case 2:
        // Fireball falling down
        enemySprite->y += enemySprite->speed_y;
        enemySprite->speed_y++;
        if (enemySprite->y >= enemy->init_y) {
          enemySprite->y = enemy->init_y;
          enemy->counter = enemy->delay;
          enemy->phase = 3;
          DOWN_ANIMATION(enemySprite);
        }
        break;
      case 3:
        // Fireball delay
        enemy->counter--;
        if (enemy->counter == 0) {
          enemy->phase = 0;
        }
        break;
      }
      break;

    case 13:
      // Bounce (big baby)
      if (enemy->dying != 0) { // If not 0, the enemy is dying or dead, and have
                               // special movement
        DEAD1(level, enemy);
        continue;
      }
      switch (enemy->phase) { // State dependent actions
      case 0:
        // remain at rest or attack!
        if (level->player.sprite.x >= enemySprite->x) {
          enemySprite->speed_x = 0 - abs(enemySprite->speed_x);
        } else {
          enemySprite->speed_x = abs(enemySprite->speed_x);
        }
        if ((abs(level->player.sprite.x - enemySprite->x) <= enemy->range_x) &&
            (abs(level->player.sprite.y - enemySprite->y) <= 40)) {
          UP_ANIMATION(enemySprite);
          enemy->phase = 1;
          enemySprite->speed_y = 10;
        }
        break;
      case 1:
        // Jump, move upwards
        enemySprite->x -= enemySprite->speed_x;
        enemySprite->y -= enemySprite->speed_y;
        enemySprite->speed_y--;
        if (enemySprite->speed_y == 0) {
          UP_ANIMATION(enemySprite);
          enemy->phase = 2;
        }
        break;
      case 2:
        // Fall down to the ground
        enemySprite->x -= enemySprite->speed_x;
        enemySprite->y += enemySprite->speed_y;
        enemySprite->speed_y++;
        if (enemySprite->speed_y > 10) {
          enemy->phase = 3;
          UP_ANIMATION(enemySprite);
          enemy->counter = enemy->delay;
        }
        break;
      case 3:
        // Stay on the ground for a while
        enemy->counter--;
        if (enemy->counter == 0) {
          DOWN_ANIMATION(enemySprite);
          DOWN_ANIMATION(enemySprite);
          DOWN_ANIMATION(enemySprite);
          enemy->phase = 0;
        }
        break;
      }
      break;

      // case 14:
      // Gravity walk when off-screen (immortal)
      // Located at case 8

    case 15:
      // Nothing (immortal)
      enemy->dying = 0; // Immortal
      break;

    case 16:
      // Nothing
      if (enemy->dying != 0) { // If not 0, the enemy is dying or dead, and have
                               // special movement
        DEAD1(level, enemy);
        continue;
      }
      break;

    case 17:
      // Drop (immortal)
      enemy->dying = 0; // Immortal
      // Delay
      if (enemy->counter + 1 < enemy->delay) {
        enemy->counter++;
        continue;
      }
      if (enemy->range_x <
          abs(enemySprite->x - level->player.sprite.x)) { // hero too far! at x
        enemy->counter = 0;
        continue;
      }
      if (enemy->range_y <
          (level->player.sprite.y - enemySprite->y)) { // hero too far! at y
        continue;
      }
      // you attack, so finding a free object
      j = 0;
      do {
        j++;
        if (j > OBJECT_CAPACITY) {
          enemy->counter = 0;
          continue;
        }
      } while (level->object[j].sprite.enabled == true);
      // object[j] is free!
      UP_ANIMATION(enemySprite);
      updateobjectsprite(level, &(level->object[j]),
                         *enemySprite->animation & 0x1FFF, true);
      level->object[j].sprite.flipped = true;
      level->object[j].sprite.x = enemySprite->x;
      level->object[j].sprite.y = enemySprite->y;
      level->object[j].sprite.droptobottom = true;
      level->object[j].sprite.killing = true;
      level->object[j].sprite.speed_y = 0;
      GRAVITY_FLAG = 4;
      DOWN_ANIMATION(enemySprite);
      enemy->counter = 0;
      break;

    case 18:
      // Guard (helicopter guy)
      if (enemy->dying != 0) { // If not 0, the enemy is dying or dead, and have
                               // special movement
        DEAD1(level, enemy);
        continue;
      }
      if ((level->player.sprite.x <
           (int16_t)(enemy->init_x -
                     enemy->range_x)) || // Player is too far left
          (level->player.sprite.x >
           (int16_t)(enemy->init_x +
                     enemy->range_x)) || // Player is too far right
          (level->player.sprite.y <
           (int16_t)(enemy->init_y -
                     enemy->range_y)) || // Player is too high above
          (level->player.sprite.y >
           (int16_t)(enemy->init_y +
                     enemy->range_y))) { // Player is too far below
        // The player is too far away, move enemy to center
        if (enemy->init_x != enemySprite->x) {
          enemySprite->speed_x = abs(enemySprite->speed_x);
          if (enemy->init_x > enemySprite->x) {
            enemySprite->speed_x = 0 - enemySprite->speed_x;
          }
          enemySprite->x -= enemySprite->speed_x;
        }
        if (enemy->init_y != enemySprite->y) {
          if (enemy->init_y > enemySprite->y) {
            enemySprite->y += enemySprite->speed_y;
          } else {
            enemySprite->y -= enemySprite->speed_y;
          }
        }
      } else {
        // The player is inside the guarded area, move enemy to player
        if (level->player.sprite.x != enemySprite->x) {
          enemySprite->speed_x = abs(enemySprite->speed_x);
          if (level->player.sprite.x > enemySprite->x) {
            enemySprite->speed_x = 0 - enemySprite->speed_x;
          }
          enemySprite->x -= enemySprite->speed_x;
        }
        if (level->player.sprite.y != enemySprite->y) {
          if (level->player.sprite.y > enemySprite->y) {
            enemySprite->y += enemySprite->speed_y;
          } else {
            enemySprite->y -= enemySprite->speed_y;
          }
        }
      }
      break;
    } // switch (enemy->NMI_ACTION & 0x1FFF)
  } // for (i = 0; i < NMI_BY_LEVEL; i++)
}
void updateenemysprite(TITUS_level *level, TITUS_enemy *enemy, int16_t number,
                       bool clearflags);
void DEAD1(TITUS_level *level, TITUS_enemy *enemy) {
  if (((enemy->dying & 0x01) != 0) || // 00000001 or 00000011
      (enemy->dead_sprite == -1)) {
    if ((enemy->dying & 0x01) == 0) {
      enemy->dying = enemy->dying | 0x01;
      enemy->sprite.speed_y = -10;
      enemy->phase = 0;
    }
    if (enemy->phase != 0xFF) {
      enemy->sprite.y += enemy->sprite.speed_y;
      if (SEECHOC_FLAG != 0) {
        level->player.sprite2.y += enemy->sprite.speed_y;
      }
      if (enemy->sprite.speed_y < MAX_SPEED_DEAD) {
        enemy->sprite.speed_y++;
      }
    }
  } else {
    enemy->dying = enemy->dying | 0x01;
    updateenemysprite(level, enemy, enemy->dead_sprite, false);
    enemy->sprite.flash = false;
    enemy->sprite.visible = false;
    enemy->sprite.speed_y = 0;
    enemy->phase = -1;
  }
}

void updateenemysprite(TITUS_level *level, TITUS_enemy *enemy, int16_t number,
                       bool clearflags) {
  updatesprite(level, &(enemy->sprite), number, clearflags);

  if ((number >= 101) && (number <= 105)) { // Walking man
    enemy->carry_sprite = 105;
  } else if ((number >= 126) && (number <= 130)) { // Fly
    enemy->carry_sprite = 130;
  } else if ((number >= 149) && (number <= 153)) { // Skeleton
    enemy->carry_sprite = 149;
  } else if ((number >= 157) && (number <= 158)) { // Worm
    enemy->carry_sprite = 158;
  } else if ((number >= 159) && (number <= 167)) { // Guy with sword
    enemy->carry_sprite = 167;
  } else if ((number >= 185) && (number <= 191)) { // Zombie
    enemy->carry_sprite = 186;
  } else if ((number >= 197) && (number <= 203)) { // Woman with pot
    enemy->carry_sprite = 203;
  } else {
    enemy->carry_sprite = -1;
  }

  if ((number >= 172) && (number <= 184)) { // Periscope
    enemy->dead_sprite = 184;
  } else if ((number >= 192) && (number <= 196)) { // Camel
    enemy->dead_sprite = 196;
  } else if ((number >= 210) && (number <= 213)) { // Old man with TV
    enemy->dead_sprite = 213;
  } else if ((number >= 214) && (number <= 220)) { // Snake in pot
    enemy->dead_sprite = 220;
  } else if ((number >= 221) && (number <= 226)) { // Man throwing knives
    enemy->dead_sprite = 226;
  } else if ((number >= 242) && (number <= 247)) { // Carnivorous plant in pot
    enemy->dead_sprite = 247;
  } else {
    enemy->dead_sprite = -1;
  }

  if (((number >= 248) && (number <= 251)) || // Man throwing rocks (3rd level)
      ((number >= 252) && (number <= 256)) || // Big baby (11th level)
      ((number >= 257) && (number <= 261)) || // Big woman (7th level)
      ((number >= 263) &&
       (number <= 267)) || // Big man (15th level on Moktar only)
      ((number >= 284) && (number <= 288)) || // Mummy (9th level)
      ((number >= 329) && (number <= 332))) { // Ax man (5th level)
    enemy->boss = true;
  } else {
    enemy->boss = false;
  }
}

void SET_NMI(TITUS_level *level) {
  // Clear enemy sprites
  // If an enemy is on the screen
  //  - Set bit 13
  //  - Animate
  //  - Collision with player
  //    - Loose life and fly
  //  - Collision with object
  //    - Decrease enemy's life

  int16_t i, k, hit;
  for (i = 0; i < ENEMY_CAPACITY; i++) { // 50
    if (!(level->enemy[i].sprite.enabled))
      continue; // Skip unused enemies
    level->enemy[i].visible = false;
    // Is the enemy on the screen?
    if ((level->enemy[i].sprite.x + 32 < BITMAP_X
                                             << 4) || // Left for the screen?
        (level->enemy[i].sprite.x - 32 >
         (BITMAP_X << 4) + screen_width * 16) ||      // Right for the screen?
        (level->enemy[i].sprite.y < BITMAP_Y << 4) || // Above the screen?
        (level->enemy[i].sprite.y - 32 >
         (BITMAP_Y << 4) + screen_height * 16)) { // Below the screen?
      if ((level->enemy[i].dying & 0x03) !=
          0) { // If the enemy is dying or dead and not on the screen, remove
               // from the list!
        level->enemy[i].sprite.enabled = false;
      }
      continue;
    }
    level->enemy[i].visible = true;
    GAL_FORM(level, &(level->enemy[i])); // Animation
    if ((level->enemy[i].dying & 0x03) !=
        0) { // If the enemy is dying or dead and not on the screen, remove from
             // the list!
      continue;
    }
    if ((KICK_FLAG == 0) && !GODMODE) { // Collision with the hero?
      if (level->enemy[i].sprite.invisible) {
        continue;
      }
      ACTIONC_NMI(level, &(level->enemy[i]));
    }
    hit = 0;
    if (GRAVITY_FLAG != 0) { // Collision with a moving object?
      for (k = 0; k < OBJECT_CAPACITY; k++) {
        if (level->object[k].sprite.speed_x == 0) {
          if (level->object[k].sprite.speed_y == 0) {
            continue;
          }
          if (level->object[k].momentum < 10) {
            continue;
          }
        }
        if (level->object[k].objectdata->no_damage) { // Is the object a weapon
                                                      // (false) or not (true)?
          continue;
        }
        if (NMI_VS_DROP(&(level->enemy[i].sprite),
                        &(level->object[k].sprite))) {
          hit = 1;
          break;
        }
      }
    }
    if ((hit == 0) && (DROP_FLAG != 0) && (CARRY_FLAG == 0) &&
        (level->player.sprite2.enabled)) {
      if (NMI_VS_DROP(&(level->enemy[i].sprite), &(level->player.sprite2))) {
        INVULNERABLE_FLAG = 0;
        level->player.sprite2.enabled = false;
        SEE_CHOC(level);
        hit = 2;
      }
    }
    if (hit != 0) {
      if (hit == 1) {
        if (level->object[k].sprite.number !=
            73) { // Change direction of the object, except if the object is a
                  // small iron ball
          level->object[k].sprite.speed_x = 0 - level->object[k].sprite.speed_x;
        }
      }
      // If final enemy, remove energy
      playEvent_c(Event_HitEnemy);
      DROP_FLAG = 0;
      if (level->enemy[i].boss) {
        if (INVULNERABLE_FLAG != 0) {
          // j++;
          continue;
        }
        INVULNERABLE_FLAG = 10;
        level->enemy[i].sprite.flash = true; // flash
        boss_lives--;
        if (boss_lives != 0) {
          // j++;
          continue;
        }
        boss_alive = false;
      }
      level->enemy[i].dying = level->enemy[i].dying | 0x02; // Kill the enemy
    }
  }
}

void GAL_FORM(TITUS_level *level, TITUS_enemy *enemy) { // Enemy animation
  enemy->sprite.invisible = false;
  if ((enemy->dying & 0x03) != 0) {
    enemy->sprite.visible = false;
    enemy->visible = true;
    return;
  }
  enemy->trigger = false;
  int16_t *animation = enemy->sprite.animation; // Animation pointer
  // jump back to start of animation
  while (*animation < 0) {
    animation += *animation;
  }
  // NOTE: this is a bit mad.
  if (*animation == 0x55AA) {
    enemy->sprite.invisible = true;
    return;
  }
  enemy->trigger = *animation & 0x2000;
  updateenemysprite(level, enemy, (*animation & 0x00FF) + FIRST_NMI, true);
  enemy->sprite.flipped = (enemy->sprite.speed_x < 0) ? true : false;
  animation++;
  if (*animation < 0) {
    animation += *animation; // jump back to start of animation
  }
  enemy->sprite.animation = animation;
  enemy->visible = true;
}

void ACTIONC_NMI(TITUS_level *level, TITUS_enemy *enemy) {
  switch (enemy->type) {
  case 0:
  case 1:
  case 2:
  case 3:
  case 4:
  case 5:
  case 6:
  case 7:
  case 8:
  case 9:
  case 10:
  case 11:
  case 12:
  case 13:
  case 14:
  case 18:
    if (NMI_VS_DROP(&(enemy->sprite), &(level->player.sprite))) {
      if (enemy->type != 11) {             // Walk and shoot
        if (enemy->sprite.number != 178) { // Periscope
          enemy->sprite.speed_x = 0 - enemy->sprite.speed_x;
        }
      }
      if ((enemy->sprite.number >= FIRST_NMI + 53) &&
          (enemy->sprite.number <= FIRST_NMI + 55)) { // Fireball
        GRANDBRULE_FLAG = 1;
      }
      if (enemy->power != 0) {
        KICK_ASH(level, &(enemy->sprite), enemy->power);
      }
    }
    break;
  }
}

void KICK_ASH(TITUS_level *level, TITUS_sprite *enemysprite, int16_t power) {
  playEvent_c(Event_HitPlayer);
  TITUS_sprite *p_sprite = &(level->player.sprite);
  DEC_ENERGY(level);
  DEC_ENERGY(level);
  KICK_FLAG = 24;
  CHOC_FLAG = 0;
  LAST_ORDER = 0;
  p_sprite->speed_x = power;
  if (p_sprite->x <= enemysprite->x) {
    p_sprite->speed_x = 0 - p_sprite->speed_x;
  }
  p_sprite->speed_y = -8 * 16;
  player_drop_carried(level);
}

bool NMI_VS_DROP(TITUS_sprite *enemysprite, TITUS_sprite *sprite) {
  if (abs(sprite->x - enemysprite->x) >= 64) {
    return false;
  }
  if (abs(sprite->y - enemysprite->y) >= 70) {
    return false;
  }

  if (sprite->y < enemysprite->y) {
    // Enemy is below the offending object
    if (sprite->y <= enemysprite->y - enemysprite->spritedata->collheight + 3)
      return false; // The offending object is too high for collision
  } else {
    // Offending object is below the enemy
    if (enemysprite->y <= sprite->y - sprite->spritedata->collheight + 3)
      return false; // The enemy is too high for collision
  }
  int16_t enemyleft = enemysprite->x - enemysprite->spritedata->refwidth;
  int16_t objectleft = sprite->x - sprite->spritedata->refwidth;
  if (enemyleft >= objectleft) {
    // The object is left for the enemy
    if ((objectleft + (sprite->spritedata->collwidth >> 1)) <= enemyleft) {
      return false; // The object is too far left
    }
  } else {
    // Enemy is left for the object
    if ((enemyleft + (enemysprite->spritedata->collwidth >> 1)) <= objectleft) {
      return false; // The enemy is too far left
    }
  }
  return true; // Collision!
}

void SEE_CHOC(TITUS_level *level) {
  updatesprite(level, &(level->player.sprite2), FIRST_OBJET + 15,
               true); // Hit (a throw hits an enemy)
  level->player.sprite2.speed_x = 0;
  level->player.sprite2.speed_y = 0;
  SEECHOC_FLAG = 5;
}

void moveTrash(TITUS_level *level) {
  int16_t i, tmp;
  for (i = 0; i < TRASH_CAPACITY; i++) {
    if (!level->trash[i].enabled)
      continue;
    if (level->trash[i].speed_x != 0) {
      level->trash[i].x += (level->trash[i].speed_x >> 4);
      tmp = (level->trash[i].x >> 4) - BITMAP_X;
      if ((tmp < 0) || (tmp > screen_width)) {
        level->trash[i].enabled = false;
        continue;
      }
      if (tmp != 0) { // Bug in the code
        level->trash[i].y += (level->trash[i].speed_y >> 4);
        tmp = (level->trash[i].y >> 4) - BITMAP_Y;
        if ((tmp < 0) || (tmp > screen_height * 16)) { // Bug?
          level->trash[i].enabled = false;
          continue;
        }
      }
    }
    if (!GODMODE && NMI_VS_DROP(&(level->trash[i]),
                                &(level->player.sprite))) { // Trash vs player
      level->trash[i].x -= level->trash[i].speed_x;
      KICK_ASH(level, &(level->trash[i]), 70);
      level->trash[i].enabled = false;
      continue;
    }
  }
}

TITUS_sprite *FIND_TRASH(TITUS_level *level) {
  int i;
  for (i = 0; i < TRASH_CAPACITY; i++) {
    if (level->trash[i].enabled == false) {
      return &(level->trash[i]);
    }
  }
  return NULL;
}

void PUT_BULLET(TITUS_level *level, TITUS_enemy *enemy, TITUS_sprite *bullet) {
  bullet->x = enemy->sprite.x;
  bullet->y =
      enemy->sprite.y - (int8_t)(*(enemy->sprite.animation - 1) & 0x00FF);
  updatesprite(level, bullet,
               (*(enemy->sprite.animation - 2) & 0x1FFF) + FIRST_OBJET, true);
  if (enemy->sprite.x < level->player.sprite.x) {
    bullet->speed_x = 16 * 11;
    bullet->flipped = true;
  } else {
    bullet->speed_x = -16 * 11;
    bullet->flipped = false;
  }
  bullet->speed_y = 0;
  bullet->x += bullet->speed_x >> 4;
}
