// SPDX-License-Identifier: GPL-2.0-or-later
#include "NativeInternal.h"
#include "doomstat.h"
#include "r_state.h"
#include "r_main.h"
#include "r_data.h"
#include "r_bmaps.h"
#include "p_mobj.h"
#include "RenderSector.h"
#include "i_system.h"
#include <string.h>
extern int numtextures;
static const byte *masks[512];
static unsigned count;
unsigned ME_BrightMask(const byte *mask) {
    if(!mask)mask=nobrightmap;
    for(unsigned i=0;i<count;i++)if(!memcmp(masks[i],mask,256))return i;
    if(count==512)I_Error("Too many brightmaps");
    masks[count]=mask;return count++;
}
void ME_InitLighting(void) {
    ME_BrightMask(nobrightmap);
    for(int i=0;i<numtextures;i++)ME_BrightMask(R_BrightmapForTexName(textures[i]->name));
    for(int i=0;i<numflats;i++)ME_BrightMask(R_BrightmapForFlatNum(i));
    for(int i=0;i<num_states;i++)ME_BrightMask(R_BrightmapForState(i));
    for(int i=0;i<num_sprites;i++)ME_BrightMask(R_BrightmapForSprite(i));
}
unsigned ME_BrightMaskCount(void){return count;}
const byte *ME_BrightMaskData(unsigned i){return masks[i];}
int ME_RenderTint(int tint) {
    if(tint<0) {
        const sector_t *s=players[0].mo->subsector->sector;tint=s->colormap;
        if(!tint && s->heightsec>=0) {
            s=&sectors[s->heightsec];fixed_t eye=ME_RenderEye();
            tint=eye<s->floorheight?s->bottommap:eye>s->ceilingheight?s->topmap:s->midmap;
        }
    }
    if(tint<0 || tint>=numcolormaps)return 0;
    return tint;
}
int ME_ThingTint(const mobj_t *m) {
    const sector_t *s=m->subsector->sector;
    return ME_RenderTint(m->tint>=0?m->tint:s->floorlightsec>=0?sectors[s->floorlightsec].tint:s->tint);
}
