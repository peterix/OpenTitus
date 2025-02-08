// Copyright (C) 2008 - 2011 The OpenTitus team
//
// Authors:
// Eirik Stople
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

// player.c
// Handles player movement and keyboard handling

const std = @import("std");

const globals = @import("globals.zig");
const c = @import("c.zig");
const SDL = @import("SDL.zig");
const game = @import("game.zig");
const window = @import("window.zig");
const data = @import("data.zig");

const credits = @import("ui/credits.zig");
const pause_menu = @import("ui/pause_menu.zig");
const status = @import("ui/status.zig");

fn add_carry() u8 {
    if (globals.CARRY_FLAG) {
        return 16;
    } else {
        return 0;
    }
    return @import("std").mem.zeroes(u8);
}

fn handle_player_input(player: *c.TITUS_player, keystate: []const u8) void {
    player.x_axis = @as(i8, @intCast(keystate[SDL.SCANCODE_RIGHT] | keystate[SDL.SCANCODE_D])) - @as(i8, @intCast(keystate[SDL.SCANCODE_LEFT] | keystate[SDL.SCANCODE_A]));
    player.y_axis = @as(i8, @intCast(keystate[SDL.SCANCODE_DOWN] | keystate[SDL.SCANCODE_S])) - @as(i8, @intCast(keystate[SDL.SCANCODE_UP] | keystate[SDL.SCANCODE_W]));
    player.action_pressed = keystate[SDL.SCANCODE_SPACE] != 0;
}

pub fn move_player(arg_context: [*c]c.ScreenContext, arg_level: [*c]c.TITUS_level) c_int {
    // Part 1: Check keyboard input
    // Part 2: Determine the player's action, and execute action dependent code
    // Part 3: Move the player + collision detection
    // Part 4: Move the throwed/carried object
    // Part 5: decrease the timers

    const context = arg_context;
    const level = arg_level;
    var retval: c_int = undefined;
    var newsensX: i8 = undefined;
    var event: SDL.Event = undefined;
    var newX: i16 = undefined;
    var newY: i16 = undefined;
    var pause: bool = false;

    // Part 1: Check keyboard input
    SDL.pumpEvents();
    const keystate = SDL.getKeyboardState();
    const mods: SDL.Keymod = SDL.getModState();

    // TODO: move this to input.zig or some such place
    while (SDL.pollEvent(&event)) {
        if (event.type == SDL.QUIT) {
            return -1;
        } else if (event.type == SDL.KEYDOWN) {
            const key_press = event.key.keysym.scancode;
            if (key_press == SDL.SCANCODE_G and game.settings.devmode) {
                if (globals.GODMODE) {
                    globals.GODMODE = false;
                    globals.NOCLIP = false;
                } else {
                    globals.GODMODE = true;
                }
            } else if (key_press == SDL.SCANCODE_N and game.settings.devmode) {
                if (globals.NOCLIP) {
                    globals.NOCLIP = false;
                } else {
                    globals.NOCLIP = true;
                    globals.GODMODE = true;
                }
            } else if (key_press == SDL.SCANCODE_D and game.settings.devmode) {
                globals.DISPLAYLOOPTIME = !globals.DISPLAYLOOPTIME;
            } else if (key_press == SDL.SCANCODE_Q) {
                if ((mods & @as(c_uint, @bitCast(SDL.KMOD_ALT | SDL.KMOD_CTRL))) != 0) {
                    _ = credits.credits_screen();
                    if (level.*.extrabonus >= 10) {
                        level.*.extrabonus -= 10;
                        level.*.lives += 1;
                    }
                }
            } else if (key_press == SDL.SCANCODE_F11) {
                window.toggle_fullscreen();
            } else if (key_press == SDL.SCANCODE_ESCAPE) {
                pause = true;
            }
        }
    }
    if (pause) {
        retval = pause_menu.pauseMenu(context);
        if (retval < 0) {
            return retval;
        }
    }
    if (keystate[SDL.SCANCODE_F1] != 0 and globals.RESETLEVEL_FLAG == 0) {
        globals.RESETLEVEL_FLAG = 2;
        return 0;
    }
    if (game.settings.devmode) {
        if (keystate[SDL.SCANCODE_F2] != 0) {
            globals.GAMEOVER_FLAG = true;
            return 0;
        }
        if (keystate[SDL.SCANCODE_F3] != 0) {
            globals.NEWLEVEL_FLAG = true;
            globals.SKIPLEVEL_FLAG = true;
        }
    }
    if (keystate[SDL.SCANCODE_E] != 0) {
        globals.BAR_FLAG = 50;
    }
    if (keystate[SDL.SCANCODE_F4] != 0) {
        _ = status.viewstatus(level, false);
    }
    const player = &level.*.player;
    handle_player_input(player, keystate);

    // Part 2: Determine the player's action, and execute action dependent code

    globals.X_FLAG = player.x_axis != 0;
    globals.Y_FLAG = player.y_axis != 0;
    if (globals.NOCLIP) {
        player.*.sprite.speed_x = player.*.x_axis * 100;
        player.*.sprite.speed_y = player.*.y_axis * 100;
        player.*.sprite.x += player.*.sprite.speed_x >> 4;
        player.*.sprite.y += player.*.sprite.speed_y >> 4;
        return 0;
    }

    // TODO: Action should be an enum?
    var action: u8 = undefined;

    if (globals.CHOC_FLAG != 0) {
        action = 11; // Headache
    } else if (globals.KICK_FLAG != 0) {
        if (globals.GRANDBRULE_FLAG) {
            action = 13; // Hit (burn)
        } else {
            action = 12; // Hit
        }
    } else {
        globals.GRANDBRULE_FLAG = false;
        if (globals.LADDER_FLAG) {
            action = 6; // Action: climb
        } else if (!globals.PRIER_FLAG and player.y_axis < 0 and globals.SAUT_FLAG == 0) {
            action = 2; // Action: jump
            if (globals.LAST_ORDER == 5) { // Test if last order was kneestanding
                globals.FURTIF_FLAG = 100; // If jump after kneestanding, init silent walk timer
            }
        } else if ((@as(c_int, @intFromBool(globals.PRIER_FLAG)) != 0) or ((@as(c_int, @bitCast(@as(c_uint, globals.SAUT_FLAG))) != 6) and (@as(c_int, @bitCast(@as(c_int, player.*.y_axis))) > 0))) {
            if (globals.X_FLAG) { // Move left or right
                action = 3; // Action: crawling
            } else {
                action = 5; // Action: kneestand
            }
        } else if (globals.X_FLAG) {
            action = 1; // Action: walk
        } else {
            action = 0; // Action: rest (no action)
        }
        // Is space button pressed?
        if (player.action_pressed and !globals.PRIER_FLAG) {
            if (!globals.DROP_FLAG) {
                if (action == 3 or action == 5) { // Kneestand
                    globals.DROPREADY_FLAG = false;
                    action = 7; // Grab an object
                } else if (globals.CARRY_FLAG and globals.DROPREADY_FLAG) { // Fall
                    action = 8; // Drop the object
                }
            }
        } else {
            globals.DROPREADY_FLAG = true;
            globals.POSEREADY_FLAG = false;
        }
    }
    if (globals.CARRY_FLAG) {
        action += 16;
    }

    if (globals.CHOC_FLAG != 0 or globals.KICK_FLAG != 0) {
        if (globals.SENSX < 0) {
            newsensX = -1;
        } else {
            newsensX = 0;
        }
    } else if (player.x_axis != 0) {
        newsensX = player.x_axis;
    } else if (globals.SENSX == -1) {
        newsensX = -1;
    } else if (action == 0) {
        newsensX = 0;
    } else {
        newsensX = 1;
    }

    if (globals.SENSX != newsensX) {
        globals.SENSX = newsensX;
        globals.ACTION_TIMER = 1;
    } else {
        if ((action == 0 or action == 1) and globals.FURTIF_FLAG != 0) {
            // Silent walk?
            action += 9;
        }
        if (action != globals.LAST_ORDER) {
            globals.ACTION_TIMER = 1;
        } else if (globals.ACTION_TIMER < 0xFF) {
            globals.ACTION_TIMER += 1;
        }
    }
    ACTION_PRG(level, action); // call movement function based on ACTION

    // Part 3: Move the player + collision detection
    // Move the player in X if the new position doesn't exceed 8 pixels from the
    // edges
    if (((@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_x))) < 0) and ((@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) + (@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_x))) >> @intCast(4))) >= 8)) or ((@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_x))) > 0) and ((@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) + (@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_x))) >> @intCast(4))) <= ((@as(c_int, @bitCast(@as(c_int, level.*.width))) << @intCast(4)) - 8)))) {
        player.*.sprite.x += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_x))) >> @intCast(4)))));
    }
    // Move player in Y
    player.*.sprite.y += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_y))) >> @intCast(4)))));
    // Test for collisions
    BRK_COLLISION(context, level);

    // Part 4: Move the throwed/carried object
    // Move throwed/carried object
    if (globals.DROP_FLAG) {
        newX = @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_int, player.*.sprite2.speed_x))) >> @intCast(4)) + @as(c_int, @bitCast(@as(c_int, player.*.sprite2.x)))))));
        if ((((@as(c_int, @bitCast(@as(c_int, newX))) < (@as(c_int, @bitCast(@as(c_int, level.*.width))) << @intCast(4))) and (@as(c_int, @bitCast(@as(c_int, newX))) >= 0)) and (@as(c_int, @bitCast(@as(c_int, newX))) >= ((@as(c_int, @bitCast(@as(c_int, globals.BITMAP_X))) << @intCast(4)) - 40))) and (@as(c_int, @bitCast(@as(c_int, newX))) <= (((@as(c_int, @bitCast(@as(c_int, globals.BITMAP_X))) << @intCast(4)) + (20 << @intCast(4))) + 40))) {
            player.*.sprite2.x = newX;
            newY = @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_int, player.*.sprite2.speed_y))) >> @intCast(4)) + @as(c_int, @bitCast(@as(c_int, player.*.sprite2.y)))))));
            if ((((@as(c_int, @bitCast(@as(c_int, newY))) < (@as(c_int, @bitCast(@as(c_int, level.*.height))) << @intCast(4))) and (@as(c_int, @bitCast(@as(c_int, newY))) >= 0)) and (@as(c_int, @bitCast(@as(c_int, newY))) >= ((@as(c_int, @bitCast(@as(c_int, globals.BITMAP_Y))) << @intCast(4)) - 20))) and (@as(c_int, @bitCast(@as(c_int, newY))) <= (((@as(c_int, @bitCast(@as(c_int, globals.BITMAP_Y))) << @intCast(4)) + (12 << @intCast(4))) + 20))) {
                player.*.sprite2.y = newY;
            } else {
                player.*.sprite2.enabled = false;
                globals.DROP_FLAG = false;
            }
        } else {
            player.*.sprite2.enabled = false;
            globals.DROP_FLAG = false;
        }
    } else if (globals.CARRY_FLAG) {
        if (!globals.LADDER_FLAG and ((@as(c_int, @bitCast(@as(c_uint, globals.LAST_ORDER))) == (16 + 5)) or (@as(c_int, @bitCast(@as(c_uint, globals.LAST_ORDER))) == (16 + 7)))) {
            player.*.sprite2.y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.y))) - 4))));
            if (player.*.sprite.flipped) {
                player.*.sprite2.x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) - 10))));
            } else {
                player.*.sprite2.x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) + 12))));
            }
        } else {
            if ((@as(c_int, @bitCast(@as(c_int, player.*.sprite.number))) == 14) or (((@as(c_int, @bitCast(@as(c_uint, globals.LAST_ORDER))) & 15) != 7) and ((@as(c_int, @bitCast(@as(c_uint, globals.LAST_ORDER))) & 15) != 8))) {
                player.*.sprite2.x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) + 2))));
                if ((@as(c_int, @bitCast(@as(c_int, player.*.sprite.number))) == 23) or (@as(c_int, @bitCast(@as(c_int, player.*.sprite.number))) == 24)) {
                    player.*.sprite2.x -= @as(i16, @bitCast(@as(c_short, @truncate(10))));
                    if (player.*.sprite.flipped) {
                        player.*.sprite2.x += @as(i16, @bitCast(@as(c_short, @truncate(18))));
                    }
                }
                player.*.sprite2.y = @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_int, player.*.sprite.y))) - @as(c_int, @bitCast(@as(c_uint, player.*.sprite.spritedata.*.collheight)))) + 1))));
            }
        }
    }
    if (@as(c_int, @bitCast(@as(c_uint, globals.SEECHOC_FLAG))) != 0) {
        globals.SEECHOC_FLAG -%= 1;
        if (@as(c_int, @bitCast(@as(c_uint, globals.SEECHOC_FLAG))) == 0) {
            player.*.sprite2.enabled = false;
        }
    }

    // Part 5: decrease the timers
    c.subto0(&globals.INVULNERABLE_FLAG);
    c.subto0(&globals.RESETLEVEL_FLAG);
    c.subto0(&globals.TAPISFLY_FLAG);
    c.subto0(&globals.CROSS_FLAG);
    c.subto0(&globals.GRAVITY_FLAG);
    c.subto0(&globals.FURTIF_FLAG);
    c.subto0(&globals.KICK_FLAG);
    if (player.sprite.speed_y == 0) {
        c.subto0(&globals.CHOC_FLAG);
    }
    if (player.*.sprite.speed_x == 0 and player.*.sprite.speed_y == 0) {
        globals.KICK_FLAG = 0;
    }
    c.subto0(&globals.FUME_FLAG);
    if ((globals.FUME_FLAG != 0) and ((globals.FUME_FLAG & 0x03) == 0)) {
        c.updatesprite(level, &player.sprite2, player.sprite2.number + 1, false);
        if (player.sprite2.number == c.FIRST_OBJET + 19) {
            player.sprite2.enabled = false;
            globals.FUME_FLAG = 0;
        }
    }
    return 0;
}

