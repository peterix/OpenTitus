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
    const context = arg_context;
    const level = arg_level;
    var retval: c_int = undefined;
    var newsensX: i8 = undefined;
    var event: SDL.Event = undefined;
    var newX: i16 = undefined;
    var newY: i16 = undefined;
    var pause: bool = false;
    SDL.pumpEvents();
    const keystate = SDL.getKeyboardState();
    const mods: SDL.Keymod = SDL.getModState();
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
    globals.X_FLAG = player.x_axis != 0;
    globals.Y_FLAG = player.y_axis != 0;
    if (globals.NOCLIP) {
        player.*.sprite.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.x_axis))) * @as(c_int, 100)))));
        player.*.sprite.speed_y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.y_axis))) * @as(c_int, 100)))));
        player.*.sprite.x += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_x))) >> @intCast(4)))));
        player.*.sprite.y += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_y))) >> @intCast(4)))));
        return 0;
    }
    var action: u8 = undefined;
    _ = &action;
    if (@as(c_int, @bitCast(@as(c_uint, globals.CHOC_FLAG))) != 0) {
        action = 11;
    } else if (@as(c_int, @bitCast(@as(c_uint, globals.KICK_FLAG))) != 0) {
        if (globals.GRANDBRULE_FLAG) {
            action = 13;
        } else {
            action = 12;
        }
    } else {
        globals.GRANDBRULE_FLAG = false;
        if (globals.LADDER_FLAG) {
            action = 6;
        } else if ((!globals.PRIER_FLAG and (@as(c_int, @bitCast(@as(c_int, player.*.y_axis))) < 0)) and (@as(c_int, @bitCast(@as(c_uint, globals.SAUT_FLAG))) == 0)) {
            action = 2;
            if (@as(c_int, @bitCast(@as(c_uint, globals.LAST_ORDER))) == @as(c_int, 5)) {
                globals.FURTIF_FLAG = 100;
            }
        } else if ((@as(c_int, @intFromBool(globals.PRIER_FLAG)) != 0) or ((@as(c_int, @bitCast(@as(c_uint, globals.SAUT_FLAG))) != @as(c_int, 6)) and (@as(c_int, @bitCast(@as(c_int, player.*.y_axis))) > 0))) {
            if (globals.X_FLAG) {
                action = 3;
            } else {
                action = 5;
            }
        } else if (globals.X_FLAG) {
            action = 1;
        } else {
            action = 0;
        }
        if ((@as(c_int, @intFromBool(player.*.action_pressed)) != 0) and !globals.PRIER_FLAG) {
            if (!globals.DROP_FLAG) {
                if ((@as(c_int, @bitCast(@as(c_uint, action))) == @as(c_int, 3)) or (@as(c_int, @bitCast(@as(c_uint, action))) == @as(c_int, 5))) {
                    globals.DROPREADY_FLAG = false;
                    action = 7;
                } else if ((@as(c_int, @intFromBool(globals.CARRY_FLAG)) != 0) and (@as(c_int, @intFromBool(globals.DROPREADY_FLAG)) != 0)) {
                    action = 8;
                }
            }
        } else {
            globals.DROPREADY_FLAG = true;
            globals.POSEREADY_FLAG = false;
        }
    }
    if (globals.CARRY_FLAG) {
        action +%= @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, 16)))));
    }
    if ((@as(c_int, @bitCast(@as(c_uint, globals.CHOC_FLAG))) != 0) or (@as(c_int, @bitCast(@as(c_uint, globals.KICK_FLAG))) != 0)) {
        if (@as(c_int, @bitCast(@as(c_int, globals.SENSX))) < 0) {
            newsensX = @as(i8, @bitCast(@as(i8, @truncate(-@as(c_int, 1)))));
        } else {
            newsensX = 0;
        }
    } else if (@as(c_int, @bitCast(@as(c_int, player.*.x_axis))) != 0) {
        newsensX = player.*.x_axis;
    } else if (@as(c_int, @bitCast(@as(c_int, globals.SENSX))) == -@as(c_int, 1)) {
        newsensX = @as(i8, @bitCast(@as(i8, @truncate(-@as(c_int, 1)))));
    } else if (@as(c_int, @bitCast(@as(c_uint, action))) == 0) {
        newsensX = 0;
    } else {
        newsensX = 1;
    }
    if (@as(c_int, @bitCast(@as(c_int, globals.SENSX))) != @as(c_int, @bitCast(@as(c_int, newsensX)))) {
        globals.SENSX = newsensX;
        globals.ACTION_TIMER = 1;
    } else {
        if (((@as(c_int, @bitCast(@as(c_uint, action))) == 0) or (@as(c_int, @bitCast(@as(c_uint, action))) == @as(c_int, 1))) and (@as(c_int, @bitCast(@as(c_uint, globals.FURTIF_FLAG))) != 0)) {
            action +%= @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, 9)))));
        }
        if (@as(c_int, @bitCast(@as(c_uint, action))) != @as(c_int, @bitCast(@as(c_uint, globals.LAST_ORDER)))) {
            globals.ACTION_TIMER = 1;
        } else if (@as(c_int, @bitCast(@as(c_uint, globals.ACTION_TIMER))) < @as(c_int, 255)) {
            globals.ACTION_TIMER +%= @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, 1)))));
        }
    }
    ACTION_PRG(level, action);
    if (((@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_x))) < 0) and ((@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) + (@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_x))) >> @intCast(4))) >= @as(c_int, 8))) or ((@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_x))) > 0) and ((@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) + (@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_x))) >> @intCast(4))) <= ((@as(c_int, @bitCast(@as(c_int, level.*.width))) << @intCast(4)) - @as(c_int, 8))))) {
        player.*.sprite.x += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_x))) >> @intCast(4)))));
    }
    player.*.sprite.y += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_y))) >> @intCast(4)))));
    BRK_COLLISION(context, level);
    if (globals.DROP_FLAG) {
        newX = @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_int, player.*.sprite2.speed_x))) >> @intCast(4)) + @as(c_int, @bitCast(@as(c_int, player.*.sprite2.x)))))));
        if ((((@as(c_int, @bitCast(@as(c_int, newX))) < (@as(c_int, @bitCast(@as(c_int, level.*.width))) << @intCast(4))) and (@as(c_int, @bitCast(@as(c_int, newX))) >= 0)) and (@as(c_int, @bitCast(@as(c_int, newX))) >= ((@as(c_int, @bitCast(@as(c_int, globals.BITMAP_X))) << @intCast(4)) - @as(c_int, 40)))) and (@as(c_int, @bitCast(@as(c_int, newX))) <= (((@as(c_int, @bitCast(@as(c_int, globals.BITMAP_X))) << @intCast(4)) + (@as(c_int, 20) << @intCast(4))) + @as(c_int, 40)))) {
            player.*.sprite2.x = newX;
            newY = @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_int, player.*.sprite2.speed_y))) >> @intCast(4)) + @as(c_int, @bitCast(@as(c_int, player.*.sprite2.y)))))));
            if ((((@as(c_int, @bitCast(@as(c_int, newY))) < (@as(c_int, @bitCast(@as(c_int, level.*.height))) << @intCast(4))) and (@as(c_int, @bitCast(@as(c_int, newY))) >= 0)) and (@as(c_int, @bitCast(@as(c_int, newY))) >= ((@as(c_int, @bitCast(@as(c_int, globals.BITMAP_Y))) << @intCast(4)) - @as(c_int, 20)))) and (@as(c_int, @bitCast(@as(c_int, newY))) <= (((@as(c_int, @bitCast(@as(c_int, globals.BITMAP_Y))) << @intCast(4)) + (@as(c_int, 12) << @intCast(4))) + @as(c_int, 20)))) {
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
        if (!globals.LADDER_FLAG and ((@as(c_int, @bitCast(@as(c_uint, globals.LAST_ORDER))) == (@as(c_int, 16) + @as(c_int, 5))) or (@as(c_int, @bitCast(@as(c_uint, globals.LAST_ORDER))) == (@as(c_int, 16) + @as(c_int, 7))))) {
            player.*.sprite2.y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.y))) - @as(c_int, 4)))));
            if (player.*.sprite.flipped) {
                player.*.sprite2.x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) - @as(c_int, 10)))));
            } else {
                player.*.sprite2.x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) + @as(c_int, 12)))));
            }
        } else {
            if ((@as(c_int, @bitCast(@as(c_int, player.*.sprite.number))) == @as(c_int, 14)) or (((@as(c_int, @bitCast(@as(c_uint, globals.LAST_ORDER))) & @as(c_int, 15)) != @as(c_int, 7)) and ((@as(c_int, @bitCast(@as(c_uint, globals.LAST_ORDER))) & @as(c_int, 15)) != @as(c_int, 8)))) {
                player.*.sprite2.x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) + @as(c_int, 2)))));
                if ((@as(c_int, @bitCast(@as(c_int, player.*.sprite.number))) == @as(c_int, 23)) or (@as(c_int, @bitCast(@as(c_int, player.*.sprite.number))) == @as(c_int, 24))) {
                    player.*.sprite2.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 10)))));
                    if (player.*.sprite.flipped) {
                        player.*.sprite2.x += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 18)))));
                    }
                }
                player.*.sprite2.y = @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_int, player.*.sprite.y))) - @as(c_int, @bitCast(@as(c_uint, player.*.sprite.spritedata.*.collheight)))) + @as(c_int, 1)))));
            }
        }
    }
    if (@as(c_int, @bitCast(@as(c_uint, globals.SEECHOC_FLAG))) != 0) {
        globals.SEECHOC_FLAG -%= 1;
        if (@as(c_int, @bitCast(@as(c_uint, globals.SEECHOC_FLAG))) == 0) {
            player.*.sprite2.enabled = false;
        }
    }
    c.subto0(&globals.INVULNERABLE_FLAG);
    c.subto0(&globals.RESETLEVEL_FLAG);
    c.subto0(&globals.TAPISFLY_FLAG);
    c.subto0(&globals.CROSS_FLAG);
    c.subto0(&globals.GRAVITY_FLAG);
    c.subto0(&globals.FURTIF_FLAG);
    c.subto0(&globals.KICK_FLAG);
    if (player.*.sprite.speed_y == 0) {
        c.subto0(&globals.CHOC_FLAG);
    }
    if (player.*.sprite.speed_x == 0 and player.*.sprite.speed_y == 0) {
        globals.KICK_FLAG = 0;
    }
    c.subto0(&globals.FUME_FLAG);
    if ((@as(c_int, @bitCast(@as(c_uint, globals.FUME_FLAG))) != 0) and ((@as(c_int, @bitCast(@as(c_uint, globals.FUME_FLAG))) & @as(c_int, 3)) == 0)) {
        c.updatesprite(level, &player.*.sprite2, @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite2.number))) + @as(c_int, 1))))), false);
        if (@as(c_int, @bitCast(@as(c_int, player.*.sprite2.number))) == (@as(c_int, 30) + @as(c_int, 19))) {
            player.*.sprite2.enabled = false;
            globals.FUME_FLAG = 0;
        }
    }
    return 0;
}

