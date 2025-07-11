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

// player.zig
// Handles player movement and keyboard handling

const std = @import("std");

const globals = @import("globals.zig");
const SDL = @import("SDL.zig");
const game = @import("game.zig");
const window = @import("window.zig");
const data = @import("data.zig");
const objects = @import("objects.zig");
const lvl = @import("level.zig");
const render = @import("render.zig");
const events = @import("events.zig");
const sprites = @import("sprites.zig");
const common = @import("common.zig");
const input = @import("input.zig");
const game_state = @import("game_state.zig");

const credits = @import("ui/credits.zig");
const pause_menu = @import("ui/pause_menu.zig");
const status = @import("ui/status.zig");

fn add_carry() u8 {
    if (globals.CARRY_FLAG) {
        return 16;
    } else {
        return 0;
    }
}

// TODO: remove impossible action, assert on them
pub const PlayerAction = enum(u8) {
    Rest = 0,
    Walk = 1,
    Jump = 2,
    Crawl = 3,
    Slide = 4,
    KneeStand = 5,
    Climb = 6,
    Grab = 7,
    Drop = 8,
    SilentRest = 9,
    SilentWalk = 10,
    Headache = 11,
    Hit = 12,
    HitBurn = 13,

    Rest_Carry = 16,
    Walk_Carry = 17,
    Jump_Carry = 18,
    Crawl_Carry = 19,
    Slide_Carry = 20,
    KneeStand_Carry = 21,
    Climb_Carry = 22,
    Grab_Carry = 23,
    Drop_Carry = 24,
    SilentRest_Carry = 25,
    SilentWalk_Carry = 26,
    Headache_Carry = 27,
    Hit_Carry = 28,
    HitBurn_Carry = 29,

    fn addCarry(self: *PlayerAction) void {
        self.* = switch(self.*) {
            .Rest => .Rest_Carry,
            .Walk => .Walk_Carry,
            .Jump => .Jump_Carry,
            .Crawl => .Crawl_Carry,
            .Slide => .Slide_Carry,
            .KneeStand => .KneeStand_Carry,
            .Climb => .Climb_Carry,
            .Grab => .Grab_Carry,
            .Drop => .Drop_Carry,
            .SilentRest => .SilentRest_Carry,
            .SilentWalk => .SilentWalk_Carry,
            .Headache => .Headache_Carry,
            .Hit => .Hit_Carry,
            .HitBurn => .HitBurn_Carry,
            else => {
                return;
            },
        };
    }
    fn withoutCarry(self: PlayerAction) PlayerAction {
        return switch(self) {
            .Rest_Carry => .Rest,
            .Walk_Carry => .Walk,
            .Jump_Carry => .Jump,
            .Crawl_Carry => .Crawl,
            .Slide_Carry => .Slide,
            .KneeStand_Carry => .KneeStand,
            .Climb_Carry => .Climb,
            .Grab_Carry => .Grab,
            .Drop_Carry => .Drop,
            .SilentRest_Carry => .SilentRest,
            .SilentWalk_Carry => .SilentWalk,
            .Headache_Carry => .Headache,
            .Hit_Carry => .Hit,
            .HitBurn_Carry => .HitBurn,
            else => {
                return self;
            },
        };
    }

    pub fn str(self: PlayerAction) []const u8 {
        const no_carry = self.withoutCarry();
        return switch(no_carry) {
            .Rest => "Rest",
            .Walk => "Walk",
            .Jump => "Jump",
            .Crawl => "Crawl",
            .Slide => "Slide",
            .KneeStand => "KneeStand",
            .Climb => "Climb",
            .Grab => "Grab",
            .Drop => "Drop",
            .SilentRest => "SRest",
            .SilentWalk => "SWalk",
            .Headache => "Headache",
            .Hit => "Hit",
            .HitBurn => "HitBurn",
            else => "Unknown"
        };
    }
};

