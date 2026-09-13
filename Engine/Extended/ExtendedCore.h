// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <stddef.h>
#include <stdint.h>
#define ME_ABI_VERSION 2
#define ME_API __attribute__((visibility("default")))
/* Experimental single-session, single-thread worker ABI. All structures are
 * copied values. No Woof pointers/types cross this boundary. No unload/reinitialization
 * or save contract yet: terminate the worker to reclaim a session (also after
 * an error). This core is NOT selected by the MetalDooM gameplay UI. */
enum { ME_PROFILE_MBF21 = 0, ME_PROFILE_RUST_PROBE = 1, ME_PROFILE_BUNDLED_COMPONENTS = 2 };
/* RUST_PROBE is an explicit development opt-in, NOT ID24 compatibility. */
typedef struct {
    uint32_t abi_version;
    const char *const *wad_paths; /* Exact resource order, independent of base identity. */
    uint32_t wad_count;
    const char *cache_directory; /* Existing caller-owned scratch directory. */
    uint32_t skill; /* 1..5 */
    uint32_t map;   /* MAP01..MAP32 for this bootstrap milestone. */
    uint32_t random_seed; /* Explicit seed; never use wall-clock time. */
    uint32_t base_wad_index;
    uint32_t profile;
} ME_Config;
typedef struct {
    int8_t forward_move, side_move;
    int16_t angle_turn;
    uint8_t buttons; /* Doom ticcmd attack/use and validated weapon-change bits. */
} ME_Command;
typedef struct {
    uint32_t tic, state_count, thing_type_count, compatibility;
    int32_t x, y, z, health, ready_weapon, ammo[4], weapon_state;
    uint32_t pending_exit, sound_events;
    char message[256];
    char level_name[128], next_map[9], secret_map[9], end_finale[9];
    uint32_t map_flags, boss_action_count;
} ME_Snapshot;
typedef struct {
    int32_t type, editor_number, state, x, y, z, health;
    uint32_t flags, flags2;
    int32_t spawn_health, min_respawn_tics, respawn_dice;
} ME_Thing;
typedef struct {
    uint32_t profile, base_wad_index, wad_count, declared_feature, option_count;
    char content_sha256[65]; /* Ordered content + base role + profile; no paths. */
    char title[128], version[64];
} ME_Session;
ME_API int ME_CopySession(ME_Session *out);
ME_API int ME_Init(const ME_Config *config);
ME_API int ME_Tick(const ME_Command *command);
ME_API int ME_CopySnapshot(ME_Snapshot *out);
/* Returns total actors; copies at most capacity entries. */
ME_API size_t ME_CopyThings(ME_Thing *out, size_t capacity);
ME_API size_t ME_CopyError(char *out, size_t capacity);
/* MGE6 geometry snapshot; see docs/EXTENDED_PRESENTATION.md. Returns required
 * bytes, copying only when capacity fits the complete snapshot. NULL queries
 * size. Zero means no ready session/error. Call on the session thread between
 * ticks. This is copied data, not an IPC or save-game contract. */
ME_API size_t ME_CopyGeometry(void *out, size_t capacity);
typedef struct {
    uint32_t tic, angle;
    int32_t x, y, eye_z, health;
    char sky[9];
} ME_View;
ME_API int ME_CopyView(ME_View *out);

/* MSP6 resolved sprite/weapon values, same whole-buffer semantics as geometry. */
ME_API size_t ME_CopyPresentation(void *out, size_t capacity);

/* MMT2 animation translations and authoritative layered/fire skies, same whole-buffer semantics as geometry. */
ME_API size_t ME_CopyMaterials(void *out, size_t capacity);
/* MBL4 palettes/custom colormaps, brightmaps and blend table bank; refresh after level changes/restore. */
ME_API size_t ME_CopyBlendTables(void *out, size_t capacity);

/* Opt in before initialization. Headless probes remain capture-free by default. */
ME_API int ME_EnableAudio(void);
/* MSA1 FIFO: NULL/undersized queries preserve events; a complete copy drains. */
ME_API size_t ME_CopyAudio(void *out,size_t capacity);

/* MUI4 HUD/music/lifecycle presentation; complete-copy semantics, no state drain. */
ME_API size_t ME_CopyUI(void *out,size_t capacity);
/* 0: restart current level with fresh inventory; 1: continue completed level.
 * Returns a fresh tic-zero world. Does not reinitialize the session/resources. */
ME_API int ME_Advance(uint32_t action);

// Boundary-only JSON, at most 1 MiB. Size queries/short buffers never write.
ME_API size_t ME_CopyCampaign(void *out,size_t capacity);

ME_API size_t ME_CopySave(void *out,size_t capacity);
ME_API int ME_RestoreSave(const void *data,size_t size);
