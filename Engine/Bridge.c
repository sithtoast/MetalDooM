// SPDX-License-Identifier: GPL-2.0-or-later
#include "Bridge.h"
#include <math.h>
#include <setjmp.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "doomstat.h"
#include "g_game.h"
#include "d_main.h"
#include "p_local.h"
#include "p_setup.h"
#include "p_tick.h"
#include "r_local.h"
#include "m_argv.h"
#include "w_wad.h"
#include "z_zone.h"
#include "i_system.h"

static jmp_buf errorBoundary;
static int guarded, initialized, poisoned, loaded;
static char errorText[1024], loadedPath[4096];
static char *arguments[] = {"MetalDooM", NULL};

// Native replacement for Chocolate Doom's fatal platform error handler.
// Unwind only within C; no Swift frames are crossed by longjmp.
void I_Error(const char *format, ...) {
    va_list args; va_start(args, format);
    vsnprintf(errorText, sizeof(errorText), format, args); va_end(args);
    poisoned = 1; loaded = 0;
    if (guarded) longjmp(errorBoundary, 1);
    fprintf(stderr,"MetalDooM engine error outside boundary: %s\n",errorText);
    abort();
}
const char *MD_LastError(void) { return errorText; }

int MD_Load(const char *path, int episode, int map) {
    if (poisoned) { snprintf(errorText,sizeof(errorText),"Engine encountered an error. Restart MetalDooM before loading another map."); return 0; }
    if (!path || strlen(path) >= sizeof(loadedPath)) { snprintf(errorText,sizeof(errorText),"Invalid IWAD path."); return 0; }
    if (initialized && strcmp(path,loadedPath)) {
        snprintf(errorText,sizeof(errorText),"This build supports one IWAD per session. Restart MetalDooM to open a different WAD."); return 0;
    }
    guarded = 1;
    if (setjmp(errorBoundary)) { guarded = 0; return 0; }
    if (!initialized) {
        myargc = 1; myargv = arguments;
        Z_Init();
        if (!W_AddFile((char *)path)) I_Error("Cannot open IWAD: %s",path);
        W_GenerateHashTable();
        gamemission = W_CheckNumForName("MAP01") >= 0 ? doom2 : doom;
        gamemode = gamemission == doom2 ? commercial : W_CheckNumForName("E4M1") >= 0 ? retail : W_CheckNumForName("E2M1") >= 0 ? registered : shareware;
        gameversion = gamemode == retail ? exe_ultimate : exe_doom_1_9;
        R_InitData(); P_Init();
        strcpy(loadedPath,path); initialized = 1;
    }
    char mapName[16];
    if (gamemode == commercial) snprintf(mapName,sizeof(mapName),"MAP%02d",map);
    else snprintf(mapName,sizeof(mapName),"E%dM%d",episode,map);
    if (W_CheckNumForName(mapName) < 0) { snprintf(errorText,sizeof(errorText),"Map %s is absent from the loaded IWAD.",mapName); guarded = 0; return 0; }
    consoleplayer = displayplayer = 0;
    memset(playeringame,0,sizeof(playeringame)); playeringame[0] = true;
    nomonsters = true; precache = false; netgame = false; deathmatch = 0;
    gametic = 0;
    G_InitNew(sk_medium,episode,map);
    // Until sprite rendering lands, avoid invisible pickups and decorations.
    // Player/sector thinkers remain original engine objects.
    thinker_t *thinker = thinkercap.next;
    while (thinker != &thinkercap) {
        thinker_t *next = thinker->next;
        if (thinker->function.acp1 == (actionf_p1)P_MobjThinker) {
            mobj_t *object = (mobj_t *)thinker;
            if (!object->player) P_RemoveMobj(object);
        }
        thinker = next;
    }
    memset(&players[0].cmd,0,sizeof(players[0].cmd));
    P_Ticker(); ++gametic;
    loaded = 1; guarded = 0; errorText[0] = 0;
    return 1;
}

int MD_Tick(int forward, int side, int turn, int use) {
    if (!loaded || poisoned) return 0;
    guarded = 1;
    if (setjmp(errorBoundary)) { guarded = 0; return 0; }
    ticcmd_t *command = &players[0].cmd;
    memset(command,0,sizeof(*command));
    command->forwardmove = (signed char)(forward < -50 ? -50 : forward > 50 ? 50 : forward);
    command->sidemove = (signed char)(side < -40 ? -40 : side > 40 ? 40 : side);
    command->angleturn = (short)turn;
    command->buttons = use ? BT_USE : 0;
    if (gameaction == ga_nothing) { P_Ticker(); ++gametic; }
    guarded = 0; return 1;
}
MD_Player MD_GetPlayer(void) {
    MD_Player result = {0};
    if (!loaded) return result;
    player_t *player = &players[0]; mobj_t *object = player->mo;
    result.x = (float)object->x/FRACUNIT; result.y = (float)object->y/FRACUNIT;
    result.eyeZ = (float)player->viewz/FRACUNIT;
    result.angle = (float)((double)object->angle * (2.0*M_PI/4294967296.0));
    result.tick = gametic; result.sector = (int)(object->subsector->sector-sectors);
    result.health = player->health; result.exitRequested = gameaction != ga_nothing;
    return result;
}
int MD_SectorCount(void) { return loaded ? numsectors : 0; }
MD_Sector MD_GetSector(int index) {
    MD_Sector result = {0};
    if (loaded && index >= 0 && index < numsectors) {
        result.floor = (float)sectors[index].floorheight/FRACUNIT;
        result.ceiling = (float)sectors[index].ceilingheight/FRACUNIT;
        result.light = (float)sectors[index].lightlevel/255.0f;
    }
    return result;
}

#ifdef MD_TESTING
int MD_TestPlacePlayer(float x, float y, float angle) {
    if (!loaded) return 0;
    mobj_t *object = players[0].mo;
    P_UnsetThingPosition(object);
    object->x = (fixed_t)(x*FRACUNIT); object->y = (fixed_t)(y*FRACUNIT);
    double normalized = fmod(angle,2*M_PI); if (normalized < 0) normalized += 2*M_PI;
    object->angle = (angle_t)(normalized * (4294967296.0/(2*M_PI)));
    P_SetThingPosition(object);
    object->floorz = object->subsector->sector->floorheight;
    object->ceilingz = object->subsector->sector->ceilingheight;
    object->z = object->floorz; object->momx = object->momy = object->momz = 0;
    players[0].viewz = object->z+41*FRACUNIT;
    players[0].usedown = false;
    return 1;
}
int MD_TestDoor(int ordinal, float *x, float *y, float *angle, int *sector) {
    for (int i=0; i<numlines; ++i) {
        line_t *line = &lines[i];
        if (line->special != 1 || !line->backsector || line->backsector->ceilingheight != line->backsector->floorheight) continue;
        if (ordinal-- > 0) continue;
        float dx = (float)line->dx/FRACUNIT, dy = (float)line->dy/FRACUNIT, length = hypotf(dx,dy);
        *x = ((float)line->v1->x+(float)line->v2->x)/(2*FRACUNIT)+dy/length*40;
        *y = ((float)line->v1->y+(float)line->v2->y)/(2*FRACUNIT)-dx/length*40;
        *angle = atan2f(dx,-dy);
        *sector = (int)(line->backsector-sectors); return i;
    }
    return -1;
}
#endif
