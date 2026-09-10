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
#include "p_inter.h"
#include "p_setup.h"
#include "p_tick.h"
#include "r_local.h"
#include "m_argv.h"
#include "w_wad.h"
#include "z_zone.h"
#include "i_system.h"
#include "d_items.h"
#include "d_englsh.h"
#include "f_finale.h"

const char *MD_FinaleText(int episode) {
    switch (episode) { case 1: return E1TEXT; case 2: return E2TEXT; case 3: return E3TEXT; case 4: return E4TEXT; default: return ""; }
}

#include "p_saveg.h"
#include "s_sound.h"
#include "sounds.h"

static jmp_buf errorBoundary;
static int guarded, initialized, poisoned, loaded;
static char errorText[1024], loadedPath[4096];
static char *stackPaths;
static int32_t *stackOrder;
static int stackCount;
static int sigilEpisode;
static char *arguments[] = {"MetalDooM", NULL};
static char lastMessage[128];
static int messageSerial;
static int monstersEnabled = 1;
static void RefreshAnimations(void);
static void RevealMap(void);
static int weaponGrinTicks;
static byte *nativeDemo;
static int nativeDemoSize, nativeDemoOffset;
static int faceIndex, faceCount, facePriority, faceOldHealth, faceAttack;
static unsigned faceRandom;
// ST_Start is called for each new level. Keep presentation state out of saves.
void MD_ResetFace(void) { weaponGrinTicks = 0; faceIndex=0; faceCount=0; facePriority=0; faceOldHealth=players[0].health; faceAttack=-1; faceRandom=1; }
static unsigned WeaponMask(void) {
    unsigned mask = 0;
    for (int i=0;i<NUMWEAPONS;++i) if (players[0].weaponowned[i]) mask |= 1u<<i;
    return mask;
}
// Native presentation counterpart of st_stuff.c's priorities and tic durations.
// Uses its own random stream; presentation never consumes gameplay randomness.
static void UpdateFace(int newWeapon) {
    player_t *p=&players[0];
    int health=p->health<0 ? 0 : p->health>100 ? 100 : p->health;
    int pain=8*((100-health)*5/101);
    faceRandom=faceRandom*1664525u+1013904223u;
    if (p->health<=0) { facePriority=9; faceIndex=41; faceCount=1; }
    if (facePriority<9 && newWeapon) { facePriority=8; faceIndex=pain+6; faceCount=2*TICRATE; }
    if (facePriority<8 && p->damagecount && !(facePriority==7 && faceIndex%8==5 && faceCount>0)) {
        facePriority=7; faceCount=TICRATE;
        // Correct vanilla's reversed subtraction so large damage actually shows OUCH.
        if (faceOldHealth-p->health>20) faceIndex=pain+5;
        else if (p->attacker && p->attacker!=p->mo) {
            angle_t angle=R_PointToAngle2(p->mo->x,p->mo->y,p->attacker->x,p->attacker->y);
            angle_t delta=angle-p->mo->angle;
            faceIndex=pain+((delta<ANG45 || delta>ANG270+ANG45) ? 7 : delta>ANG180 ? 3 : 4);
        } else { facePriority=6; faceIndex=pain+7; }
    }
    if (facePriority<6) {
        if (p->attackdown) {
            if (faceAttack<0) faceAttack=2*TICRATE;
            else if (--faceAttack==0) { facePriority=5; faceIndex=pain+7; faceCount=1; faceAttack=1; }
        } else faceAttack=-1;
    }
    if (facePriority<5 && ((p->cheats & CF_GODMODE) || p->powers[pw_invulnerability])) {
        facePriority=4; faceIndex=40; faceCount=1;
    }
    if (!faceCount) { facePriority=0; faceIndex=pain+(faceRandom>>16)%3; faceCount=TICRATE/2; }
    --faceCount; faceOldHealth=p->health;
}
#ifdef MD_TESTING
void MD_TestFaceState(int health,int damage,int attack,int invulnerable,int direction) {
    player_t *p=&players[0]; p->health=health; p->damagecount=damage;
    p->attackdown=attack; p->powers[pw_invulnerability]=invulnerable;
    static mobj_t attacker; p->attacker=NULL;
    if(direction) { attacker.x=p->mo->x; attacker.y=p->mo->y+direction*64*FRACUNIT; p->mo->angle=0; p->attacker=&attacker; }
    UpdateFace(0);
}
void MD_TestMonsters(int enabled) { monstersEnabled = enabled; }
static mobj_t *testTarget;
void MD_TestTarget(int type, float distance) {
    mobj_t *p = players[0].mo;
    double angle = (double)p->angle * (2*M_PI/4294967296.0);
    testTarget = P_SpawnMobj(p->x+cos(angle)*distance*FRACUNIT,p->y+sin(angle)*distance*FRACUNIT,ONFLOORZ,(mobjtype_t)type);
    testTarget->angle = p->angle+ANG180;
}
int MD_TestHealthForType(int type) {
    for(thinker_t *t=thinkercap.next;t!=&thinkercap;t=t->next)
        if(t->function.acp1==(actionf_p1)P_MobjThinker && ((mobj_t *)t)->type==type) return ((mobj_t *)t)->health;
    return -99999;
}
int MD_TestTargetHealth(void) { return testTarget ? testTarget->health : 0; }
void MD_TestDamagePlayer(int damage) { P_DamageMobj(players[0].mo,NULL,NULL,damage); }
#endif
extern spritedef_t *sprites;
extern int numtextures;
static char (*textureNames)[9];
static void CacheTextureNames(void) {
    textureNames = calloc(numtextures,sizeof(*textureNames));
    if (!textureNames) I_Error("Cannot allocate native texture names");
    const char *lumps[] = {"TEXTURE1","TEXTURE2"};
    for (int k=0;k<2;++k) {
        int lump=W_CheckNumForName(lumps[k]); if(lump<0) continue;
        int size=W_LumpLength(lump); byte *data=W_CacheLumpNum(lump,PU_STATIC);
        if(size<4) I_Error("Invalid texture directory");
        int32_t raw; memcpy(&raw,data,4); int count=LONG(raw);
        if(count<0 || count>(size-4)/4) I_Error("Invalid texture count");
        for(int i=0;i<count;++i) {
            memcpy(&raw,data+4+i*4,4); int offset=LONG(raw);
            if(offset<0 || offset>size-8) I_Error("Invalid texture name offset");
            char name[9]={0}; memcpy(name,data+offset,8);
            int index=R_CheckTextureNumForName(name);
            if(index>=0 && index<numtextures) memcpy(textureNames[index],name,9);
        }
        W_ReleaseLumpNum(lump);
    }
}
extern void G_DoCompleted(void), G_DoWorldDone(void);
static MD_Progress progress;
MD_Progress MD_GetProgress(void) { return progress; }
void MD_IntermissionSound(int sound) {
    if (!loaded || poisoned || !progress.phase) return;
    const int ids[] = {sfx_pistol,sfx_barexp,sfx_sgcock};
    if (sound >= 0 && sound < 3) S_StartSound(NULL,ids[sound]);
}
static void CompleteLevel(void) {
    progress = (MD_Progress){.phase=1,.episode=gameepisode,.map=gamemap,
        .commercial=gamemode == commercial,.kills=players[0].killcount,.maxKills=totalkills,
        .items=players[0].itemcount,.maxItems=totalitems,.secrets=players[0].secretcount,
        .maxSecrets=totalsecret,.seconds=leveltime/TICRATE};
    // SIGIL follows episode 3's secret return, without episode 3's boss action.
    int originalEpisode=gameepisode;
    if(sigilEpisode && gameepisode==5) gameepisode=3;
    G_DoCompleted(); gameepisode=originalEpisode;
    if(sigilEpisode && gameepisode==5) {
        static const int pars[]={90,150,360,420,780,420,780,300,660};
        wminfo.epsd=4;wminfo.partime=pars[gamemap-1]*TICRATE;
    }
    progress.didSecret = players[0].didsecret;
    if (gameaction == ga_victory) {
        progress.phase = 2; gameaction = ga_nothing;
    } else {
        progress.nextMap = wminfo.next+1; progress.parSeconds = wminfo.partime/TICRATE;
    }
}
int MD_Continue(void) {
    if (!loaded || poisoned || (progress.phase != 1 && progress.phase != 3) || (gamemode == commercial && gamemap == 30)) return 0;
    char name[16];
    if (gamemode == commercial) snprintf(name,sizeof(name),"MAP%02d",progress.nextMap);
    else snprintf(name,sizeof(name),"E%dM%d",gameepisode,progress.nextMap);
    if (W_CheckNumForName(name) < 0) { snprintf(errorText,sizeof(errorText),"Next map %s is absent.",name); return 0; }
    guarded = 1;
    if (setjmp(errorBoundary)) { guarded = 0; return 0; }
    // Unlike G_InitNew, this preserves the surviving player's inventory.
    G_DoWorldDone();
    P_Ticker(); ++gametic; UpdateFace(0);
    progress = (MD_Progress){.episode=gameepisode,.map=gamemap,.commercial=gamemode == commercial};
    lastMessage[0] = 0; ++messageSerial;
    memset(&players[0].cmd,0,sizeof(players[0].cmd));
    guarded = 0; return 1;
}
// Fixed-width extension preserves RNG, full tic time and pending button resets
// omitted by the original archive. All pointers remain process-local.
extern int rndindex, prndindex;
#define MD_SAVE_WORDS (6 + MAXBUTTONS*4)
int MD_WriteSave(const char *path) {
    if (!loaded || poisoned || progress.phase || players[0].health <= 0) {
        snprintf(errorText,sizeof(errorText),"Save during a live level, before death."); return 0;
    }
    save_stream = fopen(path,"wb");
    if (!save_stream) { snprintf(errorText,sizeof(errorText),"Cannot create save data."); return 0; }
    guarded=1;
    if(setjmp(errorBoundary)) { if(save_stream) fclose(save_stream);save_stream=NULL;guarded=0;return 0; }
    savegame_error=false;
    P_WriteSaveGameHeader("MetalDooM");
    P_ArchivePlayers();P_ArchiveWorld();P_ArchiveThinkers();P_ArchiveSpecials();P_WriteSaveGameEOF();
    int32_t extra[MD_SAVE_WORDS]={0x4d445331,gametic,leveltime,rndindex,prndindex,1};
    for(int i=0;i<MAXBUTTONS;++i) {
        button_t *b=&buttonlist[i];int offset=6+i*4;
        extra[offset]=b->btimer ? (int)(b->line-lines) : -1;
        extra[offset+1]=b->where;extra[offset+2]=b->btexture;extra[offset+3]=b->btimer;
    }
    int ok=!savegame_error && fwrite(extra,sizeof(extra),1,save_stream)==1 && !ferror(save_stream);
    if(fclose(save_stream)) ok=0;
    save_stream=NULL;guarded=0;
    if(!ok) snprintf(errorText,sizeof(errorText),"Cannot finish writing save data.");
    return ok;
}
int MD_ReadSave(const char *path) {
    if(!loaded || poisoned) { snprintf(errorText,sizeof(errorText),"Open the matching WAD before loading a save.");return 0; }
    save_stream=fopen(path,"rb");
    if(!save_stream) { snprintf(errorText,sizeof(errorText),"Cannot read save data.");return 0; }
    // Reject bad headers/extensions before changing the live game.
    unsigned char header[50];int32_t extra[MD_SAVE_WORDS];char version[16]={0};
    snprintf(version,sizeof(version),"version %i",G_VanillaVersionCode());
    int ok=fread(header,sizeof(header),1,save_stream)==1;
    ok=ok && !memcmp(header+24,version,16) && header[40]<=4 && header[41]>=1 && header[41]<=(sigilEpisode ? 5:4)
        && header[42]>=1 && header[42]<=(gamemode==commercial ? 32 : 9)
        && header[43]==1 && !header[44] && !header[45] && !header[46];
    ok=ok && !fseek(save_stream,-(long)sizeof(extra),SEEK_END) && fread(extra,sizeof(extra),1,save_stream)==1
        && extra[0]==0x4d445331 && extra[5]==1 && extra[1]>=0 && extra[2]>=0
        && extra[3]>=0 && extra[3]<256 && extra[4]>=0 && extra[4]<256;
    char mapName[16];
    if(ok) {
        if(gamemode==commercial) snprintf(mapName,sizeof(mapName),"MAP%02d",header[42]);
        else snprintf(mapName,sizeof(mapName),"E%dM%d",header[41],header[42]);
        ok=W_CheckNumForName(mapName)>=0;
    }
    if(!ok) { fclose(save_stream);save_stream=NULL;snprintf(errorText,sizeof(errorText),"Invalid or incompatible save data.");return 0; }
    rewind(save_stream);guarded=1;
    if(setjmp(errorBoundary)) { if(save_stream) fclose(save_stream);save_stream=NULL;guarded=0;return 0; }
    savegame_error=false;
    if(!P_ReadSaveGameHeader()) I_Error("Invalid native save header");
    MD_StopDemo();
    G_InitNew(gameskill,gameepisode,gamemap);
    P_UnArchivePlayers();P_UnArchiveWorld();P_UnArchiveThinkers();P_UnArchiveSpecials();
    if(!P_ReadSaveGameEOF() || savegame_error) I_Error("Invalid native save archive");
    int32_t trailing[MD_SAVE_WORDS];
    if(fread(trailing,sizeof(trailing),1,save_stream)!=1 || memcmp(trailing,extra,sizeof(extra)) || fgetc(save_stream)!=EOF) I_Error("Invalid native save extension");
    fclose(save_stream);save_stream=NULL;
    gametic=extra[1];leveltime=extra[2];rndindex=extra[3];prndindex=extra[4];
    memset(buttonlist,0,sizeof(buttonlist));
    for(int i=0;i<MAXBUTTONS;++i) {
        int offset=6+i*4,line=extra[offset],where=extra[offset+1],texture=extra[offset+2],timer=extra[offset+3];
        if(!timer) continue;
        if(line<0 || line>=numlines || where<0 || where>2 || texture<0 || texture>=numtextures || timer<0 || timer>BUTTONTIME) I_Error("Invalid saved switch");
        buttonlist[i].line=&lines[line];buttonlist[i].where=where;buttonlist[i].btexture=texture;buttonlist[i].btimer=timer;
        buttonlist[i].soundorg=&lines[line].frontsector->soundorg;
    }
    memset(&players[0].cmd,0,sizeof(players[0].cmd));
    players[0].attackdown=players[0].usedown=false;
    MD_ResetFace(); UpdateFace(0); RefreshAnimations();
    lastMessage[0]=0;++messageSerial;
    progress=(MD_Progress){.episode=gameepisode,.map=gamemap,.commercial=gamemode==commercial};
    gameaction=ga_nothing;S_Start();guarded=0;return 1;
}

