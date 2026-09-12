// SPDX-License-Identifier: GPL-2.0-or-later
#include "ExtendedCore.h"
#include "NativeInternal.h"
#include "doomstat.h"
#include "r_state.h"
#include "r_data.h"
#include "w_wad.h"
#include "i_system.h"
#include <string.h>
extern int numtextures;
static void word(unsigned char **p,uint32_t v) { for(int i=0;i<4;i++)*(*p)++=(unsigned char)(v>>(8*i)); }
static void name(unsigned char **p,const char *s) { memset(*p,0,8);for(int i=0;i<8 && s[i];i++)(*p)[i]=s[i];*p+=8; }
// Only canonical resource names cross the boundary; duplicate directory entries
// must not override the effective engine lookup. Identity mappings are implicit.
size_t ME_WriteMaterials(void *out,size_t capacity) {
    uint32_t count=0;
    for(int flat=0;flat<2;flat++)for(int i=flat?0:1;i<(flat?numflats:numtextures);i++) {
        const char *source=flat?lumpinfo[firstflat+i].name:textures[i]->name;
        if((flat?R_FlatNumForName(source):R_CheckTextureNumForName(source))!=i)continue;
        int target=flat?flattranslation[i]:texturetranslation[i];
        if(target==i)continue;
        if(target<0 || target>=(flat?numflats:numtextures))I_Error("Unsupported preview material translation");
        count++;
    }
    if(count>65536)I_Error("Excessive material translation count");
    size_t size=16+(size_t)count*20;if(!out || capacity<size)return size;
    unsigned char *p=out;memcpy(p,"MMT1",4);p+=4;word(&p,1);word(&p,leveltime);word(&p,count);
    for(int flat=0;flat<2;flat++)for(int i=flat?0:1;i<(flat?numflats:numtextures);i++) {
        const char *source=flat?lumpinfo[firstflat+i].name:textures[i]->name;
        if((flat?R_FlatNumForName(source):R_CheckTextureNumForName(source))!=i)continue;
        int target=flat?flattranslation[i]:texturetranslation[i];if(target==i)continue;
        name(&p,source);name(&p,flat?lumpinfo[firstflat+target].name:textures[target]->name);word(&p,flat);
    }
    return size;
}