fn DEC_LIFE(level: [*c]c.TITUS_level) void {
    globals.RESETLEVEL_FLAG = 10;
    globals.BAR_FLAG = 0;
    if (level.*.lives == 0) {
        globals.GAMEOVER_FLAG = true;
    } else {
        globals.LOSELIFE_FLAG = true;
    }
}

fn CASE_DEAD_IM(level: [*c]c.TITUS_level) void {
    DEC_LIFE(level);
    globals.RESETLEVEL_FLAG = 2;
}

fn BRK_COLLISION(context: [*c]c.ScreenContext, level: [*c]c.TITUS_level) void {
    const player: [*c]c.TITUS_player = &level.*.player;
    var changeX: i16 = undefined;
    var height: i16 = undefined;
    var initY: i16 = undefined;
    var tileX: u8 = undefined;
    var tileY: i16 = undefined;
    var colltest: i16 = undefined;
    var left_tileX: u8 = undefined;
    var first: bool = undefined;
    var hflag: c.enum_HFLAG = undefined;
    tileX = @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) >> @intCast(4)))));
    tileY = @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_int, player.*.sprite.y))) >> @intCast(4)) - @as(c_int, 1)))));
    initY = tileY;
    if ((@as(c_int, @bitCast(@as(c_int, player.*.sprite.y))) > ((@as(c_int, @bitCast(@as(c_int, level.*.height))) + @as(c_int, 1)) << @intCast(4))) and !globals.NOCLIP) {
        CASE_DEAD_IM(level);
    }
    globals.YFALL = 0;
    colltest = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) & @as(c_int, 15)))));
    if (@as(c_int, @bitCast(@as(c_int, colltest))) < @as(c_int, 4)) {
        colltest += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 256)))));
        tileX -%= 1;
    }
    colltest -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 4)))));
    left_tileX = tileX;
    TAKE_BLK_AND_YTEST(context, level, tileY, tileX);
    if (@as(c_int, @bitCast(@as(c_uint, globals.YFALL))) == @as(c_int, 1)) {
        colltest += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 4) * @as(c_int, 2)))));
        if (@as(c_int, @bitCast(@as(c_int, colltest))) > @as(c_int, 15)) {
            tileX +%= 1;
        }
        if (@as(c_int, @bitCast(@as(c_uint, tileX))) != @as(c_int, @bitCast(@as(c_uint, left_tileX)))) {
            TAKE_BLK_AND_YTEST(context, level, tileY, tileX);
        }
        if (@as(c_int, @bitCast(@as(c_uint, globals.YFALL))) == @as(c_int, 1)) {
            if ((@as(c_int, @bitCast(@as(c_uint, globals.CROSS_FLAG))) == 0) and (@as(c_int, @bitCast(@as(c_uint, globals.CHOC_FLAG))) == 0)) {
                COLLISION_TRP(level);
                if (@as(c_int, @bitCast(@as(c_uint, globals.YFALL))) == @as(c_int, 1)) {
                    COLLISION_OBJET(level);
                    if (@as(c_int, @bitCast(@as(c_uint, globals.YFALL))) == @as(c_int, 1)) {
                        ARAB_TOMBE(level);
                    } else {
                        player.*.GLISSE = 0;
                    }
                }
            } else {
                ARAB_TOMBE(level);
            }
        }
    }
    changeX = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 4) + @as(c_int, 4)))));
    if (@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_x))) < 0) {
        changeX = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_int, changeX)))))));
    } else if (@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_x))) == 0) {
        changeX = 0;
    }
    height = @as(i16, @bitCast(@as(c_ushort, player.*.sprite.spritedata.*.collheight)));
    if (((@as(c_int, @bitCast(@as(c_int, player.*.sprite.y))) > (-@as(c_int, 1) + @as(c_int, 1))) and (@as(c_int, @bitCast(@as(c_int, initY))) >= 0)) and (@as(c_int, @bitCast(@as(c_int, initY))) < @as(c_int, @bitCast(@as(c_int, level.*.height))))) {
        tileX = @as(u8, @bitCast(@as(i8, @truncate((@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) + @as(c_int, @bitCast(@as(c_int, changeX)))) >> @intCast(4)))));
        tileY = initY;
        first = true;
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
            height -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 16)))));
            if (!(@as(c_int, @bitCast(@as(c_int, height))) > 0)) break;
        }
    }
}