MD_Side MD_GetSide(int index) {
    MD_Side result = {0};
    if (!loaded || index < 0 || index >= numsides) return result;
    side_t *side = &sides[index]; result.x = (float)side->textureoffset/FRACUNIT; result.y = (float)side->rowoffset/FRACUNIT;
    int ids[] = {side->toptexture,side->bottomtexture,side->midtexture};
    char *names[] = {result.upper,result.lower,result.middle};
    for (int i=0;i<3;++i) {
        if (ids[i] > 0 && ids[i] < numtextures) { memcpy(names[i],textureNames[ids[i]],8); names[i][8]=0; }
        else strcpy(names[i],"-");
    }
    return result;
}

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

int MD_GetSkill(void) { return gameskill; }
int MD_Load(const char *path, int episode, int map) { return MD_LoadSkill(path,episode,map,2); }
int MD_LoadSkill(const char *path, int episode, int map, int skill) {
    if (skill < 0 || skill > 4) { snprintf(errorText,sizeof(errorText),"Invalid difficulty."); return 0; }
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
        if (stackPaths) {
            char *paths=strdup(stackPaths), *save=NULL, *part=strtok_r(paths,"\n",&save);
            if (!part || strcmp(part,path)) I_Error("WAD stack base does not match IWAD");
            while((part=strtok_r(NULL,"\n",&save))) if(!W_AddFile(part)) I_Error("Cannot open PWAD: %s",part);
            free(paths);
            lumpinfo_t **ordered=malloc(stackCount*sizeof(*ordered));
            byte *used=calloc(numlumps,1);
            if(!ordered || !used) I_Error("Cannot allocate WAD directory");
            for(int i=0;i<stackCount;i++) {
                int index=stackOrder[i];
                if(index<0 || (unsigned)index>=numlumps || used[index]) I_Error("Invalid WAD directory plan");
                used[index]=1; ordered[i]=lumpinfo[index];
            }
            free(used);free(lumpinfo);lumpinfo=ordered;numlumps=stackCount;
            modifiedgame=true;
        }
        W_GenerateHashTable();
        sigilEpisode=W_CheckNumForName("E5M1")>=0 && W_CheckNumForName("E5TEXT")>=0;
        gamemission = W_CheckNumForName("MAP01") >= 0 ? doom2 : doom;
        gamemode = gamemission == doom2 ? commercial : W_CheckNumForName("E4M1") >= 0 ? retail : W_CheckNumForName("E2M1") >= 0 ? registered : shareware;
        gameversion = gamemode == retail ? exe_ultimate : exe_doom_1_9;
        R_InitData(); CacheTextureNames(); P_Init();
        strcpy(loadedPath,path); initialized = 1;
    }
    char mapName[16];
    if (gamemode == commercial) snprintf(mapName,sizeof(mapName),"MAP%02d",map);
    else snprintf(mapName,sizeof(mapName),"E%dM%d",episode,map);
    if (W_CheckNumForName(mapName) < 0) { snprintf(errorText,sizeof(errorText),"Map %s is absent from the loaded IWAD.",mapName); guarded = 0; return 0; }
    consoleplayer = displayplayer = 0;
    memset(playeringame,0,sizeof(playeringame)); playeringame[0] = true;
    nomonsters = !monstersEnabled; precache = false; netgame = false; deathmatch = 0;
    MD_StopDemo();
    gametic = 0;
    G_InitNew((skill_t)skill,episode,map);
    progress = (MD_Progress){.episode=gameepisode,.map=gamemap,.commercial=gamemode == commercial};
    // Original thinkers now drive monsters, weapons, projectiles and pickups.
    lastMessage[0] = 0; messageSerial = 0;
    memset(&players[0].cmd,0,sizeof(players[0].cmd));
    P_Ticker(); ++gametic; UpdateFace(0);
    CaptureMessage();
    loaded = 1; guarded = 0; errorText[0] = 0;
    return 1;
}

