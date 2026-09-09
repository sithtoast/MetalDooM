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
#include "d_items.h"

static jmp_buf errorBoundary;
static int guarded, initialized, poisoned, loaded;
static char errorText[1024], loadedPath[4096];
static char *arguments[] = {"MetalDooM", NULL};
static char lastMessage[128];
static int messageSerial;
static int monstersEnabled = 1;
#ifdef MD_TESTING
void MD_TestMonsters(int enabled) { monstersEnabled = enabled; }
static mobj_t *testTarget;
void MD_TestTarget(int type, float distance) {
    mobj_t *p = players[0].mo;
    double angle = (double)p->angle * (2*M_PI/4294967296.0);
    testTarget = P_SpawnMobj(p->x+cos(angle)*distance*FRACUNIT,p->y+sin(angle)*distance*FRACUNIT,ONFLOORZ,(mobjtype_t)type);
    testTarget->angle = p->angle+ANG180;
}
int MD_TestTargetHealth(void) { return testTarget ? testTarget->health : 0; }
void MD_TestDamagePlayer(int damage) { P_DamageMobj(players[0].mo,NULL,NULL,damage); }
#endif
extern spritedef_t *sprites;

static void CaptureMessage(void) {
    if (players[0].message) {
        snprintf(lastMessage,sizeof(lastMessage),"%s",players[0].message);
        ++messageSerial;
        players[0].message = NULL;
    }
}

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
    nomonsters = !monstersEnabled; precache = false; netgame = false; deathmatch = 0;
    gametic = 0;
    G_InitNew(sk_medium,episode,map);
    // Original thinkers now drive monsters, weapons, projectiles and pickups.
    lastMessage[0] = 0; messageSerial = 0;
    memset(&players[0].cmd,0,sizeof(players[0].cmd));
    P_Ticker(); ++gametic;
    CaptureMessage();
    loaded = 1; guarded = 0; errorText[0] = 0;
    return 1;
}