fn TAKE_BLK_AND_YTEST(context: [*c]c.ScreenContext, level: [*c]c.TITUS_level, tileY_in: i16, tileX_in: u8) void {
    var tileY = tileY_in;
    var tileX = tileX_in;
    const player = &level.*.player;
    globals.POCKET_FLAG = false;
    globals.PRIER_FLAG = false;
    globals.LADDER_FLAG = false;
    var change: i8 = undefined;
    _ = &change;
    if ((@as(c_int, @bitCast(@as(c_int, player.*.sprite.y))) <= -@as(c_int, 1)) or (@as(c_int, @bitCast(@as(c_int, tileY))) < -@as(c_int, 1))) {
        ARAB_TOMBE(level);
        globals.YFALL = 255;
        return;
    }
    if ((@as(c_int, @bitCast(@as(c_int, tileY))) + @as(c_int, 1)) >= @as(c_int, @bitCast(@as(c_int, level.*.height)))) {
        ARAB_TOMBE(level);
        globals.YFALL = 255;
        return;
    }
    if (@as(c_int, @bitCast(@as(c_int, tileY))) == -@as(c_int, 1)) {
        tileY = 0;
    }
    var floor_1: c.enum_FFLAG = c.get_floorflag(level, @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, tileY))) + @as(c_int, 1))))), @as(i16, @bitCast(@as(c_ushort, tileX))));
    _ = &floor_1;
    var floor_above: c.enum_FFLAG = c.get_floorflag(level, tileY, @as(i16, @bitCast(@as(c_ushort, tileX))));
    _ = &floor_above;
    if ((@as(c_int, @bitCast(@as(c_uint, globals.LAST_ORDER))) & @as(c_int, 15)) != @as(c_int, 2)) {
        BLOCK_YYPRG(context, level, floor_1, floor_above, @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @bitCast(@as(c_int, tileY))) + @as(c_int, 1))))), tileX);
    }
    if ((@as(c_int, @bitCast(@as(c_int, tileY))) < @as(c_int, 1)) or (@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_y))) > 0)) {
        return;
    }
    var cflag: c.enum_CFLAG = c.get_ceilflag(level, @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, tileY))) - @as(c_int, 1))))), @as(i16, @bitCast(@as(c_ushort, tileX))));
    _ = &cflag;
    BLOCK_YYPRGD(level, cflag, @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @bitCast(@as(c_int, tileY))) - @as(c_int, 1))))), tileX);
    var horiz: c.enum_HFLAG = c.get_horizflag(level, tileY, @as(i16, @bitCast(@as(c_ushort, tileX))));
    _ = &horiz;
    if ((((@as(c_int, @bitCast(@as(c_uint, horiz))) == @as(c_int, @bitCast(@as(c_uint, c.HFLAG_WALL)))) or (@as(c_int, @bitCast(@as(c_uint, horiz))) == @as(c_int, @bitCast(@as(c_uint, c.HFLAG_DEADLY))))) or (@as(c_int, @bitCast(@as(c_uint, horiz))) == @as(c_int, @bitCast(@as(c_uint, c.HFLAG_PADLOCK))))) and (@as(c_int, @bitCast(@as(c_int, player.*.sprite.y))) > (-@as(c_int, 1) + @as(c_int, 1)))) {
        if (@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_x))) > 0) {
            change = @as(i8, @bitCast(@as(i8, @truncate(-@as(c_int, 1)))));
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
                    player.*.sprite.y = @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_int, player.*.sprite.y))) & @as(c_int, 65520)) + @as(c_int, 16)))));
                    globals.SAUT_COUNT = 255;
                } else if (((@as(c_int, @bitCast(@as(c_int, player.*.sprite.number))) != @as(c_int, 10)) and (@as(c_int, @bitCast(@as(c_int, player.*.sprite.number))) != @as(c_int, 21))) and (@as(c_int, @bitCast(@as(c_uint, globals.SAUT_FLAG))) != @as(c_int, 6))) {
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
                                    object.*.sprite.x += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 16)))));
                                } else {
                                    object.*.sprite.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 16)))));
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
                CASE_PASS(context, level, @as(u8, @bitCast(@as(u8, @truncate(level.*.levelnumber)))), tileY, tileX);
                break;
            },
            @as(c_int, @bitCast(@as(c_uint, @as(u8, 5)))) => {
                CASE_SECU(level, tileY, tileX);
                break;
            },
            @as(c_int, @bitCast(@as(c_uint, @as(u8, 6)))) => {
                CASE_PASS(context, level, @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, 14) - @as(c_int, 1))))), tileY, tileX);
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
    if ((@as(c_int, @bitCast(@as(c_uint, globals.KICK_FLAG))) != 0) and (@as(c_int, @bitCast(@as(c_uint, globals.SAUT_FLAG))) != @as(c_int, 6))) {
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
            if (@as(c_int, @bitCast(@as(c_int, i))) > @as(c_int, 40)) {
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
        if (@as(c_int, @bitCast(@as(c_int, object.*.sprite.number))) < @as(c_int, 101)) {
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

fn ARAB_TOMBE(arg_level: [*c]c.TITUS_level) void {
    var level = arg_level;
    _ = &level;
    var player: [*c]c.TITUS_player = &level.*.player;
    _ = &player;
    globals.SAUT_FLAG = 6;
    if (@as(c_int, @bitCast(@as(c_uint, globals.KICK_FLAG))) != 0) {
        return;
    }
    XACCELERATION(player, @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 4) * @as(c_int, 16))))));
    YACCELERATION(player, @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 12) * @as(c_int, 16))))));
    if (@as(c_int, @bitCast(@as(c_uint, globals.CHOC_FLAG))) != 0) {
        c.updatesprite(level, &player.*.sprite, @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 15))))), true);
    } else if (@as(c_int, @intFromBool(globals.CARRY_FLAG)) == 0) {
        c.updatesprite(level, &player.*.sprite, @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 10))))), true);
    } else {
        c.updatesprite(level, &player.*.sprite, @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 21))))), true);
    }
    player.*.sprite.flipped = @as(c_int, @bitCast(@as(c_int, globals.SENSX))) < 0;
}

fn XACCELERATION(arg_player: [*c]c.TITUS_player, arg_maxspeed: i16) void {
    var player = arg_player;
    _ = &player;
    var maxspeed = arg_maxspeed;
    _ = &maxspeed;
    var changeX: i16 = undefined;
    _ = &changeX;
    if (globals.X_FLAG) {
        changeX = @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_int, globals.SENSX))) << @intCast(4)) >> @intCast(@as(c_int, @bitCast(@as(c_uint, player.*.GLISSE))))))));
    } else {
        changeX = 0;
    }
    if ((@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_x))) + @as(c_int, @bitCast(@as(c_int, changeX)))) >= @as(c_int, @bitCast(@as(c_int, maxspeed)))) {
        player.*.sprite.speed_x = maxspeed;
    } else if ((@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_x))) + @as(c_int, @bitCast(@as(c_int, changeX)))) <= (0 - @as(c_int, @bitCast(@as(c_int, maxspeed))))) {
        player.*.sprite.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_int, maxspeed)))))));
    } else {
        player.*.sprite.speed_x += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, changeX)))))));
    }
}

fn YACCELERATION(arg_player: [*c]c.TITUS_player, arg_maxspeed: i16) void {
    var player = arg_player;
    _ = &player;
    var maxspeed = arg_maxspeed;
    _ = &maxspeed;
    if ((@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_y))) + @divTrunc(@as(c_int, 32), @as(c_int, 2))) < @as(c_int, @bitCast(@as(c_int, maxspeed)))) {
        player.*.sprite.speed_y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_y))) + @divTrunc(@as(c_int, 32), @as(c_int, 2))))));
    } else {
        player.*.sprite.speed_y = maxspeed;
    }
}

