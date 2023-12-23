#include "window.h"
#include "settings.h"
#include "tituserror.h"
#include "globals_old.h"
#include "settings.h"

static const char* getGameTitle() {
    switch(game) {
        case Titus:
            return "OpenTitus";
        case Moktar:
            return "OpenMoktar";
        default:
            return "Something else...";
    }
}

static uint32_t black = 0;

bool fullscreen = false;

SDL_Surface *screen;
SDL_Window *window;
static SDL_Renderer *renderer;

void window_toggle_fullscreen() {
    if(!fullscreen) {
        SDL_SetWindowFullscreen(window, SDL_WINDOW_FULLSCREEN_DESKTOP);
        fullscreen = true;
    }
    else {
        SDL_SetWindowFullscreen(window, 0);
        fullscreen = false;
    }
}

int window_init() {
    uint32_t windowflags = 0;
    int w;
    int h;
    switch (videomode) {
        default:
        case 0: //window mode
            w = 960;
            h = 600;
            windowflags = SDL_WINDOW_RESIZABLE;
            fullscreen = false;
            break;
        case 1: // fullscreen
            w = 0;
            h = 0;
            windowflags = SDL_WINDOW_FULLSCREEN_DESKTOP;
            fullscreen = true;
            break;
    }

    window = SDL_CreateWindow(
        getGameTitle(),
        SDL_WINDOWPOS_UNDEFINED,
        SDL_WINDOWPOS_UNDEFINED,
        w,
        h,
        windowflags
    );
    renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
    if (renderer == NULL) {
        printf("Unable to set video mode: %s\n", SDL_GetError());
        return TITUS_ERROR_SDL_ERROR;
    }

    // screen = SDL_GetWindowSurface(window);
    screen = SDL_CreateRGBSurfaceWithFormat(0, 352, 200, 32, SDL_GetWindowPixelFormat(window));
    black = SDL_MapRGB(screen->format, 0, 0, 0);

    SDL_RenderSetLogicalSize(renderer, 320, 200);
    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    return 0;
}

void window_clear(const SDL_Rect * rect) {
    SDL_FillRect(screen, rect, black);
}

void window_render() {
    if(!screen) {
        return;
    }
    SDL_Texture *frame = SDL_CreateTextureFromSurface(renderer, screen);
    SDL_RenderClear(renderer);
    SDL_Rect src;
    src.x = 16 - g_scroll_px_offset;
    src.y = 0;
    src.w = 320;
    src.h = 200;
    SDL_Rect dst = src;
    dst.x = 0;
    SDL_RenderCopy(renderer, frame, &src, &dst);
    SDL_RenderPresent(renderer);
    SDL_DestroyTexture(frame);
}
