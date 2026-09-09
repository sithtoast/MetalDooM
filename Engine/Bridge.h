// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <stdint.h>

typedef struct {
    float x, y, eyeZ, angle;
    int tick, sector, health, exitRequested;
} MD_Player;
typedef struct { float floor, ceiling, light; } MD_Sector;

// Single main-thread engine instance. One IWAD per process; maps may be restarted.
int MD_Load(const char *wadPath, int episode, int map);
int MD_Tick(int forward, int side, int turn, int use);
MD_Player MD_GetPlayer(void);
int MD_SectorCount(void);
MD_Sector MD_GetSector(int index);
const char *MD_LastError(void);

#ifdef MD_TESTING
int MD_TestPlacePlayer(float x, float y, float angle);
int MD_TestDoor(int ordinal, float *x, float *y, float *angle, int *sector);
#endif