fn BLOCK_YYPRG(arg_context: [*c]c.ScreenContext, arg_level: [*c]c.TITUS_level, arg_floor_1: c.enum_FFLAG, arg_floor_above: c.enum_FFLAG, arg_tileY: u8, arg_tileX: u8) void {
    var context = arg_context;
    _ = &context;
    var level = arg_level;
    _ = &level;
    var floor_1 = arg_floor_1;
    _ = &floor_1;
    var floor_above = arg_floor_above;
    _ = &floor_above;
    var tileY = arg_tileY;
    _ = &tileY;
    var tileX = arg_tileX;
    _ = &tileX;
    var player: [*c]c.TITUS_player = &level.*.player;
    _ = &player;
    var order: u8 = undefined;
    _ = &order;
    while (true) {
        switch (@as(c_int, @bitCast(@as(c_uint, floor_1)))) {
            @as(c_int, @bitCast(@as(c_uint, @as(u8, 0)))) => {
                ARAB_TOMBE_F();
                break;
            },
            @as(c_int, @bitCast(@as(c_uint, @as(u8, 1)))) => {
                ARAB_BLOCK_YU(player);
                break;
            },
            @as(c_int, @bitCast(@as(c_uint, @as(u8, 2)))) => {
                ARAB_BLOCK_YU(player);
                player.*.GLISSE = 1;
                break;
            },
            @as(c_int, @bitCast(@as(c_uint, @as(u8, 3)))) => {
                ARAB_BLOCK_YU(player);
                player.*.GLISSE = 2;
                break;
            },
            @as(c_int, @bitCast(@as(c_uint, @as(u8, 4)))) => {
                ARAB_BLOCK_YU(player);
                player.*.GLISSE = 3;
                break;
            },
            @as(c_int, @bitCast(@as(c_uint, @as(u8, 5)))) => {
                player.*.GLISSE = 0;
                if (@as(c_int, @bitCast(@as(c_uint, globals.CROSS_FLAG))) == 0) {
                    ARAB_BLOCK_YU(player);
                } else {
                    ARAB_TOMBE_F();
                }
                break;
            },
            @as(c_int, @bitCast(@as(c_uint, @as(u8, 6)))) => {
                if (@as(c_int, @bitCast(@as(c_uint, globals.CHOC_FLAG))) != 0) {
                    ARAB_TOMBE_F();
                    return;
                }
                order = @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @bitCast(@as(c_uint, globals.LAST_ORDER))) & @as(c_int, 15)))));
                if ((((@as(c_int, @bitCast(@as(c_uint, order))) == @as(c_int, 1)) or (@as(c_int, @bitCast(@as(c_uint, order))) == @as(c_int, 3))) or (@as(c_int, @bitCast(@as(c_uint, order))) == @as(c_int, 7))) or (@as(c_int, @bitCast(@as(c_uint, order))) == @as(c_int, 8))) {
                    ARAB_BLOCK_YU(player);
                    return;
                }
                if (@as(c_int, @bitCast(@as(c_uint, order))) == @as(c_int, 5)) {
                    ARAB_TOMBE_F();
                    c.updatesprite(level, &player.*.sprite, @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 14))))), true);
                    player.*.sprite.y += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 8)))));
                }
                if (@as(c_int, @bitCast(@as(c_uint, floor_above))) != @as(c_int, 6)) {
                    if (@as(c_int, @bitCast(@as(c_uint, order))) == 0) {
                        ARAB_BLOCK_YU(player);
                        return;
                    }
                    if ((@as(c_int, @bitCast(@as(c_int, player.*.y_axis))) < 0) and (@as(c_int, @bitCast(@as(c_uint, order))) == @as(c_int, 6))) {
                        ARAB_BLOCK_YU(player);
                        return;
                    }
                }
                c.subto0(&globals.SAUT_FLAG);
                globals.SAUT_COUNT = 0;
                globals.YFALL = 2;
                globals.LADDER_FLAG = true;
                break;
            },
            @as(c_int, @bitCast(@as(c_uint, @as(u8, 7)))) => {
                _ = CASE_BONUS(level, tileY, tileX);
                break;
            },
            @as(c_int, @bitCast(@as(c_uint, @as(u8, 8)))), @as(c_int, @bitCast(@as(c_uint, @as(u8, 9)))), @as(c_int, @bitCast(@as(c_uint, @as(u8, 10)))) => {
                if (!globals.GODMODE) {
                    CASE_DEAD_IM(level);
                } else {
                    ARAB_BLOCK_YU(player);
                }
                break;
            },
            @as(c_int, @bitCast(@as(c_uint, @as(u8, 11)))) => {
                CASE_PASS(context, level, @as(u8, @bitCast(@as(u8, @truncate(level.*.levelnumber)))), tileY, tileX);
                break;
            },
            @as(c_int, @bitCast(@as(c_uint, @as(u8, 12)))) => {
                CASE_SECU(level, tileY, tileX);
                break;
            },
            @as(c_int, @bitCast(@as(c_uint, @as(u8, 13)))) => {
                CASE_PASS(context, level, @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, 14) - @as(c_int, 1))))), tileY, tileX);
                break;
            },
            else => {},
        }
        break;
    }
}

fn ARAB_TOMBE_F() void {
    globals.YFALL = @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @bitCast(@as(c_uint, globals.YFALL))) | @as(c_int, 1)))));
}

fn ARAB_BLOCK_YU(arg_player: [*c]c.TITUS_player) void {
    var player = arg_player;
    _ = &player;
    globals.POCKET_FLAG = true;
    player.*.GLISSE = 0;
    if (@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_y))) < 0) {
        globals.YFALL = @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @bitCast(@as(c_uint, globals.YFALL))) | @as(c_int, 1)))));
        return;
    }
    player.*.sprite.y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.y))) & @as(c_int, 65520)))));
    player.*.sprite.speed_y = 0;
    c.subto0(&globals.SAUT_FLAG);
    globals.SAUT_COUNT = 0;
    globals.YFALL = 2;
}

fn CASE_BONUS(arg_level: [*c]c.TITUS_level, tileY: u8, tileX: u8) c_int {
    var level = arg_level;
    _ = &level;
    var i: u16 = 0;
    while (true) {
        if (@as(c_int, @bitCast(@as(c_uint, i))) >= @as(c_int, 100)) {
            return 0;
        }
        i +%= 1;
        if (!((@as(c_int, @bitCast(@as(c_uint, level.*.bonus[@as(c_uint, @intCast(@as(c_int, @bitCast(@as(c_uint, i))) - @as(c_int, 1)))].x))) != @as(c_int, @bitCast(@as(c_uint, tileX)))) or (@as(c_int, @bitCast(@as(c_uint, level.*.bonus[@as(c_uint, @intCast(@as(c_int, @bitCast(@as(c_uint, i))) - @as(c_int, 1)))].y))) != @as(c_int, @bitCast(@as(c_uint, tileY)))))) break;
    }
    i -%= 1;
    if (@as(c_int, @bitCast(@as(c_uint, level.*.bonus[i].bonustile))) >= (@as(c_int, 255) - @as(c_int, 2))) {
        level.*.bonuscollected +%= @as(usize, @bitCast(@as(c_long, @as(c_int, 1))));
        c.playEvent_c(@as(c_uint, @bitCast(c.Event_PlayerCollectBonus)));
        INC_ENERGY(level);
    }
    c.set_tile(level, tileY, tileX, level.*.bonus[i].replacetile);
    globals.GRAVITY_FLAG = 4;
    return 1;
}

fn CASE_PASS(arg_context: [*c]c.ScreenContext, arg_level: [*c]c.TITUS_level, arg_level_index: u8, arg_tileY: u8, arg_tileX: u8) void {
    var context = arg_context;
    _ = &context;
    var level = arg_level;
    _ = &level;
    var level_index = arg_level_index;
    _ = &level_index;
    var tileY = arg_tileY;
    _ = &tileY;
    var tileX = arg_tileX;
    _ = &tileX;
    if (CASE_BONUS(level, tileY, tileX) != 0) {
        c.playEvent_c(@as(c_uint, @bitCast(c.Event_PlayerCollectLamp)));
    }
}

