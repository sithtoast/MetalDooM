// SPDX-License-Identifier: GPL-2.0-or-later
#include "ExtendedCore.h"
#include "NativeInternal.h"
#include "SessionPlan.h"
#include "deh_strings.h"
#include <setjmp.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include "p_mobj.h"
#include "doomstat.h"
#include "d_event.h"
#include "dsdh_main.h"
#include "deh_main.h"
#include "g_game.h"
#include "g_umapinfo.h"
#include "w_wad.h"
#include "r_data.h"
#include "p_setup.h"
#include "p_tick.h"
#include "m_argv.h"
#include "m_config.h"
#include "mn_internal.h"
#include "m_array.h"
#include "m_random.h"
#include "i_system.h"
#include "z_zone.h"

static jmp_buf error_boundary;
static int entered, attempted, ready, failed;
static char error_text[2048], cache_directory[4096];
static uint32_t sound_events;
static char *arguments[] = {"metaldoom-extended", "-complevel", "mbf21", NULL};

_Noreturn void ME_Fatal(const char *prefix, const char *message)
{
    snprintf(error_text, sizeof(error_text), "%s: %s", prefix, message);
    ready = 0;
    failed = 1;
    if (entered) longjmp(error_boundary, 1);
    /* A fatal outside a guarded operation is a programming error. */
    abort();
}
const char *ME_CacheDirectory(void) { return cache_directory; }
void ME_RecordSound(void) { sound_events++; }
size_t ME_CopyError(char *out, size_t capacity)
{
    if (out && capacity) snprintf(out, capacity, "%s", error_text);
    return strlen(error_text);
}
static void ValidateTable(const char *name, size_t stride, size_t sentinel_offset)
{
    int lump = W_CheckNumForName(name);
    if (lump < 0) return;
    size_t length = W_LumpLength(lump);
    const unsigned char *data = W_CacheLumpNum(lump, PU_STATIC);
    int terminated = 0;
    for (size_t i = 0; i + stride <= length; i += stride) {
        if ((!strcmp(name, "ANIMATED") && data[i] == 255) ||
            (!strcmp(name, "SWITCHES") && !data[i + sentinel_offset] && !data[i + sentinel_offset + 1])) {
            terminated = 1; break;
        }
        size_t start = !strcmp(name, "ANIMATED") ? 1 : 0;
        if (!memchr(data + i + start, 0, 9) || !memchr(data + i + start + 9, 0, 9))
            I_Error("%s contains an unterminated name", name);
    }
    if (!terminated) I_Error("%s has no complete terminator", name);
    Z_ChangeTag((void *)data, PU_CACHE);
}
int ME_Init(const ME_Config *config)
{
    if (attempted) {
        snprintf(error_text, sizeof(error_text), "One session per worker; start a new process");
        return 0;
    }
    attempted = 1;
    entered = 1;
    if (setjmp(error_boundary)) { entered = 0; return 0; }
    if (!config || config->abi_version != ME_ABI_VERSION || !config->wad_paths ||
        !config->wad_count || config->wad_count > 32 || !config->cache_directory ||
        config->skill < 1 || config->skill > 5 || config->map < 1 || config->map > 32)
        I_Error("Invalid extended worker configuration");
    struct stat st;
    if (strlen(config->cache_directory) >= sizeof(cache_directory) ||
        stat(config->cache_directory, &st) || !S_ISDIR(st.st_mode))
        I_Error("An existing scratch directory is required");
    ME_PlanSession(config);
    strcpy(cache_directory, config->cache_directory);
    myargc = 3; myargv = arguments;
    gamemode = commercial; gamemission = doom2;
    /* Apply bound simulation defaults without reading the user's Woof config. */
    G_BindGameVariables(); G_BindEnemVariables();
    G_BindCompVariables(); G_BindWeapVariables();
    default_t last_entry = {0};
    array_push(defaults, last_entry);
    for (unsigned i = 0; i + 1 < array_size(defaults); i++) {
        default_t *d = &defaults[i];
        if (d->type == number) *d->location.i = d->defaultvalue.number;
        else if (d->type == string) *d->location.s = strdup(d->defaultvalue.string);
    }
    DSDH_Init(); DEH_Init();
    for (uint32_t i = 0; i < config->wad_count; i++) {
        const char *path = config->wad_paths[i];
        if (!path || stat(path, &st) || !S_ISREG(st.st_mode)) I_Error("WAD file is missing");
        if (!W_AddPath(path)) I_Error("Cannot add WAD: %s", path);
    }
    W_InitMultipleFiles();
    ValidateTable("ANIMATED", 23, 0);
    ValidateTable("SWITCHES", 20, 18);
    for (int i = 0; i < numlumps; i++)
        if (!strncasecmp(lumpinfo[i].name, "DEHACKED", 8)) DEH_LoadLump(i);
    DEH_PostProcess();
    for (int i = 0; i < num_mobj_types; i++)
        if (mobjinfo[i].pickup_message)
            (void)DEH_StringForMnemonic(mobjinfo[i].pickup_message);
    W_ProcessInWads("UMAPINFO", G_ParseMapInfo, PROCESS_IWAD | PROCESS_PWAD);
    G_ReloadDefaults(false);
    rngseed = config->random_seed;
    ME_ApplySessionOptions();
    R_InitData(); P_Init();
    playeringame[0] = true; precache = false;
    G_InitNew((skill_t)(config->skill - 1), 1, config->map, false);
    ready = 1;
    entered = 0;
    return 1;
}
int ME_Tick(const ME_Command *command)
{
    if (!ready || failed || !command) return 0;
    entered = 1;
    if (setjmp(error_boundary)) { entered = 0; return 0; }
    if (gameaction != ga_nothing) I_Error("Level transition requires a future campaign adapter");
    memset(&players[0].cmd, 0, sizeof(players[0].cmd));
    players[0].cmd.forwardmove = command->forward_move;
    players[0].cmd.sidemove = command->side_move;
    players[0].cmd.angleturn = command->angle_turn;
    if ((command->buttons & BT_SPECIAL) ||
        ((command->buttons & BT_CHANGE) &&
         ((command->buttons & BT_WEAPONMASK) >> BT_WEAPONSHIFT) >= NUMWEAPONS))
        I_Error("Invalid worker command buttons");
    players[0].cmd.buttons = command->buttons;
    P_Ticker(); gametic++;
    entered = 0;
    return 1;
}
int ME_CopySnapshot(ME_Snapshot *out)
{
    if (!ready || !out) return 0;
    const player_t *p = &players[0];
    memset(out, 0, sizeof(*out));
    out->tic = leveltime; out->state_count = num_states; out->thing_type_count = num_mobj_types;
    out->compatibility = demo_version;
    out->x = p->mo->x; out->y = p->mo->y; out->z = p->mo->z; out->health = p->health;
    out->ready_weapon = p->readyweapon;
    for (int i = 0; i < 4; i++) out->ammo[i] = p->ammo[i];
    out->weapon_state = p->psprites[0].state ? (int)(p->psprites[0].state - states) : 0;
    out->pending_exit = gameaction != ga_nothing;
    out->sound_events = sound_events;
    snprintf(out->message, sizeof(out->message), "%s", p->message ? p->message : "");
    if (gamemapinfo) {
        snprintf(out->level_name,sizeof(out->level_name),"%s",gamemapinfo->levelname ? gamemapinfo->levelname : "");
        snprintf(out->next_map,sizeof(out->next_map),"%s",gamemapinfo->nextmap);
        snprintf(out->secret_map,sizeof(out->secret_map),"%s",gamemapinfo->nextsecret);
        snprintf(out->end_finale,sizeof(out->end_finale),"%s",gamemapinfo->endfinale);
        out->map_flags = gamemapinfo->flags;
        out->boss_action_count = array_size(gamemapinfo->bossactions);
    }
    return 1;
}
size_t ME_CopyThings(ME_Thing *out, size_t capacity)
{
    if (!ready) return 0;
    size_t count = 0;
    for (thinker_t *t = thinkercap.next; t != &thinkercap; t = t->next) {
        if (t->function.p1 != P_MobjThinker) continue;
        mobj_t *m = (mobj_t *)t;
        if (out && count < capacity) out[count] = (ME_Thing){
            m->type, m->info->doomednum, (int)(m->state - states), m->x, m->y, m->z,
            m->health, m->flags, m->flags2, m->info->spawnhealth,
            m->info->min_respawn_tics, m->info->respawn_dice};
        count++;
    }
    return count;
}

