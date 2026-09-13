// SPDX-License-Identifier: GPL-2.0-or-later
#include "ExtendedCore.h"
#include "NativeInternal.h"
#include "doomstat.h"
#include "d_items.h"
#include "g_umapinfo.h"
#include "g_game.h"
#include "sounds.h"
#include "s_sound.h"
#include "s_musinfo.h"
#include "deh_strings.h"
#include "w_wad.h"
#include "i_system.h"
#include "yyjson.h"
#include <stdio.h>
#include <string.h>
static char track[8];
static uint32_t generation,looped;
static void select_track(const char *name,int looping) {
    char next[8]={0};size_t length=strnlen(name,9);
    if(!length || length>8)I_Error("Invalid music name");
    memcpy(next,name,length);
    if(!memcmp(track,next,8) && looped==(uint32_t)!!looping)return;
    memcpy(track,next,8);looped=!!looping;
    if(generation==INT32_MAX)I_Error("Music generation overflow");
    generation++;
}
void S_ChangeMusInfoMusic(int lump,int looping) {
    if(lump<0 || lump>=numlumps)I_Error("Invalid music lump");
    char name[9]={0};memcpy(name,lumpinfo[lump].name,8);select_track(name,looping);
    musinfo.current_item=lump;
}
void S_ChangeMusic(int music,int looping) {
    if(music<=mus_None || music>=NUMMUSIC)I_Error("Invalid music index");
    char name[9];snprintf(name,sizeof(name),"D_%s",DEH_String(S_music[music].name));
    select_track(name,looping);musinfo.current_item=-1;
}
void ME_StartLevelMusic(void) {
    if(gamemapinfo && gamemapinfo->music[0]) {
        int lump=W_CheckNumForName(gamemapinfo->music);
        if(lump>=0){S_ChangeMusInfoMusic(lump,1);return;}
    }
    S_ChangeMusic(mus_runnin+(gamemap-1)%(NUMMUSIC-mus_runnin),1);
}
static void word(unsigned char **p,uint32_t v){for(int i=0;i<4;i++)*(*p)++=(unsigned char)(v>>(8*i));}
size_t ME_WriteUI(void *out,size_t capacity) {
    const size_t size=144;if(!out || capacity<size)return size;
    player_t *player=&players[0];unsigned char *p=out;
    uint32_t keys=0,weapons=0;
    for(int i=0;i<NUMCARDS;i++)if(player->cards[i])keys |= 1u<<i;
    for(int i=0;i<NUMWEAPONS;i++)if(player->weaponowned[i])weapons |= 1u<<i;
    int ammo=weaponinfo[player->readyweapon].ammo;
    memcpy(p,"MUI4",4);p+=4;word(&p,4);word(&p,leveltime);
    word(&p,player->health);word(&p,player->armorpoints);word(&p,player->readyweapon);
    word(&p,ammo==am_noammo ? -1:player->ammo[ammo]);word(&p,keys);word(&p,weapons);
    for(int i=0;i<NUMAMMO;i++)word(&p,player->ammo[i]);
    for(int i=0;i<NUMAMMO;i++)word(&p,player->maxammo[i]);
    memcpy(p,track,8);p+=8;word(&p,looped);word(&p,generation);word(&p,ammo==am_noammo ? -1:ammo);word(&p,player->armortype);
    int phase=ME_LevelPhase();
    word(&p,phase);word(&p,gamemap);word(&p,phase==2 ? wminfo.next+1:0);
    word(&p,player->killcount);word(&p,totalkills);word(&p,player->itemcount);word(&p,totalitems);
    word(&p,player->secretcount);word(&p,totalsecret);word(&p,leveltime);
    word(&p,phase>=2 && secretexit);
    // Woof's normal gameplay palette selection (no menu/reduced-flash options).
    // Rendering copies state; it must not decrement timers or advance RNG.
    int damage=player->damagecount,palette=0;
    if(player->powers[pw_strength]) {
        int strength=12-(player->powers[pw_strength]>>6);
        if(strength>damage)damage=strength;
    }
    if(damage>0)palette=1+MIN(7,(damage+7)>>3);
    else if(player->bonuscount>0)palette=9+MIN(3,(player->bonuscount+7)>>3);
    else if(player->powers[pw_ironfeet]>128 || (player->powers[pw_ironfeet]&8))palette=13;
    word(&p,phase<2 ? palette:0);word(&p,phase<2 ? player->fixedcolormap:0);
    return size;
}

void ME_ArchiveNativeUI(json_mut_doc_t *doc,json_mut_t *root) {
    char name[9]={0};memcpy(name,track,8);
    yyjson_mut_obj_add_strcpy(doc,root,"native_music",name);
    JS_SetInt(doc,root,"native_music_loop",looped);
    JS_SetInt(doc,root,"native_music_generation",generation);
}
void ME_UnArchiveNativeUI(json_t *root) {
    const char *name=JS_GetStringValue(root,"native_music");
    int gen=JS_GetIntegerValue(root,"native_music_generation"),loop=JS_GetIntegerValue(root,"native_music_loop");
    if(!name || !*name || strlen(name)>8 || W_CheckNumForName(name)<0 || gen<=0 || (loop!=0 && loop!=1))I_Error("Invalid restored music");
    memset(track,0,8);memcpy(track,name,strlen(name));generation=gen;looped=loop;
}