fn CASE_SECU(level: [*c]c.TITUS_level, tileY: u8, tileX: u8) void {
    const player: [*c]c.TITUS_player = &level.*.player;
    if (CASE_BONUS(level, tileY, tileX) != 0) {
        c.playEvent_c(@as(c_uint, @bitCast(c.Event_PlayerCollectWaypoint)));
        player.*.initX = player.*.sprite.x;
        player.*.initY = player.*.sprite.y;
        if ((@as(c_int, @bitCast(@as(c_int, player.*.sprite2.number))) == (@as(c_int, 30) + @as(c_int, 26))) or (@as(c_int, @bitCast(@as(c_int, player.*.sprite2.number))) == (@as(c_int, 30) + @as(c_int, 27)))) {
            player.*.cageX = player.*.sprite.x;
            player.*.cageY = player.*.sprite.y;
        }
    }
}

fn INC_ENERGY(level: [*c]c.TITUS_level) void {
    const player: [*c]c.TITUS_player = &level.*.player;
    globals.BAR_FLAG = 50;
    if (@as(c_int, @bitCast(@as(c_uint, player.*.hp))) == @as(c_int, 16)) {
        level.*.extrabonus += @as(c_int, 1);
    } else {
        player.*.hp +%= 1;
    }
}

pub export fn DEC_ENERGY(arg_level: [*c]c.TITUS_level) void {
    var level = arg_level;
    _ = &level;
    var player: [*c]c.TITUS_player = &level.*.player;
    _ = &player;
    c.BAR_FLAG = 50;
    if (@as(c_int, @bitCast(@as(c_uint, c.RESETLEVEL_FLAG))) == 0) {
        if (@as(c_int, @bitCast(@as(c_uint, player.*.hp))) > 0) {
            player.*.hp -%= 1;
        }
        if (@as(c_int, @bitCast(@as(c_uint, player.*.hp))) == 0) {
            DEC_LIFE(level);
        }
    }
}

