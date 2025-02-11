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

/* objects.c
 * Handle objects
 */

#include "objects.h"
#include "audio.h"
#include "game.h"
#include "globals_old.h"
#include "level.h"
#include "player.h"
#include "sprites.h"

#define ORIG_OBJECT_COUNT 71

void shock(TITUS_level *level, TITUS_object *object);

void move_objects(TITUS_level *level) {

  if (GRAVITY_FLAG == 0)
    return; // Skip execution if there are no active objects

  TITUS_object *off_object;
  enum HFLAG hflag;
  enum FFLAG fflag;
  uint8_t i, max_speed;
  int16_t tileX, tileY, speed, j;
  bool obj_vs_sprite;
  int8_t reduction, tile_count;
  for (i = 0; i < OBJECT_CAPACITY; i++) {
    obj_vs_sprite = false;
    if (!(level->object[i].sprite.enabled))
      continue;                           // Skip unused objects
    if (level->object[i].sprite.x <= 8) { // Left edge of level
      level->object[i].sprite.speed_x = 2 * 16;
      level->object[i].sprite.speed_y = 0;
    }

    if (level->object[i].sprite.x >=
        level->width * 16 - 8) { // Right edge of level
      level->object[i].sprite.speed_x = -2 * 16;
      level->object[i].sprite.speed_y = 0;
    }
    // Handle carpet
    if ((level->object[i].sprite.number == FIRST_OBJET + 21) ||
        (level->object[i].sprite.number ==
         FIRST_OBJET + 22)) { // Flying carpet, flying
      GRAVITY_FLAG = 4;       // Keep doing gravity

      //(Adjust height after player)
      if (TAPISWAIT_FLAG != 0) { // Flying ready
        level->object[i].momentum = 0;
        if (level->object[i].sprite.y == (level->player.sprite.y - 8))
          level->object[i].sprite.speed_y = 0;
        else if (level->object[i].sprite.y < (level->player.sprite.y - 8))
          level->object[i].sprite.speed_y = 16;
        else
          level->object[i].sprite.speed_y = -16;
      }

      if (TAPISFLY_FLAG == 0) { // Time's up! Stop flying
        updateobjectsprite(
            level, &(level->object[i]), FIRST_OBJET + 19,
            true); // position falling and carry  (jump and carry sprite?)
        level->object[i].sprite.speed_x = 0;
        TAPISWAIT_FLAG = 2; // Timed out
      }
    } else if (((level->object[i].sprite.number == FIRST_OBJET + 19) ||
                (level->object[i].sprite.number ==
                 FIRST_OBJET + 20)) && // Flying carpet, not flying
               ((IMAGE_COUNTER & 0x03) == 0) &&
               (level->object[i].sprite.speed_y > 0) && (TAPISWAIT_FLAG != 2)) {
      // The carpet is being throwed
      if (level->object[i].sprite.number ==
          FIRST_OBJET + 19) { // Carpet is closed
        level->object[i].sprite.speed_x = level->object[i].sprite.speed_x >> 1;
        updateobjectsprite(level, &(level->object[i]), FIRST_OBJET + 20,
                           false); // Open, not flying
      } else {                     // Open, not flying (sprite FIRST_OBJET + 20)
        level->object[i].sprite.speed_x = 0;
        updateobjectsprite(level, &(level->object[i]), FIRST_OBJET + 21,
                           false); // Flying ready
      }
      TAPISWAIT_FLAG = 1;
      TAPISFLY_FLAG = 200;
    }

    // Does it move in X?
    if (level->object[i].sprite.speed_x != 0) {

      // Test for horizontal collision

      tileX = level->object[i].sprite.x >> 4;
      tileY = level->object[i].sprite.y >> 4;
      if ((level->object[i].sprite.y & 0x000F) == 0) {
        tileY--;
      }
      hflag = get_horizflag(level, tileY, tileX);
      if ((hflag == HFLAG_WALL) || (hflag == HFLAG_DEADLY) || (hflag == HFLAG_PADLOCK)) {
        // Collision horizontal, change direction
        level->object[i].sprite.speed_x = 0 - level->object[i].sprite.speed_x;
        level->object[i].sprite.x += level->object[i].sprite.speed_x >> 4;
      } else if ((((level->object[i].sprite.speed_x >> 4) +
                   level->object[i].sprite.x) >>
                  4) !=
                 tileX) { // If speed_x is big enough, check the neighbour tile
        if (level->object[i].sprite.speed_x < 0)
          tileX--;
        else
          tileX++;
        if ((tileX < level->width) && (tileX >= 0)) {
          hflag = get_horizflag(level, tileY, tileX);
          if (hflag == HFLAG_WALL || hflag == HFLAG_DEADLY || hflag == HFLAG_PADLOCK) {
            // Collision horizontal, change direction
            level->object[i].sprite.speed_x =
                0 - level->object[i].sprite.speed_x;
            level->object[i].sprite.x += level->object[i].sprite.speed_x >> 4;
          }
        }
      }

      // Move the object in X and reduce speed_x
      GRAVITY_FLAG = 4;
      level->object[i].sprite.x +=
          (level->object[i].sprite.speed_x >> 4); // Move the object
      if (abs(level->object[i].sprite.speed_y) >= 16) {
        reduction = 1;
      } else {
        reduction = 3;
      }
      if (level->object[i].sprite.speed_x < 0) {
        reduction = 0 - reduction;
      }
      level->object[i].sprite.speed_x -= reduction;
      if (abs(level->object[i].sprite.speed_x) < 16) {
        level->object[i].sprite.speed_x = 0;
      }
    }

    if (level->object[i].sprite.speed_y < 0) {
      // Object's going up!
      tileX = level->object[i].sprite.x >> 4;
      tileY = (level->object[i].sprite.y >> 4) -
              (level->object[i].sprite.spritedata->collheight >> 4) -
              1; // tile above the object
      if (get_ceilflag(level, tileY, tileX) != CFLAG_NOCEILING) {
        // Hit, stop elevating
        level->object[i].sprite.speed_y = 0;
        if (!(level->object[i].objectdata->bounce)) {
          level->object[i].sprite.y = level->object[i].sprite.y & 0xFFF0;
        }
        continue;
      } else {
        if (((level->object[i].sprite.speed_y >> 4) +
             level->object[i].sprite.y) != (level->object[i].sprite.y >> 4)) {
          // The purpose is to test if the speed makes it necessary to check
          // above sprite, the above line is a bug
          tileY--;
          if (get_ceilflag(level, tileY, tileX) != CFLAG_NOCEILING) { // Hit, stop elevating
            // Hit, stop elevating
            level->object[i].sprite.speed_y = 0;
            if (!(level->object[i].objectdata->bounce)) {
              level->object[i].sprite.y =
                  level->object[i].sprite.y &
                  0xFFF0; // if not bouncing, place it on top of the floor tile
                          // when falling down
            }
            continue;
          }
        }
      }
    } else if ((level->object[i].sprite.droptobottom) ||
               ((level->object[i].objectdata->droptobottom) &&
                (level->object[i].sprite.speed_y >= 10 * 16))) {
      // Object's falling down, and it's dropping to bottom (skip collision
      // detection)
      if (!level->object[i].sprite.visible) {
        // if it's dropping to bottom and is not visible, delete
        level->object[i].sprite.enabled = false;
        continue;
      }
    } else {
      // Object's falling down, but not dropping to bottom, do collision
      // detection!
      tileX = level->object[i].sprite.x >> 4;
      tileY = level->object[i].sprite.y >> 4;
      hflag = get_horizflag(level, tileY, tileX);
      fflag = get_floorflag(level, tileY, tileX);
      if ((level->object[i].sprite.y <= 6) ||
          (level->object[i].sprite.y >= (level->height << 4))) {
        fflag = FFLAG_NOFLOOR;
        if (level->object[i].sprite.y >= (level->height << 4) + 64) {
          // delete if object is below level + 64
          level->object[i].sprite.enabled = false;
          continue;
        }
      }
      if (fflag == FFLAG_FIRE) {
        // delete if floor eats all objects (fire)
        level->object[i].sprite.enabled = false;
        continue;
      }
      if (fflag == FFLAG_WATER) {
        if (level->object[i].sprite.number == FIRST_OBJET + 9) { // Ball
          // Collision, stop fall
          level->object[i].sprite.speed_y = 0;
          continue;
        } else {
          // if it ain't a ball, delete!
          level->object[i].sprite.enabled = false;
          continue;
        }
      }
      if ((fflag != FFLAG_LADDER) &&
          ((fflag != FFLAG_NOFLOOR) || (hflag == HFLAG_WALL) ||
           (hflag == HFLAG_DEADLY) || (hflag == HFLAG_PADLOCK))) {
        // Collision, stop fall
        level->object[i].sprite.speed_y = 0;
        if (!(level->object[i].objectdata->bounce)) {
          level->object[i].sprite.y =
              level->object[i].sprite.y &
              0xFFF0; // if not bouncing, place it on top of the floor tile when
                      // falling down
        }
        continue;
      }

      // Test for sprite collision
      tile_count = ((level->object[i].sprite.y +
                     (level->object[i].sprite.speed_y >> 4)) >>
                    4) -
                   (level->object[i].sprite.y >> 4);
      if (tile_count !=
          0) { // Bug: this should be inside the tile collision test
        obj_vs_sprite =
            SPRITES_VS_SPRITES(level, &(level->object[i].sprite),
                               level->object[i].sprite.spritedata, &off_object);
      }
      // Test all tiles the object will travel through
      for (j = 0; j < tile_count; j++) {
        if (obj_vs_sprite) {
          break;
        }
        tileY += 1;
        hflag = get_horizflag(level, tileY, tileX);
        fflag = get_floorflag(level, tileY, tileX);
        if (fflag == FFLAG_FIRE) {
          // delete if floor eats all objects (fire)
          level->object[i].sprite.enabled = false;
          break;
        }
        if ((fflag != FFLAG_LADDER) &&
            ((fflag != FFLAG_NOFLOOR) || (hflag == HFLAG_WALL) ||
             (hflag == HFLAG_DEADLY) || (hflag == HFLAG_PADLOCK))) {
          // Collision at high speed, stop fall
          if (!(level->object[i].objectdata->bounce)) {
            level->object[i].sprite.speed_y = 0;
            level->object[i].sprite.y =
                (level->object[i].sprite.y & 0xFFF0) + 16;
            if ((level->object[i].sprite.number >= FIRST_OBJET + 19) &&
                (level->object[i].sprite.number <=
                 FIRST_OBJET + 22)) { // Flying carpet
              updateobjectsprite(level, &(level->object[i]), FIRST_OBJET + 19,
                                 false); // Carpet is closed
              TAPISWAIT_FLAG = 0;
            }
            if ((level->object[i].sprite.visible) &&
                !(level->player.sprite2.enabled)) {
              FUME_FLAG = 32; // Smoke
              level->player.sprite2.y = level->object[i].sprite.y;
              level->player.sprite2.x = level->object[i].sprite.x;
              updatesprite(level, &(level->player.sprite2), FIRST_OBJET + 16,
                           true); // Smoke
            }
          } else {
            // object is bouncing
            level->object[i].sprite.y =
                (level->object[i].sprite.y & 0xFFF0) + 16;
            GRAVITY_FLAG = 4;
            level->object[i].momentum = 0;
            // Bounce, decrease speed
            level->object[i].sprite.speed_y =
                0 - level->object[i].sprite.speed_y + 16 * 3;
            if (level->object[i].sprite.speed_y > 0) {
              level->object[i].sprite.speed_y = 0;
            }
          }
          break;
        }
      }
      if (!(obj_vs_sprite) &&
          ((j < tile_count) ||
           !(level->object[i]
                 .sprite.enabled))) { // collision/kill in previous for loop
        continue;
      }
      if (!(obj_vs_sprite)) {
        obj_vs_sprite =
            SPRITES_VS_SPRITES(level, &(level->object[i].sprite),
                               level->object[i].sprite.spritedata, &off_object);
      }
      if (obj_vs_sprite) {
        level->object[i].momentum = 0;
        if (off_object->objectdata->bounce) {
          // offending object bounces
          off_object->sprite.UNDER |= 0x01;                      //(?)
          off_object->sprite.ONTOP = &(level->object[i].sprite); //(check this)
          if (level->object[i].sprite.speed_y > 64) {
            off_object->sprite.speed_y =
                ((0 - level->object[i].sprite.speed_y) >> 1) + 32;
            level->object[i].sprite.speed_y =
                ((0 - level->object[i].sprite.speed_y) >> 1) + 16;
            off_object->sprite.speed_x = level->object[i].sprite.speed_x >> 1;
          } else {
            level->object[i].sprite.speed_y = 0;
            level->object[i].sprite.y =
                off_object->sprite.y -
                off_object->sprite.spritedata->collheight;
            continue;
          }
        } else if (level->object[i].objectdata->bounce) {
          // object bounces
          level->object[i].sprite.y =
              off_object->sprite.y - off_object->sprite.spritedata->collheight;
          if ((level->object[i].sprite.speed_y >= 16) ||
              (level->object[i].sprite.speed_y < 0)) {
            GRAVITY_FLAG = 4;
            // level->object[i].momentum = 0;
            // Bounce, decrease speed
            level->object[i].sprite.speed_y =
                0 - level->object[i].sprite.speed_y + 16 * 3;
            if (level->object[i].sprite.speed_y > 0) {
              level->object[i].sprite.speed_y = 0;
            }
          } else {
            level->object[i].sprite.speed_y = 0;
          }
          continue;
        } else {
          // neither of the objects bounces
          level->object[i].sprite.y =
              off_object->sprite.y - off_object->sprite.spritedata->collheight;
          level->object[i].sprite.speed_y = 0;
        }
      }
    }

    max_speed = 15; // max speed
    if (level->object[i].sprite.number < FIRST_NMI) {
      max_speed = level->object[i].objectdata->maxspeedY;
    }
    speed = (level->object[i].sprite.speed_y >> 4);
    if (speed != 0) {
      GRAVITY_FLAG = 4;
    }
    level->object[i].sprite.y += speed; // Finally move the object at it's speed
    if (speed < max_speed) {
      level->object[i].sprite.speed_y += 16;
      if (level->object[i].sprite.speed_y > 0) {
        level->object[i].momentum++;
      }
    }
    shock(level, &(level->object[i])); // Falling object versus player
  }
}

