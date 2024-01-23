//
// Copyright(C) 2005-2014 Simon Howard
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// DESCRIPTION:
//     OPL interface.
//

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <errno.h>
#include <assert.h>

#include "SDL.h"
#include "SDL_mixer.h"

#include "opl3.h"

#include "opl.h"
#include "opl_queue.h"

uint8_t OPL_SDL_VOLUME = SDL_MIX_MAXVOLUME;

typedef struct
{
    unsigned int rate;        // Number of times the timer is advanced per sec.
    unsigned int enabled;     // Non-zero if timer is enabled.
    unsigned int value;       // Last value that was set.
    uint64_t expire_time;     // Calculated time that timer will expire.
} opl_timer_t;

// When the callback mutex is locked using OPL_Lock, callback functions
// are not invoked.

static SDL_mutex *callback_mutex = NULL;

// Queue of callbacks waiting to be invoked.

static opl_callback_queue_t *callback_queue;

// Mutex used to control access to the callback queue.

static SDL_mutex *callback_queue_mutex = NULL;

// Current time, in us since startup:

static uint64_t current_time;

// OPL software emulator structure.

static opl3_chip opl_chip;
static int opl_opl3mode;

// Temporary mixing buffer used by the mixing callback.

static uint8_t *mix_buffer = NULL;

// Timers; DBOPL does not do timer stuff itself.

static opl_timer_t timer1 = { 12500, 0, 0, 0 };
static opl_timer_t timer2 = { 3125, 0, 0, 0 };

// SDL parameters.

static int sdl_was_initialized = 0;
static int mixing_freq, mixing_channels;
static Uint16 mixing_format;

static int SDLIsInitialized(void)
{
    int freq, channels;
    Uint16 format;

    return Mix_QuerySpec(&freq, &format, &channels);
}

// Advance time by the specified number of samples, invoking any
// callback functions as appropriate.

static void AdvanceTime(unsigned int nsamples)
{
    opl_callback_t callback;
    void *callback_data;
    uint64_t us;

    SDL_LockMutex(callback_queue_mutex);

    // Advance time.

    us = ((uint64_t) nsamples * OPL_SECOND) / mixing_freq;
    current_time += us;

    // Are there callbacks to invoke now?  Keep invoking them
    // until there are no more left.

    while (!OPL_Queue_IsEmpty(callback_queue) && current_time >= OPL_Queue_Peek(callback_queue))
    {
        // Pop the callback from the queue to invoke it.

        if (!OPL_Queue_Pop(callback_queue, &callback, &callback_data))
        {
            break;
        }

        // The mutex stuff here is a bit complicated.  We must
        // hold callback_mutex when we invoke the callback (so that
        // the control thread can use OPL_Lock() to prevent callbacks
        // from being invoked), but we must not be holding
        // callback_queue_mutex, as the callback must be able to
        // call OPL_SetCallback to schedule new callbacks.

        SDL_UnlockMutex(callback_queue_mutex);

        SDL_LockMutex(callback_mutex);
        callback(callback_data);
        SDL_UnlockMutex(callback_mutex);

        SDL_LockMutex(callback_queue_mutex);
    }

    SDL_UnlockMutex(callback_queue_mutex);
}

// Call the OPL emulator code to fill the specified buffer.

static void FillBuffer(uint8_t *buffer, unsigned int nsamples)
{
    // This seems like a reasonable assumption.  mix_buffer is
    // 1 second long, which should always be much longer than the
    // SDL mix buffer.
    assert(nsamples < mixing_freq);

    // OPL output is generated into temporary buffer and then mixed
    // (to avoid overflows etc.)
    OPL3_GenerateStream(&opl_chip, (Bit16s *) mix_buffer, nsamples);
    SDL_MixAudioFormat(buffer, mix_buffer, AUDIO_S16SYS, nsamples * 4, OPL_SDL_VOLUME);
}

// Callback function to fill a new sound buffer:

static void OPL_Mix_Callback(void *udata, Uint8 *buffer, int len)
{
    unsigned int filled, buffer_samples;

    // Repeatedly call the OPL emulator update function until the buffer is
    // full.
    filled = 0;
    buffer_samples = len / 4;

    while (filled < buffer_samples)
    {
        uint64_t next_callback_time;
        uint64_t nsamples;

        SDL_LockMutex(callback_queue_mutex);

        // Work out the time until the next callback waiting in
        // the callback queue must be invoked.  We can then fill the
        // buffer with this many samples.

        if (OPL_Queue_IsEmpty(callback_queue))
        {
            nsamples = buffer_samples - filled;
        }
        else
        {
            next_callback_time = OPL_Queue_Peek(callback_queue);

            nsamples = (next_callback_time - current_time) * mixing_freq;
            nsamples = (nsamples + OPL_SECOND - 1) / OPL_SECOND;

            if (nsamples > buffer_samples - filled)
            {
                nsamples = buffer_samples - filled;
            }
        }

        SDL_UnlockMutex(callback_queue_mutex);

        // Add emulator output to buffer.

        FillBuffer(buffer + filled * 4, nsamples);
        filled += nsamples;

        // Invoke callbacks for this point in time.

        AdvanceTime(nsamples);
    }
}

static bool initialized = false;

#define MAX_SOUND_SLICE_TIME 100 /* ms */
unsigned int opl_sample_rate = 22050;