pub fn move_player(arg_context: *render.ScreenContext, arg_level: *lvl.Level) c_int {
    // Part 1: Gather input state
    // Part 2: Determine the player's action, and execute action dependent code
    // Part 3: Move the player + collision detection
    // Part 4: Move the throwed/carried object
    // Part 5: decrease the timers

    const context = arg_context;
    const level = arg_level;
    const player = &level.*.player;

    // Part 1: Gather input state
    {
        const input_state = input.processEvents();
        switch (input_state.action) {
            .Quit => {
                return -1;
            },
            .Escape, .ToggleMenu => {
                const retval = pause_menu.pauseMenu(context);
                if (retval < 0) {
                    return retval;
                }
            },
            .Status => {
                _ = status.viewstatus(level, false);
            },
            .SecretCreditsScreen => {
                // This is always available in the original.
                // Lets you convert extra bonus into lives without completing a level
                // It's a weird key combination
                // And it wasn't in the manual.
                // So I'm calling it a cheat and disabling it in normal builds.
                _ = credits.credits_screen();
                if (level.*.extrabonus >= 10) {
                    level.*.extrabonus -= 10;
                    level.*.lives += 1;
                }
            },
            .GodMode => {
                if (globals.GODMODE) {
                    globals.GODMODE = false;
                    globals.NOCLIP = false;
                } else {
                    globals.GODMODE = true;
                }
            },
            .NoClip => {
                if (globals.NOCLIP) {
                    globals.NOCLIP = false;
                } else {
                    globals.NOCLIP = true;
                    globals.GODMODE = true;
                }
            },
            .LoseLife => {
                // In the original game, this is always available, but you also lose a life. Maybe as a way to get 'unstuck'?
                DEC_LIFE(level);
            },
            .GameOver => {
                // Always available in original game. But why would you ever want this?
                globals.GAMEOVER_FLAG = true;
            },
            .SkipLevel => {
                // Added this to skip levels during testing
                globals.NEWLEVEL_FLAG = true;
                globals.SKIPLEVEL_FLAG = true;
            },

            else => {},
        }

        player.x_axis = input_state.x_axis;
        player.y_axis = input_state.y_axis;
        player.action_pressed = input_state.action_pressed;
        player.jump_pressed = input_state.jump_pressed;
        player.crouch_pressed = input_state.crouch_pressed;
        player.aim_direction = input_state.aim_direction;
    }

    // Part 2: Determine the player's action, and execute action dependent code
    if (globals.NOCLIP) {
        player.*.sprite.speed_x = player.x_axis * 100;
        player.*.sprite.speed_y = player.y_axis * 100;
        player.*.sprite.x += player.*.sprite.speed_x >> 4;
        player.*.sprite.y += player.*.sprite.speed_y >> 4;
        return 0;
    }

    var action: PlayerAction = undefined;

    if (globals.CHOC_FLAG != 0) {
        action = .Headache;
    } else if (globals.KICK_FLAG != 0) {
        if (globals.GRANDBRULE_FLAG) {
            action = .HitBurn;
        } else {
            action = .Hit;
        }
    } else {
        globals.GRANDBRULE_FLAG = false;
        if (globals.LADDER_FLAG) {
            action = .Climb;
        } else if (!globals.low_ceiling and player.jump_pressed and player.y_axis <= 0 and globals.jump_timer == 0) {
            action = .Jump;
            if (globals.LAST_ORDER == .KneeStand) { // Test if last order was kneestanding
                globals.FURTIF_FLAG = 100; // If jump after kneestanding, init silent walk timer
            }
        } else if (globals.low_ceiling or (globals.jump_timer != 6 and player.crouch_pressed)) {
            if (player.x_axis != 0) { // Move left or right
                action = .Crawl; // Action: crawling
            } else {
                action = .KneeStand; // Action: kneestand
            }
        } else if (player.x_axis != 0) {
            action = .Walk; // Action: walk
        } else {
            action = .Rest; // Action: rest (no action)
        }
        // Is space button pressed?
        if (player.action_pressed and !globals.low_ceiling) {
            if (!globals.DROP_FLAG) {
                if (action == .Crawl or action == .KneeStand) { // Kneestand
                    globals.DROPREADY_FLAG = false;
                    action = .Grab; // Grab an object
                } else if (globals.CARRY_FLAG and globals.DROPREADY_FLAG) { // Fall
                    action = .Drop; // Drop the object
                }
            }
        } else {
            globals.DROPREADY_FLAG = true;
            globals.POSEREADY_FLAG = false;
        }
    }
    if (globals.CARRY_FLAG) {
        action.addCarry();
    }

    var newsensX: i8 = undefined;
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
    } else if (action == .Rest) {
        newsensX = 0;
    } else {
        newsensX = 1;
    }

    if (globals.SENSX != newsensX) {
        globals.SENSX = newsensX;
        globals.ACTION_TIMER = 1;
    } else {
        if (globals.FURTIF_FLAG != 0) {
            if (action == .Rest) {
                action = .SilentRest;
            }
            else if (action == .Walk) {
                action = .SilentWalk;
            }
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
    if (((player.sprite.speed_x < 0) and ((player.sprite.x + (player.sprite.speed_x >> 4)) >= 8)) or // Going left
        ((player.sprite.speed_x > 0) and ((player.sprite.x + (player.sprite.speed_x >> 4)) <= (level.width << 4) - 8))) // Going right
    {
        player.sprite.x += player.sprite.speed_x >> 4;
    }
    // Move player in Y
    player.sprite.y += player.sprite.speed_y >> 4;
    // Test for collisions
    player_collide(level);

    // Part 4: Move the throwed/carried object
    // Move throwed/carried object
    if (globals.DROP_FLAG) {
        // sprite2: throwed or dropped object
        const newX: i16 = (player.sprite2.speed_x >> 4) + player.sprite2.x;
        if ((newX < (level.width << 4)) and // Left for right level edge
            (newX >= 0) and // Right for level left edge
            (newX >=
            (globals.BITMAP_X << 4) -
            globals.GESTION_X) and // Max 40 pixels left for screen (bug: the purpose
            // was probably one screen left for the screen)
            (newX <= (globals.BITMAP_X << 4) + (globals.screen_width << 4) +
            globals.GESTION_X))
        { // Max 40 pixels right for screen
            player.sprite2.x = newX;
            const newY: i16 = (player.sprite2.speed_y >> 4) + player.sprite2.y;
            if ((newY < (level.height << 4)) and // Above bottom edge of level
                (newY >= 0) and // Below top edge of level
                (newY >=
                (globals.BITMAP_Y << 4) -
                globals.GESTION_Y) and // Max 20 pixels above the screen (bug: the purpose
                // was probably one screen above the screen)
                (newY <= (globals.BITMAP_Y << 4) + (globals.screen_height << 4) +
                globals.GESTION_Y))
            { // Max 20 pixels below the screen
                player.sprite2.y = newY;
            } else {
                player.sprite2.enabled = false;
                globals.DROP_FLAG = false;
            }
        } else {
            player.sprite2.enabled = false;
            globals.DROP_FLAG = false;
        }
    } else if (globals.CARRY_FLAG) { // Place the object on top of or beside the player
        if (!globals.LADDER_FLAG and ((globals.LAST_ORDER == .KneeStand_Carry) or (globals.LAST_ORDER == .Grab_Carry)))
        { // Kneestand or take
            player.sprite2.y = player.sprite.y - 4;
            if (player.sprite.flipped) {
                player.sprite2.x = player.sprite.x - 10;
            } else {
                player.sprite2.x = player.sprite.x + 12;
            }
        } else {
            if ((player.sprite.number == 14) or // Sliding down the ladder OR
                (globals.LAST_ORDER.withoutCarry() != .Grab and globals.LAST_ORDER.withoutCarry() != .Drop)) // Not taking or dropping
            { // Not throwing/dropping
                player.sprite2.x = player.sprite.x + 2;
                if ((player.sprite.number == 23) or // Climbing (c)
                    (player.sprite.number == 24))
                { // Climbing (c) (2nd sprite)
                    player.sprite2.x -= 10;
                    if (player.sprite.flipped) {
                        player.sprite2.x += 18;
                    }
                }
                player.sprite2.y =
                    player.sprite.y - player.sprite.spritedata.?.collheight + 1;
            }
        }
    }
    if (globals.SEECHOC_FLAG != 0) {
        globals.SEECHOC_FLAG -= 1;
        if (globals.SEECHOC_FLAG == 0) {
            player.sprite2.enabled = false;
        }
    }

    // Part 5: decrease the timers
    common.subto0(&player.*.sprite.invincibility_frames);
    common.subto0(&globals.INVULNERABLE_FLAG);
    common.subto0(&globals.RESETLEVEL_FLAG);
    common.subto0(&globals.TAPISFLY_FLAG);
    common.subto0(&globals.CROSS_FLAG);
    common.subto0(&globals.GRAVITY_FLAG);
    common.subto0(&globals.FURTIF_FLAG);
    common.subto0(&globals.KICK_FLAG);
    if (player.sprite.speed_y == 0) {
        common.subto0(&globals.CHOC_FLAG);
    }
    if (player.*.sprite.speed_x == 0 and player.*.sprite.speed_y == 0) {
        globals.KICK_FLAG = 0;
    }
    common.subto0(&globals.FUME_FLAG);
    if ((globals.FUME_FLAG != 0) and ((globals.FUME_FLAG & 0x03) == 0)) {
        sprites.updatesprite(level, &player.sprite2, player.sprite2.number + 1, false);
        if (player.sprite2.number == globals.FIRST_OBJET + 19) {
            player.sprite2.enabled = false;
            globals.FUME_FLAG = 0;
        }
    }
    return 0;
}

fn DEC_LIFE(level: *lvl.Level) void {
    globals.RESETLEVEL_FLAG = 10;
    globals.BAR_FLAG = 0;
    if (level.lives == 0) {
        globals.GAMEOVER_FLAG = true;
    } else {
        globals.LOSELIFE_FLAG = true;
    }
}

fn CASE_DEAD_IM(level: *lvl.Level) void {
    // Kill the player immediately (spikes/water/flames etc.
    // Sets RESET_FLAG to 2, in opposite to being killed as a result of 0 HP (then
    // RESET_FLAG is 10)
    DEC_LIFE(level);
    globals.RESETLEVEL_FLAG = 2;
}

fn player_collide(level: *lvl.Level) void {
    // Collision detection between player
    // and tiles/objects/elevators
    // Point the foot on the block!
    const player = &level.player;
    var tileX: i16 = player.sprite.x >> 4;
    var tileY: i16 = (player.*.sprite.y >> 4) - 1;
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
    var colltest = player.sprite.x & 0x0F;
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
                player_collide_with_elevators(level);
                if (globals.YFALL == 1) {
                    player_collide_with_objects(level); // Player versus objects
                    if (globals.YFALL == 1) {
                        player_fall(level); // No wall/elevator/object under the player; fall down!
                    } else {
                        player.GLISSE = 0;
                    }
                }
            } else {
                player_fall(level); // Fall down!
            }
        }
    }

    // How will the player move in X?
    var changeX: i16 = TEST_ZONE + 4;
    if (player.sprite.speed_x < 0) {
        changeX = 0 - changeX;
    } else if (player.sprite.speed_x == 0) {
        changeX = 0;
    }
    var height: i16 = player.sprite.spritedata.?.collheight;
    if ((player.sprite.y > globals.MAP_LIMIT_Y + 1) and (initY >= 0) and (initY < level.height)) {
        tileX = (player.sprite.x + changeX) >> 4;
        tileY = initY;
        var first = true;
        while (true) {
            const hflag = level.getTileWall(tileX, tileY);
            if (first) {
                BLOCK_XXPRG(level, hflag, tileY, tileX);
                first = false;
            } else if (hflag == .Code or hflag == .Bonus) {
                BLOCK_XXPRG(level, hflag, tileY, tileX);
            }
            if (tileY == 0) {
                return;
            }
            tileY -= 1;
            height -= 16;
            if (!(height > 0)) break;
        }
    }
}

