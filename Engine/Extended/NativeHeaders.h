// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <libkern/OSByteOrder.h>
#include "doomtype.h"
boolean I_UseGamepad(void);
boolean I_GyroSupported(void);
void I_StartTextInput(void);
void I_StopTextInput(void);
void I_BindKeyboardVariables(void);
void I_BindRumbleVariables(void);
// Simulation receives native tic commands, not SDL events.
#define __I_INPUT__
#define __I_RUMBLE__
void I_FlushGamepadSensorEvents(void);
void I_ResetAllRumbleChannels(void);
#define __M_SWAP__
#define SHORT(x) ((signed short)OSSwapLittleToHostInt16(x))
#define LONG(x) ((signed int)OSSwapLittleToHostInt32(x))
#define SWAP_BE32(x) ((signed int)OSSwapBigToHostInt32(x))
void I_InitGamepad(void);
void I_InitKeyboard(void);
