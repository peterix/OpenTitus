//
// Copyright (C) 2008 - 2025 The OpenTitus team
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
const Allocator = std.mem.Allocator;

const SDL = @import("SDL.zig");

const globals = @import("globals.zig");
const window = @import("window.zig");
const events = @import("events.zig");
const game = @import("game.zig");
const GameEvent = events.GameEvent;

pub const InputMode = enum(u8) {
    Modern,
    Classic,

    pub const NameTable = [@typeInfo(InputMode).@"enum".fields.len][]const u8{
        "Modern",
        "Classic",
    };

    pub fn str(self: InputMode) []const u8 {
        return NameTable[@intFromEnum(self)];
    }
};

pub fn getInputMode() InputMode {
    return game.settings.input_mode;
}

pub fn setInputMode(input_mode: InputMode) void {
    game.settings.input_mode = input_mode;
    // FIXME: save the file
}

pub const InputAction = enum {
    None,
    Quit,
    ToggleMenu,
    Left,
    Right,
    Up,
    Down,
    Activate,
    Escape,
    Cancel,
    Status,
};

pub const InputDevice = enum {
    None,
    Keyboard,
    Gamepad,
};

pub const GamepadState = struct {
    handle: *SDL.Gamepad = undefined,
    id: SDL.JoystickID = undefined,
    has_rumble: bool = false,
    has_trigger_rumble: bool = false,

    dpad_up_pressed: bool = false,
    dpad_down_pressed: bool = false,
    dpad_left_pressed: bool = false,
    dpad_right_pressed: bool = false,
    north_pressed: bool = false,
    south_pressed: bool = false,
    east_pressed: bool = false,
    west_pressed: bool = false,
    left_shoulder_pressed: bool = false,
    right_shoulder_pressed: bool = false,

    left_stick_pressed: bool = false,
    left_stick_virtual_up_pressed: bool = false,
    left_stick_virtual_down_pressed: bool = false,
    left_stick_virtual_left_pressed: bool = false,
    left_stick_virtual_right_pressed: bool = false,
    right_stick_pressed: bool = false,

    left_trigger: f32 = 0,
    left_trigger_virtual_button_pressed: bool = false,
    right_trigger: f32 = 0,
    right_trigger_virtual_button_pressed: bool = false,

    left_x: f32 = 0,
    left_y: f32 = 0,
    right_x: f32 = 0,
    right_y: f32 = 0,

    fn rumbleGamepad(self: GamepadState, left: f32, right: f32, duration_ms: u32) void {
        const left_i: u16 = @intFromFloat(std.math.lerp(0, 0xFFFF, left));
        const right_i: u16 = @intFromFloat(std.math.lerp(0, 0xFFFF, right));
        if(self.has_rumble) {
            if(!SDL.rumbleGamepad(self.handle, left_i, right_i, duration_ms))
            {
                std.log.err("Gamepad {} failed to rumble: {s}", .{self.id, SDL.getError()});
            }
        }
        else if(self.has_trigger_rumble) {
            if(!SDL.rumbleGamepadTriggers(self.handle, left_i, right_i, duration_ms))
            {
                std.log.err("Gamepad {} failed to rumble triggers: {s}", .{self.id, SDL.getError()});
            }
        }
    }

    fn rumbleTriggers(self: GamepadState, left: f32, right: f32, duration_ms: u32) void {
        const left_i: u16 = @intFromFloat(std.math.lerp(0, 0xFFFF, left));
        const right_i: u16 = @intFromFloat(std.math.lerp(0, 0xFFFF, right));
        if(self.has_trigger_rumble) {
            if(!SDL.rumbleGamepadTriggers(self.handle, left_i, right_i, duration_ms))
            {
                std.log.err("Gamepad {} failed to rumble triggers: {s}", .{self.id, SDL.getError()});
            }
        }
        else if(self.has_rumble) {
            if(!SDL.rumbleGamepad(self.handle, left_i, right_i, duration_ms))
            {
                std.log.err("Gamepad {} failed to rumble: {s}", .{self.id, SDL.getError()});
            }
        }
    }

    pub fn triggerRumble(self: GamepadState, event: GameEvent) void {


        switch (event) {
            .Event_HitEnemy =>
            {
                self.rumbleGamepad(0.25, 0.25, 150);
            },
            .Event_HitPlayer =>
            {
                self.rumbleGamepad(1.0, 1.0, 75);
            },
            .Event_PlayerHeadImpact =>
            {
                self.rumbleGamepad(0.33, 0.33, 800);
            },
            .Event_PlayerPickup,
            .Event_PlayerPickupEnemy,
            .Event_PlayerThrow => {
                self.rumbleTriggers(0.25, 0.25, 100);
            },
            .Event_PlayerCollectWaypoint,
            .Event_PlayerCollectBonus,
            .Event_PlayerCollectLamp =>
            {
                self.rumbleGamepad(0.1, 0.1, 100);
            },
            .Event_PlayerJump => {
                //self.rumbleGamepad(6000, 6000, 100);
            },
            .Event_BallBounce => {
                self.rumbleGamepad(0.25, 0.25, 150);
            },
        }
    }
};

