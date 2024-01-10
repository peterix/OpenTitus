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

const globals = @import("globals.zig");
const sqz = @import("sqz.zig");
const scroll = @import("scroll.zig");
const c = @import("c.zig");
const data = @import("data.zig");
const window = @import("window.zig");
const elevators = @import("elevators.zig");
const game_state = @import("game_state.zig");
const draw = @import("draw.zig");
const gates = @import("gates.zig");

const image = @import("ui/image.zig");
const keyboard = @import("ui/keyboard.zig");
const status = @import("ui/status.zig");

pub fn playtitus(firstlevel: u16, allocator: std.mem.Allocator) c_int {
    var context: c.ScreenContext = undefined;
    c.screencontext_reset(&context);

    var retval: c_int = 0;

    var level: c.TITUS_level = undefined;
    var spritecache: c.TITUS_spritecache = undefined;
    var sprites: [*c][*c]c.TITUS_spritedata = undefined;
    var sprite_count: u16 = 0;
    var objects: [*c][*c]c.TITUS_objectdata = undefined;
    var object_count: u16 = 0;

    // FIXME: this is persistent between levels... do not store it in the level
    level.lives = 2;
    level.extrabonus = 0;

    level.pixelformat = &data.titus_pixelformat;

    var spritedata = sqz.unSQZ(data.constants.*.sprites, allocator) catch {
        std.debug.print("Failed to uncompress sprites file: {s}\n", .{data.constants.*.sprites});
        return -1;
    };

    // TODO: same as unSQZ()
    retval = c.loadsprites(
        &sprites,
        &spritedata[0],
        @intCast(spritedata.len),
        level.pixelformat,
        &sprite_count,
    );
    allocator.free(spritedata);
    if (retval < 0) {
        return retval;
    }
    defer c.freesprites(&sprites, sprite_count);

    // TODO: same as unSQZ()
    retval = c.initspritecache(&spritecache, 100, 3); //Cache size: 100 surfaces, 3 temporary
    if (retval < 0) {
        return retval;
    }
    defer c.freespritecache(&spritecache);

    // TODO: same as unSQZ()
    retval = c.loadobjects(&objects, &object_count);
    if (retval < 0) {
        return retval;
    }
    defer c.freeobjects(&objects, object_count);

    level.levelnumber = firstlevel;
    while (level.levelnumber < data.constants.*.levelfiles.len) : (level.levelnumber += 1) {
        level.levelid = c.getlevelid(level.levelnumber);
        const level_index = @as(usize, @intCast(level.levelnumber));
        var leveldata = sqz.unSQZ(
            data.constants.*.levelfiles[level_index].filename,
            allocator,
        ) catch {
            std.debug.print("Failed to uncompress level file: {}\n", .{level.levelnumber});
            return 1;
        };

        retval = c.loadlevel(
            &level,
            &leveldata[0],
            @intCast(leveldata.len),
            sprites,
            &(spritecache),
            objects,
            @constCast(&data.constants.levelfiles[level.levelnumber].color),
        );
        allocator.free(leveldata);
        if (retval < 0) {
            return retval;
        }
        defer c.freelevel(&level);
        var first = true;
        while (true) {
            c.music_select_song(0);
            c.CLEAR_DATA(&level);

            globals.GODMODE = false;
            globals.NOCLIP = false;
            globals.DISPLAYLOOPTIME = false;

            retval = status.viewstatus(&level, first);
            first = false;
            if (retval < 0) {
                return retval;
            }

            c.music_select_song(c.LEVEL_MUSIC[level.levelid]);

            // scroll to where the player is while 'closing' and 'opening' the screen to obscure the sudden change
            gates.CLOSE_SCREEN(&context);
            scroll.scrollToPlayer(&level);
            gates.OPEN_SCREEN(&context, &level);

            draw.draw_tiles(&level);
            draw.flip_screen(&context, true);

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

            if (globals.NEWLEVEL_FLAG and !globals.SKIPLEVEL_FLAG) {
                game_state.record_completion(
                    allocator,
                    level.levelnumber,
                    level.bonuscollected,
                    level.tickcount,
                ) catch |err| {
                    std.log.err("Could not record level completion: {}", .{err});
                };
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

fn playlevel(context: [*c]c.ScreenContext, level: *c.TITUS_level) c_int {
    var retval: c_int = 0;
    var firstrun = true;

    while (true) {
        if (!firstrun) {
            draw.draw_health_bars(level);
            c.music_restart_if_finished();
            draw.flip_screen(context, true);
        }
        firstrun = false;
        globals.IMAGE_COUNTER = (globals.IMAGE_COUNTER + 1) & 0x0FFF; //Cycle from 0 to 0x0FFF
        elevators.elevators_move(level);
        c.move_objects(level); //Object gravity
        retval = c.move_player(context, level); //Key input, update and move player, handle carried object and decrease timers
        if (retval == c.TITUS_ERROR_QUIT) {
            return retval;
        }
        c.MOVE_NMI(level); //Move enemies
        c.MOVE_TRASH(level); //Move enemy throwed objects
        c.SET_NMI(level); //Handle enemies on the screen
        gates.CROSSING_GATE(context, level); //Check and handle level completion, and if the player does a kneestand on a secret entrance
        c.SPRITES_ANIMATION(level); //Animate player and objects
        scroll.scroll(level); //X- and Y-scrolling
        draw.draw_tiles(level);
        draw.draw_sprites(level);
        level.tickcount += 1;
        retval = c.RESET_LEVEL(context, level); //Check terminate flags (finishlevel, gameover, death or theend)
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

    c.music_select_song(1);
    _ = c.FORCE_POSE(level);
    c.updatesprite(level, &(player.sprite), 13, true); //Death
    player.sprite.speedY = 15;
    for (0..60) |_| {
        draw.draw_tiles(level);
        //TODO! GRAVITY();
        draw.draw_sprites(level);
        draw.flip_screen(context, true);
        player.sprite.speedY -= 1;
        if (player.sprite.speedY < -16) {
            player.sprite.speedY = -16;
        }
        player.sprite.y -= player.sprite.speedY;
    }

    c.music_wait_to_finish();
    c.music_select_song(0);
    gates.CLOSE_SCREEN(context);
}

fn gameover(context: [*c]c.ScreenContext, level: *c.TITUS_level) void {
    var player = &(level.player);

    c.music_select_song(2);
    c.updatesprite(level, &(player.sprite), 13, true); //Death
    c.updatesprite(level, &(player.sprite2), 333, true); //Game
    player.sprite2.x = @as(i16, globals.BITMAP_X << 4) - (120 - 2);
    player.sprite2.y = @as(i16, globals.BITMAP_Y << 4) + 100;
    //over
    c.updatesprite(level, &(player.sprite3), 334, true); //Over
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
