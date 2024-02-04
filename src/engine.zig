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

const audio = @import("audio/engine.zig");
const globals = @import("globals.zig");
const sqz = @import("sqz.zig");
const scroll = @import("scroll.zig");
const sprites = @import("sprites.zig");
const c = @import("c.zig");
const data = @import("data.zig");
const window = @import("window.zig");
const elevators = @import("elevators.zig");
const game_state = @import("game_state.zig");
const draw = @import("draw.zig");
const reset = @import("reset.zig");
const gates = @import("gates.zig");
const spr = @import("sprites.zig");
const lvl = @import("level.zig");

const image = @import("ui/image.zig");
const keyboard = @import("ui/keyboard.zig");
const status = @import("ui/status.zig");
const final_cutscene = @import("final_cutscene.zig");

pub fn playtitus(firstlevel: u16, allocator: std.mem.Allocator) !c_int {
    var context: c.ScreenContext = undefined;
    draw.screencontext_reset(&context);

    var retval: c_int = 0;

    var level: lvl.Level = undefined;
    level.c_level.parent = @ptrCast(&level);

    // FIXME: this is persistent between levels... do not store it in the level
    level.c_level.lives = 2;
    level.c_level.extrabonus = 0;

    level.c_level.pixelformat = &data.titus_pixelformat;

    var spritedata = sqz.unSQZ(data.constants.*.sprites, allocator) catch {
        std.debug.print("Failed to uncompress sprites file: {s}\n", .{data.constants.*.sprites});
        return -1;
    };

    spr.init(
        allocator,
        spritedata,
        level.c_level.pixelformat,
    ) catch |err| {
        std.debug.print("Failed to load sprites: {}\n", .{err});
        return -1;
    };
    defer spr.deinit();

    const pixelformat = c.SDL_GetWindowPixelFormat(window.window);
    spr.sprite_cache.init(pixelformat, allocator) catch |err| {
        std.debug.print("Failed to initialize sprite cache: {}\n", .{err});
        return -1;
    };
    defer spr.sprite_cache.deinit();

    level.c_level.levelnumber = firstlevel;
    while (level.c_level.levelnumber < data.constants.*.levelfiles.len) : (level.c_level.levelnumber += 1) {
        const current_constants = data.constants.levelfiles[level.c_level.levelnumber];
        level.c_level.is_finish = current_constants.is_finish;
        level.c_level.has_cage = current_constants.has_cage;
        level.c_level.boss_power = current_constants.boss_power;
        level.c_level.music = current_constants.music;

        const level_index = @as(usize, @intCast(level.c_level.levelnumber));
        var leveldata = sqz.unSQZ(
            data.constants.*.levelfiles[level_index].filename,
            allocator,
        ) catch {
            std.debug.print("Failed to uncompress level file: {}\n", .{level.c_level.levelnumber});
            return 1;
        };

        retval = try lvl.loadlevel(
            &level,
            &level.c_level,
            allocator,
            leveldata,
            data.object_data,
            @constCast(&data.constants.levelfiles[level.c_level.levelnumber].color),
        );
        allocator.free(leveldata);
        if (retval < 0) {
            return retval;
        }
        defer lvl.freelevel(&level, allocator);

        var first = true;
        while (true) {
            audio.music_select_song(0);
            reset.CLEAR_DATA(&level.c_level);

            globals.GODMODE = false;
            globals.NOCLIP = false;
            globals.DISPLAYLOOPTIME = false;

            retval = status.viewstatus(&level.c_level, first);
            first = false;
            if (retval < 0) {
                return retval;
            }

            audio.music_select_song(level.c_level.music);

            // scroll to where the player is while 'closing' and 'opening' the screen to obscure the sudden change
            gates.CLOSE_SCREEN(&context);
            scroll.scrollToPlayer(&level.c_level);
            gates.OPEN_SCREEN(&context, &level.c_level);

            draw.draw_tiles(&level.c_level);
            draw.flip_screen(&context, true);

            game_state.visit_level(
                allocator,
                level.c_level.levelnumber,
            ) catch |err| {
                std.log.err("Could not record level entry: {}", .{err});
            };

            retval = playlevel(&context, &level.c_level);
            if (retval < 0) {
                return retval;
            }

            if (globals.NEWLEVEL_FLAG) {
                if (!globals.SKIPLEVEL_FLAG) {
                    game_state.record_completion(
                        allocator,
                        level.c_level.levelnumber,
                        level.c_level.bonuscollected,
                        level.c_level.tickcount,
                    ) catch |err| {
                        std.log.err("Could not record level completion: {}", .{err});
                    };
                }
                break;
            }
            if (globals.LOSELIFE_FLAG) {
                if (level.c_level.lives == 0) {
                    globals.GAMEOVER_FLAG = true;
                } else {
                    level.c_level.lives -= 1;
                    death(&context, &level.c_level);
                }
            } else if (globals.RESETLEVEL_FLAG == 1) {
                death(&context, &level.c_level);
            }

            if (globals.GAMEOVER_FLAG) {
                gameover(&context, &level.c_level);
                return 0;
            }
        }

        if (retval < 0) {
            unreachable;
            // return retval;
        }
    }
    if (data.constants.*.finish != null) {
        const finish = data.constants.*.finish.?;
        retval = image.viewImageFile(
            finish,
            .FadeOut,
            0,
            allocator,
        ) catch {
            return -1;
        };
        if (retval < 0) {
            return retval;
        }
    }

    return (0);
}