const GamepadMap = std.AutoHashMap(SDL.JoystickID, GamepadState);

pub const AimDirection = enum(u8) {
    Forward,
    Up,
};

pub const InputState = struct {
    should_redraw: bool = false,
    any_key_pressed: bool = false,

    action: InputAction = .None,
    device: InputDevice = .None,

    // Player input this frame
    x_axis: i8 = 0,
    y_axis: i8 = 0,
    action_pressed: bool = false,
    jump_pressed: bool = false,
    crouch_pressed: bool = false,
    aim_direction: AimDirection = .Forward,

    gamepad_map: GamepadMap = undefined,
    current_gamepad: SDL.JoystickID = 0,
};

var g_input_state = InputState{};

pub fn getCurrentGamepad() ?* const GamepadState {
    if(g_input_state.device == .Gamepad) {
        if(g_input_state.gamepad_map.getPtr(g_input_state.current_gamepad)) |pad_state| {
            return pad_state;
        }
    }
    return null;
}

pub fn init(allocator: Allocator) bool {
    g_input_state.gamepad_map = GamepadMap.init(allocator);
    return true;
}

pub fn deinit() void {
    var it = g_input_state.gamepad_map.iterator();
    while (it.next()) |kv| {
        SDL.closeGamepad(kv.value_ptr.*.handle);
    }
    g_input_state.gamepad_map.deinit();
}

pub fn getCurrentInputState() *const InputState {
    return &g_input_state;
}

// TODO: implement again
//     SDL.EVENT_KEY_DOWN => {
//         const key_press = event.key.scancode;
//         if (key_press == SDL.SCANCODE_G and game.settings.devmode) {
//             if (globals.GODMODE) {
//                 globals.GODMODE = false;
//                 globals.NOCLIP = false;
//             } else {
//                 globals.GODMODE = true;
//             }
//         } else if (key_press == SDL.SCANCODE_N and game.settings.devmode) {
//             if (globals.NOCLIP) {
//                 globals.NOCLIP = false;
//             } else {
//                 globals.NOCLIP = true;
//                 globals.GODMODE = true;
//             }
//         } else if (key_press == SDL.SCANCODE_D and game.settings.devmode) {
//             globals.DISPLAYLOOPTIME = !globals.DISPLAYLOOPTIME;
//         } else if (key_press == SDL.SCANCODE_Q) {
//             if ((mods & @as(c_uint, @bitCast(SDL.KMOD_ALT | SDL.KMOD_CTRL))) != 0) {
//                 _ = credits.credits_screen();
//                 if (level.*.extrabonus >= 10) {
//                     level.*.extrabonus -= 10;
//                     level.*.lives += 1;
//                 }
//             }
//         }
//     },
//     if (keystate[SDL.SCANCODE_F1] != 0 and globals.RESETLEVEL_FLAG == 0) {
//         globals.RESETLEVEL_FLAG = 2;
//         return 0;
//     }
//     if (game.settings.devmode) {
//         if (keystate[SDL.SCANCODE_F2] != 0) {
//             globals.GAMEOVER_FLAG = true;
//             return 0;
//         }
//         if (keystate[SDL.SCANCODE_F3] != 0) {
//             globals.NEWLEVEL_FLAG = true;
//             globals.SKIPLEVEL_FLAG = true;
//         }
//     }
//     if (keystate[SDL.SCANCODE_E] != 0) {
//         globals.BAR_FLAG = 50;
//     }