fn DEC_LIFE(level: *c.TITUS_level) void {
    globals.RESETLEVEL_FLAG = 10;
    globals.BAR_FLAG = 0;
    if (level.lives == 0) {
        globals.GAMEOVER_FLAG = true;
    } else {
        globals.LOSELIFE_FLAG = true;
    }
}

fn CASE_DEAD_IM(level: *c.TITUS_level) void {
    // Kill the player immediately (spikes/water/flames etc.
    // Sets RESET_FLAG to 2, in opposite to being killed as a result of 0 HP (then
    // RESET_FLAG is 10)
    DEC_LIFE(level);
    globals.RESETLEVEL_FLAG = 2;
}

fn BRK_COLLISION(context: *c.ScreenContext, level: *c.TITUS_level) void {
    // Collision detection between player
    // and tiles/objects/elevators
    // Point the foot on the block!
    const player = &level.*.player;
    var changeX: i16 = undefined;
    var height: i16 = undefined;
    var tileX: u8 = undefined;
    var tileY: i16 = undefined;
    var colltest: i16 = undefined;
    var hflag: c.enum_HFLAG = undefined;
    tileX = @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) >> @intCast(4)))));
    tileY = @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_int, player.*.sprite.y))) >> @intCast(4)) - 1))));
    const initY = tileY;

    // if too low then die!
    if ((player.sprite.y > ((level.height + 1) << 4)) and !globals.NOCLIP) {
        CASE_DEAD_IM(level);
    }

    // Test under the feet of the hero and on his head! (In y)
    const TEST_ZONE = 4;
    globals.YFALL = 0;
    // Find the left tile
    // colltest can be 0 to 15 +- 8 (-1 to -8 will change into 255 to 248)
    colltest = player.sprite.x & 0x0F;
    if (colltest < TEST_ZONE) {
        colltest += 256;
        tileX -%= 1;
    }
    colltest -= TEST_ZONE;

    const left_tileX = tileX;
    // Test the tile for vertical blocking
    TAKE_BLK_AND_YTEST(level, tileY, tileX);

    if (globals.YFALL == 1) { // Have the fall stopped?
        // No! Is it necessary to test the right tile?
        colltest += TEST_ZONE * 2; // 4 * 2
        //      if (colltest > 255) {
        //          colltest -= 256;
        //          tileX++;
        //      } elseif
        if (colltest > 15) {
            tileX +%= 1;
        }
        if (tileX != left_tileX) {
            // Also test the left tile
            TAKE_BLK_AND_YTEST(level, tileY, tileX);
        }
        if (globals.YFALL == 1) {
            if (globals.CROSS_FLAG == 0 and globals.CHOC_FLAG == 0) {
                COLLISION_TRP(level); // Player versus elevators
                if (globals.YFALL == 1) {
                    COLLISION_OBJET(level); // Player versus objects
                    if (globals.YFALL == 1) {
                        ARAB_TOMBE(level); // No wall/elevator/object under the player; fall down!
                    } else {
                        player.GLISSE = 0;
                    }
                }
            } else {
                ARAB_TOMBE(level); // Fall down!
            }
        }
    }

    // How will the player move in X?
    changeX = @as(i16, @bitCast(@as(c_short, @truncate(TEST_ZONE + 4))));
    if (@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_x))) < 0) {
        changeX = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_int, changeX)))))));
    } else if (@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_x))) == 0) {
        changeX = 0;
    }
    height = @as(i16, @bitCast(@as(c_ushort, player.*.sprite.spritedata.*.collheight)));
    if (((@as(c_int, @bitCast(@as(c_int, player.*.sprite.y))) > (-1 + 1)) and (@as(c_int, @bitCast(@as(c_int, initY))) >= 0)) and (@as(c_int, @bitCast(@as(c_int, initY))) < @as(c_int, @bitCast(@as(c_int, level.*.height))))) {
        tileX = @as(u8, @bitCast(@as(i8, @truncate((@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) + @as(c_int, @bitCast(@as(c_int, changeX)))) >> @intCast(4)))));
        tileY = initY;
        var first = true;
        while (true) {
            hflag = c.get_horizflag(level, tileY, @as(i16, @bitCast(@as(c_ushort, tileX))));
            if (first) {
                BLOCK_XXPRG(context, level, hflag, @as(u8, @bitCast(@as(i8, @truncate(tileY)))), tileX);
                first = false;
            } else if ((@as(c_int, @bitCast(@as(c_uint, hflag))) == @as(c_int, @bitCast(@as(c_uint, c.HFLAG_CODE)))) or (@as(c_int, @bitCast(@as(c_uint, hflag))) == @as(c_int, @bitCast(@as(c_uint, c.HFLAG_BONUS))))) {
                BLOCK_XXPRG(context, level, hflag, @as(u8, @bitCast(@as(i8, @truncate(tileY)))), tileX);
            }
            if (@as(c_int, @bitCast(@as(c_int, tileY))) == 0) {
                return;
            }
            tileY -= 1;
            height -= @as(i16, @bitCast(@as(c_short, @truncate(16))));
            if (!(@as(c_int, @bitCast(@as(c_int, height))) > 0)) break;
        }
    }
}