fn TAKE_BLK_AND_YTEST(level: *lvl.Level, tileY_in: i16, tileX_in: i16) void {
    var tileY = tileY_in;
    var tileX = tileX_in;
    const player = &level.*.player;
    globals.POCKET_FLAG = false;
    globals.low_ceiling = false;
    globals.LADDER_FLAG = false;
    var change: i8 = undefined;
    // if player is too high (<= -1), skip test
    if (player.sprite.y <= -1 or tileY < -1) {
        player_fall(level);
        globals.YFALL = 255;
        return;
    }
    // if player is too low, skip test
    if (tileY + 1 >= level.height) {
        player_fall(level);
        globals.YFALL = 255;
        return;
    }
    // In order to fall down in the right chamber if jumping above level 8
    if (tileY == -1) {
        tileY = 0;
    }
    const floor = level.getTileFloor(tileX, tileY + 1);
    const floor_above = level.getTileFloor(tileX, tileY);

    if (globals.LAST_ORDER.withoutCarry() != .Jump) {
        // Player versus floor
        BLOCK_YYPRG(level, floor, floor_above, tileY + 1, tileX);
    }
    // Test the tile on his head
    if (tileY < 1 or player.sprite.speed_y > 0) {
        return;
    }
    const cflag = level.getTileCeiling(tileX, tileY - 1);
    BLOCK_YYPRGD(level, cflag, tileY - 1, tileX);

    var horiz = level.getTileWall(tileX, tileY);
    if ((horiz == .Wall or horiz == .Deadly or horiz == .Padlock) and // Step on a hard tile?
        player.*.sprite.y > globals.MAP_LIMIT_Y + 1)
    {
        if (player.sprite.speed_x > 0) {
            change = -1;
        } else {
            change = 1;
        }
        tileX +%= change;
        horiz = level.getTileWall(tileX, tileY);
        if (horiz == .NoWall) { // No wall
            player.sprite.x += change << 1;
        } else {
            change = 0 - change;
            tileX +%= change + change;
            horiz = level.getTileWall(tileX, tileY);
            if (horiz == .NoWall) {
                player.sprite.x += change << 1;
            }
        }
    }
}