void shock(TITUS_level *level,
           TITUS_object *object) { // Falling object versus player

  TITUS_player *player = &(level->player);

  // Quick test
  if (object->momentum < 10)
    return;
  if (player->sprite.speed_y >= MAX_Y * 16)
    return;
  if (abs(player->sprite.y - object->sprite.y) >= 32) {
    return;
  }
  if (abs(player->sprite.x - object->sprite.x) >= 32) {
    return;
  }

  // Test X
  if (object->sprite.x > player->sprite.x) { // Object center is right for
                                             // player
    if (object->sprite.x > player->sprite.x + 24)
      return; // Object is too far right
  } else {    // Object center is left for center
    if (object->sprite.x + object->sprite.spritedata->collwidth <
        player->sprite.x)
      return; // Return if object is too far left
  }

  // Test Y
  if (object->sprite.y <
      player->sprite.y) { // Object bottom is above player bottom
    if (object->sprite.y <= player->sprite.y - 32)
      return; // Return if object is completely above the player
  } else {    // Object bottom is below player bottom
    if (object->sprite.y - object->sprite.spritedata->collheight + 1 >=
        player->sprite.y)
      return; // Return if object is completely below the player
  }

  // Hit!
  playEvent_c(Event_PlayerHeadImpact);
  CHOC_FLAG = 24;
  if (object->sprite.killing) {
    if (!GODMODE) {
      DEC_ENERGY(level);
    }
    object->sprite.killing = false;
  }
}