fn TAKE_BLK_AND_YTEST(level: *c.TITUS_level, tileY_in: i16, tileX_in: u8) void {
    var tileY = tileY_in;
    var tileX = tileX_in;
    const player = &level.*.player;
    globals.POCKET_FLAG = false;
    globals.PRIER_FLAG = false;
    globals.LADDER_FLAG = false;
    var change: i8 = undefined;
    _ = &change;
    if ((@as(c_int, @bitCast(@as(c_int, player.*.sprite.y))) <= -1) or (@as(c_int, @bitCast(@as(c_int, tileY))) < -1)) {
        ARAB_TOMBE(level);
        globals.YFALL = 255;
        return;
    }
    if ((@as(c_int, @bitCast(@as(c_int, tileY))) + 1) >= @as(c_int, @bitCast(@as(c_int, level.*.height)))) {
        ARAB_TOMBE(level);
        globals.YFALL = 255;
        return;
    }
    if (@as(c_int, @bitCast(@as(c_int, tileY))) == -1) {
        tileY = 0;
    }
    var floor_1: c.enum_FFLAG = c.get_floorflag(level, @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, tileY))) + 1)))), @as(i16, @bitCast(@as(c_ushort, tileX))));
    _ = &floor_1;
    var floor_above: c.enum_FFLAG = c.get_floorflag(level, tileY, @as(i16, @bitCast(@as(c_ushort, tileX))));
    _ = &floor_above;
    if ((@as(c_int, @bitCast(@as(c_uint, globals.LAST_ORDER))) & 15) != 2) {
        BLOCK_YYPRG(level, floor_1, floor_above, @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @bitCast(@as(c_int, tileY))) + 1)))), tileX);
    }
    if ((@as(c_int, @bitCast(@as(c_int, tileY))) < 1) or (@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_y))) > 0)) {
        return;
    }
    var cflag: c.enum_CFLAG = c.get_ceilflag(level, @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, tileY))) - 1)))), @as(i16, @bitCast(@as(c_ushort, tileX))));
    _ = &cflag;
    BLOCK_YYPRGD(level, cflag, @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @bitCast(@as(c_int, tileY))) - 1)))), tileX);
    var horiz: c.enum_HFLAG = c.get_horizflag(level, tileY, @as(i16, @bitCast(@as(c_ushort, tileX))));
    _ = &horiz;
    if ((((@as(c_int, @bitCast(@as(c_uint, horiz))) == @as(c_int, @bitCast(@as(c_uint, c.HFLAG_WALL)))) or (@as(c_int, @bitCast(@as(c_uint, horiz))) == @as(c_int, @bitCast(@as(c_uint, c.HFLAG_DEADLY))))) or (@as(c_int, @bitCast(@as(c_uint, horiz))) == @as(c_int, @bitCast(@as(c_uint, c.HFLAG_PADLOCK))))) and (@as(c_int, @bitCast(@as(c_int, player.*.sprite.y))) > (-1 + 1))) {
        if (@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_x))) > 0) {
            change = @as(i8, @bitCast(@as(i8, @truncate(-1))));
        } else {
            change = 1;
        }
        tileX +%= @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @bitCast(@as(c_int, change)))))));
        horiz = c.get_horizflag(level, tileY, @as(i16, @bitCast(@as(c_ushort, tileX))));
        if (@as(c_int, @bitCast(@as(c_uint, horiz))) == 0) {
            player.*.sprite.x += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, change))) << @intCast(1)))));
        } else {
            change = @as(i8, @bitCast(@as(i8, @truncate(0 - @as(c_int, @bitCast(@as(c_int, change)))))));
            tileX +%= @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @bitCast(@as(c_int, change))) + @as(c_int, @bitCast(@as(c_int, change)))))));
            horiz = c.get_horizflag(level, tileY, @as(i16, @bitCast(@as(c_ushort, tileX))));
            if (@as(c_int, @bitCast(@as(c_uint, horiz))) == 0) {
                player.*.sprite.x += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, change))) << @intCast(1)))));
            }
        }
    }
}

fn BLOCK_YYPRGD(level: [*c]c.TITUS_level, cflag: c.enum_CFLAG, tileY_in: u8, tileX_in: u8) void {
    var tileX = tileX_in;
    var tileY = tileY_in;
    const player: [*c]c.TITUS_player = &level.*.player;
    var object: [*c]c.TITUS_object = undefined;
    while (true) {
        switch (@as(c_int, @bitCast(@as(c_uint, cflag)))) {
            @as(c_int, @bitCast(@as(c_uint, @as(u8, 0)))) => break,
            @as(c_int, @bitCast(@as(c_uint, @as(u8, 1)))), @as(c_int, @bitCast(@as(c_uint, @as(u8, 4)))) => {
                if ((@as(c_int, @bitCast(@as(c_uint, cflag))) == @as(c_int, @bitCast(@as(c_uint, c.CFLAG_DEADLY)))) and !globals.GODMODE) {
                    CASE_DEAD_IM(level);
                } else if (@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_y))) != 0) {
                    player.*.sprite.speed_y = 0;
                    player.*.sprite.y = @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_int, player.*.sprite.y))) & 65520) + 16))));
                    globals.SAUT_COUNT = 255;
                } else if (((@as(c_int, @bitCast(@as(c_int, player.*.sprite.number))) != 10) and (@as(c_int, @bitCast(@as(c_int, player.*.sprite.number))) != 21)) and (@as(c_int, @bitCast(@as(c_uint, globals.SAUT_FLAG))) != 6)) {
                    globals.PRIER_FLAG = true;
                    if (globals.CARRY_FLAG) {
                        object = FORCE_POSE(level);
                        if (object != @as([*c]c.TITUS_object, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(0)))))) {
                            tileX = @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @bitCast(@as(c_int, object.*.sprite.x))) >> @intCast(4)))));
                            tileY = @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @bitCast(@as(c_int, object.*.sprite.y))) >> @intCast(4)))));
                            var hflag: c.enum_HFLAG = c.get_horizflag(level, @as(i16, @bitCast(@as(c_ushort, tileY))), @as(i16, @bitCast(@as(c_ushort, tileX))));
                            _ = &hflag;
                            if (((@as(c_int, @bitCast(@as(c_uint, hflag))) == @as(c_int, @bitCast(@as(c_uint, c.HFLAG_WALL)))) or (@as(c_int, @bitCast(@as(c_uint, hflag))) == @as(c_int, @bitCast(@as(c_uint, c.HFLAG_DEADLY))))) or (@as(c_int, @bitCast(@as(c_uint, hflag))) == @as(c_int, @bitCast(@as(c_uint, c.HFLAG_PADLOCK))))) {
                                tileX -%= 1;
                                hflag = c.get_horizflag(level, @as(i16, @bitCast(@as(c_ushort, tileY))), @as(i16, @bitCast(@as(c_ushort, tileX))));
                                if (((@as(c_int, @bitCast(@as(c_uint, hflag))) == @as(c_int, @bitCast(@as(c_uint, c.HFLAG_WALL)))) or (@as(c_int, @bitCast(@as(c_uint, hflag))) == @as(c_int, @bitCast(@as(c_uint, c.HFLAG_DEADLY))))) or (@as(c_int, @bitCast(@as(c_uint, hflag))) == @as(c_int, @bitCast(@as(c_uint, c.HFLAG_PADLOCK))))) {
                                    object.*.sprite.x += @as(i16, @bitCast(@as(c_short, @truncate(16))));
                                } else {
                                    object.*.sprite.x -= @as(i16, @bitCast(@as(c_short, @truncate(16))));
                                }
                            }
                        }
                    }
                }
                break;
            },
            @as(c_int, @bitCast(@as(c_uint, @as(u8, 2)))) => {
                if ((@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_y))) < 0) and (@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_x))) == 0)) {
                    globals.SAUT_COUNT = 10;
                    globals.LADDER_FLAG = true;
                }
                break;
            },
            @as(c_int, @bitCast(@as(c_uint, @as(u8, 3)))) => {
                CASE_SECU(level, tileY, tileX);
                break;
            },
            else => {},
        }
        break;
    }
}