const DEAD_ZONE = 8000;
const DEAD_ZONE_TRIGGER = 500;
const Y_ZONE = 0.25;
const X_ZONE = 0.25;

fn getAxisValueWithDeadzone(value_in: i16, dead_zone: i16, gamepad_id: SDL.JoystickID) f32 {
    var value: f32 = 0.0;
    if(@abs(value_in) > dead_zone)
    {
        g_input_state.device = .Gamepad;
        g_input_state.current_gamepad = gamepad_id;
        if(value_in < 0)
        {
            value = -(@as(f32, @floatFromInt(value_in + dead_zone)) / @as(f32, @floatFromInt(SDL.JOYSTICK_AXIS_MIN + dead_zone)));
        }
        else
        {
            value = @as(f32, @floatFromInt(value_in - dead_zone)) / @as(f32, @floatFromInt(SDL.JOYSTICK_AXIS_MAX - dead_zone));
        }
    }
    return value;
}

pub fn processEvents() *InputState {
    SDL.pumpEvents();
    SDL.updateGamepads();
    const keystate = SDL.getKeyboardState();

    g_input_state.should_redraw = false;
    g_input_state.any_key_pressed = false;
    g_input_state.action = .None;

    var event: SDL.Event = undefined;
    while (SDL.pollEvent(&event)) {
        switch (event.type) {
            SDL.EVENT_QUIT => {
                g_input_state.action = .Quit;
            },
            SDL.EVENT_KEY_DOWN => {
                if (event.key.scancode == SDL.SCANCODE_F11) {
                    window.toggle_fullscreen();
                    continue;
                }
                switch (event.key.scancode) {
                    SDL.SCANCODE_ESCAPE,
                    SDL.SCANCODE_BACKSPACE,
                    => {
                        g_input_state.action = .Escape;
                    },
                    SDL.SCANCODE_KP_ENTER,
                    SDL.SCANCODE_RETURN,
                    SDL.SCANCODE_SPACE,
                    => {
                        g_input_state.action = .Activate;
                    },
                    SDL.SCANCODE_DOWN, SDL.SCANCODE_S => {
                        g_input_state.action = .Down;
                    },
                    SDL.SCANCODE_UP, SDL.SCANCODE_W => {
                        g_input_state.action = .Up;
                    },
                    SDL.SCANCODE_LEFT, SDL.SCANCODE_A => {
                        g_input_state.action = .Left;
                    },
                    SDL.SCANCODE_RIGHT, SDL.SCANCODE_D => {
                        g_input_state.action = .Right;
                    },
                    SDL.SCANCODE_F4 => {
                        g_input_state.action = .Status;
                    },
                    else => {
                        // NOOP
                    },
                }
                g_input_state.any_key_pressed = true;
                g_input_state.device = .Keyboard;
            },
            SDL.EVENT_WINDOW_RESIZED,
            SDL.EVENT_WINDOW_PIXEL_SIZE_CHANGED,
            SDL.EVENT_WINDOW_MAXIMIZED,
            SDL.EVENT_WINDOW_RESTORED,
            SDL.EVENT_WINDOW_EXPOSED,
            => {
                g_input_state.should_redraw = true;
            },
            SDL.EVENT_GAMEPAD_AXIS_MOTION => {
                const gamepadId = event.gaxis.which;
                if(g_input_state.gamepad_map.getPtr(gamepadId)) |pad_state| {
                    switch (event.gaxis.axis) {
                        SDL.GAMEPAD_AXIS_LEFTX => {
                            const value = getAxisValueWithDeadzone(event.gaxis.value, DEAD_ZONE, gamepadId);
                            pad_state.left_x = value;
                            if (value <= 0.0 and pad_state.left_stick_virtual_right_pressed)
                            {
                                // Left stick 'on right button up'
                                pad_state.left_stick_virtual_right_pressed = false;
                            }
                            if (value >= 0.0 and pad_state.left_stick_virtual_left_pressed)
                            {
                                // Left stick 'on left button up'
                                pad_state.left_stick_virtual_left_pressed = false;
                            }

                            if(value > X_ZONE and !pad_state.left_stick_virtual_right_pressed)
                            {
                                // Left stick 'on right button down'
                                pad_state.left_stick_virtual_right_pressed = true;
                                g_input_state.action = .Right;
                            }
                            if(value < -X_ZONE and !pad_state.left_stick_virtual_left_pressed)
                            {
                                // Left stick 'on left button down'
                                pad_state.left_stick_virtual_left_pressed = true;
                                g_input_state.action = .Left;
                            }
                        },
                        SDL.GAMEPAD_AXIS_LEFTY => {
                            const value = getAxisValueWithDeadzone(event.gaxis.value, DEAD_ZONE, gamepadId);
                            pad_state.left_y = value;
                            if (value <= 0.0 and pad_state.left_stick_virtual_down_pressed)
                            {
                                // Left stick 'on down button up'
                                pad_state.left_stick_virtual_down_pressed = false;
                            }
                            if (value >= 0.0 and pad_state.left_stick_virtual_up_pressed)
                            {
                                // Left stick 'on up button up'
                                pad_state.left_stick_virtual_up_pressed = false;
                            }

                            if(value > Y_ZONE and !pad_state.left_stick_virtual_down_pressed)
                            {
                                // Left stick 'on down button down'
                                pad_state.left_stick_virtual_down_pressed = true;
                                g_input_state.action = .Down;
                            }
                            if(value < -Y_ZONE and !pad_state.left_stick_virtual_up_pressed)
                            {
                                // Left stick 'on right button down'
                                pad_state.left_stick_virtual_up_pressed = true;
                                g_input_state.action = .Up;
                            }
                        },
                        SDL.GAMEPAD_AXIS_RIGHTX => {
                            const value = getAxisValueWithDeadzone(event.gaxis.value, DEAD_ZONE, gamepadId);
                            pad_state.right_x = value;
                        },
                        SDL.GAMEPAD_AXIS_RIGHTY => {
                            const value = getAxisValueWithDeadzone(event.gaxis.value, DEAD_ZONE, gamepadId);
                            pad_state.right_y = value;
                        },
                        SDL.GAMEPAD_AXIS_LEFT_TRIGGER => {
                            const value = getAxisValueWithDeadzone(event.gaxis.value, DEAD_ZONE_TRIGGER, gamepadId);
                            pad_state.left_trigger = value;
                            if(value > 0.0 and !pad_state.left_trigger_virtual_button_pressed)
                            {
                                // Left trigger 'on button down'
                                pad_state.left_trigger_virtual_button_pressed = true;
                            }
                            else if (value == 0.0 and pad_state.left_trigger_virtual_button_pressed)
                            {
                                // Left trigger 'on button up'
                                pad_state.left_trigger_virtual_button_pressed = false;
                            }
                        },
                        SDL.GAMEPAD_AXIS_RIGHT_TRIGGER => {
                            const value = getAxisValueWithDeadzone(event.gaxis.value, DEAD_ZONE_TRIGGER, gamepadId);
                            pad_state.right_trigger = value;
                            if(value > 0.0 and !pad_state.right_trigger_virtual_button_pressed)
                            {
                                // Right trigger 'on button down'
                                pad_state.right_trigger_virtual_button_pressed = true;
                            }
                            else if (value == 0.0 and pad_state.right_trigger_virtual_button_pressed)
                            {
                                // Right trigger 'on button up'
                                pad_state.right_trigger_virtual_button_pressed = false;
                            }
                        },
                        else => {
                            // eh
                        }
                    }
                }
                else
                {
                    std.log.err("Gamepad {} not found for axis motion event!", .{gamepadId});
                }
            },
            SDL.EVENT_GAMEPAD_BUTTON_DOWN => {
                const gamepadId = event.gbutton.which;
                if(g_input_state.gamepad_map.getPtr(gamepadId)) |pad_state| {
                    switch (event.gbutton.button) {
                        SDL.GAMEPAD_BUTTON_SOUTH => {
                            g_input_state.action = .Activate;
                            pad_state.south_pressed = true;
                        },
                        SDL.GAMEPAD_BUTTON_EAST => {
                            g_input_state.action = .Cancel;
                            pad_state.east_pressed = true;
                        },
                        SDL.GAMEPAD_BUTTON_NORTH => {
                            pad_state.north_pressed = true;
                        },
                        SDL.GAMEPAD_BUTTON_WEST => {
                            pad_state.west_pressed = true;
                        },
                        SDL.GAMEPAD_BUTTON_BACK => {
                            g_input_state.action = .Status;
                        },
                        SDL.GAMEPAD_BUTTON_START => {
                            g_input_state.action = .ToggleMenu;
                        },
                        SDL.GAMEPAD_BUTTON_LEFT_SHOULDER => {
                            pad_state.left_shoulder_pressed = true;
                        },
                        SDL.GAMEPAD_BUTTON_RIGHT_SHOULDER => {
                            pad_state.right_shoulder_pressed = true;
                        },
                        SDL.GAMEPAD_BUTTON_LEFT_STICK => {
                            pad_state.left_stick_pressed = true;
                        },
                        SDL.GAMEPAD_BUTTON_RIGHT_STICK => {
                            pad_state.right_stick_pressed = true;
                        },
                        SDL.GAMEPAD_BUTTON_DPAD_UP => {
                            g_input_state.action = .Up;
                            pad_state.dpad_up_pressed = true;
                        },
                        SDL.GAMEPAD_BUTTON_DPAD_DOWN => {
                            g_input_state.action = .Down;
                            pad_state.dpad_down_pressed = true;
                        },
                        SDL.GAMEPAD_BUTTON_DPAD_LEFT => {
                            g_input_state.action = .Left;
                            pad_state.dpad_left_pressed = true;
                        },
                        SDL.GAMEPAD_BUTTON_DPAD_RIGHT => {
                            g_input_state.action = .Right;
                            pad_state.dpad_right_pressed = true;
                        },
                        else => {
                            // Some other button.
                            // std.log.info("Gamepad {} button {} down!", .{event.gbutton.which, event.gbutton.button});
                        },
                    }
                    g_input_state.any_key_pressed = true;
                    g_input_state.device = .Gamepad;
                    g_input_state.current_gamepad = gamepadId;
                }
                else
                {
                    std.log.err("Gamepad {} not found for button down event!", .{gamepadId});
                }
            },
            SDL.EVENT_GAMEPAD_BUTTON_UP => {
                const gamepadId = event.gbutton.which;
                if(g_input_state.gamepad_map.getPtr(gamepadId)) |pad_state| {
                    switch (event.gbutton.button) {
                        SDL.GAMEPAD_BUTTON_SOUTH => {
                            pad_state.south_pressed = false;
                        },
                        SDL.GAMEPAD_BUTTON_EAST => {
                            pad_state.east_pressed = false;
                        },
                        SDL.GAMEPAD_BUTTON_NORTH => {
                            pad_state.north_pressed = false;
                        },
                        SDL.GAMEPAD_BUTTON_WEST => {
                            pad_state.west_pressed = false;
                        },
                        SDL.GAMEPAD_BUTTON_LEFT_SHOULDER => {
                            pad_state.left_shoulder_pressed = false;
                        },
                        SDL.GAMEPAD_BUTTON_RIGHT_SHOULDER => {
                            pad_state.right_shoulder_pressed = false;
                        },
                        SDL.GAMEPAD_BUTTON_LEFT_STICK => {
                            pad_state.left_stick_pressed = false;
                        },
                        SDL.GAMEPAD_BUTTON_RIGHT_STICK => {
                            pad_state.right_stick_pressed = false;
                        },
                        SDL.GAMEPAD_BUTTON_DPAD_UP => {
                            pad_state.dpad_up_pressed = false;
                        },
                        SDL.GAMEPAD_BUTTON_DPAD_DOWN => {
                            pad_state.dpad_down_pressed = false;
                        },
                        SDL.GAMEPAD_BUTTON_DPAD_LEFT => {
                            pad_state.dpad_left_pressed = false;
                        },
                        SDL.GAMEPAD_BUTTON_DPAD_RIGHT => {
                            pad_state.dpad_right_pressed = false;
                        },
                        else => {
                            // Some other button.
                            // std.log.info("Gamepad {} button {} up!", .{event.gbutton.which, event.gbutton.button});
                        },
                    }
                    g_input_state.device = .Gamepad;
                    g_input_state.current_gamepad = gamepadId;
                }
                else
                {
                    std.log.err("Gamepad {} not found for button up event!", .{gamepadId});
                }
            },
            SDL.EVENT_GAMEPAD_ADDED => {
                const gamepadId = event.gdevice.which;
                const maybe_gamepad = SDL.openGamepad(gamepadId);
                if(maybe_gamepad) |gamepad|
                {
                    const props = SDL.getGamepadProperties(gamepad);
                    const has_rumble = SDL.getBooleanProperty(props, SDL.PROP_GAMEPAD_CAP_RUMBLE_BOOLEAN, false);
                    const has_trigger_rumble = SDL.getBooleanProperty(props, SDL.PROP_GAMEPAD_CAP_TRIGGER_RUMBLE_BOOLEAN, false);
                    const gamepadName = SDL.getGamepadName(gamepad);
                    g_input_state.gamepad_map.put(
                        gamepadId,
                        .{
                            .handle = gamepad,
                            .id = gamepadId,
                            .has_rumble = has_rumble,
                            .has_trigger_rumble = has_trigger_rumble,
                        }
                    ) catch @panic("SDL: out of memory");
                    std.log.info("Gamepad {} added: {s}.", .{gamepadId, gamepadName});
                    if(has_rumble)
                        std.log.info("Gamepad {} has rumble.", .{gamepadId});
                    if(has_trigger_rumble)
                        std.log.info("Gamepad {} has trigger rumble.", .{gamepadId});
                }
                else
                {
                    std.log.err("Gamepad {} failed to be added!", .{gamepadId});
                }
            },
            SDL.EVENT_GAMEPAD_REMOVED => {
                const gamepadId = event.gdevice.which;
                if (g_input_state.gamepad_map.fetchRemove(gamepadId)) |kv| {
                    SDL.closeGamepad(kv.value.handle);
                    std.log.info("Gamepad {} removed!", .{event.gdevice.which});
                }

            },
            SDL.EVENT_GAMEPAD_UPDATE_COMPLETE => {
                // This event fires when all gamepad events for this frame are finished.
                // std.log.info("Gamepad {} update complete!", .{event.gdevice.which});
            },
            else => {
                // NOOP
            },
        }
    }


    switch(g_input_state.device) {
        .Gamepad => {
            if(g_input_state.gamepad_map.getPtr(g_input_state.current_gamepad)) |pad_state| {
                handle_gamepad(pad_state);
            }
            else {
                g_input_state.x_axis = 0;
                g_input_state.y_axis = 0;
                g_input_state.action_pressed = false;
                g_input_state.jump_pressed = false;
                g_input_state.crouch_pressed = false;
                g_input_state.aim_direction = .Forward;
            }
        },
        .Keyboard => {
            // We have a keyboard
            g_input_state.x_axis =
                @as(i8, @intCast(keystate[SDL.SCANCODE_RIGHT] | keystate[SDL.SCANCODE_D])) -
                @as(i8, @intCast(keystate[SDL.SCANCODE_LEFT]  | keystate[SDL.SCANCODE_A]));
            g_input_state.y_axis =
                @as(i8, @intCast(keystate[SDL.SCANCODE_DOWN] | keystate[SDL.SCANCODE_S])) -
                @as(i8, @intCast(keystate[SDL.SCANCODE_UP] | keystate[SDL.SCANCODE_W]));
            g_input_state.action_pressed = keystate[SDL.SCANCODE_SPACE] != 0;
            g_input_state.jump_pressed = g_input_state.y_axis < 0;
            g_input_state.crouch_pressed = g_input_state.y_axis > 0;
            if(g_input_state.y_axis < 0) {
                g_input_state.aim_direction = .Up;
            }
            else {
                g_input_state.aim_direction = .Forward;
            }
        },
        .None => {
            // We got nothing
            g_input_state.x_axis = 0;
            g_input_state.y_axis = 0;
            g_input_state.action_pressed = false;
            g_input_state.jump_pressed = false;
            g_input_state.crouch_pressed = false;
            g_input_state.aim_direction = .Forward;
        },
    }
    return &g_input_state;
}

