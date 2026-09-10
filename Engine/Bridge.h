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
    int lump, flip, fullbright, doomedType, shadow;
} MD_Thing;
typedef struct {
    int health, armor, readyAmmo, readyWeapon;
    int bullets, shells, cells, rockets;
    int maxBullets, maxShells, maxCells, maxRockets;
    uint32_t keys, weapons;
    int weaponGrin, faceIndex;
    int fixedColorMap, suitFlash, berserkFlash, allmap, invisibility;
    int bonusFlash, messageSerial, tick, damageFlash, kills, totalKills;
    int items, totalItems, secrets, totalSecrets, levelTics, parSeconds;
    char message[128];
} MD_HUD;

// Single main-thread engine instance. One IWAD per process; maps may be restarted.
int MD_Load(const char *wadPath, int episode, int map);
int MD_LoadSkill(const char *wadPath, int episode, int map, int skill);
int MD_GetSkill(void);
int MD_Tick(int forward, int side, int turn, int use);
// weapon is a classic number-key slot 0...6, or -1 for no change.
int MD_CombatTick(int forward, int side, int turn, int use, int attack, int weapon);
typedef struct { float x, y, light; int lump, flip, fullbright, shadow; } MD_WeaponSprite;
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
typedef struct { float x,y; char upper[9],lower[9],middle[9]; } MD_Side;
MD_Side MD_GetSide(int index);
// phase 0 = playing, 1 = stats, 2 = Doom episode ending, 3 = Doom II story, 4 = cast.
typedef struct {
    int phase, episode, map, nextMap, commercial, didSecret;
    int kills, maxKills, items, maxItems, secrets, maxSecrets, seconds, parSeconds;
} MD_Progress;
MD_Progress MD_GetProgress(void);
int MD_Continue(void);
void MD_IntermissionSound(int sound);
// Native payload I/O; the Swift save container checks format, WAD identity and digest.
int MD_WriteSave(const char *path);
int MD_ReadSave(const char *path);

#ifdef MD_TESTING
void MD_TestMonsters(int enabled);
int MD_TestCrossSpecial(int special);
int MD_TestFindSecret(float *x,float *y);
void MD_TestFaceState(int health, int damage, int attack, int invulnerable, int direction);
void MD_TestExit(int secret);
int MD_TestSwitch(int special, float *x,float *y,float *angle,int *side);
void MD_TestTarget(int type, float distance);
int MD_TestTargetHealth(void);
int MD_TestHealthForType(int type);
void MD_TestDamagePlayer(int damage);
int MD_TestPlacePlayer(float x, float y, float angle);
int MD_TestDoor(int ordinal, float *x, float *y, float *angle, int *sector);
int MD_TestKeyDoor(int key, float *x, float *y, float *angle, int *sector);
#endif

// Animation source frames, and their current engine translation. Indexes are copied IDs.
typedef struct { int index, flat; char name[9]; } MD_Material;
int MD_CopyAnimatedMaterials(MD_Material *output, int capacity);
int MD_TranslatedMaterial(int index, int flat);

int MD_Cheat(const char *name);
int MD_StartDemo(const char *name);
int MD_DemoPlaying(void);
void MD_StopDemo(void);

typedef struct { float x1,y1,x2,y2; int kind,mapped; } MD_MapLine;
int MD_CopyMapLines(MD_MapLine *output,int capacity);

// Original Doom episode story text; static storage.
const char *MD_FinaleText(int episode);

// Doom II: stats -> story -> next map, or the original interactive cast.
int MD_BeginStory(void);
const char *MD_StoryText(void);
const char *MD_StoryFlat(void);
int MD_StartCast(void);
int MD_CastTick(int attack);
typedef struct { char name[64], patch[9]; int member, flip, dying; } MD_Cast;
MD_Cast MD_GetCast(void);
#ifdef MD_TESTING
int MD_TestDamageType(int type, int damage, int limit);
int MD_TestSectorTag(int sector);
int MD_TestWakeBrain(void);
#endif

// Configure before the first map load; later calls must describe the same stack.
int MD_ConfigureWADStack(const char *paths, const int32_t *order, int count);

// Main-thread offline OPL2 rendering; 44.1 kHz stereo WAV, maximum ten minutes.
int MD_RenderOPL(const void *genmidi, int length, const char *midiPath, const char *wavPath);
