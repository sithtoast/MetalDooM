// SPDX-License-Identifier: GPL-2.0-or-later
#include "ExtendedCore.h"
#include "NativeInternal.h"
#include "r_tranmap.h"
#include "w_wad.h"
#include "z_zone.h"
#include "i_system.h"
#include <string.h>
static void word(unsigned char **p,uint32_t v) {for(int i=0;i<4;i++)*(*p)++=(unsigned char)(v>>(8*i));}
size_t ME_WriteBlendTables(void *out,size_t capacity) {
    const size_t size=16+768+2*65536;
    if(!out || capacity<size)return size;
    int palette=W_GetNumForName("PLAYPAL");
    if(W_LumpLength(palette)<768 || !main_tranmap || !main_addimap)I_Error("Missing presentation blend tables");
    unsigned char *p=out;memcpy(p,"MBL1",4);p+=4;
    word(&p,1);word(&p,768);word(&p,2);
    memcpy(p,W_CacheLumpNum(palette,PU_CACHE),768);p+=768;
    memcpy(p,main_tranmap,65536);p+=65536;
    memcpy(p,main_addimap,65536);
    return size;
}