fn BLOCK_YYPRGD(level: *lvl.Level, cflag: lvl.CeilingType, tileY_in: i16, tileX_in: i16) void {
    var tileX = tileX_in;
    var tileY = tileY_in;
    const player = &level.player;

    // Action on different ceiling flags
    switch (cflag) {
        .NoCeiling => {},
        .Ceiling, .Deadly => {
            if (cflag == .Deadly and !globals.GODMODE) {
                CASE_DEAD_IM(level);
            } else if (player.sprite.speed_y != 0) {
                // Stop movement
                player.sprite.speed_y = 0;
                player.sprite.y = @as(i16, @bitCast(@as(u16, @bitCast(player.sprite.y)) & 0xFFF0)) + 16;
                globals.jump_acceleration_counter = 0xFF;
            } else if (player.sprite.number != 10 and // 10 = Free fall
                player.sprite.number != 21 and // 21 = Free fall (c)
                globals.jump_timer != 6)
            {
                globals.low_ceiling = true;
                if (globals.CARRY_FLAG) {
                    const maybe_object = player_drop_carried(level);
                    if (maybe_object) |object| {
                        tileX = object.sprite.x >> 4;
                        tileY = object.sprite.y >> 4;
                        var hflag = level.getTileWall(tileX, tileY);
                        if (hflag == .Wall or hflag == .Deadly or hflag == .Padlock) {
                            tileX -%= 1;
                            hflag = level.getTileWall(tileX, tileY);
                            if (hflag == .Wall or hflag == .Deadly or hflag == .Padlock) {
                                object.sprite.x += 16;
                            } else {
                                object.sprite.x -= 16;
                            }
                        }
                    }
                }
            }
        },
        .Ladder => {
            // Can we go up a ladder?
            //if (player.sprite.speed_y < 0 and player.sprite.speed_x == 0) {
            //if (player.sprite.speed_y <= 0 and player.y_axis < 0 and player.x_axis == 0) {
            if (player.sprite.speed_y <= 0 and player.y_axis < 0) {
                globals.jump_acceleration_counter = 10;
                globals.LADDER_FLAG = true;
            }
        },
        .Padlock => {
            collect_checkpoint(level, tileY, tileX);
        },
    }
}

fn BLOCK_XXPRG(level: *lvl.Level, hflag: lvl.WallType, tileY: i16, tileX: i16) void {
    switch (hflag) {
        .NoWall => {},
        .Wall => {
            player_block_x(level);
        },
        .Bonus => {
            _ = collect_bonus(level, tileY, tileX);
        },
        .Deadly => {
            if (!globals.GODMODE) {
                CASE_DEAD_IM(level);
            } else {
                player_block_x(level);
            }
        },
        .Code => {
            collect_level_unlock(level, @truncate(level.levelnumber), tileY, tileX);
        },
        .Padlock => {
            collect_checkpoint(level, tileY, tileX);
        },
        .CodeLevel14 => {
            collect_level_unlock(level, 14 - 1, tileY, tileX);
        },
    }
}

fn player_block_x(level: *lvl.Level) void {
    const player = &level.player;
    // Horizontal hit (wall), stop the player
    player.sprite.x -= player.sprite.speed_x >> 4;
    player.sprite.speed_x = 0;
    if (globals.KICK_FLAG != 0 and globals.jump_timer != 6) {
        globals.CHOC_FLAG = 20;
        globals.KICK_FLAG = 0;
    }
}

pub fn player_drop_carried(level: *lvl.Level) ?*lvl.Object {
    const sprite2 = &level.*.player.sprite2;
    if (!sprite2.enabled or !globals.CARRY_FLAG)
        return null;

    for (&level.*.object) |*object| {
        if (object.sprite.enabled)
            continue;
        objects.updateobjectsprite(level, object, sprite2.number, true);
        sprite2.enabled = false;
        object.sprite.killing = false;
        if (object.sprite.number < globals.FIRST_NMI) {
            object.sprite.droptobottom = false;
        } else {
            object.sprite.droptobottom = true;
        }
        object.sprite.x = sprite2.x;
        object.sprite.y = sprite2.y;
        object.momentum = 0;
        object.sprite.speed_y = 0;
        object.sprite.speed_x = 0;
        object.sprite.UNDER = 0;
        object.sprite.ONTOP = null;
        globals.POSEREADY_FLAG = true;
        globals.GRAVITY_FLAG = 4;
        globals.CARRY_FLAG = false;
        return object;
    }
    std.log.err("Could not drop carried object: it was not found!", .{});
    return null;
}

fn player_fall(level: *lvl.Level) void {
    // No wall under the player; fall down!
    const player = &level.player;
    globals.jump_timer = 6;
    if (globals.KICK_FLAG != 0) {
        return;
    }
    XACCELERATION(player, globals.MAX_X * 16);
    YACCELERATION(player, globals.MAX_Y * 16);
    if (globals.CHOC_FLAG != 0) {
        sprites.updatesprite(level, &player.sprite, 15, true); // sprite when hit
    } else if (!globals.CARRY_FLAG) {
        sprites.updatesprite(level, &player.sprite, 10, true); // position while falling  (jump sprite?)
    } else {
        sprites.updatesprite(level, &player.sprite, 21, true); // position falling and carry  (jump and carry sprite?)
    }
    player.*.sprite.flipped = globals.SENSX < 0;
}

