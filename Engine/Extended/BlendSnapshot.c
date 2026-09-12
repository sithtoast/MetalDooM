// SPDX-License-Identifier: GPL-2.0-or-later
#include "ExtendedCore.h"
#include "NativeInternal.h"
#include "r_tranmap.h"
#include "info.h"
#include "r_state.h"
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
    if(lump==numlumps || W_LumpLength(lump)!=65536)
        I_Error("Blend table must contain exactly 65536 entries");
    if(table_count==MAX_BLEND_TABLES)I_Error("Too many blend tables (maximum 64 including defaults)");
    tables[table_count++]=table;
}
void ME_InitBlendTables(void) {
    if(table_count || !main_tranmap || !main_addimap)I_Error("Invalid blend table initialization");
    tables[0]=main_tranmap;tables[1]=main_addimap;table_count=2;
    for(int state=0;state<num_states;state++)register_table(states[state].tranmap);
    state_table_count=table_count;
}
void ME_LevelBlendTables(void) {
    table_count=state_table_count;
    for(int line=0;line<numlines;line++)register_table(lines[line].tranmap);
}
size_t ME_WriteBlendTables(void *out,size_t capacity) {
    int palette=W_GetNumForName("PLAYPAL"),maps=W_GetNumForName("COLORMAP");
    int colors=W_LumpLength(palette),mapping=W_LumpLength(maps);
    if(colors<768 || colors%768 || colors>256*768 || mapping<256 || mapping%256 || mapping>256*256)
        I_Error("Invalid palette/colormap resource sizes");
    const size_t size=24+(size_t)colors+mapping+(size_t)table_count*65536;
    if(!out || capacity<size)return size;
    unsigned char *p=out;memcpy(p,"MBL3",4);p+=4;
    word(&p,3);word(&p,colors);word(&p,table_count);word(&p,mapping);word(&p,0);
    memcpy(p,W_CacheLumpNum(palette,PU_CACHE),colors);p+=colors;
    memcpy(p,W_CacheLumpNum(maps,PU_CACHE),mapping);p+=mapping;
    for(unsigned i=0;i<table_count;i++){memcpy(p,tables[i],65536);p+=65536;}
    return size;
}