fn handle_gamepad(pad_state: *GamepadState) void {
    // handle left <-> right - dpad has priority, then we use the left stick
    if(pad_state.dpad_right_pressed)
    {
        g_input_state.x_axis = 1;
    }
    else if (pad_state.dpad_left_pressed)
    {
        g_input_state.x_axis = -1;
    }
    else
    {
        // use the x axis of the left stick
        if(pad_state.left_x < -X_ZONE)
        {
            g_input_state.x_axis = -1;
        }
        else if(pad_state.left_x > X_ZONE)
        {
            g_input_state.x_axis = 1;
        }
        else
        {
            g_input_state.x_axis = 0;
        }
    }

    if(pad_state.dpad_down_pressed)
    {
        // crawl
        g_input_state.y_axis = 1;
    }
    else if(pad_state.dpad_up_pressed) // or pad_state.south_pressed
    {
        // go up ladders
        g_input_state.y_axis = -1;
    }
    else
    {
        // use the y axis of the left stick
        if(pad_state.left_y < -Y_ZONE)
        {
            g_input_state.y_axis = -1;
        }
        else if(pad_state.left_y > Y_ZONE)
        {
            g_input_state.y_axis = 1;
        }
        else
        {
            g_input_state.y_axis = 0;
        }
    }
    switch(game.settings.input_mode) {
        .Classic => {
            // Left stick behaves the same as dpad, no dedicated buttons for jump and crawl
            g_input_state.action_pressed = pad_state.south_pressed;
            g_input_state.jump_pressed = g_input_state.y_axis < 0;
            g_input_state.crouch_pressed = g_input_state.y_axis > 0;
            if(g_input_state.y_axis < 0) {
                g_input_state.aim_direction = .Up;
            }
            else {
                g_input_state.aim_direction = .Forward;
            }
        },
        .Modern => {
            // Left stick controls direction to go in (including up and down ladders), action, jump and crouch have dedicated buttons
            // dpad behaves just like in classic
            g_input_state.action_pressed = pad_state.right_trigger > 0.0 or pad_state.west_pressed or pad_state.right_shoulder_pressed;
            g_input_state.jump_pressed = pad_state.dpad_up_pressed or pad_state.south_pressed;
            g_input_state.crouch_pressed = pad_state.dpad_down_pressed or pad_state.left_shoulder_pressed or pad_state.left_trigger > 0.0;
            if(pad_state.left_y < -Y_ZONE and @abs(pad_state.left_y) > @abs(pad_state.left_x))
            {
                g_input_state.aim_direction = .Up;
            }
            else
            {
                g_input_state.aim_direction = .Forward;
            }
        },
    }
}

pub fn waitforbutton() c_int {
    var waiting: c_int = 1;
    while (waiting > 0) {
        const input_state = processEvents();
        if(input_state.action == .Quit)
        {
            waiting = -1;
        }
        else if(input_state.any_key_pressed)
        {
            waiting = 0;
        }
        if(input_state.should_redraw)
        {
            window.window_render();
        }
        SDL.delay(1);
    }
    return waiting;
}

// Respond to game events - apply controller effects like rumble, RGB lights, etc.
pub fn triggerEvent(event: GameEvent) void {
    if (g_input_state.device != .Gamepad)
        return;
    if(g_input_state.gamepad_map.getPtr(g_input_state.current_gamepad)) |pad_state| {
        pad_state.triggerRumble(event);
    }
}
