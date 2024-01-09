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

const c = @import("../c.zig");
const sqz = @import("../sqz.zig");
const image = @import("image.zig");
const window = @import("../window.zig");
const ImageFile = image.ImageFile;

// TODO: redo all UI
// - Add settings menu
// - Remove level code input and replace it with level select
// - Levels are unlocked by collecting the locks and the unlock state is persisted on disk instead of codes
// - Add pause menu
// - Esc opens pause menu instead of instant quit

pub fn viewMenu(file: ImageFile, allocator: std.mem.Allocator) !c_int {
    var selection: usize = 0;
    var curlevel: c_int = 1;

    var fade_time: c_uint = 1000;
    var tick_start: c_uint = 0;
    var image_alpha: c_uint = 0;

    var menudata = try sqz.unSQZ2(file.filename, allocator);
    var image_memory = try image.loadImage(menudata, file.format, allocator);
    defer image_memory.deinit();
    var menu = image_memory.value;

    var src = c.SDL_Rect{
        .x = 0,
        .y = 0,
        .w = menu.*.w,
        .h = menu.*.h,
    };

    var dest = c.SDL_Rect{
        .x = 0,
        .y = 0,
        .w = menu.*.w,
        .h = menu.*.h,
    };

    var sel: [2]c.SDL_Rect = undefined;
    var sel_dest: [2]c.SDL_Rect = undefined;

    if (c.game == c.Titus) {
        sel[0].x = 120;
        sel[0].y = 160;
        sel[0].w = 8;
        sel[0].h = 8;

        sel[1].x = 120;
        sel[1].y = 173;
        sel[1].w = 8;
        sel[1].h = 8;
    } else if (c.game == c.Moktar) {
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

    tick_start = c.SDL_GetTicks();

    while (image_alpha < 255) { //Fade in
        var event: c.SDL_Event = undefined;
        if (c.SDL_PollEvent(&event) != c.SDL_FALSE) {
            if (event.type == c.SDL_QUIT) {
                return (-1);
            }

            if (event.type == c.SDL_KEYDOWN) {
                if (event.key.keysym.scancode == c.SDL_SCANCODE_ESCAPE) {
                    return (-1);
                }
                if (event.key.keysym.scancode == c.KEY_FULLSCREEN) {
                    window.window_toggle_fullscreen();
                }
            }
        }

        image_alpha = (c.SDL_GetTicks() - tick_start) * 256 / fade_time;

        if (image_alpha > 255)
            image_alpha = 255;

        window.window_clear(null);
        // FIXME: handle errors?
        _ = c.SDL_SetSurfaceBlendMode(menu, c.SDL_BLENDMODE_BLEND);
        _ = c.SDL_SetSurfaceAlphaMod(menu, @truncate(image_alpha));
        _ = c.SDL_BlitSurface(menu, &src, window.screen, &dest);
        _ = c.SDL_BlitSurface(menu, &sel[1], window.screen, &sel_dest[0]);
        _ = c.SDL_BlitSurface(menu, &sel[0], window.screen, &sel_dest[selection]);
        window.window_render();
        c.SDL_Delay(1);
    }

    // View the menu
    MENULOOP: while (true) {
        var event: c.SDL_Event = undefined;
        if (c.SDL_PollEvent(&event) != c.SDL_FALSE) {
            if (event.type == c.SDL_QUIT) {
                return (-1);
            }

            if (event.type == c.SDL_KEYDOWN) {
                if (event.key.keysym.scancode == c.SDL_SCANCODE_ESCAPE) {
                    return (-1);
                }
                if (event.key.keysym.scancode == c.SDL_SCANCODE_UP)
                    selection = 0;
                if (event.key.keysym.scancode == c.SDL_SCANCODE_DOWN)
                    selection = 1;
                if (event.key.keysym.scancode == c.KEY_RETURN or event.key.keysym.scancode == c.KEY_ENTER or event.key.keysym.scancode == c.KEY_SPACE) {
                    switch (selection) {
                        0 => break :MENULOOP,
                        1 => {
                            // TODO: implement level select sub-menu
                            // retval = enterpassword(levelcount);

                            // if (retval < 0)
                            //     return retval;

                            // if (retval > 0) {
                            //     curlevel = retval;
                            // }
                            selection = 0;
                        },
                        else => {
                            unreachable;
                        },
                    }
                }

                if (event.key.keysym.scancode == c.KEY_FULLSCREEN) {
                    window.window_toggle_fullscreen();
                }
            }
        }

        window.window_clear(null);
        _ = c.SDL_BlitSurface(menu, &src, window.screen, &dest);
        _ = c.SDL_BlitSurface(menu, &sel[1], window.screen, &sel_dest[0]);
        _ = c.SDL_BlitSurface(menu, &sel[0], window.screen, &sel_dest[selection]);
        window.window_render();
        c.SDL_Delay(1);
    }

    // Close the menu
    tick_start = c.SDL_GetTicks();
    image_alpha = 0;
    while (image_alpha < 255) { //Fade out
        var event: c.SDL_Event = undefined;
        if (c.SDL_PollEvent(&event) != c.SDL_FALSE) {
            if (event.type == c.SDL_QUIT) {
                return (-1);
            }

            if (event.type == c.SDL_KEYDOWN) {
                if (event.key.keysym.scancode == c.SDL_SCANCODE_ESCAPE) {
                    return (-1);
                }
                if (event.key.keysym.scancode == c.KEY_FULLSCREEN) {
                    window.window_toggle_fullscreen();
                }
                // TODO: add a way to activate devmode from here (cheat code style using state machine)
            }
        }

        image_alpha = (c.SDL_GetTicks() - tick_start) * 256 / fade_time;

        if (image_alpha > 255)
            image_alpha = 255;

        window.window_clear(null);
        _ = c.SDL_SetSurfaceBlendMode(menu, c.SDL_BLENDMODE_BLEND);
        _ = c.SDL_SetSurfaceAlphaMod(menu, 255 - @as(u8, @truncate(image_alpha)));
        _ = c.SDL_BlitSurface(menu, &src, window.screen, &dest);
        _ = c.SDL_FillRect(window.screen, &sel_dest[0], 0); //SDL_MapRGB(surface->format, 0, 0, 0));
        _ = c.SDL_BlitSurface(menu, &sel[0], window.screen, &sel_dest[selection]);
        window.window_render();
        c.SDL_Delay(1);
    }

    return (curlevel);
}

// int enterpassword(int levelcount){
//     int retval;
//     char code[] = "____";
//     int i = 0;

//     window_clear(NULL);

//     text_render("CODE", 111, 80, false);

//     while (i < 4) {
//         SDL_Event event;
//         while(SDL_PollEvent(&event)) { //Check all events
//             if (event.type == SDL_QUIT) {
//                 return (-1);
//             }

//             if (event.type == SDL_KEYDOWN) {
//                 switch (event.key.keysym.scancode) {
//                     case SDL_SCANCODE_0:
//                         code[i++] = '0';
//                         break;
//                     case SDL_SCANCODE_1:
//                         code[i++] = '1';
//                         break;
//                     case SDL_SCANCODE_2:
//                         code[i++] = '2';
//                         break;
//                     case SDL_SCANCODE_3:
//                         code[i++] = '3';
//                         break;
//                     case SDL_SCANCODE_4:
//                         code[i++] = '4';
//                         break;
//                     case SDL_SCANCODE_5:
//                         code[i++] = '5';
//                         break;
//                     case SDL_SCANCODE_6:
//                         code[i++] = '6';
//                         break;
//                     case SDL_SCANCODE_7:
//                         code[i++] = '7';
//                         break;
//                     case SDL_SCANCODE_8:
//                         code[i++] = '8';
//                         break;
//                     case SDL_SCANCODE_9:
//                         code[i++] = '9';
//                         break;
//                     case SDL_SCANCODE_A:
//                         code[i++] = 'A';
//                         break;
//                     case SDL_SCANCODE_B:
//                         code[i++] = 'B';
//                         break;
//                     case SDL_SCANCODE_C:
//                         code[i++] = 'C';
//                         break;
//                     case SDL_SCANCODE_D:
//                         code[i++] = 'D';
//                         break;
//                     case SDL_SCANCODE_E:
//                         code[i++] = 'E';
//                         break;
//                     case SDL_SCANCODE_F:
//                         code[i++] = 'F';
//                         break;
//                     case SDL_SCANCODE_BACKSPACE:
//                         if(i > 0) {
//                             code[i--] = '\0';
//                         }
//                         break;
//                     default:
//                         break;
//                 }
//                 if (event.key.keysym.scancode == SDL_SCANCODE_ESCAPE) {
//                     return (-1);
//                 }

//                 if (event.key.keysym.scancode == KEY_FULLSCREEN) {
//                     window_toggle_fullscreen();
//                 }
//             }
//         }
//         text_render(code, 159, 80, true);
//         window_render();
//         SDL_Delay(1);
//     }

//     i = levelForCode(code);
//     if (i != -1 && i < levelcount) {
//         if (game == Titus) {
//             text_render("Level", 103, 104, false);
//         } else if (game == Moktar) {
//             text_render("Etape", 103, 104, false);
//         }
//         sprintf(code, "%d", i + 1);
//         size_t code_width = text_width(code, false);
//         text_render(code, 199 - code_width, 104, false);
//         window_render();
//         retval = waitforbutton();

//         if (retval < 0)
//             return retval;

//         window_clear(NULL);
//         window_render();

//         return (i + 1);
//     }

//     text_render("!  WRONG CODE  !", 87, 104, false);
//     window_render();
//     retval = waitforbutton();

//     window_clear(NULL);
//     window_render();
//     return (retval);
// }