fn BLOCK_XXPRG(arg_context: [*c]c.ScreenContext, arg_level: [*c]c.TITUS_level, arg_hflag: c.enum_HFLAG, arg_tileY: u8, arg_tileX: u8) void {
    var context = arg_context;
    _ = &context;
    var level = arg_level;
    _ = &level;
    var hflag = arg_hflag;
    _ = &hflag;
    var tileY = arg_tileY;
    _ = &tileY;
    var tileX = arg_tileX;
    _ = &tileX;
    while (true) {
        switch (@as(c_int, @bitCast(@as(c_uint, hflag)))) {
            @as(c_int, @bitCast(@as(c_uint, @as(u8, 0)))) => break,
            @as(c_int, @bitCast(@as(c_uint, @as(u8, 1)))) => {
                ARAB_BLOCKX(level);
                break;
            },
            @as(c_int, @bitCast(@as(c_uint, @as(u8, 2)))) => {
                _ = CASE_BONUS(level, tileY, tileX);
                break;
            },
            @as(c_int, @bitCast(@as(c_uint, @as(u8, 3)))) => {
                if (!globals.GODMODE) {
                    CASE_DEAD_IM(level);
                } else {
                    ARAB_BLOCKX(level);
                }
                break;
            },
            @as(c_int, @bitCast(@as(c_uint, @as(u8, 4)))) => {
                CASE_PASS(level, @as(u8, @bitCast(@as(u8, @truncate(level.*.levelnumber)))), tileY, tileX);
                break;
            },
            @as(c_int, @bitCast(@as(c_uint, @as(u8, 5)))) => {
                CASE_SECU(level, tileY, tileX);
                break;
            },
            @as(c_int, @bitCast(@as(c_uint, @as(u8, 6)))) => {
                CASE_PASS(level, @as(u8, @bitCast(@as(i8, @truncate(14 - 1)))), tileY, tileX);
                break;
            },
            else => {},
        }
        break;
    }
}

fn ARAB_BLOCKX(arg_level: [*c]c.TITUS_level) void {
    var level = arg_level;
    _ = &level;
    var player: [*c]c.TITUS_player = &level.*.player;
    _ = &player;
    player.*.sprite.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_x))) >> @intCast(4)))));
    player.*.sprite.speed_x = 0;
    if ((@as(c_int, @bitCast(@as(c_uint, globals.KICK_FLAG))) != 0) and (@as(c_int, @bitCast(@as(c_uint, globals.SAUT_FLAG))) != 6)) {
        globals.CHOC_FLAG = 20;
        globals.KICK_FLAG = 0;
    }
}

pub export fn FORCE_POSE(level: [*c]c.TITUS_level) [*c]c.TITUS_object {
    const sprite2: [*c]c.TITUS_sprite = &level.*.player.sprite2;
    var i: i16 = undefined;
    _ = &i;
    if ((@as(c_int, @intFromBool(sprite2.*.enabled)) != 0) and (@as(c_int, @intFromBool(globals.CARRY_FLAG)) != 0)) {
        i = 0;
        while (true) {
            if (@as(c_int, @bitCast(@as(c_int, i))) > 40) {
                std.log.err("FORCE_POSE returned NULL.", .{});
                return null;
            }
            if (!level.*.object[@as(c_ushort, @intCast(i))].sprite.enabled) break;
            i += 1;
        }
        const object = &level.*.object[@as(c_ushort, @intCast(i))];
        c.updateobjectsprite(level, object, sprite2.*.number, true);
        sprite2.*.enabled = false;
        object.*.sprite.killing = false;
        if (@as(c_int, @bitCast(@as(c_int, object.*.sprite.number))) < 101) {
            object.*.sprite.droptobottom = false;
        } else {
            object.*.sprite.droptobottom = true;
        }
        object.*.sprite.x = sprite2.*.x;
        object.*.sprite.y = sprite2.*.y;
        object.*.momentum = 0;
        object.*.sprite.speed_y = 0;
        object.*.sprite.speed_x = 0;
        object.*.sprite.UNDER = 0;
        object.*.sprite.ONTOP = null;
        globals.POSEREADY_FLAG = true;
        globals.GRAVITY_FLAG = 4;
        globals.CARRY_FLAG = false;
        return object;
    }
    return null;
}

fn ARAB_TOMBE(level: *c.TITUS_level) void {
    // No wall under the player; fall down!
    const player = &level.player;
    globals.SAUT_FLAG = 6;
    if (globals.KICK_FLAG != 0) {
        return;
    }
    XACCELERATION(player, c.MAX_X * 16);
    YACCELERATION(player, c.MAX_Y * 16);
    if (globals.CHOC_FLAG != 0) {
        c.updatesprite(level, &player.sprite, 15, true); // sprite when hit
    } else if (!globals.CARRY_FLAG) {
        c.updatesprite(level, &player.sprite, 10, true); // position while falling  (jump sprite?)
    } else {
        c.updatesprite(level, &player.sprite, 21, true); // position falling and carry  (jump and carry sprite?)
    }
    player.*.sprite.flipped = globals.SENSX < 0;
}

fn XACCELERATION(player: *c.TITUS_player, maxspeed: i16) void {
    // Sideway acceleration
    var changeX: i16 = undefined;
    if (globals.X_FLAG) {
        changeX = (globals.SENSX << 4) >> @truncate(player.GLISSE);
    } else {
        changeX = 0;
    }

    if (player.sprite.speed_x + changeX >= maxspeed) {
        player.sprite.speed_x = maxspeed;
    } else if (player.sprite.speed_x + changeX <= 0 - maxspeed) {
        player.sprite.speed_x = 0 - maxspeed;
    } else {
        player.sprite.speed_x += changeX;
    }
}

fn YACCELERATION(player: *c.TITUS_player, maxspeed: i16) void {
    // Accelerate downwards
    if (player.sprite.speed_y + 16 < maxspeed) {
        player.sprite.speed_y = player.sprite.speed_y + 16;
    } else {
        player.sprite.speed_y = maxspeed;
    }
}

fn BLOCK_YYPRG(level: *c.TITUS_level, floor: c.enum_FFLAG, floor_above: c.enum_FFLAG, tileY: u8, tileX: u8) void {
    // Action on different floor flags
    const player = &level.player;
    var order: u8 = undefined;
    switch (floor) {
        // No floor
        c.FFLAG_NOFLOOR => {
            ARAB_TOMBE_F();
        },
        // Floor
        c.FFLAG_FLOOR => {
            ARAB_BLOCK_YU(player);
        },
        // Slightly slippery floor
        c.FFLAG_SSFLOOR => {
            ARAB_BLOCK_YU(player);
            player.GLISSE = 1;
        },
        // Slippery floor
        c.FFLAG_SFLOOR => {
            ARAB_BLOCK_YU(player);
            player.GLISSE = 2;
        },
        // Very slippery floor
        c.FFLAG_VSFLOOR => {
            ARAB_BLOCK_YU(player);
            player.GLISSE = 3;
        },
        // Drop-through if kneestanding
        c.FFLAG_DROP => {
            player.GLISSE = 0;
            if (globals.CROSS_FLAG == 0) {
                ARAB_BLOCK_YU(player);
            } else {
                ARAB_TOMBE_F();
            }
        },
        // Ladder
        c.FFLAG_LADDER => {
            // Fall if hit
            // Skip if walking/crawling
            if (globals.CHOC_FLAG != 0) {
                ARAB_TOMBE_F(); // Free fall
                return;
            }
            order = globals.LAST_ORDER & 0x0F;
            if (order == 1 or order == 3 or order == 7 or order == 8) {
                ARAB_BLOCK_YU(player); // Stop fall
                return;
            }
            if (order == 5) {   // action baisse
                ARAB_TOMBE_F(); // Free fall
                c.updatesprite(level, &player.sprite, 14, true); // sprite: start climbing down
                player.sprite.y += 8;
            }
            if (floor_above != 6) {        // ladder
                if (order == 0) {          // action repos
                    ARAB_BLOCK_YU(player); // Stop fall
                    return;
                }
                if (player.y_axis < 0 and order == 6) { // action UP + climb ladder
                    ARAB_BLOCK_YU(player);              // Stop fall
                    return;
                }
            }

            c.subto0(&globals.SAUT_FLAG);
            globals.SAUT_COUNT = 0;
            globals.YFALL = 2;

            globals.LADDER_FLAG = true;
        },
        c.FFLAG_BONUS => {
            _ = CASE_BONUS(level, tileY, tileX);
        },
        c.FFLAG_WATER, c.FFLAG_FIRE, c.FFLAG_SPIKES => {
            if (!globals.GODMODE) {
                CASE_DEAD_IM(level);
            } else {
                ARAB_BLOCK_YU(player); // If godmode; ordinary floor
            }
        },
        c.FFLAG_CODE => {
            CASE_PASS(level, @as(u8, @bitCast(@as(u8, @truncate(level.*.levelnumber)))), tileY, tileX);
        },
        c.FFLAG_PADLOCK => {
            CASE_SECU(level, tileY, tileX);
        },
        c.FFLAG_LEVEL14 => {
            CASE_PASS(level, 14 - 1, tileY, tileX);
        },
        else => {},
    }
}

