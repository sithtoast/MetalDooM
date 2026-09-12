// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include "r_defs.h"
// Presentation copies only: never mutate the engine's collision sectors.
void ME_RenderSector(const sector_t *source,int back,sector_t *out,int *floorlight,int *ceilinglight);
void ME_SectorClip(const sector_t *source,fixed_t *bottom,fixed_t *top);

fixed_t ME_RenderEye(void);
