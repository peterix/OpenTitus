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

const SDL = @import("SDL.zig");

const audio = @import("audio/audio.zig");
const globals = @import("globals.zig");
const sqz = @import("sqz.zig");
const scroll = @import("scroll.zig");
const sprites = @import("sprites.zig");
const data = @import("data.zig");
const window = @import("window.zig");
const elevators = @import("elevators.zig");
const objects = @import("objects.zig");
const enemies = @import("enemies.zig");
const game_state = @import("game_state.zig");
const render = @import("render.zig");
const ScreenContext = render.ScreenContext;
const reset = @import("reset.zig");
const gates = @import("gates.zig");
const lvl = @import("level.zig");
const player = @import("player.zig");

const input = @import("input.zig");

const image = @import("ui/image.zig");
const status = @import("ui/status.zig");
const final_cutscene = @import("final_cutscene.zig");

pub fn playtitus(firstlevel: u16, allocator: std.mem.Allocator) !c_int {
    var context = render.ScreenContext{};

    var retval: c_int = 0;

    var level: lvl.Level = undefined;

    // FIXME: this is persistent between levels... do not store it in the level
    level.lives = 2;
    level.extrabonus = 0;

    const spritedata = sqz.unSQZ(data.constants.*.sprites, allocator) catch {
        std.debug.print("Failed to uncompress sprites file: {s}\n", .{data.constants.*.sprites});
        return -1;
    };

    sprites.init(
        allocator,
        spritedata,
        &data.titus_palette,
    ) catch |err| {
        std.debug.print("Failed to load sprites: {}\n", .{err});
        return -1;
    };
    defer sprites.deinit();

    const pixelformat = SDL.getWindowPixelFormat(window.window);
    sprites.sprite_cache.init(pixelformat, allocator) catch |err| {
        std.debug.print("Failed to initialize sprite cache: {}\n", .{err});
        return -1;
    };
    defer sprites.sprite_cache.deinit();

    level.levelnumber = firstlevel;
    while (level.levelnumber < data.constants.*.levelfiles.len) : (level.levelnumber += 1) {
        const current_constants = data.constants.levelfiles[level.levelnumber];
        level.is_finish = current_constants.is_finish;
        level.has_cage = current_constants.has_cage;
        level.boss_power = current_constants.boss_power;
        level.music = current_constants.music;

        const level_index = @as(usize, @intCast(level.levelnumber));
        const leveldata = sqz.unSQZ(
            data.constants.*.levelfiles[level_index].filename,
            allocator,
        ) catch {
            std.debug.print("Failed to uncompress level file: {}\n", .{level.levelnumber});
            return 1;
        };

        retval = try lvl.loadlevel(
            &level,
            allocator,
            leveldata,
            &data.object_data,
            @constCast(&data.constants.levelfiles[level.levelnumber].color),
        );
        allocator.free(leveldata);
        if (retval < 0) {
            return retval;
        }
        defer lvl.freelevel(&level, allocator);

        var first = true;
        while (true) {
            audio.playTrack(.Bonus);
            reset.CLEAR_DATA(&level);

            globals.GODMODE = false;
            globals.NOCLIP = false;

            retval = status.viewstatus(&level, first);
            first = false;
            if (retval < 0) {
                return retval;
            }

            audio.playTrack(level.music);

            // scroll to where the player is while 'closing' and 'opening' the screen to obscure the sudden change
            gates.CLOSE_SCREEN(&context);
            scroll.scrollToPlayer(&level);
            gates.OPEN_SCREEN(&context, &level);

            render.render_tiles(&level);
            render.flip_screen(&context, true);

            game_state.visit_level(
                allocator,
                level.levelnumber,
            ) catch |err| {
                std.log.err("Could not record level entry: {}", .{err});
            };

            retval = playlevel(&context, &level);
            if (retval < 0) {
                return retval;
            }

            if (globals.NEWLEVEL_FLAG) {
                if (!globals.SKIPLEVEL_FLAG) {
                    game_state.record_completion(
                        allocator,
                        level.levelnumber,
                        level.bonuscollected,
                        level.tickcount,
                    ) catch |err| {
                        std.log.err("Could not record level completion: {}", .{err});
                    };
                }
                break;
            }
            if (globals.LOSELIFE_FLAG) {
                if (level.lives == 0) {
                    globals.GAMEOVER_FLAG = true;
                } else {
                    level.lives -= 1;
                    death(&context, &level);
                }
            } else if (globals.RESETLEVEL_FLAG == 1) {
                death(&context, &level);
            }

            if (globals.GAMEOVER_FLAG) {
                gameover(&context, &level);
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
fn resetLevel(context: *ScreenContext, level: *lvl.Level) c_int {
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

fn playlevel(context: *ScreenContext, level: *lvl.Level) c_int {
    var retval: c_int = 0;
    var firstrun = true;

    while (true) {
        if (!firstrun) {
            render.render_health_bars(level);
            audio.music_restart_if_finished();
            render.flip_screen(context, true);
        }
        firstrun = false;
        globals.IMAGE_COUNTER = (globals.IMAGE_COUNTER + 1) & 0x0FFF; //Cycle from 0 to 0x0FFF
        elevators.move(level);
        objects.move_objects(level); //Object gravity
        retval = player.move_player(context, level); //Key input, update and move player, handle carried object and decrease timers
        if (retval == -1) { //c.TITUS_ERROR_QUIT) {
            return retval;
        }
        enemies.moveEnemies(level); //Move enemies
        enemies.moveTrash(level); //Move enemy throwed objects
        enemies.SET_NMI(level); //Handle enemies on the screen
        gates.CROSSING_GATE(context, level); //Check and handle level completion, and if the player does a kneestand on a secret entrance
        sprites.animateSprites(level); //Animate player and objects
        scroll.scroll(level); //X- and Y-scrolling
        render.render_tiles(level);
        render.render_sprites(level);
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

fn death(context: *ScreenContext, level: *lvl.Level) void {
    var plr = &(level.player);

    audio.playTrack(.Death);
    _ = player.player_drop_carried(level);
    sprites.updatesprite(level, &(plr.sprite), 13, true); //Death
    plr.sprite.speed_y = 15;
    for (0..60) |_| {
        render.render_tiles(level);
        //TODO! GRAVITY();
        render.render_sprites(level);
        render.flip_screen(context, true);
        plr.sprite.speed_y -= 1;
        if (plr.sprite.speed_y < -16) {
            plr.sprite.speed_y = -16;
        }
        plr.sprite.y -= plr.sprite.speed_y;
    }

    audio.music_wait_to_finish();
    audio.playTrack(.Bonus);
    gates.CLOSE_SCREEN(context);
}

fn gameover(context: *ScreenContext, level: *lvl.Level) void {
    var plr = &(level.player);

    audio.playTrack(.GameOver);
    sprites.updatesprite(level, &(plr.sprite), 13, true); //Death
    sprites.updatesprite(level, &(plr.sprite2), 333, true); //Game
    plr.sprite2.x = @as(i16, globals.BITMAP_X << 4) - (120 - 2);
    plr.sprite2.y = @as(i16, globals.BITMAP_Y << 4) + 100;
    //over
    sprites.updatesprite(level, &(plr.sprite3), 334, true); //Over
    plr.sprite3.x = @as(i16, globals.BITMAP_X << 4) + (window.game_width + 120 - 2);
    plr.sprite3.y = @as(i16, globals.BITMAP_Y << 4) + 100;
    for (0..31) |_| {
        render.render_tiles(level);
        render.render_sprites(level);
        render.flip_screen(context, true);
        plr.sprite2.x += 8;
        plr.sprite3.x -= 8;
    }
    if (input.waitforbutton() < 0)
        return;

    render.fadeout();
}
