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

const SDL = @import("../SDL.zig");

const sqz = @import("../sqz.zig");
const image = @import("image.zig");
const window = @import("../window.zig");
const data = @import("../data.zig");
const game = @import("../game.zig");
const fonts = @import("fonts.zig");
const render = @import("../render.zig");
const ImageFile = image.ImageFile;

// TODO: redo all UI
// - Add settings menu
// - Remove level code input and replace it with level select
// - Levels are unlocked by collecting the locks and the unlock state is persisted on disk instead of codes
// - Add pause menu
// - Esc opens pause menu instead of instant quit

pub fn view_menu(file: ImageFile, allocator: std.mem.Allocator) !?usize {
    var selection: usize = 0;

    const menudata = try sqz.unSQZ(file.filename, allocator);
    var image_memory = try image.loadImage(menudata, file.format, allocator);
    defer image_memory.deinit();
    const menu = image_memory.value;

    var src = SDL.Rect{
        .x = 0,
        .y = 0,
        .w = menu.*.w,
        .h = menu.*.h,
    };

    var dest = SDL.Rect{
        .x = 0,
        .y = 0,
        .w = menu.*.w,
        .h = menu.*.h,
    };

    var sel: [2]SDL.Rect = undefined;
    var sel_dest: [2]SDL.Rect = undefined;

    if (data.game == .Titus) {
        sel[0].x = 120;
        sel[0].y = 160;
        sel[0].w = 8;
        sel[0].h = 8;

        sel[1].x = 120;
        sel[1].y = 173;
        sel[1].w = 8;
        sel[1].h = 8;
    } else if (data.game == .Moktar) {
        sel[0].x = 130;
        sel[0].y = 167;
        sel[0].w = 8;
        sel[0].h = 8;

        sel[1].x = 130;
        sel[1].y = 180;
        sel[1].w = 8;
        sel[1].h = 8;
    }
    sel_dest[0] = sel[0];
    //sel_dest[0].x += 16;
    sel_dest[1] = sel[1];
    //sel_dest[1].x += 16;

    // FIXME: move to render.zig
    const fade_time = 1000;
    var image_alpha: u64 = 0;
    const tick_start = SDL.getTicks();

    // Fade in
    while (image_alpha < 255) {
        var event: SDL.Event = undefined;
        while (SDL.pollEvent(&event)) {
            if (event.type == SDL.EVENT_QUIT) {
                return null;
            }

            if (event.type == SDL.EVENT_KEY_DOWN) {
                if (event.key.scancode == SDL.SCANCODE_ESCAPE) {
                    return null;
                }
                if (event.key.scancode == SDL.SCANCODE_F11) {
                    window.toggle_fullscreen();
                }
            }
        }

        image_alpha = (SDL.getTicks() - tick_start) * 256 / fade_time;

        if (image_alpha > 255)
            image_alpha = 255;

        window.window_clear(null);
        // FIXME: handle errors?
        _ = SDL.setSurfaceBlendMode(menu, SDL.BLENDMODE_BLEND);
        _ = SDL.setSurfaceAlphaMod(menu, @truncate(image_alpha));
        _ = SDL.blitSurface(menu, &src, window.screen, &dest);
        _ = SDL.blitSurface(menu, &sel[1], window.screen, &sel_dest[0]);
        _ = SDL.blitSurface(menu, &sel[0], window.screen, &sel_dest[selection]);
        window.window_render();
        SDL.delay(1);
    }

    var curlevel: ?usize = null;
    // View the menu
    MENULOOP: while (true) {
        var event: SDL.Event = undefined;
        while (SDL.pollEvent(&event)) {
            if (event.type == SDL.EVENT_QUIT) {
                return null;
            }

            if (event.type == SDL.EVENT_KEY_DOWN) {
                if (event.key.scancode == SDL.SCANCODE_ESCAPE) {
                    return null;
                }
                if (event.key.scancode == SDL.SCANCODE_UP)
                    selection = 0;
                if (event.key.scancode == SDL.SCANCODE_DOWN)
                    selection = 1;
                if (event.key.scancode == SDL.SCANCODE_RETURN or
                    event.key.scancode == SDL.SCANCODE_KP_ENTER or
                    event.key.scancode == SDL.SCANCODE_SPACE)
                {
                    switch (selection) {
                        0 => {
                            curlevel = 0;
                            break :MENULOOP;
                        },
                        1 => {
                            curlevel = try select_level(allocator);
                            if (curlevel != null) {
                                break :MENULOOP;
                            }
                            // retval = enterpassword(levelcount);

                            // if (retval < 0)
                            //     return retval;

                            // if (retval > 0) {
                            //     curlevel = retval;
                            // }
                            // selection = 0;
                        },
                        // TODO: implement options menu
                        else => {
                            unreachable;
                        },
                    }
                }

                if (event.key.scancode == SDL.SCANCODE_F11) {
                    window.toggle_fullscreen();
                }
            }
        }

        window.window_clear(null);
        _ = SDL.blitSurface(menu, &src, window.screen, &dest);
        _ = SDL.blitSurface(menu, &sel[1], window.screen, &sel_dest[0]);
        _ = SDL.blitSurface(menu, &sel[0], window.screen, &sel_dest[selection]);
        window.window_render();
        SDL.delay(1);
    }

    // Close the menu
    render.fadeout();
    return curlevel;
}

