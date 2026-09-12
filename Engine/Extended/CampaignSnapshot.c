// SPDX-License-Identifier: GPL-2.0-or-later
// A copied, read-only boundary. No presentation ticker or sound lookup may
// allocate engine sound IDs, consume RNG, or drain the gameplay audio queue.
#include "NativeInternal.h"
#include "doomstat.h"
#include "g_umapinfo.h"
#include "g_game.h"
#include "sounds.h"
#include "deh_strings.h"
#include "dsdh_main.h"
#include "w_wad.h"
#include "yyjson.h"
#include "i_system.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static void string(yyjson_mut_doc *d,yyjson_mut_val *o,const char *key,const char *value) {
    if(!yyjson_mut_obj_add(o,yyjson_mut_strcpy(d,key),yyjson_mut_strcpy(d,value ? value:"")))I_Error("Campaign JSON allocation failed");
}
size_t ME_WriteCampaign(void *out,size_t capacity) {
    if(ME_LevelPhase()<2)return 0;
    yyjson_mut_doc *d=yyjson_mut_doc_new(NULL);if(!d)I_Error("Campaign JSON allocation failed");
    yyjson_mut_val *o=yyjson_mut_obj(d);yyjson_mut_doc_set_root(d,o);
    yyjson_mut_obj_add_int(d,o,"version",1);yyjson_mut_obj_add_int(d,o,"map",gamemap);
    yyjson_mut_obj_add_int(d,o,"tic",leveltime);yyjson_mut_obj_add_int(d,o,"nextMap",ME_LevelPhase()==2 ? wminfo.next+1:0);
    yyjson_mut_obj_add_int(d,o,"parTics",wminfo.partime);
    const mapentry_t *m=gamemapinfo,*next=wminfo.nextmapinfo;
    string(d,o,"name",m ? m->levelname:NULL);string(d,o,"levelPic",m ? m->levelpic:NULL);
    string(d,o,"nextName",next ? next->levelname:NULL);string(d,o,"nextPic",next ? next->levelpic:NULL);
    string(d,o,"exitAnim",m ? m->exitanim:NULL);string(d,o,"enterAnim",next ? next->enteranim:NULL);
    const char *story=NULL;
    if(m) {
        if(secretexit) {if(!(m->flags&MapInfo_InterTextSecretClear))story=m->intertextsecret;}
        else if(!(m->flags&MapInfo_InterTextClear))story=m->intertext;
    }
    string(d,o,"story",story);string(d,o,"storyMusic",m ? m->intermusic:NULL);
    string(d,o,"storyFlat",m ? m->interbackdrop:NULL);string(d,o,"endPic",m ? m->endpic:NULL);
    string(d,o,"endFinale",m ? m->endfinale:NULL);
    yyjson_mut_val *visited=yyjson_mut_arr(d);yyjson_mut_obj_add_val(d,o,"visited",visited);
    for(int i=0;i<players[0].num_visitedlevels;i++)if(players[0].visitedlevels[i].episode==1)
        yyjson_mut_arr_add_int(d,visited,players[0].visitedlevels[i].map);
    yyjson_mut_val *sounds=yyjson_mut_obj(d);yyjson_mut_obj_add_val(d,o,"sounds",sounds);
    for(int id=1;id<4096;id++) {
        int index=DSDH_SoundLookup(id);if(index<0 || index>=num_sfx)continue;
        sfxinfo_t *sfx=&S_sfx[index];int links=0;
        while(sfx->link && links++<num_sfx)sfx=sfx->link;
        if(links>=num_sfx || !sfx->name || (sfx->flags&(SFX_Random|SFX_Ambient)) || sfx->looping)continue;
        char name[9]={0},key[16];snprintf(name,sizeof(name),(sfx->flags&SFX_NoPrefix)?"%.8s":"DS%.6s",sfx->name);
        int lump=W_CheckNumForName(name);if(lump<0)continue;
        memcpy(name,lumpinfo[lump].name,8);snprintf(key,sizeof(key),"%d",id);string(d,sounds,key,name);
    }
    yyjson_mut_val *labels=yyjson_mut_obj(d);yyjson_mut_obj_add_val(d,o,"labels",labels);
    const char *keys[]={"ID24_CC_GHOUL","ID24_CC_BANSHEE","ID24_CC_SHOCKTROOPER","ID24_CC_MINDWEAVER","ID24_CC_VASSAGO","ID24_CC_TYRANT","CC_HERO"};
    for(size_t i=0;i<sizeof(keys)/sizeof(*keys);i++)string(d,labels,keys[i],DEH_StringForMnemonic(keys[i]));
    size_t length=0;char *json=yyjson_mut_write(d,0,&length);yyjson_mut_doc_free(d);
    if(!json || length>1024*1024){free(json);I_Error("Invalid campaign metadata size");}
    if(out && capacity>=length)memcpy(out,json,length);
    free(json);return length;
}