fn ACTION_PRG(arg_level: [*c]c.TITUS_level, arg_action: u8) callconv(.C) void {
    var level = arg_level;
    _ = &level;
    var action = arg_action;
    _ = &action;
    var player: [*c]c.TITUS_player = &level.*.player;
    _ = &player;
    var tileX: u8 = undefined;
    _ = &tileX;
    var tileY: u8 = undefined;
    _ = &tileY;
    var fflag: u8 = undefined;
    _ = &fflag;
    var object: [*c]c.TITUS_object = undefined;
    _ = &object;
    var i: i16 = undefined;
    _ = &i;
    var diffX: i16 = undefined;
    _ = &diffX;
    var speed_x: i16 = undefined;
    _ = &speed_x;
    var speed_y: i16 = undefined;
    _ = &speed_y;
    while (true) {
        switch (action) {
            0, @as(c_int, 9), @as(c_int, 16) => {
                globals.LAST_ORDER = action;
                DECELERATION(player);
                if ((c.abs(@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_x)))) >= (@as(c_int, 1) * @as(c_int, 16))) and (@as(c_int, @intFromBool(player.*.sprite.flipped)) == @intFromBool(@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_x))) < 0))) {
                    player.*.sprite.animation = data.get_anim_player(@as(u8, @bitCast(@as(i8, @truncate(@as(c_int, 4) + @as(c_int, @bitCast(@as(c_uint, add_carry()))))))));
                } else {
                    player.*.sprite.animation = data.get_anim_player(action);
                }
                c.updatesprite(level, &player.*.sprite, player.*.sprite.animation.*, true);
                player.*.sprite.flipped = @as(c_int, @bitCast(@as(c_int, globals.SENSX))) < 0;
                break;
            },
            @as(c_int, 1), @as(c_int, 17), @as(c_int, 19) => {
                XACCELERATION(player, @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 4) * @as(c_int, 16))))));
                NEW_FORM(player, action);
                GET_IMAGE(level);
                break;
            },
            @as(c_int, 2), @as(c_int, 18) => {
                if (@as(c_int, @bitCast(@as(c_uint, globals.SAUT_COUNT))) >= @as(c_int, 3)) {
                    globals.SAUT_FLAG = 6;
                } else {
                    globals.SAUT_COUNT +%= 1;
                    YACCELERATION_NEG(player, @as(i16, @bitCast(@as(c_short, @truncate(@divTrunc(@as(c_int, 12) * @as(c_int, 16), @as(c_int, 4)))))));
                    XACCELERATION(player, @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 4) * @as(c_int, 16))))));
                    NEW_FORM(player, action);
                    GET_IMAGE(level);
                }
                break;
            },
            @as(c_int, 3) => {
                NEW_FORM(player, action);
                GET_IMAGE(level);
                XACCELERATION(player, @as(i16, @bitCast(@as(c_short, @truncate(@divTrunc(@as(c_int, 4) * @as(c_int, 16), @as(c_int, 2)))))));
                if (c.abs(@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_x)))) < (@as(c_int, 2) * @as(c_int, 16))) {
                    c.updatesprite(level, &player.*.sprite, @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 6))))), true);
                    player.*.sprite.flipped = @as(c_int, @bitCast(@as(c_int, globals.SENSX))) < 0;
                }
                break;
            },
            @as(c_int, 4), @as(c_int, 14), @as(c_int, 15), @as(c_int, 20), @as(c_int, 25), @as(c_int, 26) => break,
            @as(c_int, 5) => {
                NEW_FORM(player, action);
                GET_IMAGE(level);
                DECELERATION(player);
                if (@as(c_int, @bitCast(@as(c_uint, globals.ACTION_TIMER))) == @as(c_int, 15)) {
                    globals.CROSS_FLAG = 6;
                    player.*.sprite.speed_y = 0;
                }
                break;
            },
            @as(c_int, 6), @as(c_int, 22) => {
                if (@as(c_int, @intFromBool(globals.X_FLAG)) != 0) {
                    XACCELERATION(player, @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 4) * @as(c_int, 16))))));
                } else {
                    DECELERATION(player);
                }
                if (@as(c_int, @bitCast(@as(c_uint, globals.ACTION_TIMER))) <= @as(c_int, 1)) {
                    if (@as(c_int, @intFromBool(globals.CARRY_FLAG)) == 0) {
                        c.updatesprite(level, &player.*.sprite, @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 12))))), true);
                    } else {
                        c.updatesprite(level, &player.*.sprite, @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 23))))), true);
                    }
                }
                if (@as(c_int, @intFromBool(globals.Y_FLAG)) != 0) {
                    NEW_FORM(player, @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, 6) + @as(c_int, @bitCast(@as(c_uint, add_carry()))))))));
                    GET_IMAGE(level);
                    player.*.sprite.x = @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) & @as(c_int, 65520)) + @as(c_int, 8)))));
                    tileX = @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) >> @intCast(4)))));
                    tileY = @as(u8, @bitCast(@as(i8, @truncate((@as(c_int, @bitCast(@as(c_int, player.*.sprite.y))) & @as(c_int, 65520)) >> @intCast(4)))));
                    if (@as(c_int, @bitCast(@as(c_uint, c.get_floorflag(level, @as(i16, @bitCast(@as(c_ushort, tileY))), @as(i16, @bitCast(@as(c_ushort, tileX))))))) != @as(c_int, @bitCast(@as(c_uint, c.FFLAG_LADDER)))) {
                        if (@as(c_int, @bitCast(@as(c_uint, c.get_floorflag(level, @as(i16, @bitCast(@as(c_ushort, tileY))), @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_uint, tileX))) - @as(c_int, 1))))))))) == @as(c_int, @bitCast(@as(c_uint, c.FFLAG_LADDER)))) {
                            player.*.sprite.x -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 16)))));
                        } else if (@as(c_int, @bitCast(@as(c_uint, c.get_floorflag(level, @as(i16, @bitCast(@as(c_ushort, tileY))), @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_uint, tileX))) + @as(c_int, 1))))))))) == @as(c_int, @bitCast(@as(c_uint, c.FFLAG_LADDER)))) {
                            player.*.sprite.x += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 16)))));
                        }
                    }
                    if (@as(c_int, @bitCast(@as(c_int, player.*.y_axis))) >= 0) {
                        player.*.sprite.speed_y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 4) * @as(c_int, 16)))));
                    } else {
                        player.*.sprite.speed_y = @as(i16, @bitCast(@as(c_short, @truncate(0 - (@as(c_int, 4) * @as(c_int, 16))))));
                    }
                } else {
                    player.*.sprite.speed_y = 0;
                }
                break;
            },
            @as(c_int, 7), @as(c_int, 23) => {
                NEW_FORM(player, action);
                GET_IMAGE(level);
                DECELERATION(player);
                if (!globals.POSEREADY_FLAG) {
                    if ((@as(c_int, @bitCast(@as(c_uint, globals.ACTION_TIMER))) == @as(c_int, 1)) and (@as(c_int, @intFromBool(globals.CARRY_FLAG)) != 0)) {
                        object = FORCE_POSE(level);
                        if (object != @as([*c]c.TITUS_object, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(0)))))) {
                            tileX = @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @bitCast(@as(c_int, object.*.sprite.x))) >> @intCast(4)))));
                            tileY = @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @bitCast(@as(c_int, object.*.sprite.y))) >> @intCast(4)))));
                            fflag = c.get_floorflag(level, @as(i16, @bitCast(@as(c_ushort, tileY))), @as(i16, @bitCast(@as(c_ushort, tileX))));
                            if ((@as(c_int, @bitCast(@as(c_uint, fflag))) != @as(c_int, @bitCast(@as(c_uint, c.FFLAG_NOFLOOR)))) and (@as(c_int, @bitCast(@as(c_uint, fflag))) != @as(c_int, @bitCast(@as(c_uint, c.FFLAG_WATER))))) {
                                tileX +%= 1;
                                fflag = c.get_floorflag(level, @as(i16, @bitCast(@as(c_ushort, tileY))), @as(i16, @bitCast(@as(c_ushort, tileX))));
                                if ((@as(c_int, @bitCast(@as(c_uint, fflag))) != @as(c_int, @bitCast(@as(c_uint, c.FFLAG_NOFLOOR)))) and (@as(c_int, @bitCast(@as(c_uint, fflag))) != @as(c_int, @bitCast(@as(c_uint, c.FFLAG_WATER))))) {
                                    object.*.sprite.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 16) * @as(c_int, 3)))));
                                } else {
                                    object.*.sprite.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - (@as(c_int, 16) * @as(c_int, 3))))));
                                }
                            }
                        }
                    } else {
                        if (!globals.CARRY_FLAG) {
                            {
                                i = 0;
                                while (@as(c_int, @bitCast(@as(c_int, i))) < @as(c_int, 40)) : (i += 1) {
                                    if (!level.*.object[@as(c_ushort, @intCast(i))].sprite.enabled or (c.abs(@as(c_int, @bitCast(@as(c_int, player.*.sprite.y))) - @as(c_int, @bitCast(@as(c_int, level.*.object[@as(c_ushort, @intCast(i))].sprite.y)))) >= @as(c_int, 20))) {
                                        continue;
                                    }
                                    diffX = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) - @as(c_int, @bitCast(@as(c_int, level.*.object[@as(c_ushort, @intCast(i))].sprite.x)))))));
                                    if (!player.*.sprite.flipped) {
                                        diffX = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_int, diffX)))))));
                                    }
                                    if (c.game == @as(c_uint, @bitCast(c.Moktar))) {
                                        if (@as(c_int, @bitCast(@as(c_int, diffX))) >= @as(c_int, 25)) {
                                            continue;
                                        }
                                    } else if (c.game == @as(c_uint, @bitCast(c.Titus))) {
                                        if (@as(c_int, @bitCast(@as(c_int, diffX))) >= @as(c_int, 20)) {
                                            continue;
                                        }
                                    }
                                    if (@as(c_int, @bitCast(@as(c_int, level.*.object[@as(c_ushort, @intCast(i))].sprite.x))) > @as(c_int, @bitCast(@as(c_int, player.*.sprite.x)))) {
                                        if (@as(c_int, @bitCast(@as(c_int, level.*.object[@as(c_ushort, @intCast(i))].sprite.x))) > (@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) + @as(c_int, 32))) {
                                            continue;
                                        }
                                    } else {
                                        if ((@as(c_int, @bitCast(@as(c_int, level.*.object[@as(c_ushort, @intCast(i))].sprite.x))) + @as(c_int, @bitCast(@as(c_uint, level.*.object[@as(c_ushort, @intCast(i))].sprite.spritedata.*.collwidth)))) < @as(c_int, @bitCast(@as(c_int, player.*.sprite.x)))) {
                                            continue;
                                        }
                                    }
                                    if (@as(c_int, @bitCast(@as(c_int, level.*.object[@as(c_ushort, @intCast(i))].sprite.y))) < @as(c_int, @bitCast(@as(c_int, player.*.sprite.y)))) {
                                        if (@as(c_int, @bitCast(@as(c_int, level.*.object[@as(c_ushort, @intCast(i))].sprite.y))) <= (@as(c_int, @bitCast(@as(c_int, player.*.sprite.y))) - @as(c_int, 10))) {
                                            continue;
                                        }
                                    } else {
                                        if (((@as(c_int, @bitCast(@as(c_int, level.*.object[@as(c_ushort, @intCast(i))].sprite.y))) - @as(c_int, @bitCast(@as(c_uint, level.*.object[@as(c_ushort, @intCast(i))].sprite.spritedata.*.collheight)))) + @as(c_int, 1)) >= @as(c_int, @bitCast(@as(c_int, player.*.sprite.y)))) {
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
                                    if (@as(c_int, @bitCast(@as(c_int, player.*.sprite2.number))) == (@as(c_int, 30) + @as(c_int, 19))) {
                                        globals.TAPISWAIT_FLAG = 0;
                                    }
                                    player.*.sprite2.y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.y))) - @as(c_int, 4)))));
                                    if (player.*.sprite.flipped) {
                                        player.*.sprite2.x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) - @as(c_int, 10)))));
                                    } else {
                                        player.*.sprite2.x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) + @as(c_int, 12)))));
                                    }
                                    break;
                                }
                            }
                            if (!globals.CARRY_FLAG) {
                                i = 0;
                                while (@as(c_int, @bitCast(@as(c_int, i))) < @as(c_int, 50)) : (i += 1) {
                                    if (!level.*.enemy[@as(c_ushort, @intCast(i))].sprite.enabled or (c.abs(@as(c_int, @bitCast(@as(c_int, player.*.sprite.y))) - @as(c_int, @bitCast(@as(c_int, level.*.enemy[@as(c_ushort, @intCast(i))].sprite.y)))) >= @as(c_int, 20))) {
                                        continue;
                                    }
                                    diffX = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) - @as(c_int, @bitCast(@as(c_int, level.*.enemy[@as(c_ushort, @intCast(i))].sprite.x)))))));
                                    if (!player.*.sprite.flipped) {
                                        diffX = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_int, diffX)))))));
                                    }
                                    if (c.game == @as(c_uint, @bitCast(c.Moktar))) {
                                        if (@as(c_int, @bitCast(@as(c_int, diffX))) >= @as(c_int, 25)) {
                                            continue;
                                        }
                                    } else if (c.game == @as(c_uint, @bitCast(c.Titus))) {
                                        if (@as(c_int, @bitCast(@as(c_int, diffX))) >= @as(c_int, 20)) {
                                            continue;
                                        }
                                    }
                                    if (@as(c_int, @bitCast(@as(c_int, level.*.enemy[@as(c_ushort, @intCast(i))].carry_sprite))) == -@as(c_int, 1)) {
                                        continue;
                                    }
                                    if (@as(c_int, @bitCast(@as(c_int, level.*.enemy[@as(c_ushort, @intCast(i))].sprite.x))) > @as(c_int, @bitCast(@as(c_int, player.*.sprite.x)))) {
                                        if (@as(c_int, @bitCast(@as(c_int, level.*.enemy[@as(c_ushort, @intCast(i))].sprite.x))) > (@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) + @as(c_int, 32))) {
                                            continue;
                                        }
                                    } else {
                                        if ((@as(c_int, @bitCast(@as(c_int, level.*.enemy[@as(c_ushort, @intCast(i))].sprite.x))) + @as(c_int, @bitCast(@as(c_uint, level.*.enemy[@as(c_ushort, @intCast(i))].sprite.spritedata.*.collwidth)))) < @as(c_int, @bitCast(@as(c_int, player.*.sprite.x)))) {
                                            continue;
                                        }
                                    }
                                    if (@as(c_int, @bitCast(@as(c_int, level.*.enemy[@as(c_ushort, @intCast(i))].sprite.y))) < @as(c_int, @bitCast(@as(c_int, player.*.sprite.y)))) {
                                        if (@as(c_int, @bitCast(@as(c_int, level.*.enemy[@as(c_ushort, @intCast(i))].sprite.y))) <= (@as(c_int, @bitCast(@as(c_int, player.*.sprite.y))) - @as(c_int, 10))) {
                                            continue;
                                        }
                                    } else {
                                        if (((@as(c_int, @bitCast(@as(c_int, level.*.enemy[@as(c_ushort, @intCast(i))].sprite.y))) - @as(c_int, @bitCast(@as(c_uint, level.*.enemy[@as(c_ushort, @intCast(i))].sprite.spritedata.*.collheight)))) - @as(c_int, 1)) >= @as(c_int, @bitCast(@as(c_int, player.*.sprite.y)))) {
                                            continue;
                                        }
                                    }
                                    if (@as(c_int, @bitCast(@as(c_int, level.*.enemy[@as(c_ushort, @intCast(i))].sprite.number))) >= @as(c_int, 101)) {
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
                                    player.*.sprite2.y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.y))) - @as(c_int, 4)))));
                                    if (player.*.sprite.flipped) {
                                        player.*.sprite2.x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) - @as(c_int, 10)))));
                                    } else {
                                        player.*.sprite2.x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) + @as(c_int, 12)))));
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
            @as(c_int, 8), @as(c_int, 24) => {
                NEW_FORM(player, action);
                GET_IMAGE(level);
                DECELERATION(player);
                if (globals.CARRY_FLAG) {
                    if (@as(c_int, @bitCast(@as(c_int, player.*.y_axis))) >= 0) {
                        speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 14) * @as(c_int, 16)))));
                        speed_y = 0;
                        if (player.*.sprite.flipped) {
                            speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_int, speed_x)))))));
                        }
                        player.*.sprite2.y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.y))) - @as(c_int, 16)))));
                    } else {
                        speed_x = 0;
                        speed_y = @as(i16, @bitCast(@as(c_short, @truncate(0 - (@as(c_int, 10) * @as(c_int, 16))))));
                    }
                    if (@as(c_int, @bitCast(@as(c_int, speed_y))) != 0) {
                        object = FORCE_POSE(level);
                        if (object != @as([*c]c.TITUS_object, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(0)))))) {
                            object.*.sprite.speed_y = speed_y;
                            object.*.sprite.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, speed_x))) - (@as(c_int, @bitCast(@as(c_int, speed_x))) >> @intCast(2))))));
                        }
                    } else {
                        if (@as(c_int, @bitCast(@as(c_int, player.*.sprite2.number))) < @as(c_int, 101)) {
                            if ((blk: {
                                const tmp = @as(c_int, @bitCast(@as(c_int, player.*.sprite2.number))) - @as(c_int, 30);
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
                    c.updatesprite(level, &player.*.sprite, @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 10))))), true);
                    player.*.sprite.flipped = @as(c_int, @bitCast(@as(c_int, globals.SENSX))) < 0;
                    globals.CARRY_FLAG = false;
                }
                break;
            },
            @as(c_int, 10) => {
                XACCELERATION(player, @as(i16, @bitCast(@as(c_short, @truncate((@as(c_int, 4) - @as(c_int, 1)) * @as(c_int, 16))))));
                NEW_FORM(player, action);
                GET_IMAGE(level);
                break;
            },
            @as(c_int, 11) => {
                player.*.sprite.speed_x = 0;
                NEW_FORM(player, action);
                GET_IMAGE(level);
                break;
            },
            @as(c_int, 12), @as(c_int, 13), @as(c_int, 28), @as(c_int, 29) => {
                YACCELERATION(player, @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 12) * @as(c_int, 16))))));
                NEW_FORM(player, action);
                GET_IMAGE(level);
                break;
            },
            @as(c_int, 21) => {
                NEW_FORM(player, action);
                GET_IMAGE(level);
                DECELERATION(player);
                break;
            },
            @as(c_int, 27) => {
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

fn NEW_FORM(arg_player: [*c]c.TITUS_player, arg_action: u8) void {
    var player = arg_player;
    _ = &player;
    var action = arg_action;
    _ = &action;
    if ((@as(c_int, @bitCast(@as(c_uint, globals.LAST_ORDER))) != @as(c_int, @bitCast(@as(c_uint, action)))) or (player.*.sprite.animation == @as([*c]const i16, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(0))))))) {
        globals.LAST_ORDER = action;
        player.*.sprite.animation = data.get_anim_player(action);
    }
}