int MD_Tick(int forward, int side, int turn, int use) {
    return MD_CombatTick(forward,side,turn,use,0,-1);
}
int MD_CombatTick(int forward, int side, int turn, int use, int attack, int weapon) {
    if (!loaded || poisoned) return 0;
    if (progress.phase != 0) return 1;
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
    if (nativeDemo) {
        if(nativeDemoOffset>=nativeDemoSize || nativeDemo[nativeDemoOffset]==0x80) {
            MD_StopDemo(); guarded=0; return 1;
        }
        byte *tic=nativeDemo+nativeDemoOffset; nativeDemoOffset+=4;
        command->forwardmove=(signed char)tic[0]; command->sidemove=(signed char)tic[1];
        command->angleturn=(short)(tic[2]<<8); command->buttons=tic[3];
        if(command->buttons & BT_SPECIAL) command->buttons=0;
    }
    if (gameaction == ga_nothing) {
        unsigned oldWeapons = WeaponMask();
        if (weaponGrinTicks > 0) --weaponGrinTicks;
        P_Ticker(); ++gametic; CaptureMessage();
        // Original status bar: a newly acquired weapon earns a two-second grin.
        if (players[0].bonuscount && (WeaponMask() & ~oldWeapons)) weaponGrinTicks = 2*TICRATE;
        if (players[0].health <= 0) weaponGrinTicks = 0;
        UpdateFace(players[0].bonuscount && (WeaponMask() & ~oldWeapons));
        if(gametic%5==0) RevealMap();
    }
    if (nativeDemo && (gameaction!=ga_nothing || players[0].playerstate==PST_REBORN)) { MD_StopDemo(); gameaction=ga_nothing; }
    else if (gameaction == ga_completed) CompleteLevel();
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
                mobjinfo[object->type].doomednum, !!(object->flags & MF_SHADOW)
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
            firstspritelump+frame->lump[0],frame->flip[0],(psp->state->frame & FF_FULLBRIGHT) != 0,
            player->powers[pw_invisibility]>128 || (player->powers[pw_invisibility]&8)
        };
        ++count;
    }
    return count;
}

