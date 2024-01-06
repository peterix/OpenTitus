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

#include "SDL.h"

#include "opl.h"
#include "opl_internal.h"

#include <stdbool.h>

//#define OPL_DEBUG_TRACE

int OPL_SDL_Init(unsigned int port_base);
void OPL_SDL_Shutdown(void);
unsigned int OPL_SDL_PortRead(opl_port_t port);
void OPL_SDL_PortWrite(opl_port_t port, unsigned int value);
void OPL_SDL_SetCallback(uint64_t us, opl_callback_t callback, void *data);
void OPL_SDL_ClearCallbacks(void);
void OPL_SDL_Lock(void);
void OPL_SDL_Unlock(void);
void OPL_SDL_SetPaused(int paused);
void OPL_SDL_AdjustCallbacks(float factor);

static bool initialized = false;

unsigned int opl_sample_rate = 22050;

//
// Init/shutdown code.
//

// Initialize the OPL library. Return value indicates type of OPL chip
// detected, if any.
opl_init_result_t OPL_Init(unsigned int port_base)
{
    opl_init_result_t result1, result2;

    if (!OPL_SDL_Init(port_base))
    {
        return OPL_INIT_NONE;
    }

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

void OPL_WritePort(opl_port_t port, unsigned int value)
{
    if (!initialized) {
        return;
    }
#ifdef OPL_DEBUG_TRACE
    printf("OPL_write: %i, %x\n", port, value);
    fflush(stdout);
#endif
    OPL_SDL_PortWrite(port, value);
}

unsigned int OPL_ReadPort(opl_port_t port)
{
    if (!initialized) {
        return 0;
    }

#ifdef OPL_DEBUG_TRACE
    printf("OPL_read: %i...\n", port);
    fflush(stdout);
#endif

    unsigned int result = OPL_SDL_PortRead(port);

#ifdef OPL_DEBUG_TRACE
    printf("OPL_read: %i -> %x\n", port, result);
    fflush(stdout);
#endif

    return result;
}

//
// Higher-level functions, based on the lower-level functions above
// (register write, etc).
//

unsigned int OPL_ReadStatus(void)
{
    return OPL_ReadPort(OPL_REGISTER_PORT);
}

// Write an OPL register value

void OPL_WriteRegister(int reg, int value)
{
    int i;

    if (reg & 0x100)
    {
        OPL_WritePort(OPL_REGISTER_PORT_OPL3, reg);
    }
    else
    {
        OPL_WritePort(OPL_REGISTER_PORT, reg);
    }

    // For timing, read the register port six times after writing the
    // register number to cause the appropriate delay

    for (i=0; i<6; ++i)
    {
        // An oddity of the Doom OPL code: at startup initialization,
        // the spacing here is performed by reading from the register
        // port; after initialization, the data port is read, instead.

        OPL_ReadPort(OPL_DATA_PORT);
    }

    OPL_WritePort(OPL_DATA_PORT, value);

    // Read the register port 24 times after writing the value to
    // cause the appropriate delay

    for (i=0; i<24; ++i)
    {
        OPL_ReadStatus();
    }
}

// Initialize registers on startup

void OPL_InitRegisters(int opl3)
{
    int r;

    // Initialize level registers

    for (r=OPL_REGS_LEVEL; r <= OPL_REGS_LEVEL + OPL_NUM_OPERATORS; ++r)
    {
        OPL_WriteRegister(r, 0x3f);
    }

    // Initialize other registers
    // These two loops write to registers that actually don't exist,
    // but this is what Doom does ...
    // Similarly, the <= is also intenational.

    for (r=OPL_REGS_ATTACK; r <= OPL_REGS_WAVEFORM + OPL_NUM_OPERATORS; ++r)
    {
        OPL_WriteRegister(r, 0x00);
    }

    // More registers ...

    for (r=1; r < OPL_REGS_LEVEL; ++r)
    {
        OPL_WriteRegister(r, 0x00);
    }

    // Re-initialize the low registers:

    // Reset both timers and enable interrupts:
    OPL_WriteRegister(OPL_REG_TIMER_CTRL,      0x60);
    OPL_WriteRegister(OPL_REG_TIMER_CTRL,      0x80);

    // "Allow FM chips to control the waveform of each operator":
    OPL_WriteRegister(OPL_REG_WAVEFORM_ENABLE, 0x20);

    if (opl3)
    {
        OPL_WriteRegister(OPL_REG_NEW, 0x01);

        // Initialize level registers

        for (r=OPL_REGS_LEVEL; r <= OPL_REGS_LEVEL + OPL_NUM_OPERATORS; ++r)
        {
            OPL_WriteRegister(r | 0x100, 0x3f);
        }

        // Initialize other registers
        // These two loops write to registers that actually don't exist,
        // but this is what Doom does ...
        // Similarly, the <= is also intenational.

        for (r=OPL_REGS_ATTACK; r <= OPL_REGS_WAVEFORM + OPL_NUM_OPERATORS; ++r)
        {
            OPL_WriteRegister(r | 0x100, 0x00);
        }

        // More registers ...

        for (r=1; r < OPL_REGS_LEVEL; ++r)
        {
            OPL_WriteRegister(r | 0x100, 0x00);
        }
    }

    // Keyboard split point on (?)
    OPL_WriteRegister(OPL_REG_FM_MODE,         0x40);

    if (opl3)
    {
        OPL_WriteRegister(OPL_REG_NEW, 0x01);
    }
}

//
// Timer functions.
//

void OPL_SetCallback(uint64_t us, opl_callback_t callback, void *data)
{
    if (initialized)
    {
        OPL_SDL_SetCallback(us, callback, data);
    }
}

void OPL_ClearCallbacks(void)
{
    if (initialized)
    {
        OPL_SDL_ClearCallbacks();
    }
}

void OPL_Lock(void)
{
    if (initialized)
    {
        OPL_SDL_Lock();
    }
}

void OPL_Unlock(void)
{
    if (initialized)
    {
        OPL_SDL_Unlock();
    }
}

void OPL_SetPaused(int paused)
{
    if (initialized)
    {
        OPL_SDL_SetPaused(paused);
    }
}

void OPL_AdjustCallbacks(float value)
{
    if (initialized)
    {
        OPL_SDL_AdjustCallbacks(value);
    }
}