fn GET_IMAGE(arg_level: [*c]c.TITUS_level) void {
    var level = arg_level;
    _ = &level;
    var player: [*c]c.TITUS_player = &level.*.player;
    _ = &player;
    var frame: i16 = player.*.sprite.animation.*;
    _ = &frame;
    if (@as(c_int, @bitCast(@as(c_int, frame))) < 0) {
        if (@as(c_int, @bitCast(@as(c_int, frame))) == -@as(c_int, 1)) {
            std.log.err("Player frame is -1, advancing by {}\n", .{@divTrunc(@as(c_int, @bitCast(@as(c_int, frame))), @as(c_int, 2))});
        }
        player.*.sprite.animation += @as(usize, @bitCast(@as(isize, @intCast(@divTrunc(@as(c_int, @bitCast(@as(c_int, frame))), @as(c_int, 2))))));
        frame = player.*.sprite.animation.*;
    }
    c.updatesprite(level, &player.*.sprite, frame, true);
    player.*.sprite.flipped = @as(c_int, @bitCast(@as(c_int, globals.SENSX))) < 0;
    player.*.sprite.animation += 1;
}

fn YACCELERATION_NEG(arg_player: [*c]c.TITUS_player, arg_maxspeed: i16) void {
    var player = arg_player;
    _ = &player;
    var maxspeed = arg_maxspeed;
    _ = &maxspeed;
    maxspeed = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_int, maxspeed)))))));
    var speed: i16 = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_y))) - @as(c_int, 32)))));
    _ = &speed;
    if (@as(c_int, @bitCast(@as(c_int, speed))) >= @as(c_int, @bitCast(@as(c_int, maxspeed)))) {
        speed = maxspeed;
    }
    player.*.sprite.speed_y = speed;
}