int MD_Tick(int forward, int side, int turn, int use) {
    return MD_CombatTick(forward,side,turn,use,0,-1);
}
int MD_CombatTick(int forward, int side, int turn, int use, int attack, int weapon) {
    if (!loaded || poisoned) return 0;
    guarded = 1;
    if (setjmp(errorBoundary)) { guarded = 0; return 0; }
    ticcmd_t *command = &players[0].cmd;
    memset(command,0,sizeof(*command));
    command->forwardmove = (signed char)(forward < -50 ? -50 : forward > 50 ? 50 : forward);
    command->sidemove = (signed char)(side < -40 ? -40 : side > 40 ? 40 : side);
    command->angleturn = (short)turn;
    // R reloads the map; do not enter PS_REBORN without the full G_Ticker loop.
    command->buttons = use && players[0].health > 0 ? BT_USE : 0;
    if (attack) command->buttons |= BT_ATTACK;
    if (weapon >= 0 && weapon <= 6) command->buttons |= BT_CHANGE | (weapon << BT_WEAPONSHIFT);
    if (gameaction == ga_nothing) { P_Ticker(); ++gametic; CaptureMessage(); }
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

int MD_CopyThings(MD_Thing *output, int capacity, float cameraX, float cameraY) {
    if (!loaded) return 0;
    int count = 0;
    for (thinker_t *thinker=thinkercap.next; thinker!=&thinkercap; thinker=thinker->next) {
        if (thinker->function.acp1 != (actionf_p1)P_MobjThinker) continue;
        mobj_t *object = (mobj_t *)thinker;
        if (object->player || object->sprite < 0 || object->sprite >= numsprites) continue;
        spritedef_t *definition = &sprites[object->sprite];
        int frameIndex = object->frame & FF_FRAMEMASK;
        if (frameIndex >= definition->numframes) continue;
        spriteframe_t *frame = &definition->spriteframes[frameIndex];
        unsigned rotation = 0;
        if (frame->rotate) {
            angle_t angle = R_PointToAngle2((fixed_t)(cameraX*FRACUNIT),(fixed_t)(cameraY*FRACUNIT),object->x,object->y);
            rotation = (angle-object->angle+(unsigned)(ANG45/2)*9)>>29;
        }
        int lump = firstspritelump+frame->lump[rotation];
        if (lump < firstspritelump || lump > lastspritelump) continue;
        if (output && count < capacity) {
            output[count] = (MD_Thing){
                (float)object->x/FRACUNIT, (float)object->y/FRACUNIT, (float)object->z/FRACUNIT,
                (float)object->subsector->sector->lightlevel/255.0f,
                (float)object->floorz/FRACUNIT,
                lump, frame->flip[rotation], (object->frame & FF_FULLBRIGHT) != 0,
                mobjinfo[object->type].doomednum
            };
        }
        ++count;
    }
    return count;
}

int MD_CopyWeaponSprites(MD_WeaponSprite *output, int capacity) {
    if (!loaded) return 0;
    player_t *player = &players[0]; int count = 0;
    for (int i=0; i<NUMPSPRITES; ++i) {
        pspdef_t *psp = &player->psprites[i];
        if (!psp->state) continue;
        spriteframe_t *frame = &sprites[psp->state->sprite].spriteframes[psp->state->frame & FF_FRAMEMASK];
        if (output && count < capacity) output[count] = (MD_WeaponSprite){
            (float)psp->sx/FRACUNIT,(float)psp->sy/FRACUNIT,
            fminf(1,(float)player->mo->subsector->sector->lightlevel/255.0f + player->extralight*0.125f),
            firstspritelump+frame->lump[0],frame->flip[0],(psp->state->frame & FF_FULLBRIGHT) != 0
        };
        ++count;
    }
    return count;
}

MD_HUD MD_GetHUD(void) {
    MD_HUD hud = {0};
    if (!loaded) return hud;
    player_t *player = &players[0];
    hud.health = player->health; hud.armor = player->armorpoints;
    hud.readyWeapon = player->readyweapon;
    ammotype_t ammo = weaponinfo[player->readyweapon].ammo;
    hud.readyAmmo = ammo == am_noammo ? -1 : player->ammo[ammo];
    hud.bullets = player->ammo[am_clip]; hud.shells = player->ammo[am_shell];
    hud.cells = player->ammo[am_cell]; hud.rockets = player->ammo[am_misl];
    hud.maxBullets = player->maxammo[am_clip]; hud.maxShells = player->maxammo[am_shell];
    hud.maxCells = player->maxammo[am_cell]; hud.maxRockets = player->maxammo[am_misl];
    for (int i=0; i<NUMCARDS; ++i) if (player->cards[i]) hud.keys |= 1u<<i;
    for (int i=0; i<NUMWEAPONS; ++i) if (player->weaponowned[i]) hud.weapons |= 1u<<i;
    hud.damageFlash = player->damagecount; hud.kills = player->killcount; hud.totalKills = totalkills;
    hud.bonusFlash = player->bonuscount; hud.messageSerial = messageSerial; hud.tick = gametic;
    snprintf(hud.message,sizeof(hud.message),"%s",lastMessage);
    return hud;
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
int MD_TestKeyDoor(int key, float *x, float *y, float *angle, int *sector) {
    const int special[3] = {26,27,28}; // blue, yellow, red manual doors
    if (key < 0 || key > 2) return -1;
    for (int i=0; i<numlines; ++i) {
        line_t *line = &lines[i];
        if (line->special != special[key] || !line->backsector || line->backsector->ceilingheight != line->backsector->floorheight) continue;
        float dx=(float)line->dx/FRACUNIT, dy=(float)line->dy/FRACUNIT, length=hypotf(dx,dy);
        *x=((float)line->v1->x+(float)line->v2->x)/(2*FRACUNIT)+dy/length*40;
        *y=((float)line->v1->y+(float)line->v2->y)/(2*FRACUNIT)-dx/length*40;
        *angle=atan2f(dx,-dy); *sector=(int)(line->backsector-sectors); return i;
    }
    return -1;
}
#endif
