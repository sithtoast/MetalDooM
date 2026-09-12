// SPDX-License-Identifier: GPL-2.0-or-later
#include "ExtendedCore.h"
#include "NativeInternal.h"
#include "r_tranmap.h"
#include "info.h"
#include "w_wad.h"
#include "z_zone.h"
#include "i_system.h"
#include <string.h>
static void word(unsigned char **p,uint32_t v) {for(int i=0;i<4;i++)*(*p)++=(unsigned char)(v>>(8*i));}
// IDs are assigned by ascending patched state index, before any level spawns.
// The bank is immutable across state changes, restart, Continue and fresh restore.
#define MAX_BLEND_TABLES 64
static const unsigned char *tables[MAX_BLEND_TABLES];
static unsigned table_count;
unsigned ME_BlendTableIndex(const unsigned char *table) {
    if(!table)return 0;
    for(unsigned i=0;i<table_count;i++)if(tables[i]==table)return i+1;
    I_Error("Unregistered actor blend table");
}
void ME_InitBlendTables(void) {
    if(table_count || !main_tranmap || !main_addimap)I_Error("Invalid blend table initialization");
    tables[0]=main_tranmap;tables[1]=main_addimap;table_count=2;
    for(int state=0;state<num_states;state++) {
        const unsigned char *table=states[state].tranmap;
        if(!table)continue;
        unsigned i=0;for(;i<table_count;i++)if(tables[i]==table)break;
        if(i<table_count)continue;
        // Only validated complete WAD lumps may cross the copy boundary. Do not
        // dereference a patched pointer until its backing allocation is known.
        int lump=0;for(;lump<numlumps;lump++)if(lumpcache[lump]==table)break;
        if(lump==numlumps || W_LumpLength(lump)!=65536)
            I_Error("State %d blend table must contain exactly 65536 entries",state);
        if(table_count==MAX_BLEND_TABLES)I_Error("Too many actor blend tables (maximum 64 including defaults)");
        tables[table_count++]=table;
    }
}
size_t ME_WriteBlendTables(void *out,size_t capacity) {
    const size_t size=16+768+(size_t)table_count*65536;
    if(!out || capacity<size)return size;
    int palette=W_GetNumForName("PLAYPAL");
    if(W_LumpLength(palette)<768 || !main_tranmap || !main_addimap)I_Error("Missing presentation blend tables");
    unsigned char *p=out;memcpy(p,"MBL2",4);p+=4;
    word(&p,2);word(&p,768);word(&p,table_count);
    memcpy(p,W_CacheLumpNum(palette,PU_CACHE),768);p+=768;
    for(unsigned i=0;i<table_count;i++){memcpy(p,tables[i],65536);p+=65536;}
    return size;
}