fn COLLISION_TRP(arg_level: [*c]c.TITUS_level) void {
    var level = arg_level;
    _ = &level;
    var i: u8 = undefined;
    _ = &i;
    var player: [*c]c.TITUS_player = &level.*.player;
    _ = &player;
    var elevator: [*c]c.TITUS_elevator = @as([*c]c.TITUS_elevator, @ptrCast(@alignCast(&level.*.elevator)));
    _ = &elevator;
    if ((@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_y))) >= 0) and (@as(c_int, @bitCast(@as(c_uint, globals.CROSS_FLAG))) == 0)) {
        {
            i = 0;
            while (@as(c_int, @bitCast(@as(c_uint, i))) < @as(c_int, 10)) : (i +%= 1) {
                if (((!elevator[i].enabled or !elevator[i].sprite.visible) or (c.abs(@as(c_int, @bitCast(@as(c_int, elevator[i].sprite.x))) - @as(c_int, @bitCast(@as(c_int, player.*.sprite.x)))) >= @as(c_int, 64))) or (c.abs(@as(c_int, @bitCast(@as(c_int, elevator[i].sprite.y))) - @as(c_int, @bitCast(@as(c_int, player.*.sprite.y)))) >= @as(c_int, 16))) {
                    continue;
                }
                if ((@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) - @as(c_int, @bitCast(@as(c_uint, level.*.spritedata[@as(c_uint, @intCast(0))].refwidth)))) < @as(c_int, @bitCast(@as(c_int, elevator[i].sprite.x)))) {
                    if (((@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) - @as(c_int, @bitCast(@as(c_uint, level.*.spritedata[@as(c_uint, @intCast(0))].refwidth)))) + @as(c_int, @bitCast(@as(c_uint, level.*.spritedata[@as(c_uint, @intCast(0))].collwidth)))) <= @as(c_int, @bitCast(@as(c_int, elevator[i].sprite.x)))) {
                        continue;
                    }
                } else {
                    if ((@as(c_int, @bitCast(@as(c_int, player.*.sprite.x))) - @as(c_int, @bitCast(@as(c_uint, level.*.spritedata[@as(c_uint, @intCast(0))].refwidth)))) >= (@as(c_int, @bitCast(@as(c_int, elevator[i].sprite.x))) + @as(c_int, @bitCast(@as(c_uint, elevator[i].sprite.spritedata.*.collwidth))))) {
                        continue;
                    }
                }
                if ((@as(c_int, @bitCast(@as(c_int, player.*.sprite.y))) - @as(c_int, 6)) < @as(c_int, @bitCast(@as(c_int, elevator[i].sprite.y)))) {
                    if (((@as(c_int, @bitCast(@as(c_int, player.*.sprite.y))) - @as(c_int, 6)) + @as(c_int, 8)) <= @as(c_int, @bitCast(@as(c_int, elevator[i].sprite.y)))) {
                        continue;
                    }
                } else {
                    if ((@as(c_int, @bitCast(@as(c_int, player.*.sprite.y))) - @as(c_int, 6)) >= (@as(c_int, @bitCast(@as(c_int, elevator[i].sprite.y))) + @as(c_int, @bitCast(@as(c_uint, elevator[i].sprite.spritedata.*.collheight))))) {
                        continue;
                    }
                }
                if (@as(c_int, @bitCast(@as(c_uint, globals.ACTION_TIMER))) == @as(c_int, 14)) {
                    globals.ACTION_TIMER = 16;
                }
                globals.YFALL = 0;
                player.*.sprite.y = elevator[i].sprite.y;
                player.*.sprite.speed_y = 0;
                c.subto0(&globals.SAUT_FLAG);
                globals.SAUT_COUNT = 0;
                globals.YFALL = 2;
                player.*.sprite.x += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, elevator[i].sprite.speed_x)))))));
                if (@as(c_int, @bitCast(@as(c_int, elevator[i].sprite.speed_y))) > 0) {
                    player.*.sprite.y += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, elevator[i].sprite.speed_y)))))));
                }
                return;
            }
        }
    }
}

fn COLLISION_OBJET(arg_level: [*c]c.TITUS_level) void {
    var level = arg_level;
    _ = &level;
    var player: [*c]c.TITUS_player = &level.*.player;
    _ = &player;
    var off_object: [*c]c.TITUS_object = undefined;
    _ = &off_object;
    if (@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_y))) < 0) {
        return;
    }
    if (!c.SPRITES_VS_SPRITES(level, &player.*.sprite, &level.*.spritedata[@as(c_uint, @intCast(0))], &off_object)) {
        return;
    }
    player.*.sprite.y = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, off_object.*.sprite.y))) - @as(c_int, @bitCast(@as(c_uint, off_object.*.sprite.spritedata.*.collheight)))))));
    if ((@as(c_int, @bitCast(@as(c_int, off_object.*.sprite.number))) == (@as(c_int, 30) + @as(c_int, 24))) or (@as(c_int, @bitCast(@as(c_int, off_object.*.sprite.number))) == (@as(c_int, 30) + @as(c_int, 25)))) {
        off_object.*.sprite.UNDER = @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @bitCast(@as(c_uint, off_object.*.sprite.UNDER))) | @as(c_int, 2)))));
        off_object.*.sprite.ONTOP = &player.*.sprite;
    }
    if ((@as(c_int, @bitCast(@as(c_int, off_object.*.sprite.number))) == (@as(c_int, 30) + @as(c_int, 21))) or (@as(c_int, @bitCast(@as(c_int, off_object.*.sprite.number))) == (@as(c_int, 30) + @as(c_int, 22)))) {
        if (!player.*.sprite.flipped) {
            off_object.*.sprite.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 6) * @as(c_int, 16)))));
        } else {
            off_object.*.sprite.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - (@as(c_int, 6) * @as(c_int, 16))))));
        }
        off_object.*.sprite.flipped = player.*.sprite.flipped;
        globals.GRAVITY_FLAG = 4;
        globals.TAPISWAIT_FLAG = 0;
    } else if ((((@as(c_int, @bitCast(@as(c_uint, globals.ACTION_TIMER))) > @as(c_int, 10)) and ((@as(c_int, @bitCast(@as(c_uint, globals.LAST_ORDER))) & @as(c_int, 15)) == 0)) and (@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_y))) == 0)) and ((@as(c_int, @bitCast(@as(c_int, off_object.*.sprite.number))) == @as(c_int, 83)) or (@as(c_int, @bitCast(@as(c_int, off_object.*.sprite.number))) == @as(c_int, 94)))) {
        if (!player.*.sprite.flipped) {
            off_object.*.sprite.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 16) * @as(c_int, 3)))));
        } else {
            off_object.*.sprite.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(0 - (@as(c_int, 16) * @as(c_int, 3))))));
        }
        off_object.*.sprite.flipped = player.*.sprite.flipped;
        globals.GRAVITY_FLAG = 4;
    }
    if (@as(c_int, @bitCast(@as(c_int, off_object.*.sprite.speed_x))) < 0) {
        player.*.sprite.speed_x = off_object.*.sprite.speed_x;
    } else if (@as(c_int, @bitCast(@as(c_int, off_object.*.sprite.speed_x))) > 0) {
        player.*.sprite.speed_x = @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, off_object.*.sprite.speed_x))) + @as(c_int, 16)))));
    }
    if (((@as(c_int, @bitCast(@as(c_uint, globals.CROSS_FLAG))) == 0) and (@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_y))) > (@as(c_int, 16) * @as(c_int, 3)))) and (@as(c_int, @intFromBool(off_object.*.objectdata.*.bounce)) != 0)) {
        if (@as(c_int, @bitCast(@as(c_int, player.*.y_axis))) > 0) {
            player.*.sprite.speed_y = 0;
        } else {
            if (@as(c_int, @bitCast(@as(c_int, player.*.y_axis))) < 0) {
                player.*.sprite.speed_y += @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 16) * @as(c_int, 3)))));
            } else {
                player.*.sprite.speed_y -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, 16)))));
            }
            player.*.sprite.speed_y = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_y)))))));
            if (@as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_y))) > 0) {
                player.*.sprite.speed_y = 0;
            }
        }
        globals.ACTION_TIMER = 0;
        if (@as(c_int, @bitCast(@as(c_int, off_object.*.sprite.speed_y))) == 0) {
            c.playEvent_c(@as(c_uint, @bitCast(c.Event_BallBounce)));
            off_object.*.sprite.speed_y = @as(i16, @bitCast(@as(c_short, @truncate(0 - @as(c_int, @bitCast(@as(c_int, player.*.sprite.speed_y)))))));
            off_object.*.sprite.y -= @as(i16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_int, off_object.*.sprite.speed_y))) >> @intCast(4)))));
            globals.GRAVITY_FLAG = 4;
        }
    } else {
        if (@as(c_int, @bitCast(@as(c_int, off_object.*.sprite.speed_y))) != 0) {
            player.*.sprite.speed_y = off_object.*.sprite.speed_y;
        } else {
            player.*.sprite.speed_y = 0;
        }
        c.subto0(&globals.SAUT_FLAG);
        globals.SAUT_COUNT = 0;
        globals.YFALL = 2;
    }
}
