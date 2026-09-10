// SPDX-License-Identifier: GPL-2.0-or-later
// Native replacements for three upstream platform headers. Preincluded only in
// the engine build; keeps vendored source unchanged and avoids an SDL dependency.
#pragma once
#include <libkern/OSByteOrder.h>
#define __I_SWAP__
#define SHORT(x) ((signed short)OSSwapLittleToHostInt16(x))
#define LONG(x) ((signed int)OSSwapLittleToHostInt32(x))
#define __I_INPUT__
#define MAX_MOUSE_BUTTONS 8
#define __I_JOYSTICK__
extern int use_analog, joystick_move_sensitivity, joystick_turn_sensitivity;
#define SDL_SwapBE16(x) OSSwapBigToHostInt16(x)
#define SDL_SwapBE32(x) OSSwapBigToHostInt32(x)