// FIXME: most of the different return values are meaningless and unused
fn resetLevel(context: *c.ScreenContext, level: *c.TITUS_level) c_int {
    if (globals.NEWLEVEL_FLAG) {
        return 1;
    }
    if (globals.GAMEOVER_FLAG) {
        return 2;
    }
    if (globals.RESETLEVEL_FLAG == 1) {
        return 3;
    }
    if (level.is_finish) {
        // FIXME: replace with error handling? or some sensible return value enum
        const retval = final_cutscene.play(context, level);
        if (retval < 0) {
            return retval;
        }
        globals.NEWLEVEL_FLAG = true;
        return 3;
    }
    return 0;
}

fn playlevel(context: [*c]c.ScreenContext, level: *c.TITUS_level) c_int {
    var retval: c_int = 0;
    var firstrun = true;

    while (true) {
        if (!firstrun) {
            draw.draw_health_bars(level);
            audio.music_restart_if_finished();
            draw.flip_screen(context, true);
        }
        firstrun = false;
        globals.IMAGE_COUNTER = (globals.IMAGE_COUNTER + 1) & 0x0FFF; //Cycle from 0 to 0x0FFF
        elevators.move(level);
        c.move_objects(level); //Object gravity
        retval = c.move_player(context, level); //Key input, update and move player, handle carried object and decrease timers
        if (retval == c.TITUS_ERROR_QUIT) {
            return retval;
        }
        c.moveEnemies(level); //Move enemies
        c.moveTrash(level); //Move enemy throwed objects
        c.SET_NMI(level); //Handle enemies on the screen
        gates.CROSSING_GATE(context, level); //Check and handle level completion, and if the player does a kneestand on a secret entrance
        sprites.animateSprites(level); //Animate player and objects
        scroll.scroll(level); //X- and Y-scrolling
        draw.draw_tiles(level);
        draw.draw_sprites(level);
        level.tickcount += 1;
        retval = resetLevel(context, level); //Check terminate flags (finishlevel, gameover, death or theend)
        if (retval < 0) {
            return retval;
        }
        if (retval != 0) {
            break;
        }
    }
    return (0);
}

fn death(context: [*c]c.ScreenContext, level: *c.TITUS_level) void {
    var player = &(level.player);

    audio.music_play_jingle_c(1);
    _ = c.FORCE_POSE(level);
    spr.updatesprite(level, &(player.sprite), 13, true); //Death
    player.sprite.speed_y = 15;
    for (0..60) |_| {
        draw.draw_tiles(level);
        //TODO! GRAVITY();
        draw.draw_sprites(level);
        draw.flip_screen(context, true);
        player.sprite.speed_y -= 1;
        if (player.sprite.speed_y < -16) {
            player.sprite.speed_y = -16;
        }
        player.sprite.y -= player.sprite.speed_y;
    }

    audio.music_wait_to_finish();
    audio.music_select_song(0);
    gates.CLOSE_SCREEN(context);
}

fn gameover(context: [*c]c.ScreenContext, level: *c.TITUS_level) void {
    var player = &(level.player);

    audio.music_select_song(2);
    spr.updatesprite(level, &(player.sprite), 13, true); //Death
    spr.updatesprite(level, &(player.sprite2), 333, true); //Game
    player.sprite2.x = @as(i16, globals.BITMAP_X << 4) - (120 - 2);
    player.sprite2.y = @as(i16, globals.BITMAP_Y << 4) + 100;
    //over
    spr.updatesprite(level, &(player.sprite3), 334, true); //Over
    player.sprite3.x = @as(i16, globals.BITMAP_X << 4) + (window.game_width + 120 - 2);
    player.sprite3.y = @as(i16, globals.BITMAP_Y << 4) + 100;
    for (0..31) |_| {
        draw.draw_tiles(level);
        draw.draw_sprites(level);
        draw.flip_screen(context, true);
        player.sprite2.x += 8;
        player.sprite3.x -= 8;
    }
    if (keyboard.waitforbutton() < 0)
        return;

    draw.fadeout();
}