int ME_CopySession(ME_Session *out)
{
    if (!ready || !out) return 0;
    *out = *ME_CurrentSession();
    return 1;
}

size_t ME_CopyGeometry(void *out, size_t capacity)
{
    if (!ready) return 0;
    entered = 1;
    if (setjmp(error_boundary)) { entered = 0; return 0; }
    size_t result = ME_WriteGeometry(out, capacity);
    entered = 0;
    return result;
}

int ME_CopyView(ME_View *out)
{
    if (!ready || !out) return 0;
    memset(out, 0, sizeof(*out));
    out->tic=leveltime; out->angle=players[0].mo->angle;
    out->x=players[0].mo->x; out->y=players[0].mo->y;
    out->eye_z=players[0].viewz; out->health=players[0].health;
    /* P_SpawnPlayer sets viewheight; viewz is first computed by P_PlayerThink.
     * Supply the standing spawn camera without advancing simulation/RNG. */
    if (!leveltime) {
        int64_t eye=(int64_t)players[0].mo->z+players[0].viewheight;
        int64_t ceiling=(int64_t)players[0].mo->ceilingz-4*FRACUNIT;
        out->eye_z=(int32_t)(eye<ceiling ? eye:ceiling);
    }
    const char *sky=gamemapinfo && gamemapinfo->skytexture[0] ? gamemapinfo->skytexture :
        gamemap > 20 ? "SKY3" : gamemap > 11 ? "SKY2" : "SKY1";
    snprintf(out->sky,sizeof(out->sky),"%s",sky);
    return 1;
}

size_t ME_CopyPresentation(void *out, size_t capacity)
{
    if (!ready) return 0;
    entered=1;
    if (setjmp(error_boundary)) { entered=0; return 0; }
    size_t result=ME_WritePresentation(out,capacity);
    entered=0;return result;
}
