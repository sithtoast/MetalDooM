// SPDX-License-Identifier: GPL-2.0-or-later
#include "ExtendedCore.h"
#include "NativeInternal.h"
#include "doomstat.h"
#include "r_state.h"
#include "r_data.h"
#include "w_wad.h"
#include "i_system.h"
#include "r_sky.h"
#include "m_array.h"
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
    size_t size=20+(size_t)count*20;
    if(array_size(levelskies)>4096)I_Error("Excessive sky count");
    for(unsigned i=0;i<array_size(levelskies);i++) {
        sky_t *sky=&levelskies[i];int tex=sky->background.texture;
        int w=texturewidth[tex],h=textureheight[tex]>>FRACBITS;
        if(w<1 || h<1 || w>4096 || h>4096)I_Error("Invalid sky dimensions");
        size+=68+(sky->type==SkyType_Fire?(size_t)w*h:0);
    }
    if(size>32*1024*1024)I_Error("Excessive sky snapshot");if(!out || capacity<size)return size;
    unsigned char *p=out;memcpy(p,"MMT2",4);p+=4;word(&p,2);word(&p,leveltime);word(&p,count);
    for(int flat=0;flat<2;flat++)for(int i=flat?0:1;i<(flat?numflats:numtextures);i++) {
        const char *source=flat?lumpinfo[firstflat+i].name:textures[i]->name;
        if((flat?R_FlatNumForName(source):R_CheckTextureNumForName(source))!=i)continue;
        int target=flat?flattranslation[i]:texturetranslation[i];if(target==i)continue;
        name(&p,source);name(&p,flat?lumpinfo[firstflat+target].name:textures[target]->name);word(&p,flat);
    }
    word(&p,array_size(levelskies));
    for(unsigned i=0;i<array_size(levelskies);i++) {
        sky_t *sky=&levelskies[i];word(&p,sky->type);
        for(int layer=0;layer<2;layer++) {
            skytex_t *t=layer?&sky->foreground:&sky->background;
            if(layer && sky->type!=SkyType_WithForeground) {memset(p,0,28);p+=28;continue;}
            name(&p,textures[t->texture]->name);
            word(&p,((uint32_t)t->currx<<6)+(sky->side?(uint32_t)sky->side->textureoffset:0));
            word(&p,(uint32_t)t->mid+(uint32_t)t->curry+(sky->side?(uint32_t)sky->side->rowoffset:0));
            word(&p,t->scalex);word(&p,t->scaley);word(&p,ME_RenderTint(-1));
        }
        int tex=sky->background.texture,w=texturewidth[tex],h=textureheight[tex]>>FRACBITS;
        word(&p,sky->type==SkyType_Fire?w:0);word(&p,sky->type==SkyType_Fire?h:0);
        if(sky->type==SkyType_Fire) {
            // Copy generated columns; never run the fire RNG during presentation.
            for(int x=0;x<w;x++){const byte *col=R_GetColumn(tex,x);for(int y=0;y<h;y++)p[y*w+x]=col[y];}
            p+=(size_t)w*h;
        }
    }
    return size;
}
