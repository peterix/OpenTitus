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

const globals = @import("globals.zig");
const SDL = @import("SDL.zig");
const sprites = @import("sprites.zig");
const scroll = @import("scroll.zig");
const render = @import("render.zig");
const ScreenContext = render.ScreenContext;
const window = @import("window.zig");
const keyboard = @import("ui/keyboard.zig");
const lvl = @import("level.zig");

const anim_zoubida: []const i16 = &.{ 337, 337, 337, 338, 338, 338, 339, 339, 339, 340, 340, 340, 341, 341, 341, 342, 342, 342, -18 };
const anim_moktar: []const i16 = &.{ 343, 343, 343, 344, 344, 344, 345, 345, 345, -9 };
const anim_smoke: []const i16 = &.{ 347, 347, 348, 348, 349, 349, 350, 350, 351, 351, 352, 352, 353, 353, 354, 354, -16 };
const heart_animation: []const i16 = &.{ 153, 142, 153, 142, 153, 142, 139, 148, 139, 148, 139, 148, 139, 162, 139, 162, 139, 162, 152, 171, 152, 171, 152, 171, 171, 165, 171, 165, 171, 165, 170, 147, 170, 147, 170, 147, -12 * 3 };

fn advanceAnimation(level: *lvl.Level, spr: *lvl.Sprite) void {
    var pointer = spr.animation + 1;
    while (pointer.* < 0) {
        // this is just ugly...
        pointer -= @as(usize, @intCast(-pointer.*)); //End of animation, jump back
    }
    sprites.updatesprite(level, spr, pointer.*, true);
    spr.animation = pointer;
}

pub fn play(context: *ScreenContext, level: *lvl.Level) c_int {
    var player = &level.player;
    globals.BITMAP_X = 0;
    globals.NOSCROLL_FLAG = true;

    // Prepare Titus/Moktar
    sprites.updatesprite(level, &(player.sprite), 343, true);
    player.sprite.x = -100;
    player.sprite.y = 180;
    player.sprite.animation = &anim_moktar[0];

    // Prepare Zoubida
    sprites.updatesprite(level, &(player.sprite2), 337, true);
    player.sprite2.x = 420;
    player.sprite2.y = 180;
    player.sprite2.animation = &anim_zoubida[0];
    while (player.sprite2.x > player.sprite.x + 28) {
        // Animate tiles
        scroll.scroll(level);
        // Move Titus/Moktar
        player.sprite.x += 3;
        advanceAnimation(level, &(player.sprite));
        // Move Zoubida
        player.sprite2.x -= 3;
        advanceAnimation(level, &(player.sprite2));
        // View all
        render.render_tiles(level);
        render.render_sprites(level);
        render.flip_screen(context, true);
    }

    // Lovers in one sprite
    sprites.updatesprite(level, &(player.sprite2), 346, true);
    player.sprite2.flipped = true;
    player.sprite2.x -= 24;

    // Smoke
    player.sprite.animation = &anim_smoke[0];
    player.sprite.y -= 16;
    for (0..16) |_| {
        advanceAnimation(level, &(player.sprite));
        scroll.scroll(level);
        render.render_tiles(level);
        render.render_sprites(level);
        render.flip_screen(context, true);
        player.sprite.y += 1;
    }

    // Display hearts
    sprites.updatesprite(level, &(player.sprite), 355, true);
    var heart: i16 = 0;
    var pass = false;
    while (!pass) {
        if (heart_animation[@intCast(heart)] < 0) {
            heart += heart_animation[@intCast(heart)]; //jump back
        }
        player.sprite.x = heart_animation[@intCast(heart)];
        heart += 1;
        player.sprite.y = heart_animation[@intCast(heart)];
        heart += 1;

        scroll.scroll(level);
        render.render_tiles(level);
        render.render_sprites(level);
        render.flip_screen(context, true);

        SDL.pumpEvents(); //Update keyboard state

        var event: SDL.Event = undefined;
        //Check all events
        while (SDL.pollEvent(&event)) {
            if (event.type == SDL.EVENT_QUIT) {
                return -1; //c.TITUS_ERROR_QUIT;
            } else if (event.type == SDL.EVENT_KEY_DOWN) {
                if (event.key.scancode == SDL.SCANCODE_F11) {
                    window.toggle_fullscreen();
                } else if (event.key.scancode == SDL.SCANCODE_RETURN or
                    event.key.scancode == SDL.SCANCODE_KP_ENTER or
                    event.key.scancode == SDL.SCANCODE_SPACE or
                    event.key.scancode == SDL.SCANCODE_ESCAPE)
                {
                    pass = true;
                    break;
                }
            }
        }
    }

    // Display THE END
    // THE
    sprites.updatesprite(level, &(player.sprite), 335, true);
    player.sprite.x = (globals.BITMAP_X << 4) - (120 - 2);
    player.sprite.y = (globals.BITMAP_Y << 4) + 100;
    // END
    sprites.updatesprite(level, &(player.sprite3), 336, true);
    player.sprite3.x = (globals.BITMAP_X << 4) + (320 + 120 - 2);
    player.sprite3.y = (globals.BITMAP_Y << 4) + 100;
    for (0..31) |_| {
        render.render_tiles(level);
        render.render_sprites(level);
        render.flip_screen(context, true);
        player.sprite.x += 8;
        player.sprite3.x -= 8;
    }
    return keyboard.waitforbutton();
}