MD_HUD MD_GetHUD(void) {
    MD_HUD hud = {0};
    if (!loaded) return hud;
    player_t *player = &players[0];
    hud.weaponGrin = weaponGrinTicks > 0; hud.faceIndex=faceIndex;
    hud.fixedColorMap=player->fixedcolormap;
    hud.suitFlash=player->powers[pw_ironfeet]>128 || (player->powers[pw_ironfeet]&8);
    hud.berserkFlash=player->powers[pw_strength] ? 12-(player->powers[pw_strength]>>6):0;
    hud.allmap=player->powers[pw_allmap]!=0;hud.invisibility=player->powers[pw_invisibility];
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
int MD_TestCrossSpecial(int special) {
    for (int i=0;i<numlines;++i) if (lines[i].special==special) {
        P_CrossSpecialLine(i,0,players[0].mo); return 1;
    }
    return 0;
}
int MD_TestFindSecret(float *x,float *y) {
    for (int i=0;i<numlines;++i) {
        line_t *line=&lines[i];
        if (!line->frontsector || line->frontsector->special!=9) continue;
        float dx=(float)line->dx/FRACUNIT,dy=(float)line->dy/FRACUNIT,len=hypotf(dx,dy);
        if (len==0) continue;
        float px=((double)line->v1->x+line->v2->x)/(2*FRACUNIT)+dy/len*8;
        float py=((double)line->v1->y+line->v2->y)/(2*FRACUNIT)-dx/len*8;
        if (R_PointInSubsector(px*FRACUNIT,py*FRACUNIT)->sector==line->frontsector) { *x=px;*y=py;return 1; }
    }
    return 0;
}
void MD_TestExit(int secret) { if (secret) G_SecretExitLevel(); else G_ExitLevel(); }
int MD_TestSwitch(int special,float *x,float *y,float *angle,int *side) {
    for (int i=0;i<numlines;++i) if (lines[i].special == special) {
        line_t *line=&lines[i]; float dx=(float)line->dx/FRACUNIT,dy=(float)line->dy/FRACUNIT,len=hypotf(dx,dy);
        *x=((double)line->v1->x+line->v2->x)/(2*FRACUNIT)+dy/len*32;
        *y=((double)line->v1->y+line->v2->y)/(2*FRACUNIT)-dx/len*32;
        *angle=atan2f(dx,-dy); *side=line->sidenum[0]; return i;
    }
    return -1;
}
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

// Layout from pinned p_spec.c; no engine-owned pointers cross the bridge.
typedef struct { boolean istexture; int picnum,basepic,numpics,speed; } MD_EngineAnim;
extern MD_EngineAnim anims[], *lastanim;
int MD_CopyAnimatedMaterials(MD_Material *output,int capacity) {
    if (!loaded || poisoned) return 0;
    int count=0;
    for(MD_EngineAnim *a=anims;a<lastanim;++a) for(int i=a->basepic;i<a->basepic+a->numpics;++i) {
        if(output && count<capacity) {
            MD_Material *m=&output[count]; memset(m,0,sizeof(*m)); m->index=i; m->flat=!a->istexture;
            memcpy(m->name,a->istexture ? textureNames[i] : lumpinfo[firstflat+i]->name,8);
        }
        ++count;
    }
    return count;
}
int MD_TranslatedMaterial(int index,int flat) {
    if(!loaded || poisoned || index<0 || index>=(flat ? numflats : numtextures)) return -1;
    return flat ? flattranslation[index] : texturetranslation[index];
}

static void RefreshAnimations(void) {
    int time=leveltime>0 ? leveltime-1 : 0;
    for(MD_EngineAnim *a=anims;a<lastanim;++a) for(int i=a->basepic;i<a->basepic+a->numpics;++i) {
        int pic=a->basepic+(time/a->speed+i)%a->numpics;
        if(a->istexture) texturetranslation[i]=pic; else flattranslation[i]=pic;
    }
}

int MD_DemoPlaying(void) { return nativeDemo!=NULL; }
void MD_StopDemo(void) {
    if(!nativeDemo) return;
    free(nativeDemo); nativeDemo=NULL; nativeDemoOffset=nativeDemoSize=0;
    demoplayback=false; usergame=true;gameversion=gamemode==retail ? exe_ultimate:exe_doom_1_9; respawnparm=fastparm=false; nomonsters=!monstersEnabled;
}
int MD_StartDemo(const char *name) {
    if(!loaded || poisoned) return 0;
    int lump=W_CheckNumForName(name);
    if(lump<0) { snprintf(errorText,sizeof(errorText),"Demo is absent."); return 0; }
    int size=W_LumpLength(lump);
    if(size<14 || size>4*1024*1024) { snprintf(errorText,sizeof(errorText),"Invalid demo size.");return 0; }
    byte *data=malloc(size); if(!data) return 0;
    guarded=1;if(setjmp(errorBoundary)) { free(data);guarded=0;return 0; }
    W_ReadLump(lump,data);
    int valid=(data[0]==108 || data[0]==109) && data[1]<=4 && data[2]>=1 && data[2]<=(sigilEpisode ? 5:4) && data[3]>=1
        && data[3]<=(gamemode==commercial ? 32:9) && !data[4] && data[5]<=1 && data[6]<=1 && data[7]<=1
        && !data[8] && data[9]==1 && !data[10] && !data[11] && !data[12];
    int end=13;while(end<size && data[end]!=0x80) end+=4;
    valid=valid && end<size && end>13;
    char mapName[9]; if(gamemode==commercial) snprintf(mapName,9,"MAP%02d",data[3]);else snprintf(mapName,9,"E%dM%d",data[2],data[3]);
    valid=valid && W_CheckNumForName(mapName)>=0;
    if(!valid) { free(data);guarded=0;snprintf(errorText,sizeof(errorText),"Only valid single-player Doom 1.8/1.9 demos are supported.");return 0; }
    MD_StopDemo(); respawnparm=data[5];fastparm=data[6];nomonsters=data[7];gametic=0;
    gameversion=data[0]==108 ? exe_doom_1_8 : gamemode==retail ? exe_ultimate:exe_doom_1_9;
    G_InitNew(data[1],data[2],data[3]); demoplayback=true;usergame=false;
    nativeDemo=data;nativeDemoSize=end+1;nativeDemoOffset=13;
    progress=(MD_Progress){.episode=gameepisode,.map=gamemap,.commercial=gamemode==commercial};
    lastMessage[0]=0;++messageSerial;UpdateFace(0);guarded=0;return 1;
}
int MD_Cheat(const char *name) {
    if(!loaded || poisoned || nativeDemo || progress.phase || gameskill==sk_nightmare || players[0].health<=0) return 0;
    player_t *p=&players[0]; const char *message=NULL;
    if(!strcmp(name,"iddqd")) { p->cheats^=CF_GODMODE;if(p->cheats & CF_GODMODE) p->health=p->mo->health=100;message=(p->cheats & CF_GODMODE) ? "Degreelessness Mode On":"Degreelessness Mode Off"; }
    else if(!strcmp(name,"idclip") || !strcmp(name,"idspispopd")) { p->cheats^=CF_NOCLIP;message=(p->cheats & CF_NOCLIP) ? "No Clipping Mode ON":"No Clipping Mode OFF"; }
    else if(!strcmp(name,"idfa") || !strcmp(name,"idkfa")) {
        p->armorpoints=200;p->armortype=2;
        for(int i=0;i<NUMWEAPONS;++i) if((gamemode!=shareware || (i!=wp_plasma && i!=wp_bfg)) && (gamemode==commercial || i!=wp_supershotgun)) p->weaponowned[i]=true;
        for(int i=0;i<NUMAMMO;++i) p->ammo[i]=p->maxammo[i];
        if(!strcmp(name,"idkfa")) for(int i=0;i<NUMCARDS;++i) p->cards[i]=true;
        message=!strcmp(name,"idkfa") ? "Very Happy Ammo Added":"Ammo Added";
    } else if(!strcmp(name,"idchoppers")) { p->weaponowned[wp_chainsaw]=true;p->powers[pw_invulnerability]=1;message="... doesn't suck - GM"; }
    else {
        const char *names[]={"idbeholdv","idbeholds","idbeholdi","idbeholdr","idbeholda","idbeholdl"};
        for(int i=0;i<NUMPOWERS;++i) if(!strcmp(name,names[i])) {
            if(!p->powers[i]) P_GivePower(p,i);else p->powers[i]=i==pw_strength ? 0:1;
            message="Power-up Toggled";break;
        }
    }
    if(!message) return 0;
    p->message=(char *)message;CaptureMessage();UpdateFace(0);return 1;
}

// Approximate first-person exploration using original sector sight tests. The
// hardware renderer does not run R_StoreWallRange, which normally sets ML_MAPPED.
static void RevealMap(void) {
    player_t *p=&players[0]; if(!p->mo) return;
    double angle=p->mo->angle*(2*M_PI/4294967296.0),fx=cos(angle),fy=sin(angle);
    for(int i=0;i<numlines;i++) {
        line_t *l=&lines[i];if(l->flags & (ML_MAPPED|ML_DONTDRAW)) continue;
        double x=((double)l->v1->x+l->v2->x)/2,y=((double)l->v1->y+l->v2->y)/2;
        double dx=x-p->mo->x,dy=y-p->mo->y,distance=hypot(dx,dy);
        if(distance>4096.0*FRACUNIT || dx*fx+dy*fy < -32.0*FRACUNIT) continue;
        if(distance>4*FRACUNIT) { x-=dx/distance*4*FRACUNIT;y-=dy/distance*4*FRACUNIT; }
        mobj_t target={0};target.x=x;target.y=y;target.z=p->mo->z;target.height=p->mo->height;
        target.subsector=R_PointInSubsector(target.x,target.y);
        if(P_CheckSight(p->mo,&target)) l->flags|=ML_MAPPED;
    }
}
int MD_CopyMapLines(MD_MapLine *output,int capacity) {
    if(!loaded || poisoned) return 0;
    for(int i=0;output && i<numlines && i<capacity;i++) {
        line_t *l=&lines[i];int kind=0;
        if(l->flags & ML_DONTDRAW) kind=-1;
        else if(!l->backsector || (l->flags & ML_SECRET)) kind=1;
        else if(l->special==39 || l->special==97) kind=4;
        else if(l->frontsector->floorheight!=l->backsector->floorheight) kind=2;
        else if(l->frontsector->ceilingheight!=l->backsector->ceilingheight) kind=3;
        output[i]=(MD_MapLine){(float)l->v1->x/FRACUNIT,(float)l->v1->y/FRACUNIT,
            (float)l->v2->x/FRACUNIT,(float)l->v2->y/FRACUNIT,kind,!!(l->flags & ML_MAPPED)};
    }
    return numlines;
}

extern const char *finaletext, *finaleflat;
extern void F_StartCast(void), F_CastTicker(void);
extern boolean F_CastResponder(event_t *event);
extern state_t *caststate;
extern int castnum;
extern boolean castdeath;
extern struct { const char *name; mobjtype_t type; } castorder[];
int MD_BeginStory(void) {
    if (!loaded || poisoned || progress.phase!=1 || gamemode!=commercial) return 0;
    G_WorldDone();
    if (gamestate!=GS_FINALE) return 0;
    progress.phase=3; memset(&players[0].cmd,0,sizeof(players[0].cmd)); return 1;
}
const char *MD_StoryText(void) { return progress.phase>=3 && finaletext ? finaletext : ""; }
const char *MD_StoryFlat(void) { return progress.phase>=3 && finaleflat ? finaleflat : ""; }
int MD_StartCast(void) {
    if (!loaded || poisoned || progress.phase!=3 || gamemap!=30) return 0;
    F_StartCast(); progress.phase=4; return 1;
}
int MD_CastTick(int attack) {
    if (!loaded || poisoned || progress.phase!=4) return 0;
    guarded=1; if(setjmp(errorBoundary)) { guarded=0;return 0; }
    if (attack) { event_t event={.type=ev_keydown}; F_CastResponder(&event); }
    F_CastTicker(); guarded=0; return 1;
}
MD_Cast MD_GetCast(void) {
    MD_Cast result={0}; if (!loaded || poisoned || progress.phase!=4) return result;
    result.member=castnum;result.dying=castdeath;
    snprintf(result.name,sizeof(result.name),"%s",castorder[castnum].name);
    spriteframe_t *frame=&sprites[caststate->sprite].spriteframes[caststate->frame & FF_FRAMEMASK];
    int lump=firstspritelump+frame->lump[0]; result.flip=frame->flip[0];
    memcpy(result.patch,lumpinfo[lump]->name,8); return result;
}
#ifdef MD_TESTING
int MD_TestDamageType(int type,int damage,int limit) {
    int count=0;
    for(thinker_t *t=thinkercap.next;t!=&thinkercap;t=t->next) {
        if(t->function.acp1!=(actionf_p1)P_MobjThinker) continue;
        mobj_t *mo=(mobj_t *)t;
        if(mo->type==type && mo->health>0 && count<limit) { P_DamageMobj(mo,players[0].mo,players[0].mo,damage);count++; }
    }
    return count;
}
int MD_TestSectorTag(int sector) { return sectors[sector].tag; }
#endif

#ifdef MD_TESTING
extern void A_BrainAwake(mobj_t *), A_BrainSpit(mobj_t *);
extern int numbraintargets;
int MD_TestWakeBrain(void) {
    for(thinker_t *t=thinkercap.next;t!=&thinkercap;t=t->next) {
        if(t->function.acp1==(actionf_p1)P_MobjThinker && ((mobj_t *)t)->type==MT_BOSSSPIT) {
            A_BrainAwake((mobj_t *)t); A_BrainSpit((mobj_t *)t); return numbraintargets;
        }
    }
    return 0;
}
#endif

int MD_ConfigureWADStack(const char *paths,const int32_t *order,int count) {
    if(!paths || !order || count<1 || count>200000 || strlen(paths)>131072) return 0;
    if(initialized) {
        if(stackPaths && !strcmp(paths,stackPaths) && stackCount==count && !memcmp(order,stackOrder,count*sizeof(*order))) return 1;
        snprintf(errorText,sizeof(errorText),"Restart MetalDooM to change the WAD stack.");return 0;
    }
    char *newPaths=strdup(paths);int32_t *newOrder=malloc(count*sizeof(*order));
    if(!newPaths || !newOrder) { free(newPaths);free(newOrder);return 0; }
    memcpy(newOrder,order,count*sizeof(*order));free(stackPaths);free(stackOrder);
    stackPaths=newPaths;stackOrder=newOrder;stackCount=count;return 1;
}
