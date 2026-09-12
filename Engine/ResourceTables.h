// SPDX-License-Identifier: GPL-2.0-or-later
#ifndef MD_RESOURCE_TABLES_H
#define MD_RESOURCE_TABLES_H
#include "doomtype.h"

// Shared with p_spec.c and the bridge: one layout, no private struct mirror.
typedef struct {
    boolean istexture;
    int picnum, basepic, numpics, speed;
} MD_EngineAnim;
extern MD_EngineAnim *anims, *lastanim;
extern int *switchlist, numswitches;
// Return false only when the lump is absent, retaining the vanilla defaults.
boolean MD_LoadAnimations(void);
boolean MD_LoadSwitches(int episode);
#endif
