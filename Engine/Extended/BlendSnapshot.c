// SPDX-License-Identifier: GPL-2.0-or-later
#include "ExtendedCore.h"
#include "NativeInternal.h"
#include "r_tranmap.h"
#include "info.h"
#include "p_tick.h"
#include "p_mobj.h"
#include "r_state.h"
#include "r_main.h"
#include "r_data.h"
#include "r_bmaps.h"
extern int numtextures,firstcolormaplump;
#include "w_wad.h"
#include "z_zone.h"
#include "i_system.h"
#include <string.h>
static void word(unsigned char **p,uint32_t v) {for(int i=0;i<4;i++)*(*p)++=(unsigned char)(v>>(8*i));}
// IDs are assigned by ascending patched state index, before any level spawns.
// The state prefix is stable; wall-only tables are rebuilt for each level.
#define MAX_BLEND_TABLES 64
static const unsigned char *tables[MAX_BLEND_TABLES];
static unsigned table_count,state_table_count;
unsigned ME_BlendTableIndex(const unsigned char *table) {
    if(!table)return 0;
    for(unsigned i=0;i<table_count;i++)if(tables[i]==table)return i+1;
    I_Error("Unregistered blend table");
}
static void register_table(const unsigned char *table) {
    if(!table)return;
    for(unsigned i=0;i<table_count;i++)if(tables[i]==table)return;
    int lump=0;for(;lump<numlumps;lump++)if(lumpcache[lump]==table)break;
    if(lump==numlumps ? ME_NormalBlendAlpha(table)<0 : W_LumpLength(lump)!=65536)
        I_Error("Blend table must contain exactly 65536 entries");
    if(lump<numlumps)Z_ChangeTag((void *)table,PU_STATIC);
    if(table_count==MAX_BLEND_TABLES)I_Error("Too many blend tables (maximum 64 including defaults)");
    tables[table_count++]=table;
}
void ME_InitBlendTables(void) {
    if(table_count || !main_tranmap || !main_addimap)I_Error("Invalid blend table initialization");
    tables[0]=main_tranmap;tables[1]=main_addimap;table_count=2;
    for(int state=0;state<num_states;state++)register_table(states[state].tranmap);
    state_table_count=table_count;ME_InitLighting();
}
void ME_LevelBlendTables(void) {
    table_count=state_table_count;
    for(int line=0;line<numlines;line++)register_table(lines[line].tranmap);
    for(thinker_t *t=thinkercap.next;t!=&thinkercap;t=t->next)if(t->function.p1==P_MobjThinker) {
        mobj_t *m=(mobj_t *)t;register_table(m->tranmap);register_table(m->spawnpoint.tranmap);
    }
}
size_t ME_WriteBlendTables(void *out,size_t capacity) {
    int palette=W_GetNumForName("PLAYPAL"),maps=W_GetNumForName("COLORMAP");
    int colors=W_LumpLength(palette),mapping=W_LumpLength(maps);
    if(colors<768 || colors%768 || colors>256*768 || mapping<256 || mapping%256 || mapping>256*256)
        I_Error("Invalid palette/colormap resource sizes");
    if(numcolormaps<1 || numcolormaps>256)I_Error("Excessive tint bank");
    unsigned bindings=0;
    for(int flat=0;flat<2;flat++)for(int i=flat?0:1;i<(flat?numflats:numtextures);i++)
        if(ME_BrightMask(flat?R_BrightmapForFlatNum(i):R_BrightmapForTexName(textures[i]->name)))bindings++;
    for(int i=1;i<numcolormaps;i++)if(W_LumpLength(firstcolormaplump+i)<34*256)I_Error("Short custom colormap");
    const size_t extra=12+(numcolormaps-1)*34*256+ME_BrightMaskCount()*256+bindings*16;
    const size_t size=extra+24+(size_t)colors+mapping+(size_t)table_count*65536;
    if(!out || capacity<size)return size;
    unsigned char *p=out;memcpy(p,"MBL4",4);p+=4;
    word(&p,4);word(&p,colors);word(&p,table_count);word(&p,mapping);word(&p,0);
    memcpy(p,W_CacheLumpNum(palette,PU_CACHE),colors);p+=colors;
    memcpy(p,W_CacheLumpNum(maps,PU_CACHE),mapping);p+=mapping;
    for(unsigned i=0;i<table_count;i++){memcpy(p,tables[i],65536);p+=65536;}
    word(&p,numcolormaps-1);word(&p,ME_BrightMaskCount());word(&p,bindings);
    for(int i=1;i<numcolormaps;i++){memcpy(p,colormaps[i],34*256);p+=34*256;}
    for(unsigned i=0;i<ME_BrightMaskCount();i++){memcpy(p,ME_BrightMaskData(i),256);p+=256;}
    for(int flat=0;flat<2;flat++)for(int i=flat?0:1;i<(flat?numflats:numtextures);i++) {
        unsigned mask=ME_BrightMask(flat?R_BrightmapForFlatNum(i):R_BrightmapForTexName(textures[i]->name));if(!mask)continue;
        memcpy(p,flat?lumpinfo[firstflat+i].name:textures[i]->name,8);p+=8;word(&p,flat);word(&p,mask);
    }
    return size;
}

// Resource/alpha references survive a fresh worker; process pointers never do.
int ME_SaveBlend(const unsigned char *table) {
    if(!table)return 0;
    if(table==main_tranmap)return 1;
    if(table==main_addimap)return 2;
    for(int lump=0;lump<numlumps;lump++)if(lumpcache[lump]==table && W_LumpLength(lump)==65536)return lump+3;
    int alpha=ME_NormalBlendAlpha(table);
    if(alpha>=0)return -alpha-1;
    I_Error("Unserializable object blend table");
}
unsigned char *ME_RestoreBlend(int ref) {
    if(!ref)return NULL;
    if(ref==1)return (unsigned char *)main_tranmap;
    if(ref==2)return (unsigned char *)main_addimap;
    if(ref>=-100 && ref<=-1)return GetNormalTranMap(-ref-1);
    if(ref<3 || ref-3>=numlumps || W_LumpLength(ref-3)!=65536)I_Error("Invalid saved blend table");
    return W_CacheLumpNum(ref-3,PU_STATIC);
}