fn select_level(allocator: std.mem.Allocator) !?usize {
    const LevelSelect = struct {
        unlocked: bool,
        text: []const u8,
        font: *fonts.Font,
        width: u16,
        y: c_int,
    };
    var level_list = try std.ArrayList(LevelSelect).initCapacity(allocator, data.constants.levelfiles.len);
    defer level_list.deinit();

    var selection: usize = 0;
    var max_width: c_int = 0;

    for (data.constants.levelfiles, 0..) |level, i| {
        const y: c_int = @intCast(i * 13);
        const known = game.game_state.isKnown(i);
        if (!known) {
            const width = fonts.Gray.metrics("...", .{});
            if (width > max_width) {
                max_width = width;
            }
            level_list.append(LevelSelect{
                .unlocked = false,
                .text = "...",
                .font = &fonts.Gray,
                .width = width,
                .y = y,
            }) catch {
                // already inited up to capacity, this is fine
                unreachable;
            };
            break;
        }
        const unlocked = game.game_state.isUnlocked(i);
        const font = if (unlocked) &fonts.Gold else &fonts.Gray;
        const width = font.metrics(level.title, .{});
        if (width > max_width) {
            max_width = width;
        }
        level_list.append(LevelSelect{
            .unlocked = unlocked,
            .text = level.title,
            .font = font,
            .width = width,
            .y = y,
        }) catch {
            // already inited up to capacity, this is fine
            unreachable;
        };
    }

    while (true) {
        var event: SDL.Event = undefined;
        while (SDL.pollEvent(&event)) {
            if (event.type == SDL.EVENT_QUIT) {
                return null;
            }

            if (event.type == SDL.EVENT_KEY_DOWN) {
                if (event.key.scancode == SDL.SCANCODE_ESCAPE) {
                    return null;
                }
                if (event.key.scancode == SDL.SCANCODE_DOWN) {
                    if (selection < level_list.items.len - 1) {
                        selection += 1;
                    }
                }
                if (event.key.scancode == SDL.SCANCODE_UP) {
                    if (selection > 0) {
                        selection -= 1;
                    }
                }
                if (event.key.scancode == SDL.SCANCODE_RETURN) {
                    if (game.game_state.isUnlocked(selection)) {
                        return selection;
                    } else {}
                }

                if (event.key.scancode == SDL.SCANCODE_F11) {
                    window.toggle_fullscreen();
                }
            }
        }

        // TODO: render this nicer...
        window.window_clear(null);
        for (level_list.items, 0..) |level, i| {
            if (selection == i) {
                const x = 160 - level.width / 2;
                level.font.render(level.text, x, level.y, .{});
                const left = ">";
                const right = "<";
                const left_width = fonts.Gold.metrics(left, .{});
                fonts.Gold.render(left, x - 4 - left_width, level.y, .{});
                fonts.Gold.render(right, x + level.width + 4, level.y, .{});
            } else {
                level.font.render_center(level.text, level.y, .{});
            }
        }
        window.window_render();
        SDL.delay(1);
    }
}