fn XACCELERATION(player: *lvl.Player, maxspeed: i16) void {
    // Sideway acceleration
    var changeX: i16 = undefined;
    if (player.x_axis != 0) {
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

fn YACCELERATION(player: *lvl.Player, maxspeed: i16) void {
    // Accelerate downwards
    if (player.sprite.speed_y + 16 < maxspeed) {
        player.sprite.speed_y = player.sprite.speed_y + 16;
    } else {
        player.sprite.speed_y = maxspeed;
    }
}

fn BLOCK_YYPRG(level: *lvl.Level, floor: lvl.FloorType, floor_above: lvl.FloorType, tileY: i16, tileX: i16) void {
    // Action on different floor flags
    const player = &level.player;
    switch (floor) {
        .NoFloor => {
            player_fall_F();
        },
        .Floor => {
            player_block_yu(player);
        },
        .SlightlySlipperyFloor => {
            player_block_yu(player);
            player.GLISSE = 1;
        },
        .SlipperyFloor => {
            player_block_yu(player);
            player.GLISSE = 2;
        },
        .VerySlipperyFloor => {
            player_block_yu(player);
            player.GLISSE = 3;
        },
        // Drop-through if kneestanding
        .Drop => {
            player.GLISSE = 0;
            if (globals.CROSS_FLAG == 0) {
                player_block_yu(player);
            } else {
                player_fall_F();
            }
        },
        .Ladder => {
            // Fall if hit
            if (globals.CHOC_FLAG != 0) {
                player_fall_F(); // Free fall
                return;
            }
            const order = globals.LAST_ORDER.withoutCarry();
            const is_in_air = globals.YFALL != 0 or globals.jump_acceleration_counter != 0;
            // Skip if walking/crawling
            if (order == .Walk or order == .Crawl or order == .Grab or order == .Drop or order == .KneeStand or order == .Rest) {
                if(player.y_axis <= 0 and !is_in_air) {
                    player_block_yu(player); // Stop fall
                    return;
                }
                else
                {
                    player_fall_F(); // Free fall
                    const flip = player.sprite.flipped;
                    sprites.updatesprite(level, &player.sprite, 14, true); // sprite: start climbing down
                    player.sprite.flipped = flip;
                    player.sprite.y += 8;
                }
            }
            // we stand on top of a ladder
            if (floor_above != .Ladder) { // ladder
//                 if (order == .Rest) { // action repos
//                     player_block_yu(player); // Stop fall
//                     return;
//                 }
                if (player.y_axis < 0 and order == .Climb) { // action UP + climb ladder
                    player_block_yu(player); // Stop fall
                    return;
                }
            }

            common.subto0(&globals.jump_timer);
            globals.jump_acceleration_counter = 0;
            globals.YFALL = 2;

            globals.LADDER_FLAG = true;
        },
        .Bonus => {
            _ = collect_bonus(level, tileY, tileX);
        },
        .Water, .Fire, .Spikes => {
            if (!globals.GODMODE) {
                CASE_DEAD_IM(level);
            } else {
                player_block_yu(player); // If godmode; ordinary floor
            }
        },
        .Code => {
            collect_level_unlock(level, @truncate(level.levelnumber), tileY, tileX);
        },
        .Padlock => {
            collect_checkpoint(level, tileY, tileX);
        },
        .CodeLevel14 => {
            collect_level_unlock(level, 14 - 1, tileY, tileX);
        },
    }
}

fn player_fall_F() void {
    globals.YFALL = globals.YFALL | 0x01;
}

fn player_block_yu(player: *lvl.Player) void {
    // Floor; the player will not fall through
    globals.POCKET_FLAG = true;
    player.GLISSE = 0;
    if (player.sprite.speed_y < 0) {
        globals.YFALL = globals.YFALL | 0x01;
        return;
    }
    player.sprite.y = @bitCast(@as(u16, @bitCast(player.sprite.y)) & 0xFFF0);
    player.sprite.speed_y = 0;
    common.subto0(&globals.jump_timer);
    globals.jump_acceleration_counter = 0;
    globals.YFALL = 2;
}

fn collect_bonus(level: *lvl.Level, tileY: i16, tileX: i16) bool {
    // Handle bonuses. Increase energy if HP, and change the bonus tile to normal tile
    for (&level.bonus) |*bonus| {
        if (!bonus.exists)
            continue;
        if (bonus.x != tileX or bonus.y != tileY)
            continue;

        if (bonus.bonustile >= (255 - 2)) {
            level.bonuscollected += 1;
            events.triggerEvent(.Event_PlayerCollectBonus);
            INC_ENERGY(level);
        }
        level.setTile(@intCast(tileX), @intCast(tileY), bonus.replacetile);
        globals.GRAVITY_FLAG = 4;
        return true;
    }
    return false;
}

fn collect_level_unlock(level: *lvl.Level, level_index: u8, tileY: i16, tileX: i16) void {
    // Codelamp
    // if the bonus is found in the bonus list
    if (!collect_bonus(level, tileY, tileX))
        return;
    const allocator = std.heap.page_allocator;
    game_state.unlock_level(allocator, level_index, level.lives) catch |err| {
        std.log.err("Failed to save progression: {s}", .{ @errorName(err) });
    };
    events.triggerEvent(.Event_PlayerCollectLamp);
}

fn collect_checkpoint(level: *lvl.Level, tileY: i16, tileX: i16) void {
    if (!collect_bonus(level, tileY, tileX))
        return;

    const player = &level.player;
    events.triggerEvent(.Event_PlayerCollectWaypoint);
    player.initX = player.sprite.x;
    player.initY = player.sprite.y;
    // carrying cage?
    if (player.sprite2.number == globals.FIRST_OBJET + 26 or player.sprite2.number == globals.FIRST_OBJET + 27) {
        player.cageX = player.sprite.x;
        player.cageY = player.sprite.y;
    }
}

fn INC_ENERGY(level: *lvl.Level) void {
    const player = &level.player;
    globals.BAR_FLAG = 50;
    if (player.hp == globals.MAXIMUM_ENERGY) {
        level.extrabonus += 1;
    } else {
        player.hp += 1;
    }
}

pub fn DEC_ENERGY(level: *lvl.Level) void {
    const player = &level.player;
    globals.BAR_FLAG = 50;
    if (globals.RESETLEVEL_FLAG == 0) {
        if (player.hp > 0) {
            player.hp -= 1;
        }
        if (player.hp == 0) {
            player.sprite.invincibility_frames = 0;
            DEC_LIFE(level);
        }
    }
}

// Action dependent code
fn ACTION_PRG(level: *lvl.Level, action: PlayerAction) void {
    const player = &level.player;
    var tileX: i16 = undefined;
    var tileY: i16 = undefined;
    var diffX: i16 = undefined;
    var speed_x: i16 = undefined;
    var speed_y: i16 = undefined;

    switch (action) {
        .Rest, .SilentRest, .Rest_Carry => {
            // Rest. Handle deacceleration and slide
            globals.LAST_ORDER = action;
            player_friction(player);
            if (@abs(player.*.sprite.speed_x) >= 1 * 16 and player.sprite.flipped == (player.*.sprite.speed_x < 0)) {
                player.sprite.animation = data.get_anim_player(if (globals.CARRY_FLAG) .Slide_Carry else .Slide);
            } else {
                player.sprite.animation = data.get_anim_player(action);
            }
            sprites.updatesprite(level, &player.sprite, player.sprite.animation.*, true);
            player.sprite.flipped = globals.SENSX < 0;
        },
        .Walk, .Walk_Carry, .Crawl_Carry => {
            // Handle walking
            XACCELERATION(player, globals.MAX_X * 16);
            NEW_FORM(player, action); // Update last order and action (animation)
            GET_IMAGE(level); // Update player sprite
        },
        .Jump, .Jump_Carry => {
            // Handle a jump
            if (globals.jump_acceleration_counter == 0) {
                events.triggerEvent(.Event_PlayerJump);
            }
            if (globals.jump_acceleration_counter >= 3) {
                globals.jump_timer = 6; // Stop jump animation and acceleration
            } else {
                globals.jump_acceleration_counter +%= 1;
                YACCELERATION_NEG(player, globals.MAX_Y * 16 / 4);
                XACCELERATION(player, globals.MAX_X * 16);
                NEW_FORM(player, action);
                GET_IMAGE(level);
            }
        },
        .Crawl => {
            // Handle crawling
            NEW_FORM(player, action);
            GET_IMAGE(level);
            XACCELERATION(player, @divTrunc(globals.MAX_X * 16, 2));
            if (@abs(player.sprite.speed_x) < (2 * 16)) {
                sprites.updatesprite(level, &player.sprite, 6, true); // Crawling but not moving
                player.*.sprite.flipped = globals.SENSX < 0;
            }
        },
        .KneeStand => {
            // Kneestand
            NEW_FORM(player, action);
            GET_IMAGE(level);
            player_friction(player);
            if (globals.ACTION_TIMER == 15) {
                globals.CROSS_FLAG = 6;
                player.sprite.speed_y = 0;
            }
        },
        .Climb, .Climb_Carry => {
            // Climb a ladder
            if (player.x_axis != 0) {
                XACCELERATION(player, globals.MAX_X * 16);
                player.sprite.flipped = globals.SENSX < 0;
            } else {
                player_friction(player);
            }
            if (globals.ACTION_TIMER <= 1) {
                if (!globals.CARRY_FLAG) {
                    sprites.updatesprite(level, &player.sprite, 12, true); // Last climb sprite
                } else {
                    sprites.updatesprite(level, &player.sprite, 23, true); // First climb sprite (c)
                }
            }
            const is_in_air = globals.YFALL != 0 or globals.jump_acceleration_counter != 0;
            // attach to ladder in air
            if(is_in_air and globals.LAST_ORDER != .Climb) {
                NEW_FORM(player, if (globals.CARRY_FLAG) .Climb_Carry else .Climb);
                GET_IMAGE(level);
                player.sprite.speed_y = 0;
            }
            if (player.y_axis != 0) {
                NEW_FORM(player, if (globals.CARRY_FLAG) .Climb_Carry else .Climb);
                GET_IMAGE(level);

                // Snap to the ladder they are climbing
                const startX = player.sprite.x;
                var endX = startX;
                tileX = endX >> 4;
                // -1 is a fudge factor to hide the fact we are 1 pixel inside the floor all the time
                tileY = player.sprite.y - 1 >> 4;
                if (level.getTileFloor(tileX, tileY) != .Ladder) {
                    if (level.getTileFloor(tileX - 1, tileY) == .Ladder) {
                        endX -= 16;
                    } else if (level.getTileFloor(tileX + 1, tileY) == .Ladder) {
                        endX += 16;
                    }
                    else
                    {
                        std.log.err("No ladder found for adjustment!!!!", .{});
                    }
                }
                // put player in the middle of the new tile
                endX = @as(i16, @bitCast(@as(u16, @bitCast(endX)) & 0xFFF0)) + 8;

                player.sprite.x = endX;
                if (player.y_axis > 0) {
                    player.sprite.speed_y = 4 * 16;
                } else {
                    player.sprite.speed_y = 0 - (4 * 16);
                }
            } else {
                player.sprite.speed_y = 0;
            }
        },
        .Grab, .Grab_Carry => {
            // Take a box
            NEW_FORM(player, action);
            GET_IMAGE(level);
            player_friction(player);
            if (!globals.POSEREADY_FLAG) {
                if (globals.ACTION_TIMER == 1 and globals.CARRY_FLAG) {
                    // If the object is placed in a block, fix a speed_x
                    const maybe_object = player_drop_carried(level);
                    if (maybe_object) |object| {
                        tileX = object.sprite.x >> 4;
                        tileY = object.sprite.y >> 4;
                        var fflag = level.getTileFloor(tileX, tileY);
                        if (fflag != .NoFloor and fflag != .Water) {
                            tileX +%= 1;
                            fflag = level.getTileFloor(tileX, tileY);
                            if (fflag != .NoFloor and fflag != .Water) {
                                object.*.sprite.speed_x = 16 * 3;
                            } else {
                                object.*.sprite.speed_x = 0 - (16 * 3);
                            }
                        }
                    }
                } else {
                    if (!globals.CARRY_FLAG) {
                        for (&level.object) |*object| {
                            // First do a quick test
                            if (!object.sprite.enabled or @abs(player.sprite.y - object.sprite.y) >= 20) {
                                continue;
                            }
                            diffX = player.sprite.x - object.sprite.x;
                            if (!player.sprite.flipped) {
                                diffX = 0 - diffX;
                            }
                            if (data.game == .Moktar) {
                                if (diffX >= 25) {
                                    continue;
                                }
                            } else if (data.game == .Titus) {
                                if (diffX >= 20) {
                                    continue;
                                }
                            }

                            // X distance check
                            if (object.sprite.x > player.sprite.x) { // The object is right
                                if (object.sprite.x > player.sprite.x + 32) {
                                    continue; // The object is too far right
                                }
                            } else { // The object is left
                                if (object.sprite.x + object.sprite.spritedata.?.collwidth < player.*.sprite.x) {
                                    continue; // The object is too far left
                                }
                            }

                            // Y distance check
                            if (object.sprite.y < player.sprite.y) {
                                if (object.sprite.y <= player.sprite.y - 10) {
                                    continue;
                                }
                            } else {
                                if (object.sprite.y - object.sprite.spritedata.?.collheight + 1 >= player.*.sprite.y) {
                                    continue;
                                }
                            }

                            // Take the object
                            events.triggerEvent(.Event_PlayerPickup);
                            globals.FUME_FLAG = 0;
                            object.sprite.speed_y = 0;
                            object.sprite.speed_x = 0;
                            globals.GRAVITY_FLAG = 4;
                            sprites.copysprite(level, &player.*.sprite2, &object.sprite);
                            object.sprite.enabled = false;
                            globals.CARRY_FLAG = true;
                            globals.SEECHOC_FLAG = 0;
                            if (player.sprite2.number == globals.FIRST_OBJET + 19) { // flying carpet
                                globals.TAPISWAIT_FLAG = 0;
                            }
                            player.sprite2.y = player.sprite.y - 4;
                            if (player.sprite.flipped) {
                                player.sprite2.x = player.sprite.x - 10;
                            } else {
                                player.sprite2.x = player.sprite.x + 12;
                            }
                            break;
                        }
                        if (!globals.CARRY_FLAG) { // No objects taken, check if he picks up an enemy!
                            for (&level.enemy) |*enemy| {
                                if (!enemy.sprite.enabled or @abs(player.sprite.y - enemy.sprite.y) >= 20) {
                                    continue;
                                }
                                diffX = player.sprite.x - enemy.sprite.x;
                                if (!player.sprite.flipped) {
                                    diffX = 0 - diffX;
                                }
                                if (data.game == .Moktar) {
                                    if (diffX >= 25) {
                                        continue;
                                    }
                                } else if (data.game == .Titus) {
                                    if (diffX >= 20) {
                                        continue;
                                    }
                                }

                                // The ordinary test
                                if (enemy.carry_sprite == -1) {
                                    continue;
                                }

                                // X
                                if (enemy.sprite.x > player.sprite.x) { // The enemy is right
                                    if (enemy.sprite.x > player.sprite.x + 32) {
                                        continue; // The enemy is too far right
                                    }
                                } else { // The enemy is left
                                    if (enemy.sprite.x + enemy.sprite.spritedata.?.collwidth < player.sprite.x) {
                                        continue; // The enemy is too far left
                                    }
                                }

                                // Y
                                if (enemy.sprite.y < player.sprite.y) { // The enemy is above
                                    if (enemy.sprite.y <= player.sprite.y - 10) {
                                        continue;
                                    }
                                } else { // The enemy is below
                                    if (enemy.sprite.y - enemy.sprite.spritedata.?.collheight - 1 >= player.sprite.y) {
                                        continue;
                                    }
                                }

                                if (enemy.sprite.number >= globals.FIRST_NMI) {
                                    diffX = player.*.sprite.x - enemy.sprite.x;
                                    if (enemy.sprite.flipped) {
                                        diffX = -diffX;
                                    }
                                    if (diffX < 0) {
                                        continue;
                                    }
                                }

                                events.triggerEvent(.Event_PlayerPickupEnemy);
                                globals.FUME_FLAG = 0;
                                enemy.sprite.speed_y = 0;
                                enemy.sprite.speed_x = 0;
                                globals.GRAVITY_FLAG = 4;
                                player.*.sprite2.flipped = enemy.sprite.flipped;
                                player.*.sprite2.flash = enemy.sprite.flash;
                                player.*.sprite2.invincibility_frames = enemy.sprite.invincibility_frames;
                                player.*.sprite2.visible = enemy.sprite.visible;
                                sprites.updatesprite(level, &player.sprite2, enemy.carry_sprite, false);
                                enemy.sprite.enabled = false;
                                globals.CARRY_FLAG = true;
                                globals.SEECHOC_FLAG = 0;
                                player.sprite2.y = player.sprite.y - 4;
                                if (player.sprite.flipped) {
                                    player.sprite2.x = player.sprite.x - 10;
                                } else {
                                    player.sprite2.x = player.*.sprite.x + 12;
                                }
                                break;
                            } // for loop, enemy
                        } // condition (!CARRY_FLAG), check for enemy pickup
                    } // condition (!CARRY_FLAG), check for object/enemy pickup
                } // condition ((ACTION_TIMER == 1) and (CARRY_FLAG)),
            } // condition (POSEREADY_FLAG == 0)
            globals.POSEREADY_FLAG = true;
        },
        .Drop, .Drop_Carry => {
            // Throw
            NEW_FORM(player, action);
            GET_IMAGE(level);
            player_friction(player);

            if (!globals.CARRY_FLAG)
                return;

            if (player.aim_direction == .Forward) {
                speed_x = 0x0E * 16;
                speed_y = 0;
                if (player.*.sprite.flipped) {
                    speed_x = -speed_x;
                }
                player.sprite2.y = player.sprite.y - 16;
            } else {
                speed_x = 0;
                speed_y = -0x0A * 16;
            }
            if (speed_y != 0) {
                // Throw up
                if (player_drop_carried(level)) |object| {
                    object.sprite.speed_y = speed_y;
                    object.sprite.speed_x = speed_x - speed_x >> 2;
                }
            } else {
                if (player.sprite2.number < globals.FIRST_NMI) {
                    if (level.objectdata[@intCast(player.sprite2.number - globals.FIRST_OBJET)].gravity) {
                        // Gravity throw
                        if (player_drop_carried(level)) |object| {
                            object.*.sprite.speed_y = speed_y;
                            object.*.sprite.speed_x = speed_x - (speed_x >> 2);
                            events.triggerEvent(.Event_PlayerThrow);
                        }
                    } else { // Ordinary throw
                        globals.DROP_FLAG = true;
                        player.sprite2.speed_x = speed_x;
                        player.sprite2.speed_y = speed_y;
                        events.triggerEvent(.Event_PlayerThrow);
                    }
                } else { // Ordinary throw
                    globals.DROP_FLAG = true;
                    player.sprite2.speed_x = speed_x;
                    player.sprite2.speed_y = speed_y;
                    events.triggerEvent(.Event_PlayerThrow);
                }
            }
            sprites.updatesprite(level, &player.sprite, 10, true); // The same as in free fall
            player.sprite.flipped = globals.SENSX < 0;
            globals.CARRY_FLAG = false;
        },
        .SilentWalk => {
            XACCELERATION(player, (globals.MAX_X - 1) * 16);
            NEW_FORM(player, action);
            GET_IMAGE(level);
        },
        .Headache => {
            player.*.sprite.speed_x = 0;
            NEW_FORM(player, action);
            GET_IMAGE(level);
        },
        .Hit, .HitBurn, .Hit_Carry, .HitBurn_Carry => {
            YACCELERATION(player, globals.MAX_Y * 16);
            NEW_FORM(player, action);
            GET_IMAGE(level);
        },
        .KneeStand_Carry => {
            NEW_FORM(player, action);
            GET_IMAGE(level);
            player_friction(player);
        },
        .Headache_Carry => {
            _ = player_drop_carried(level);
            player.*.sprite.speed_x = 0;
            NEW_FORM(player, action);
            GET_IMAGE(level);
        },
        else => {},
    }
}

fn player_friction(player: *lvl.Player) void {
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

fn NEW_FORM(player: *lvl.Player, action: PlayerAction) void {
    // if the order is changed, change player animation
    if (globals.LAST_ORDER != action or player.sprite.animation == null) {
        globals.LAST_ORDER = action;
        player.sprite.animation = data.get_anim_player(action);
    }
}

fn GET_IMAGE(level: *lvl.Level) void {
    const player = &level.player;
    var frame: i16 = player.sprite.animation.*;
    if (@as(c_int, @bitCast(@as(c_int, frame))) < 0) {
        if (@as(c_int, @bitCast(@as(c_int, frame))) == -1) {
            std.log.err("Player frame is -1, advancing by {}\n", .{@divTrunc(@as(c_int, frame), 2)});
        }
        player.*.sprite.animation += @as(usize, @bitCast(@as(isize, @intCast(@divTrunc(@as(c_int, frame), 2)))));
        frame = player.*.sprite.animation.*;
    }
    sprites.updatesprite(level, &player.*.sprite, frame, true);
    player.*.sprite.flipped = @as(c_int, @bitCast(@as(c_int, globals.SENSX))) < 0;
    player.*.sprite.animation += 1;
}

fn YACCELERATION_NEG(player: *lvl.Player, maxspeed_in: i16) void {
    // Accelerate upwards
    const maxspeed = 0 - maxspeed_in;
    var speed: i16 = player.sprite.speed_y - 32;
    if (speed >= maxspeed) {
        speed = maxspeed;
    }
    player.sprite.speed_y = speed;
}

fn player_collide_with_elevators(level: *lvl.Level) void {
    // Player versus elevators
    // Change player's location according to the elevator
    const player = &level.player;
    if (player.sprite.speed_y < 0 or globals.CROSS_FLAG != 0)
        return;

    for (&level.elevator) |*elevator| {
        if (!elevator.enabled or !elevator.sprite.visible)
            continue;
        if (@abs(elevator.sprite.x - player.sprite.x) >= 64 or @abs(elevator.sprite.y - player.sprite.y) >= 16) {
            continue;
        }
        if (player.sprite.x - level.spritedata[0].refwidth < elevator.sprite.x) { // The elevator is right
            if (player.sprite.x - level.spritedata[0].refwidth + level.spritedata[0].collwidth <= elevator.sprite.x) { // player->sprite must be 0
                continue; // The elevator is too far right
            }
        } else { // The elevator is left
            if (player.sprite.x - level.spritedata[0].refwidth >= elevator.sprite.x + elevator.sprite.spritedata.?.collwidth) {
                continue; // The elevator is too far left
            }
        }
        if (player.sprite.y - 6 < elevator.sprite.y) { // The elevator is below
            if ((player.sprite.y - 6 + 8) <= elevator.sprite.y) {
                continue; // The elevator is too far below
            }
        } else { // The elevator is above
            if (player.sprite.y - 6 >= elevator.sprite.y + elevator.sprite.spritedata.?.collheight) {
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
        common.subto0(&globals.jump_timer);
        globals.jump_acceleration_counter = 0;
        globals.YFALL = 2;

        player.sprite.x += elevator.sprite.speed_x;
        if (elevator.sprite.speed_y > 0) {
            // Going down
            player.sprite.y += elevator.sprite.speed_y;
        }
        return;
    }
}

// Player versus objects
// Collision, spring state, speed up carpet/scooter/skateboard, bounce bouncy
// objects
fn player_collide_with_objects(level: *lvl.Level) void {
    const player = &level.player;
    if (player.sprite.speed_y < 0) {
        return;
    }
    // Collision with a sprite
    var off_object_c: *lvl.Object = undefined;
    if (!objects.SPRITES_VS_SPRITES(level, &player.sprite, &level.spritedata[@as(c_uint, @intCast(0))], &off_object_c)) {
        return;
    }
    const off_object: *lvl.Object = off_object_c;

    player.sprite.y = off_object.sprite.y - off_object.sprite.spritedata.?.collheight;
    // If the foot is placed on a spring, it must be soft!
    if (off_object.sprite.number == globals.FIRST_OBJET + 24 or off_object.sprite.number == globals.FIRST_OBJET + 25) {
        off_object.sprite.UNDER = off_object.sprite.UNDER | 0x02;
        off_object.sprite.ONTOP = &player.sprite;
    }
    // If we jump on the flying carpet, let it fly
    if (off_object.sprite.number == globals.FIRST_OBJET + 21 or off_object.sprite.number == globals.FIRST_OBJET + 22) {
        if (!player.sprite.flipped) {
            off_object.sprite.speed_x = 6 * 16;
        } else {
            off_object.sprite.speed_x = 0 - (6 * 16);
        }
        off_object.sprite.flipped = player.sprite.flipped;
        globals.GRAVITY_FLAG = 4;
        globals.TAPISWAIT_FLAG = 0;
    } else if (globals.ACTION_TIMER > 10 and
        globals.LAST_ORDER.withoutCarry() == .Rest and
        player.sprite.speed_y == 0 and
        (off_object.sprite.number == 83 or off_object.sprite.number == 94))
    {
        if (!player.*.sprite.flipped) {
            off_object.sprite.speed_x = 16 * 3;
        } else {
            off_object.sprite.speed_x = 0 - (16 * 3);
        }
        off_object.sprite.flipped = player.sprite.flipped;
        globals.GRAVITY_FLAG = 4;
    }
    if (off_object.sprite.speed_x < 0) {
        player.sprite.speed_x = off_object.sprite.speed_x;
    } else if (off_object.sprite.speed_x > 0) {
        player.sprite.speed_x = off_object.sprite.speed_x + 16;
    }

    // If we want to CROSS (cross) it does not bounce
    if (globals.CROSS_FLAG == 0 and // No long kneestand
        (player.sprite.speed_y > 16 * 3) and off_object.objectdata.*.bounce)
    {
        // Bounce on a ball if no long kneestand (down key)
        if (player.y_axis > 0) {
            player.sprite.speed_y = 0;
        } else {
            if (player.y_axis < 0 or player.jump_pressed) {
                player.sprite.speed_y += 16 * 3; // increase speed
            } else {
                player.sprite.speed_y -= 16; // reduce speed
            }
            player.sprite.speed_y = 0 - player.sprite.speed_y;
            if (player.sprite.speed_y > 0) {
                player.sprite.speed_y = 0;
            }
        }
        globals.ACTION_TIMER = 0;

        // If the ball lies on the ground
        if (off_object.sprite.speed_y == 0) {
            events.triggerEvent(.Event_BallBounce);
            off_object.sprite.speed_y = 0 - player.sprite.speed_y;
            off_object.sprite.y -= off_object.sprite.speed_y >> 4;
            globals.GRAVITY_FLAG = 4;
        }
    } else {
        if (off_object.sprite.speed_y != 0) {
            player.sprite.speed_y = off_object.sprite.speed_y;
        } else {
            player.sprite.speed_y = 0;
        }
        common.subto0(&globals.jump_timer);
        globals.jump_acceleration_counter = 0;
        globals.YFALL = 2;
    }
}