bool SPRITES_VS_SPRITES(
    TITUS_level *level, TITUS_sprite *sprite1,
    const TITUS_spritedata *sprite1data,
    TITUS_object **object2) { // check if there is an object below that can
                              // support the input object
  uint8_t i;
  int16_t obj1left, obj2left;
  // sprite1ref is equal to sprite1, except when sprite1 is the player, then
  // sprite1ref is level->spritedata[0] (first player sprite)
  obj1left = sprite1->x - (sprite1data->width >> 1);
  for (i = 0; i < OBJECT_CAPACITY; i++) { // loop all objects
    if ((&(level->object[i].sprite) == sprite1) ||
        !(level->object[i].sprite.enabled) ||
        !(level->object[i].objectdata->support))
      continue; // skip disabled objects and itself, and it must support
    if (abs(level->object[i].sprite.x - obj1left) > 64)
      continue; // Bug, center vs left edge
    if (abs(level->object[i].sprite.y - sprite1->y) > 70)
      continue;
    // complex test, first test X
    // level->object[i].sprite.collisionwidth = true size of the X
    // level->object[i]
    obj2left = level->object[i].sprite.x -
               (level->object[i].sprite.spritedata->collwidth >>
                1); // Object 2's left X for collision
    if (obj2left > obj1left) {
      // Object 2's left collision edge is right for object 1's left sprite edge
      if (obj1left + sprite1data->collwidth <= obj2left)
        continue; // Sprite 1 is too far left (SZOBJ2 = object 1 collision
                  // width)
    } else {
      // Object 2's left collision edge is left for or equal to object 1's left
      // sprite edge
      if (obj2left + level->object[i].sprite.spritedata->collwidth <= obj1left)
        continue; // Sprite 1 is too far right
    }

    // test Y
    if (level->object[i].sprite.y -
            (level->object[i].sprite.spritedata->collheight >> 3) >=
        sprite1->y) { // The object must necessarily be below!
      if (level->object[i].sprite.y -
              level->object[i].sprite.spritedata->collheight <=
          sprite1->y) {
        // Collision!
        *object2 = &(level->object[i]);
        return true;
      }
    }
  } // loop to next object
  return false; // No collision
}

void updateobjectsprite(TITUS_level *level, TITUS_object *obj, int16_t number,
                        bool clearflags) {
  int16_t index = number - FIRST_OBJET;
  updatesprite(level, &(obj->sprite), number, clearflags);
  if ((index < 0) || (index >= ORIG_OBJECT_COUNT)) {
    index = 0;
  }
  obj->objectdata = &level->objectdata[index];
}
