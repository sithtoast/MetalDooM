// SPDX-License-Identifier: GPL-2.0-or-later
#include "NativeInternal.h"
#include "SessionPlan.h"
#include "doomstat.h"
#include "d_event.h"
#include "p_spec.h"
#include "r_main.h"
#include "r_data.h"
extern int numtextures;
#include "g_game.h"
#include "p_keyframe.h"
#include "p_saveg.h"
#include "p_enemy.h"
#include "p_tick.h"
#include "p_setup.h"
#include "r_state.h"
#include "s_musinfo.h"
#include "w_wad.h"
#include "i_system.h"
#include "yyjson.h"
#include "m_array.h"
#include "r_sky.h"
#include <limits.h>
#include <stdlib.h>
#include <string.h>
#define MAX_SAVE (64*1024*1024)
int ME_SaveInteger(json_t *v) {
    if(!yyjson_is_int(v) || yyjson_get_sint(v)<INT_MIN || yyjson_get_sint(v)>UINT_MAX)I_Error("Invalid save integer");
    return (int)yyjson_get_sint(v);
}
json_t *ME_SaveObject(json_t *o,const char *key) {
    json_t *v=yyjson_obj_get(o,key);if(!v)I_Error("Missing save field: %s",key);return v;
}
int ME_SaveIntegerValue(json_t *o,const char *key){return ME_SaveInteger(ME_SaveObject(o,key));}
void ME_CheckSaveIndex(int index,const char *base) {
    int count=!strcmp(base,"lines") ? numlines:!strcmp(base,"sides") ? numsides:!strcmp(base,"sectors") ? numsectors:
        !strcmp(base,"subsectors") ? numsubsectors:!strcmp(base,"states") ? num_states:!strcmp(base,"mobjinfo") ? num_mobj_types:
        !strcmp(base,"players") ? MAXPLAYERS:0;
    if(index < -1 || index>=count)I_Error("Invalid save index for %s",base);
}
static void bounded(json_t *v,int depth,size_t *nodes) {
    if(depth>32 || ++*nodes>2000000)I_Error("Save document exceeds structural limits");
    if(yyjson_is_arr(v)) {
        size_t i,n;json_t *item;yyjson_arr_foreach(v,i,n,item){bounded(item,depth+1,nodes);}
    } else if(yyjson_is_obj(v)) {
        if(yyjson_obj_size(v)>256)I_Error("Oversized save object");
        size_t i,n;json_t *key,*value;
        yyjson_obj_foreach(v,i,n,key,value){
            if(strlen(yyjson_get_str(key))!=yyjson_get_len(key))I_Error("Invalid save key");
            if(yyjson_obj_get(v,yyjson_get_str(key))!=value)I_Error("Duplicate save key");
            bounded(value,depth+1,nodes);
        }
    } else if(yyjson_is_str(v)) {if(yyjson_get_len(v)>4096)I_Error("Oversized save string");}
    else if(!yyjson_is_int(v))I_Error("Unsupported save value");
}
static int integer(json_t *root,const char *key,int low,int high) {
    int v=ME_SaveIntegerValue(root,key);if(v<low || v>high)I_Error("Invalid saved %s",key);return v;
}
static void array(json_t *root,const char *key,int count) {
    json_t *v=ME_SaveObject(root,key);if(!yyjson_is_arr(v) || yyjson_arr_size(v)!=(size_t)count)I_Error("Invalid saved %s count",key);
}
static void archive_skies(json_mut_doc_t *doc,json_mut_t *root) {
    json_mut_t *list=JS_NewArray(doc);
    for(unsigned i=0;i<array_size(levelskies);i++) {
        sky_t *s=&levelskies[i];json_mut_t *obj=JS_NewObject(doc),*offsets=JS_NewArray(doc),*fire=JS_NewArray(doc);
        for(int j=0;j<2;j++) {skytex_t *t=j?&s->foreground:&s->background;
            JS_ArrayAddInt(doc,offsets,t->currx);JS_ArrayAddInt(doc,offsets,t->curry);
            JS_ArrayAddInt(doc,offsets,t->prevx);JS_ArrayAddInt(doc,offsets,t->prevy);
        }
        JS_SetArray(doc,obj,"offsets",offsets);JS_SetInt(doc,obj,"tics",s->tics_left);
        if(s->type==SkyType_Fire) {
            int tex=s->background.texture,n=texturewidth[tex]*(textureheight[tex]>>FRACBITS);
            for(int j=0;j<n;j++)JS_ArrayAddInt(doc,fire,s->fire[j]);
        }
        JS_SetArray(doc,obj,"fire",fire);JS_ArrayAddObject(doc,list,obj);
    }
    JS_SetArray(doc,root,"native_skies",list);
}
static void restore_skies(json_t *root) {
    array(root,"native_skies",array_size(levelskies));json_t *list=ME_SaveObject(root,"native_skies");
    for(unsigned i=0;i<array_size(levelskies);i++) {
        sky_t *s=&levelskies[i];json_t *obj=yyjson_arr_get(list,i);array(obj,"offsets",8);
        json_t *offsets=ME_SaveObject(obj,"offsets");
        for(int j=0;j<2;j++) {skytex_t *t=j?&s->foreground:&s->background;
            t->currx=ME_SaveInteger(yyjson_arr_get(offsets,j*4));t->curry=ME_SaveInteger(yyjson_arr_get(offsets,j*4+1));
            t->prevx=ME_SaveInteger(yyjson_arr_get(offsets,j*4+2));t->prevy=ME_SaveInteger(yyjson_arr_get(offsets,j*4+3));
        }
        s->tics_left=integer(obj,"tics",0,MAX(0,s->updatetime));
        int tex=s->background.texture,w=texturewidth[tex],h=textureheight[tex]>>FRACBITS;
        array(obj,"fire",s->type==SkyType_Fire?w*h:0);
        if(s->type==SkyType_Fire) {
            json_t *fire=ME_SaveObject(obj,"fire");
            for(int j=0;j<w*h;j++) {
                int v=ME_SaveInteger(yyjson_arr_get(fire,j));
                if(v<0 || v>=array_size(s->palette))I_Error("Invalid saved fire palette index");s->fire[j]=v;
            }
            // Rebuild visible columns without consuming RNG or advancing a tic.
            for(int x=0;x<w;x++) {byte *col=R_GetColumn(tex,x);for(int y=0;y<h;y++)col[y]=s->palette[s->fire[y*w+x]];}
        }
    }
}
size_t ME_WriteSave(void *out,size_t capacity) {
    if(ME_LevelPhase()!=0 || gameaction!=ga_nothing)return 0;
    json_mut_doc_t *doc=JS_NewDoc();json_mut_t *root=JS_NewObject(doc);JS_SetRoot(doc,root);
    JS_SetInt(doc,root,"native_version",1);JS_SetString(doc,root,"identity",ME_CurrentSession()->content_sha256);
    JS_SetInt(doc,root,"map",gamemap);JS_SetInt(doc,root,"skill",gameskill+1);JS_SetInt(doc,root,"tic",leveltime);
    JS_SetInt(doc,root,"gametic",gametic);JS_SetInt(doc,root,"basetic",boom_basetic);
    JS_SetInt(doc,root,"totalleveltimes",totalleveltimes);JS_SetInt(doc,root,"totalkills",totalkills);JS_SetInt(doc,root,"totalitems",totalitems);JS_SetInt(doc,root,"totalsecret",totalsecret);
    JS_SetInt(doc,root,"max_kill_requirement",max_kill_requirement);JS_SetInt(doc,root,"validcount",validcount);
    JS_SetInt(doc,root,"brain_target",brain.targeton);JS_SetInt(doc,root,"brain_easy",brain.easy);
    JS_SetInt(doc,root,"mus_tics",musinfo.tics);JS_SetInt(doc,root,"mus_item",musinfo.current_item);
    json_mut_t *textures=JS_NewArray(doc),*flats=JS_NewArray(doc);
    for(int i=0;i<numtextures;i++)JS_ArrayAddInt(doc,textures,texturetranslation[i]);
    for(int i=0;i<numflats;i++)JS_ArrayAddInt(doc,flats,flattranslation[i]);
    JS_SetArray(doc,root,"native_textures",textures);JS_SetArray(doc,root,"native_flats",flats);
    archive_skies(doc,root);
    P_ArchiveKeyframe(doc,root);
    ME_ArchiveNativeUI(doc,root);
    size_t length=0;char *json=JS_DocWriteString(doc,&length);JS_FreeDoc(doc);
    if(!json || !length || length>MAX_SAVE){free(json);I_Error("Save snapshot exceeds size limit");}
    if(out && capacity>=length)memcpy(out,json,length);
    free(json);return length;
}
int ME_ReadSave(const void *data,size_t size) {
    // Candidate workers restore only into their untouched initial level.
    static int attempted;
    if(attempted++ || !data || !size || size>MAX_SAVE || leveltime!=0 || gametic!=0)I_Error("Invalid save restore boundary");
    yyjson_doc *doc=yyjson_read(data,size,0);if(!doc)I_Error("Invalid save JSON");
    json_t *root=yyjson_doc_get_root(doc);size_t nodes=0;bounded(root,0,&nodes);
    if(integer(root,"native_version",1,1)!=1)I_Error("Unsupported save version");
    const char *identity=yyjson_get_str(yyjson_obj_get(root,"identity"));
    if(!identity || strcmp(identity,ME_CurrentSession()->content_sha256))I_Error("Save resources do not match");
    if(integer(root,"map",1,32)!=gamemap || integer(root,"skill",1,5)!=gameskill+1)I_Error("Save map/skill do not match worker");
    int tic=integer(root,"tic",0,INT_MAX-1),gt=integer(root,"gametic",tic,INT_MAX-1);
    array(root,"sectors",numsectors);array(root,"lines",numlines);array(root,"players",MAXPLAYERS);array(root,"blocklinks",bmapwidth*bmapheight);
    array(root,"thinkerclasscaps",NUMTHCLASS);array(root,"tmbbox",4);array(root,"buttonlist",MAXBUTTONS);
    ME_ValidateKeyframe(root);
    saveg_compat=saveg_current;
    P_UnArchiveKeyframe(root);
    leveltime=tic;gametic=gt;boom_basetic=ME_SaveIntegerValue(root,"basetic");
    totalleveltimes=integer(root,"totalleveltimes",0,INT_MAX);totalkills=integer(root,"totalkills",0,INT_MAX);totalitems=integer(root,"totalitems",0,INT_MAX);totalsecret=integer(root,"totalsecret",0,INT_MAX);
    max_kill_requirement=ME_SaveIntegerValue(root,"max_kill_requirement");validcount=ME_SaveIntegerValue(root,"validcount");
    brain.targeton=integer(root,"brain_target",0,INT_MAX);brain.easy=integer(root,"brain_easy",0,1);
    musinfo.tics=ME_SaveIntegerValue(root,"mus_tics");musinfo.current_item=integer(root,"mus_item",-1,numlumps-1);
    array(root,"native_textures",numtextures);array(root,"native_flats",numflats);
    for(int i=0;i<numtextures;i++) {
        int target=ME_SaveInteger(yyjson_arr_get(yyjson_obj_get(root,"native_textures"),i));
        if(target<0 || target>=numtextures)I_Error("Invalid saved texture translation");texturetranslation[i]=target;
    }
    for(int i=0;i<numflats;i++) {
        int target=ME_SaveInteger(yyjson_arr_get(yyjson_obj_get(root,"native_flats"),i));
        if(target<0 || target>=numflats)I_Error("Invalid saved flat translation");flattranslation[i]=target;
    }
    restore_skies(root);
    ME_UnArchiveNativeUI(root);ME_ResetRestoredAudio();
    gameaction=ga_nothing;gamestate=GS_LEVEL;secretexit=false;
    yyjson_doc_free(doc);return 1;
}