fn ARAB_TOMBE_F() void {
    globals.YFALL = globals.YFALL | 0x01;
}

fn ARAB_BLOCK_YU(player: *c.TITUS_player) void {
    // Floor; the player will not fall through
    globals.POCKET_FLAG = true;
    player.GLISSE = 0;
    if (player.sprite.speed_y < 0) {
        globals.YFALL = globals.YFALL | 0x01;
        return;
    }
    player.sprite.y = @bitCast(@as(u16, @bitCast(player.sprite.y)) & 0xFFF0);
    player.sprite.speed_y = 0;
    c.subto0(&globals.SAUT_FLAG);
    globals.SAUT_COUNT = 0;
    globals.YFALL = 2;
}

fn CASE_BONUS(level: *c.TITUS_level, tileY: u8, tileX: u8) bool {
    // Handle bonuses. Increase energy if HP, and change the bonus tile to normal tile
    for(&level.bonus) |*bonus| {
        if(!bonus.exists)
            continue;
        if(bonus.x != tileX or bonus.y != tileY)
            continue;

        if (bonus.bonustile >= (255 - 2)) {
            level.bonuscollected += 1;
            c.playEvent_c(c.Event_PlayerCollectBonus);
            INC_ENERGY(level);
        }
        c.set_tile(level, tileY, tileX, bonus.replacetile);
        globals.GRAVITY_FLAG = 4;
        return true;
    }
    return false;
}

fn CASE_PASS(level: *c.TITUS_level, level_index: u8, tileY: u8, tileX: u8) void {
    // FIXME: nothing is done here really. It should unlock the level as a starting point
    _ = &level_index;
    // Codelamp
    // if the bonus is found in the bonus list
    if (!CASE_BONUS(level, tileY, tileX))
        return;

    c.playEvent_c(c.Event_PlayerCollectLamp);
}

fn CASE_SECU(level: *c.TITUS_level, tileY: u8, tileX: u8) void {
    if (!CASE_BONUS(level, tileY, tileX))
        return;

    const player = &level.player;
    c.playEvent_c(c.Event_PlayerCollectWaypoint);
    player.initX = player.sprite.x;
    player.initY = player.sprite.y;
    // carrying cage?
    if (player.sprite2.number == c.FIRST_OBJET + 26 or player.sprite2.number == c.FIRST_OBJET + 27) {
        player.cageX = player.sprite.x;
        player.cageY = player.sprite.y;
    }
}

fn INC_ENERGY(level: *c.TITUS_level) void {
    const player = &level.player;
    globals.BAR_FLAG = 50;
    if (player.hp == c.MAXIMUM_ENERGY) {
        level.extrabonus += 1;
    } else {
        player.hp += 1;
    }
}

pub export fn DEC_ENERGY(level: *c.TITUS_level) void {
    const player = &level.player;
    globals.BAR_FLAG = 50;
    if (globals.RESETLEVEL_FLAG == 0) {
        if (player.hp > 0) {
            player.hp -= 1;
        }
        if (player.hp == 0) {
            DEC_LIFE(level);
        }
    }
}

