#pragma once

#include <stdint.h>
#include <stdbool.h>

// FIXME: put this somewhere else...
enum GameType {
    Titus,
    Moktar
};
extern enum GameType game;

typedef struct _Settings Settings;
struct _Settings {
    bool devmode;
    bool fullscreen;
    bool music;
    uint8_t volume;
    uint16_t window_width;
    uint16_t window_height;
};
extern Settings settings;
