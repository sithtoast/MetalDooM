// SPDX-License-Identifier: GPL-2.0-or-later
// Native, non-interpolated adaptation of pinned Woof r_bsp.c R_FakeFlat.
#include "RenderSector.h"
#include "doomstat.h"
#include "p_mobj.h"
#include "r_state.h"
#include "r_data.h"
#include <stdint.h>
static int light(const sector_t *s,int ceiling) {
    int other=ceiling?s->ceilinglightsec:s->floorlightsec;
    int base=other<0?s->lightlevel:sectors[other].lightlevel;
    int offset=ceiling?s->lightceiling:s->lightfloor;
    int absolute=s->flags&(ceiling?SECF_ABS_LIGHT_CEIL:SECF_ABS_LIGHT_FLOOR);
    return offset+(absolute?0:base);
}
static fixed_t offset(fixed_t value,int delta) {
    int64_t result=(int64_t)value+delta;
    return result<INT32_MIN?INT32_MIN:result>INT32_MAX?INT32_MAX:(fixed_t)result;
}
fixed_t ME_RenderEye(void) {
    if(leveltime)return players[0].viewz;
    int64_t eye=(int64_t)players[0].mo->z+players[0].viewheight;
    int64_t ceiling=(int64_t)players[0].mo->ceilingz-4*FRACUNIT;
    return (fixed_t)MIN(eye,ceiling);
}
void ME_RenderSector(const sector_t *sec,int back,sector_t *out,int *fl,int *cl) {
    *out=*sec;*fl=light(sec,0);*cl=light(sec,1);
    if(sec->heightsec<0)return;
    const sector_t *s=&sectors[sec->heightsec];
    int phs=players[0].mo->subsector->sector->heightsec;
    fixed_t eye=ME_RenderEye();
    int underwater=phs>=0 && eye<=sectors[phs].floorheight;
    out->floorheight=s->floorheight;out->ceilingheight=s->ceilingheight;
    if(underwater) {
        out->floorheight=sec->floorheight;out->ceilingheight=offset(s->floorheight,-1);
    }
    if(underwater && !back) {
        out->floorpic=s->floorpic;out->floor_xoffs=s->floor_xoffs;out->floor_yoffs=s->floor_yoffs;
        if(s->ceilingpic==skyflatnum) {
            out->floorheight=offset(out->ceilingheight,1);out->ceilingpic=out->floorpic;
            out->ceiling_xoffs=out->floor_xoffs;out->ceiling_yoffs=out->floor_yoffs;
        } else {
            out->ceilingpic=s->ceilingpic;out->ceiling_xoffs=s->ceiling_xoffs;out->ceiling_yoffs=s->ceiling_yoffs;
        }
        out->lightlevel=s->lightlevel;*fl=light(s,0);*cl=light(s,1);
    } else if(phs>=0 && eye>=sectors[phs].ceilingheight && sec->ceilingheight>s->ceilingheight) {
        out->ceilingheight=s->ceilingheight;out->floorheight=offset(s->ceilingheight,1);
        out->floorpic=out->ceilingpic=s->ceilingpic;
        out->floor_xoffs=out->ceiling_xoffs=s->ceiling_xoffs;
        out->floor_yoffs=out->ceiling_yoffs=s->ceiling_yoffs;
        if(s->floorpic!=skyflatnum) {
            out->ceilingheight=sec->ceilingheight;out->floorpic=s->floorpic;
            out->floor_xoffs=s->floor_xoffs;out->floor_yoffs=s->floor_yoffs;
        }
        out->lightlevel=s->lightlevel;*fl=light(s,0);*cl=light(s,1);
    }
}
void ME_SectorClip(const sector_t *sec,fixed_t *bottom,fixed_t *top) {
    *bottom=INT32_MIN;*top=INT32_MAX;
    if(sec->heightsec<0)return;
    const sector_t *s=&sectors[sec->heightsec];
    int phs=players[0].mo->subsector->sector->heightsec;
    fixed_t eye=ME_RenderEye();
    if(eye>=s->floorheight || (phs>=0 && eye>sectors[phs].floorheight))*bottom=s->floorheight;
    else if(phs>=0 && eye<=sectors[phs].floorheight)*top=s->floorheight;
    if(phs>=0 && eye>=sectors[phs].ceilingheight)*bottom=MAX(*bottom,s->ceilingheight);
    else *top=MIN(*top,s->ceilingheight);
}
