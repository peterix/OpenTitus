/* See end of file for license */

#pragma once
#include <stdint.h>
#include <stdbool.h>

typedef struct pocketmod_context pocketmod_context;

bool pocketmod_init (pocketmod_context *c, const uint8_t *data, uint32_t size, uint32_t rate);
uint32_t pocketmod_render (pocketmod_context *c, void *buffer, uint32_t size);
uint32_t pocketmod_loop_count(pocketmod_context *c);

#ifndef POCKETMOD_MAX_CHANNELS
#define POCKETMOD_MAX_CHANNELS 32
#endif

#ifndef POCKETMOD_MAX_SAMPLES
#define POCKETMOD_MAX_SAMPLES 31
#endif

/* The size of one sample in bytes */
#define POCKETMOD_SAMPLE_SIZE sizeof(float[2])

typedef struct {
    int8_t  *data;               /* Sample data buffer                      */
    uint32_t length;             /* Data length (in bytes)                  */
} _pocketmod_sample;

typedef struct {
    uint8_t  dirty;              /* Pitch/volume dirty flags                */
    uint8_t  sample;             /* Sample number (0..31)                   */
    uint8_t  volume;             /* Base volume without tremolo (0..64)     */
    uint8_t  balance;            /* Stereo balance (0..255)                 */
    uint16_t period;             /* Note period (113..856)                  */
    uint16_t delayed;            /* Delayed note period (113..856)          */
    uint16_t target;             /* Target period (for tone portamento)     */
    uint8_t  finetune;           /* Note finetune (0..15)                   */
    uint8_t  loop_count;         /* E6x loop counter                        */
    uint8_t  loop_line;          /* E6x target line                         */
    uint8_t  lfo_step;           /* Vibrato/tremolo LFO step counter        */
    uint8_t  lfo_type[2];        /* LFO type for vibrato/tremolo            */
    uint8_t  effect;             /* Current effect (0x0..0xf or 0xe0..0xef) */
    uint8_t  param;              /* Raw effect parameter value              */
    uint8_t  param3;             /* Parameter memory for 3xx                */
    uint8_t  param4;             /* Parameter memory for 4xy                */
    uint8_t  param7;             /* Parameter memory for 7xy                */
    uint8_t  param9;             /* Parameter memory for 9xx                */
    uint8_t  paramE1;            /* Parameter memory for E1x                */
    uint8_t  paramE2;            /* Parameter memory for E2x                */
    uint8_t  paramEA;            /* Parameter memory for EAx                */
    uint8_t  paramEB;            /* Parameter memory for EBx                */
    uint8_t  real_volume;        /* Volume (with tremolo adjustment)        */
    float    position;           /* Position in sample data buffer          */
    float    increment;          /* Position increment per output sample    */
} _pocketmod_chan;

struct pocketmod_context
{
    /* Read-only song data */
    _pocketmod_sample samples[POCKETMOD_MAX_SAMPLES];
    const uint8_t *source;             /* Pointer to source MOD data              */
    const uint8_t *order;              /* Pattern order table                     */
    const uint8_t *patterns;           /* Start of pattern data                   */
    uint8_t  length;             /* Patterns in the order (1..128)          */
    uint8_t  reset;              /* Pattern to loop back to (0..127)        */
    uint8_t  num_patterns;       /* Patterns in the file (1..128)           */
    uint8_t  num_samples;        /* Sample count (15 or 31)                 */
    uint8_t  num_channels;       /* Channel count (1..32)                   */

    /* Timing variables */
    int32_t samples_per_second;  /* Sample rate (set by user)               */
    int32_t ticks_per_line;      /* A.K.A. song speed (initially 6)         */
    float   samples_per_tick;    /* Depends on sample rate and BPM          */

    /* Loop detection state */
    uint8_t visited[16];         /* Bit mask of previously visited patterns */
    uint32_t loop_count;          /* How many times the song has looped      */

    /* Render state */
    _pocketmod_chan channels[POCKETMOD_MAX_CHANNELS];
    uint8_t pattern_delay;       /* EEx pattern delay counter               */
    uint32_t lfo_rng;            /* RNG used for the random LFO waveform    */

    /* Position in song (from least to most granular) */
    int8_t pattern;              /* Current pattern in order                */
    int8_t line;                 /* Current line in pattern                 */
    int16_t tick;                /* Current tick in line                    */
    float sample;                /* Current sample in tick                  */
};

/*******************************************************************************

MIT License

Copyright (c) 2018 rombankzero

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*******************************************************************************/