static unsigned int GetSliceSize(void)
{
    int limit;
    int n;

    limit = (opl_sample_rate * MAX_SOUND_SLICE_TIME) / 1000;

    // Try all powers of two, not exceeding the limit.

    for (n=0;; ++n)
    {
        // 2^n <= limit < 2^n+1 ?

        if ((1 << (n + 1)) > limit)
        {
            return (1 << n);
        }
    }

    // Should never happen?
    return 1024;
}

static void OPLTimer_CalculateEndTime(opl_timer_t *timer)
{
    int tics;

    // If the timer is enabled, calculate the time when the timer
    // will expire.

    if (timer->enabled)
    {
        tics = 0x100 - timer->value;
        timer->expire_time = current_time + ((uint64_t) tics * OPL_SECOND) / timer->rate;
    }
}

//
// Init/shutdown code.
//

void OPL_SDL_Shutdown(void)
{
    Mix_HookMusic(NULL, NULL);

    if (sdl_was_initialized)
    {
        Mix_CloseAudio();
        SDL_QuitSubSystem(SDL_INIT_AUDIO);
        OPL_Queue_Destroy(callback_queue);
        free(mix_buffer);
        sdl_was_initialized = 0;
    }

    if (callback_mutex != NULL)
    {
        SDL_DestroyMutex(callback_mutex);
        callback_mutex = NULL;
    }

    if (callback_queue_mutex != NULL)
    {
        SDL_DestroyMutex(callback_queue_mutex);
        callback_queue_mutex = NULL;
    }
}

// Initialize the OPL library. Return value indicates type of OPL chip
// detected, if any.
opl_init_result_t OPL_Init(unsigned int port_base)
{
    // Check if SDL_mixer has been opened already
    // If not, we must initialize it now
    if (!SDLIsInitialized())
    {
        if (SDL_Init(SDL_INIT_AUDIO) < 0)
        {
            fprintf(stderr, "Unable to set up sound.\n");
            return OPL_INIT_NONE;
        }

        if (Mix_OpenAudioDevice(opl_sample_rate, AUDIO_S16SYS, 2, GetSliceSize(), NULL, SDL_AUDIO_ALLOW_FREQUENCY_CHANGE) < 0)
        {
            fprintf(stderr, "Error initialising SDL_mixer: %s\n", Mix_GetError());

            SDL_QuitSubSystem(SDL_INIT_AUDIO);
            return OPL_INIT_NONE;
        }

        SDL_PauseAudio(0);

        // When this module shuts down, it has the responsibility to 
        // shut down SDL.

        sdl_was_initialized = 1;
    }
    else
    {
        sdl_was_initialized = 0;
    }

    // Queue structure of callbacks to invoke.

    callback_queue = OPL_Queue_Create();
    current_time = 0;

    // Get the mixer frequency, format and number of channels.

    Mix_QuerySpec(&mixing_freq, &mixing_format, &mixing_channels);

    // Only supports AUDIO_S16SYS

    if (mixing_format != AUDIO_S16SYS || mixing_channels != 2)
    {
        fprintf(stderr, "OPL_SDL only supports native signed 16-bit LSB, stereo format!\n");

        OPL_SDL_Shutdown();
        return OPL_INIT_NONE;
    }

    // Mix buffer: four bytes per sample (16 bits * 2 channels):
    mix_buffer = (uint8_t *) malloc(mixing_freq * 4);

    // Create the emulator structure:

    OPL3_Reset(&opl_chip, mixing_freq);
    opl_opl3mode = 0;

    callback_mutex = SDL_CreateMutex();
    callback_queue_mutex = SDL_CreateMutex();

    // Set postmix that adds the OPL music. This is deliberately done
    // as a postmix and not using Mix_HookMusic() as the latter disables
    // normal SDL_mixer music mixing.
    Mix_SetPostMix(OPL_Mix_Callback, NULL);

    initialized = true;
    return OPL_INIT_OPL3;

}

// Shut down the OPL library.

void OPL_Shutdown(void)
{
    if (!initialized) {
        return;
    }
    OPL_SDL_Shutdown();
}

// Set the sample rate used for software OPL emulation.

void OPL_SetSampleRate(unsigned int rate)
{
    opl_sample_rate = rate;
}

void OPL_WriteRegister(uint16_t reg_num, uint8_t value)
{
    switch (reg_num)
    {
        case OPL_REG_TIMER1:
            timer1.value = value;
            OPLTimer_CalculateEndTime(&timer1);
            break;

        case OPL_REG_TIMER2:
            timer2.value = value;
            OPLTimer_CalculateEndTime(&timer2);
            break;

        case OPL_REG_TIMER_CTRL:
            if (value & 0x80)
            {
                timer1.enabled = 0;
                timer2.enabled = 0;
            }
            else
            {
                if ((value & 0x40) == 0)
                {
                    timer1.enabled = (value & 0x01) != 0;
                    OPLTimer_CalculateEndTime(&timer1);
                }

                if ((value & 0x20) == 0)
                {
                    timer1.enabled = (value & 0x02) != 0;
                    OPLTimer_CalculateEndTime(&timer2);
                }
            }

            break;

        case OPL_REG_NEW:
            opl_opl3mode = value & 0x01;

        default:
            OPL3_WriteRegBuffered(&opl_chip, reg_num, value);
            break;
    }
}

//
// Timer functions.
//

void OPL_SetCallback(uint64_t us, opl_callback_t callback, void *data)
{
    if (!initialized) {
        return;
    }
    SDL_LockMutex(callback_queue_mutex);
    OPL_Queue_Push(callback_queue, callback, data, current_time + us);
    SDL_UnlockMutex(callback_queue_mutex);
}