fn ACTION_PRG(level: *c.TITUS_level, action: u8) void {
    const player = &level.player;
    var tileX: u8 = undefined;
    var tileY: u8 = undefined;
    var fflag: u8 = undefined;
    var object: [*c]c.TITUS_object = undefined;
    var i: i16 = undefined;
    var diffX: i16 = undefined;
    var speed_x: i16 = undefined;
    var speed_y: i16 = undefined;

    while (true) {
        switch (action) {
            0, 9, 16 => {
                globals.LAST_ORDER = action;
                DECELERATION(player);
                if ((c.abs(@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_x)))) >= (1 * 16)) and (@as(c_int, @intFromBool(player.*.sprite.flipped)) == @intFromBool(@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_x))) < 0))) {
                    player.*.sprite.animation = data.get_anim_player(@as(u8, @bitCast(@as(i8, @truncate(4 + @as(c_int, @bitCast(@as(c_uint, add_carry()))))))));
                } else {
                    player.*.sprite.animation = data.get_anim_player(action);
                }
                c.updatesprite(level, &player.*.sprite, player.*.sprite.animation.*, true);
                player.*.sprite.flipped = @as(c_int, @bitCast(@as(c_int, globals.SENSX))) < 0;
                break;
            },
            1, 17, 19 => {
                XACCELERATION(player, @as(i16, @bitCast(@as(c_short, @truncate(4 * 16)))));
                NEW_FORM(player, action);
                GET_IMAGE(level);
                break;
            },
            2, 18 => {
                if (@as(c_int, @bitCast(@as(c_uint, globals.SAUT_COUNT))) >= 3) {
                    globals.SAUT_FLAG = 6;
                } else {
                    globals.SAUT_COUNT +%= 1;
                    YACCELERATION_NEG(player, @as(i16, @bitCast(@as(c_short, @truncate(@divTrunc(12 * 16, 4))))));
                    XACCELERATION(player, @as(i16, @bitCast(@as(c_short, @truncate(4 * 16)))));
                    NEW_FORM(player, action);
                    GET_IMAGE(level);
                }
                break;
            },
            3 => {
                NEW_FORM(player, action);
                GET_IMAGE(level);
                XACCELERATION(player, @as(i16, @bitCast(@as(c_short, @truncate(@divTrunc(4 * 16, 2))))));
                if (c.abs(@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_x)))) < (2 * 16)) {
                    c.updatesprite(level, &player.*.sprite, @as(i16, @bitCast(@as(c_short, @truncate(6)))), true);
                    player.*.sprite.flipped = @as(c_int, @bitCast(@as(c_int, globals.SENSX))) < 0;
                }
                break;
            },
            4, 14, 15, 20, 25, 26 => break,
            5 => {
                NEW_FORM(player, action);
                GET_IMAGE(level);
                DECELERATION(player);
                if (@as(c_int, @bitCast(@as(c_uint, globals.ACTION_TIMER))) == 15) {
                    globals.CROSS_FLAG = 6;
                    player.*.sprite.speed_y = 0;
                }
                break;
            },
            6, 22 => {
                if (@as(c_int, @intFromBool(globals.X_FLAG)) != 0) {
                    XACCELERATION(player, @as(i16, @bitCast(@as(c_short, @truncate(4 * 16)))));
                } else {
                    DECELERATION(player);
                }
                if (@as(c_int, @bitCast(@as(c_uint, globals.ACTION_TIMER))) <= 1) {
                    if (@as(c_int, @intFromBool(globals.CARRY_FLAG)) == 0) {
                        c.updatesprite(level, &player.*.sprite, @as(i16, @bitCast(@as(c_short, @truncate(12)))), true);
                    } else {
                        c.updatesprite(level, &player.*.sprite, @as(i16, @bitCast(@as(c_short, @truncate(23)))), true);
                    }
                }
                if (@as(c_int, @intFromBool(globals.Y_FLAG)) != 0) {
                    NEW_FORM(player, @as(u8, @bitCast(@as(i8, @truncate(6 + @as(c_int, @bitCast(@as(c_uint, add_carry()))))))));
                    GET_IMAGE(level);
                    player.*.sprite.x = @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) & 65520) + 8))));
                    tileX = @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) >> @intCast(4)))));
                    tileY = @as(u8, @bitCast(@as(i8, @truncate((@as(c_int, @bitCast(@as(c_int, player.*.sprite.y))) & 65520) >> @intCast(4)))));
                    if (@as(c_int, @bitCast(@as(c_uint, c.get_floorflag(level, @as(i16, @bitCast(@as(c_ushort, tileY))), @as(i16, @bitCast(@as(c_ushort, tileX))))))) != @as(c_int, @bitCast(@as(c_uint, c.FFLAG_LADDER)))) {
                        if (@as(c_int, @bitCast(@as(c_uint, c.get_floorflag(level, @as(i16, @bitCast(@as(c_ushort, tileY))), @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_uint, tileX))) - 1)))))))) == @as(c_int, @bitCast(@as(c_uint, c.FFLAG_LADDER)))) {
                            player.*.sprite.x -= @as(i16, @bitCast(@as(c_short, @truncate(16))));
                        } else if (@as(c_int, @bitCast(@as(c_uint, c.get_floorflag(level, @as(i16, @bitCast(@as(c_ushort, tileY))), @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_uint, tileX))) + 1)))))))) == @as(c_int, @bitCast(@as(c_uint, c.FFLAG_LADDER)))) {
                            player.*.sprite.x += @as(i16, @bitCast(@as(c_short, @truncate(16))));
                        }
                    }
                    if (@as(c_int, @bitCast(@as(c_int, player.*.y_axis))) >= 0) {
                        player.*.sprite.speed_y = @as(i16, @bitCast(@as(c_short, @truncate(4 * 16))));
                    } else {
                        player.*.sprite.speed_y = @as(i16, @bitCast(@as(c_short, @truncate(0 - (4 * 16)))));
                    }
                } else {
                    player.*.sprite.speed_y = 0;
                }
                break;
            },
            7, 23 => {
                NEW_FORM(player, action);
                GET_IMAGE(level);
                DECELERATION(player);
                if (!globals.POSEREADY_FLAG) {
                    if ((@as(c_int, @bitCast(@as(c_uint, globals.ACTION_TIMER))) == 1) and (@as(c_int, @intFromBool(globals.CARRY_FLAG)) != 0)) {
                        object = FORCE_POSE(level);
                        if (object != @as([*c]c.TITUS_object, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(0)))))) {
                            tileX = @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @bitCast(@as(c_int, object.*.sprite.x))) >> @intCast(4)))));
                            tileY = @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @bitCast(@as(c_int, object.*.sprite.y))) >> @intCast(4)))));
                            fflag = c.get_floorflag(level, @as(i16, @bitCast(@as(c_ushort, tileY))), @as(i16, @bitCast(@as(c_ushort, tileX))));
                            if ((@as(c_int, @bitCast(@as(c_uint, fflag))) != @as(c_int, @bitCast(@as(c_uint, c.FFLAG_NOFLOOR)))) and (@as(c_int, @bitCast(@as(c_uint, fflag))) != @as(c_int, @bitCast(@as(c_uint, c.FFLAG_WATER))))) {
                                tileX +%= 1;
                                fflag = c.get_floorflag(level, @as(i16, @bitCast(@as(c_ushort, tileY))), @as(i16, @bitCast(@as(c_ushort, tileX))));
                                if ((@as(c_int, @bitCast(@as(c_uint, fflag))) != @as(c_int, @bitCast(@as(c_uint, c.FFLAG_NOFLOOR)))) and (@as(c_int, @bitCast(@as(c_uint, fflag))) != @as(c_int, @bitCast(@as(c_uint, c.FFLAG_WATER))))) {
                                    object.*.sprite.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(16 * 3))));
                                } else {
                                    object.*.sprite.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - (16 * 3)))));
                                }
                            }
                        }
                    } else {
                        if (!globals.CARRY_FLAG) {
                            {
                                i = 0;
                                while (@as(c_int, @bitCast(@as(c_int, i))) < 40) : (i += 1) {
                                    if (!level.*.object[@as(c_ushort, @intCast(i))].sprite.enabled or (c.abs(@as(c_int, @bitCast(@as(c_int, player.*.sprite.y))) - @as(c_int, @bitCast(@as(c_int, level.*.object[@as(c_ushort, @intCast(i))].sprite.y)))) >= 20)) {
                                        continue;
                                    }
                                    diffX = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) - @as(c_int, @bitCast(@as(c_int, level.*.object[@as(c_ushort, @intCast(i))].sprite.x)))))));
                                    if (!player.*.sprite.flipped) {
                                        diffX = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_int, diffX)))))));
                                    }
                                    if (c.game == @as(c_uint, @bitCast(c.Moktar))) {
                                        if (@as(c_int, @bitCast(@as(c_int, diffX))) >= 25) {
                                            continue;
                                        }
                                    } else if (c.game == @as(c_uint, @bitCast(c.Titus))) {
                                        if (@as(c_int, @bitCast(@as(c_int, diffX))) >= 20) {
                                            continue;
                                        }
                                    }
                                    if (@as(c_int, @bitCast(@as(c_int, level.*.object[@as(c_ushort, @intCast(i))].sprite.x))) > @as(c_int, @bitCast(@as(c_int, player.*.sprite.x)))) {
                                        if (@as(c_int, @bitCast(@as(c_int, level.*.object[@as(c_ushort, @intCast(i))].sprite.x))) > (@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) + 32)) {
                                            continue;
                                        }
                                    } else {
                                        if ((@as(c_int, @bitCast(@as(c_int, level.*.object[@as(c_ushort, @intCast(i))].sprite.x))) + @as(c_int, @bitCast(@as(c_uint, level.*.object[@as(c_ushort, @intCast(i))].sprite.spritedata.*.collwidth)))) < @as(c_int, @bitCast(@as(c_int, player.*.sprite.x)))) {
                                            continue;
                                        }
                                    }
                                    if (@as(c_int, @bitCast(@as(c_int, level.*.object[@as(c_ushort, @intCast(i))].sprite.y))) < @as(c_int, @bitCast(@as(c_int, player.*.sprite.y)))) {
                                        if (@as(c_int, @bitCast(@as(c_int, level.*.object[@as(c_ushort, @intCast(i))].sprite.y))) <= (@as(c_int, @bitCast(@as(c_int, player.*.sprite.y))) - 10)) {
                                            continue;
                                        }
                                    } else {
                                        if (((@as(c_int, @bitCast(@as(c_int, level.*.object[@as(c_ushort, @intCast(i))].sprite.y))) - @as(c_int, @bitCast(@as(c_uint, level.*.object[@as(c_ushort, @intCast(i))].sprite.spritedata.*.collheight)))) + 1) >= @as(c_int, @bitCast(@as(c_int, player.*.sprite.y)))) {
                                            continue;
                                        }
                                    }
                                    c.playEvent_c(@as(c_uint, @bitCast(c.Event_PlayerPickup)));
                                    globals.FUME_FLAG = 0;
                                    level.*.object[@as(c_ushort, @intCast(i))].sprite.speed_y = 0;
                                    level.*.object[@as(c_ushort, @intCast(i))].sprite.speed_x = 0;
                                    globals.GRAVITY_FLAG = 4;
                                    c.copysprite(level, &player.*.sprite2, &level.*.object[@as(c_ushort, @intCast(i))].sprite);
                                    level.*.object[@as(c_ushort, @intCast(i))].sprite.enabled = false;
                                    globals.CARRY_FLAG = true;
                                    globals.SEECHOC_FLAG = 0;
                                    if (@as(c_int, @bitCast(@as(c_int, player.*.sprite2.number))) == (c.FIRST_OBJET + 19)) {
                                        globals.TAPISWAIT_FLAG = 0;
                                    }
                                    player.*.sprite2.y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.y))) - 4))));
                                    if (player.*.sprite.flipped) {
                                        player.*.sprite2.x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) - 10))));
                                    } else {
                                        player.*.sprite2.x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) + 12))));
                                    }
                                    break;
                                }
                            }
                            if (!globals.CARRY_FLAG) {
                                i = 0;
                                while (@as(c_int, @bitCast(@as(c_int, i))) < 50) : (i += 1) {
                                    if (!level.*.enemy[@as(c_ushort, @intCast(i))].sprite.enabled or (c.abs(@as(c_int, @bitCast(@as(c_int, player.*.sprite.y))) - @as(c_int, @bitCast(@as(c_int, level.*.enemy[@as(c_ushort, @intCast(i))].sprite.y)))) >= 20)) {
                                        continue;
                                    }
                                    diffX = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) - @as(c_int, @bitCast(@as(c_int, level.*.enemy[@as(c_ushort, @intCast(i))].sprite.x)))))));
                                    if (!player.*.sprite.flipped) {
                                        diffX = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_int, diffX)))))));
                                    }
                                    if (c.game == @as(c_uint, @bitCast(c.Moktar))) {
                                        if (@as(c_int, @bitCast(@as(c_int, diffX))) >= 25) {
                                            continue;
                                        }
                                    } else if (c.game == @as(c_uint, @bitCast(c.Titus))) {
                                        if (@as(c_int, @bitCast(@as(c_int, diffX))) >= 20) {
                                            continue;
                                        }
                                    }
                                    if (@as(c_int, @bitCast(@as(c_int, level.*.enemy[@as(c_ushort, @intCast(i))].carry_sprite))) == -1) {
                                        continue;
                                    }
                                    if (@as(c_int, @bitCast(@as(c_int, level.*.enemy[@as(c_ushort, @intCast(i))].sprite.x))) > @as(c_int, @bitCast(@as(c_int, player.*.sprite.x)))) {
                                        if (@as(c_int, @bitCast(@as(c_int, level.*.enemy[@as(c_ushort, @intCast(i))].sprite.x))) > (@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) + 32)) {
                                            continue;
                                        }
                                    } else {
                                        if ((@as(c_int, @bitCast(@as(c_int, level.*.enemy[@as(c_ushort, @intCast(i))].sprite.x))) + @as(c_int, @bitCast(@as(c_uint, level.*.enemy[@as(c_ushort, @intCast(i))].sprite.spritedata.*.collwidth)))) < @as(c_int, @bitCast(@as(c_int, player.*.sprite.x)))) {
                                            continue;
                                        }
                                    }
                                    if (@as(c_int, @bitCast(@as(c_int, level.*.enemy[@as(c_ushort, @intCast(i))].sprite.y))) < @as(c_int, @bitCast(@as(c_int, player.*.sprite.y)))) {
                                        if (@as(c_int, @bitCast(@as(c_int, level.*.enemy[@as(c_ushort, @intCast(i))].sprite.y))) <= (@as(c_int, @bitCast(@as(c_int, player.*.sprite.y))) - 10)) {
                                            continue;
                                        }
                                    } else {
                                        if (((@as(c_int, @bitCast(@as(c_int, level.*.enemy[@as(c_ushort, @intCast(i))].sprite.y))) - @as(c_int, @bitCast(@as(c_uint, level.*.enemy[@as(c_ushort, @intCast(i))].sprite.spritedata.*.collheight)))) - 1) >= @as(c_int, @bitCast(@as(c_int, player.*.sprite.y)))) {
                                            continue;
                                        }
                                    }
                                    if (@as(c_int, @bitCast(@as(c_int, level.*.enemy[@as(c_ushort, @intCast(i))].sprite.number))) >= 101) {
                                        diffX = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) - @as(c_int, @bitCast(@as(c_int, level.*.enemy[@as(c_ushort, @intCast(i))].sprite.x)))))));
                                        if (level.*.enemy[@as(c_ushort, @intCast(i))].sprite.flipped) {
                                            diffX = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_int, diffX)))))));
                                        }
                                        if (@as(c_int, @bitCast(@as(c_int, diffX))) < 0) {
                                            continue;
                                        }
                                    }
                                    c.playEvent_c(@as(c_uint, @bitCast(c.Event_PlayerPickupEnemy)));
                                    globals.FUME_FLAG = 0;
                                    level.*.enemy[@as(c_ushort, @intCast(i))].sprite.speed_y = 0;
                                    level.*.enemy[@as(c_ushort, @intCast(i))].sprite.speed_x = 0;
                                    globals.GRAVITY_FLAG = 4;
                                    player.*.sprite2.flipped = level.*.enemy[@as(c_ushort, @intCast(i))].sprite.flipped;
                                    player.*.sprite2.flash = level.*.enemy[@as(c_ushort, @intCast(i))].sprite.flash;
                                    player.*.sprite2.visible = level.*.enemy[@as(c_ushort, @intCast(i))].sprite.visible;
                                    c.updatesprite(level, &player.*.sprite2, level.*.enemy[@as(c_ushort, @intCast(i))].carry_sprite, false);
                                    level.*.enemy[@as(c_ushort, @intCast(i))].sprite.enabled = false;
                                    globals.CARRY_FLAG = true;
                                    globals.SEECHOC_FLAG = 0;
                                    player.*.sprite2.y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.y))) - 4))));
                                    if (player.*.sprite.flipped) {
                                        player.*.sprite2.x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) - 10))));
                                    } else {
                                        player.*.sprite2.x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) + 12))));
                                    }
                                    break;
                                }
                            }
                        }
                    }
                }
                globals.POSEREADY_FLAG = true;
                break;
            },
            8, 24 => {
                NEW_FORM(player, action);
                GET_IMAGE(level);
                DECELERATION(player);
                if (globals.CARRY_FLAG) {
                    if (@as(c_int, @bitCast(@as(c_int, player.*.y_axis))) >= 0) {
                        speed_x = @as(i16, @bitCast(@as(c_short, @truncate(14 * 16))));
                        speed_y = 0;
                        if (player.*.sprite.flipped) {
                            speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_int, speed_x)))))));
                        }
                        player.*.sprite2.y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.y))) - 16))));
                    } else {
                        speed_x = 0;
                        speed_y = @as(i16, @bitCast(@as(c_short, @truncate(0 - (10 * 16)))));
                    }
                    if (@as(c_int, @bitCast(@as(c_int, speed_y))) != 0) {
                        object = FORCE_POSE(level);
                        if (object != @as([*c]c.TITUS_object, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(0)))))) {
                            object.*.sprite.speed_y = speed_y;
                            object.*.sprite.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, speed_x))) - (@as(c_int, @bitCast(@as(c_int, speed_x))) >> @intCast(2))))));
                        }
                    } else {
                        if (@as(c_int, @bitCast(@as(c_int, player.*.sprite2.number))) < 101) {
                            if ((blk: {
                                const tmp = @as(c_int, @bitCast(@as(c_int, player.*.sprite2.number))) - c.FIRST_OBJET;
                                if (tmp >= 0) break :blk level.*.objectdata + @as(usize, @intCast(tmp)) else break :blk level.*.objectdata - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).*.gravity) {
                                object = FORCE_POSE(level);
                                if (object != @as([*c]c.TITUS_object, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(0)))))) {
                                    object.*.sprite.speed_y = speed_y;
                                    object.*.sprite.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, speed_x))) - (@as(c_int, @bitCast(@as(c_int, speed_x))) >> @intCast(2))))));
                                }
                            } else {
                                globals.DROP_FLAG = true;
                                player.*.sprite2.speed_x = speed_x;
                                player.*.sprite2.speed_y = speed_y;
                                c.playEvent_c(@as(c_uint, @bitCast(c.Event_PlayerThrow)));
                            }
                        } else {
                            globals.DROP_FLAG = true;
                            player.*.sprite2.speed_x = speed_x;
                            player.*.sprite2.speed_y = speed_y;
                            c.playEvent_c(@as(c_uint, @bitCast(c.Event_PlayerThrow)));
                        }
                    }
                    c.updatesprite(level, &player.*.sprite, @as(i16, @bitCast(@as(c_short, @truncate(10)))), true);
                    player.*.sprite.flipped = @as(c_int, @bitCast(@as(c_int, globals.SENSX))) < 0;
                    globals.CARRY_FLAG = false;
                }
                break;
            },
            10 => {
                XACCELERATION(player, @as(i16, @bitCast(@as(c_short, @truncate((4 - 1) * 16)))));
                NEW_FORM(player, action);
                GET_IMAGE(level);
                break;
            },
            11 => {
                player.*.sprite.speed_x = 0;
                NEW_FORM(player, action);
                GET_IMAGE(level);
                break;
            },
            12, 13, 28, 29 => {
                YACCELERATION(player, @as(i16, @bitCast(@as(c_short, @truncate(12 * 16)))));
                NEW_FORM(player, action);
                GET_IMAGE(level);
                break;
            },
            21 => {
                NEW_FORM(player, action);
                GET_IMAGE(level);
                DECELERATION(player);
                break;
            },
            27 => {
                _ = FORCE_POSE(level);
                player.*.sprite.speed_x = 0;
                NEW_FORM(player, action);
                GET_IMAGE(level);
                break;
            },
            else => {},
        }
        break;
    }
}

