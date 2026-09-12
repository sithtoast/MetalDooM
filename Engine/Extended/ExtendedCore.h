// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <stddef.h>
#include <stdint.h>
#define ME_ABI_VERSION 1
#define ME_API __attribute__((visibility("default")))
/* Experimental single-session, single-thread worker ABI. All structures are
 * copied values. No Woof pointers/types cross this boundary. No unload/restart
 * or save contract yet: terminate the worker to reclaim a session (also after
 * an error). This core is NOT selected by the MetalDooM gameplay UI. */
typedef struct {
    uint32_t abi_version;
    const char *const *wad_paths; /* Doom II IWAD first, then ordered overlays. */
    uint32_t wad_count;
    const char *cache_directory; /* Existing caller-owned scratch directory. */
    uint32_t skill; /* 1..5 */
    uint32_t map;   /* MAP01..MAP32 for this bootstrap milestone. */
    uint32_t random_seed; /* Explicit seed; never use wall-clock time. */
} ME_Config;
typedef struct {
    int8_t forward_move, side_move;
    int16_t angle_turn;
    uint8_t buttons; /* Doom ticcmd bits: attack=1, use=2. */
} ME_Command;
typedef struct {
    uint32_t tic, state_count, thing_type_count, compatibility;
    int32_t x, y, z, health, ready_weapon, ammo[4], weapon_state;
    uint32_t pending_exit, sound_events;
} ME_Snapshot;
typedef struct {
    int32_t type, editor_number, state, x, y, z, health;
    uint32_t flags, flags2;
} ME_Thing;
ME_API int ME_Init(const ME_Config *config);
ME_API int ME_Tick(const ME_Command *command);
ME_API int ME_CopySnapshot(ME_Snapshot *out);
/* Returns total actors; copies at most capacity entries. */
ME_API size_t ME_CopyThings(ME_Thing *out, size_t capacity);
ME_API size_t ME_CopyError(char *out, size_t capacity);
