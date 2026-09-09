// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <stdint.h>

typedef struct {
    float x, y, eyeZ, angle;
    int tick, sector, health, exitRequested;
} MD_Player;
typedef struct { float floor, ceiling, light; } MD_Sector;
typedef struct {
    float x, y, z, light, floorZ;
    int lump, flip, fullbright, doomedType;
} MD_Thing;
typedef struct {
    int health, armor, readyAmmo, readyWeapon;
    int bullets, shells, cells, rockets;
    int maxBullets, maxShells, maxCells, maxRockets;
    uint32_t keys, weapons;
    int bonusFlash, messageSerial, tick, damageFlash, kills, totalKills;
    char message[128];
} MD_HUD;

// Single main-thread engine instance. One IWAD per process; maps may be restarted.
int MD_Load(const char *wadPath, int episode, int map);
int MD_Tick(int forward, int side, int turn, int use);
// weapon is a classic number-key slot 0...6, or -1 for no change.
int MD_CombatTick(int forward, int side, int turn, int use, int attack, int weapon);
typedef struct { float x, y, light; int lump, flip, fullbright; } MD_WeaponSprite;
int MD_CopyWeaponSprites(MD_WeaponSprite *output, int capacity);
// Fixed native voice slots; lump -1 stops that voice. No engine pointers escape.
typedef struct { int channel, lump; float volume, pan; } MD_SoundEvent;
int MD_PopSound(MD_SoundEvent *output);
MD_Player MD_GetPlayer(void);
int MD_SectorCount(void);
MD_Sector MD_GetSector(int index);
const char *MD_LastError(void);
// Returns total eligible things. Writes at most capacity copied snapshots.
// The lump index addresses the single loaded IWAD's directory.
int MD_CopyThings(MD_Thing *output, int capacity, float cameraX, float cameraY);
MD_HUD MD_GetHUD(void);

#ifdef MD_TESTING
void MD_TestMonsters(int enabled);
void MD_TestTarget(int type, float distance);
int MD_TestTargetHealth(void);
void MD_TestDamagePlayer(int damage);
int MD_TestPlacePlayer(float x, float y, float angle);
int MD_TestDoor(int ordinal, float *x, float *y, float *angle, int *sector);
int MD_TestKeyDoor(int key, float *x, float *y, float *angle, int *sector);
#endif