fn DECELERATION(player: *c.TITUS_player) void {
    // Stop acceleration
    const friction: u8 = @as(u8, 12) >> @truncate(player.GLISSE);
    var speed: i16 = 0;
    if (player.sprite.speed_x < 0) {
        speed = player.sprite.speed_x + friction;
        if (speed > 0) {
            speed = 0;
        }
    } else {
        speed = player.sprite.speed_x - friction;
        if (speed < 0) {
            speed = 0;
        }
    }
    player.sprite.speed_x = speed;
}

fn NEW_FORM(player: *c.TITUS_player, action: u8) void {
    // if the order is changed, change player animation
    if (globals.LAST_ORDER != action or player.sprite.animation == null) {
        globals.LAST_ORDER = action;
        player.sprite.animation = data.get_anim_player(action);
    }
}

fn GET_IMAGE(level: *c.TITUS_level) void {
    const player = &level.player;
    var frame: i16 = player.sprite.animation.*;
    if (@as(c_int, @bitCast(@as(c_int, frame))) < 0) {
        if (@as(c_int, @bitCast(@as(c_int, frame))) == -1) {
            std.log.err("Player frame is -1, advancing by {}\n", .{@divTrunc(@as(c_int, frame), 2)});
        }
        player.*.sprite.animation += @as(usize, @bitCast(@as(isize, @intCast(@divTrunc(@as(c_int, frame), 2)))));
        frame = player.*.sprite.animation.*;
    }
    c.updatesprite(level, &player.*.sprite, frame, true);
    player.*.sprite.flipped = @as(c_int, @bitCast(@as(c_int, globals.SENSX))) < 0;
    player.*.sprite.animation += 1;
}

