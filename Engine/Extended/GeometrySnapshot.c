// SPDX-License-Identifier: GPL-2.0-or-later
#include "ExtendedCore.h"
#include "NativeInternal.h"
#include "SessionPlan.h"
#include "RenderSector.h"
#include "doomstat.h"
#include "p_mobj.h"
#include "r_state.h"
#include "r_data.h"
#include "w_wad.h"
#include "i_system.h"
#include <string.h>
extern int numtextures;

static void Word(unsigned char **out, uint32_t value)
{
    for (int i = 0; i < 4; i++) *(*out)++ = (unsigned char)(value >> (8*i));
}
static void Name(unsigned char **out, const char *name)
{
    memset(*out, 0, 8);
    for (int i = 0; i < 8 && name[i]; i++) (*out)[i] = (unsigned char)name[i];
    *out += 8;
}
static void Texture(unsigned char **out, int index)
{
    if (index == 0 || index == NO_TEXTURE) { Name(out, "-"); return; }
    if (index < 0 || index >= numtextures) I_Error("Invalid geometry texture index");
    Name(out, textures[index]->name);
}
static void Flat(unsigned char **out, int index)
{
    if (index < 0 || index >= numflats || firstflat + index >= numlumps)
        I_Error("Invalid geometry flat index");
    Name(out, lumpinfo[firstflat + index].name);
}
size_t ME_WriteGeometry(void *out, size_t capacity)
{
    const int counts[] = {numvertexes, numlines, numsides, numsectors, numsegs, numsubsectors, numnodes};
    const size_t strides[] = {8,24,36,76,16,12,24};
    size_t size = 120;
    for (int i = 0; i < 7; i++) {
        if (counts[i] < 0 || counts[i] > 1000000) I_Error("Excessive geometry count");
        size += (size_t)counts[i]*strides[i];
    }
    if (!out || capacity < size) return size;
    unsigned char *p = out;
    memcpy(p,"MGE4",4); p += 4;
    Word(&p,4); Word(&p,leveltime); Word(&p,gamemap);
    Word(&p,players[0].mo->x); Word(&p,players[0].mo->y); Word(&p,players[0].mo->angle);
    for (int i=0;i<7;i++) Word(&p,counts[i]);
    memcpy(p,ME_CurrentSession()->content_sha256,64); p += 64;
    for (int i=0;i<numvertexes;i++) { Word(&p,vertexes[i].x); Word(&p,vertexes[i].y); }
    for (int i=0;i<numlines;i++) {
        const line_t *l=&lines[i];
        Word(&p,l->v1-vertexes); Word(&p,l->v2-vertexes); Word(&p,l->flags);
        Word(&p,l->sidenum[0]); Word(&p,l->sidenum[1]); Word(&p,ME_BlendTableIndex(l->tranmap));
    }
    for (int i=0;i<numsides;i++) {
        const side_t *s=&sides[i];
        Word(&p,s->sector-sectors); Word(&p,s->textureoffset); Word(&p,s->rowoffset);
        Texture(&p,s->toptexture); Texture(&p,s->bottomtexture); Texture(&p,s->midtexture);
    }
    for (int i=0;i<numsectors;i++) {
        sector_t front,back;int fl,cl,unused1,unused2;
        ME_RenderSector(&sectors[i],0,&front,&fl,&cl);
        ME_RenderSector(&sectors[i],1,&back,&unused1,&unused2);
        const sector_t *s=&front;
        Word(&p,s->floorheight); Word(&p,s->ceilingheight); Word(&p,s->lightlevel);
        Flat(&p,s->floorpic); Flat(&p,s->ceilingpic);
        Word(&p,s->floor_xoffs); Word(&p,s->floor_yoffs);
        Word(&p,s->ceiling_xoffs); Word(&p,s->ceiling_yoffs);
        Word(&p,MAX(0,MIN(255,fl))); Word(&p,MAX(0,MIN(255,cl)));
        Word(&p,back.floorheight); Word(&p,back.ceilingheight); Flat(&p,back.ceilingpic);
        fixed_t bottom,top;ME_SectorClip(&sectors[i],&bottom,&top);Word(&p,bottom);Word(&p,top);
    }
    for (int i=0;i<numsegs;i++) {
        const seg_t *s=&segs[i];
        if (!s->linedef || !s->sidedef) I_Error("Minisegs need a future geometry adapter");
        Word(&p,s->v1-vertexes); Word(&p,s->v2-vertexes); Word(&p,s->linedef-lines);
        int side = s->sidedef-sides;
        if (side != s->linedef->sidenum[0] && side != s->linedef->sidenum[1])
            I_Error("Invalid geometry seg side");
        Word(&p,side == s->linedef->sidenum[0] ? 0 : 1);
    }
    for (int i=0;i<numsubsectors;i++) {
        Word(&p,subsectors[i].numlines); Word(&p,subsectors[i].firstline);
        Word(&p,subsectors[i].sector-sectors);
    }
    for (int i=0;i<numnodes;i++) {
        const node_t *n=&nodes[i];
        Word(&p,n->x); Word(&p,n->y); Word(&p,n->dx); Word(&p,n->dy);
        Word(&p,n->children[0]); Word(&p,n->children[1]);
    }
    return size;
}