fn YACCELERATION_NEG(player: *c.TITUS_player, maxspeed_in: i16) void {
    // Accelerate upwards
    const maxspeed = 0 - maxspeed_in;
    var speed: i16 = player.sprite.speed_y - 32;
    if (speed >= maxspeed) {
        speed = maxspeed;
    }
    player.sprite.speed_y = speed;
}

fn COLLISION_TRP(level: *c.TITUS_level) void {
    // Player versus elevators
    // Change player's location according to the elevator
    const player = &level.player;
    if (player.sprite.speed_y < 0 or globals.CROSS_FLAG != 0)
        return;

    for(&level.elevator) |*elevator| {
        if(!elevator.enabled or !elevator.sprite.visible)
            continue;
        if (
            (@abs(@as(c_int, @bitCast(@as(c_int, elevator.sprite.x))) - @as(c_int, @bitCast(@as(c_int, player.sprite.x)))) >= 64)
            or
            (@abs(@as(c_int, @bitCast(@as(c_int, elevator.sprite.y))) - @as(c_int, @bitCast(@as(c_int, player.sprite.y)))) >= 16)
        ) {
            continue;
        }
        if (player.sprite.x - level.spritedata[0].refwidth < elevator.sprite.x) { // The elevator is right
            if (player.sprite.x - level.spritedata[0].refwidth + level.spritedata[0].collwidth <= elevator.sprite.x) { // player->sprite must be 0
                continue; // The elevator is too far right
            }
        } else { // The elevator is left
            if (player.sprite.x - level.spritedata[0].refwidth >= elevator.sprite.x + elevator.sprite.spritedata.*.collwidth) {
                continue; // The elevator is too far left
            }
        }
        if (player.sprite.y - 6 < elevator.sprite.y) {// The elevator is below
            if ((player.sprite.y - 6 + 8) <= elevator.sprite.y) {
                continue; // The elevator is too far below
            }
        } else { // The elevator is above
            if (player.sprite.y - 6 >= elevator.sprite.y + elevator.sprite.spritedata.*.collheight) {
                continue; // The elevator is too far above
            }
        }

        // Skip fall-through-tile action (ACTION_TIMER == 15)
        if (globals.ACTION_TIMER == 14) {
            globals.ACTION_TIMER = 16;
        }

        globals.YFALL = 0;
        player.sprite.y = elevator.sprite.y;

        player.sprite.speed_y = 0;
        c.subto0(&globals.SAUT_FLAG);
        globals.SAUT_COUNT = 0;
        globals.YFALL = 2;

        player.sprite.x += elevator.sprite.speed_x;
        if (elevator.sprite.speed_y > 0) {
            // Going down
            player.sprite.y += elevator.sprite.speed_y;
        }
        return;
    }
}

fn COLLISION_OBJET(level: *c.TITUS_level) void {
    // Player versus objects
    // Collision, spring state, speed up carpet/scooter/skateboard, bounce bouncy
    // objects
    const player = &level.player;
    if (player.sprite.speed_y < 0) {
        return;
    }
    // Collision with a sprite
    var off_object_c: [*c]c.TITUS_object = undefined;
    if (!c.SPRITES_VS_SPRITES(level, &player.sprite, &level.spritedata[@as(c_uint, @intCast(0))], &off_object_c)) {
        return;
    }
    const off_object: *c.TITUS_object = off_object_c;
    player.sprite.y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, off_object.sprite.y))) - @as(c_int, @bitCast(@as(c_uint, off_object.sprite.spritedata.*.collheight)))))));
    if ((@as(c_int, @bitCast(@as(c_int, off_object.sprite.number))) == (c.FIRST_OBJET + 24)) or (@as(c_int, @bitCast(@as(c_int, off_object.sprite.number))) == (c.FIRST_OBJET + 25))) {
        off_object.sprite.UNDER = @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @bitCast(@as(c_uint, off_object.sprite.UNDER))) | 2))));
        off_object.sprite.ONTOP = &player.*.sprite;
    }
    if ((@as(c_int, @bitCast(@as(c_int, off_object.sprite.number))) == (c.FIRST_OBJET + 21)) or (@as(c_int, @bitCast(@as(c_int, off_object.sprite.number))) == (c.FIRST_OBJET + 22))) {
        if (!player.*.sprite.flipped) {
            off_object.sprite.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(6 * 16))));
        } else {
            off_object.sprite.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - (6 * 16)))));
        }
        off_object.sprite.flipped = player.*.sprite.flipped;
        globals.GRAVITY_FLAG = 4;
        globals.TAPISWAIT_FLAG = 0;
    } else if ((((@as(c_int, @bitCast(@as(c_uint, globals.ACTION_TIMER))) > 10) and ((@as(c_int, @bitCast(@as(c_uint, globals.LAST_ORDER))) & 15) == 0)) and (@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_y))) == 0)) and ((@as(c_int, @bitCast(@as(c_int, off_object.sprite.number))) == 83) or (@as(c_int, @bitCast(@as(c_int, off_object.sprite.number))) == 94))) {
        if (!player.*.sprite.flipped) {
            off_object.sprite.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(16 * 3))));
        } else {
            off_object.sprite.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - (16 * 3)))));
        }
        off_object.sprite.flipped = player.*.sprite.flipped;
        globals.GRAVITY_FLAG = 4;
    }
    if (@as(c_int, @bitCast(@as(c_int, off_object.sprite.speed_x))) < 0) {
        player.*.sprite.speed_x = off_object.sprite.speed_x;
    } else if (@as(c_int, @bitCast(@as(c_int, off_object.sprite.speed_x))) > 0) {
        player.*.sprite.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, off_object.sprite.speed_x))) + 16))));
    }
    if (((@as(c_int, @bitCast(@as(c_uint, globals.CROSS_FLAG))) == 0) and (@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_y))) > (16 * 3))) and (@as(c_int, @intFromBool(off_object.objectdata.*.bounce)) != 0)) {
        if (@as(c_int, @bitCast(@as(c_int, player.*.y_axis))) > 0) {
            player.*.sprite.speed_y = 0;
        } else {
            if (@as(c_int, @bitCast(@as(c_int, player.*.y_axis))) < 0) {
                player.*.sprite.speed_y += @as(i16, @bitCast(@as(c_short, @truncate(16 * 3))));
            } else {
                player.*.sprite.speed_y -= @as(i16, @bitCast(@as(c_short, @truncate(16))));
            }
            player.*.sprite.speed_y = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_y)))))));
            if (@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_y))) > 0) {
                player.*.sprite.speed_y = 0;
            }
        }
        globals.ACTION_TIMER = 0;
        if (@as(c_int, @bitCast(@as(c_int, off_object.sprite.speed_y))) == 0) {
            c.playEvent_c(@as(c_uint, @bitCast(c.Event_BallBounce)));
            off_object.sprite.speed_y = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_y)))))));
            off_object.sprite.y -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, off_object.sprite.speed_y))) >> @intCast(4)))));
            globals.GRAVITY_FLAG = 4;
        }
    } else {
        if (@as(c_int, @bitCast(@as(c_int, off_object.sprite.speed_y))) != 0) {
            player.*.sprite.speed_y = off_object.sprite.speed_y;
        } else {
            player.*.sprite.speed_y = 0;
        }
        c.subto0(&globals.SAUT_FLAG);
        globals.SAUT_COUNT = 0;
        globals.YFALL = 2;
    }
}
