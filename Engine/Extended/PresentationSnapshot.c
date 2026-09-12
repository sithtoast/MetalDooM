// SPDX-License-Identifier: GPL-2.0-or-later
#include "ExtendedCore.h"
#include "NativeInternal.h"
#include "doomstat.h"
#include "d_items.h"
#include "p_mobj.h"
#include "p_tick.h"
#include "r_state.h"
#include "r_main.h"
#include "w_wad.h"
#include "i_system.h"
#include <string.h>

static void word(unsigned char **p,uint32_t v) { for(int i=0;i<4;i++)*(*p)++=(unsigned char)(v>>(8*i)); }
// Woof normally supplies the blank TNT1 patch in its own resource WAD.
// Preserve that invisible fallback only when the session provides no frames;
// an explicit replacement remains drawable.
static int invisible(int sprite) {
    return sprite>=0 && sprite<num_sprites && !sprites[sprite].numframes &&
        sprnames[sprite] && !strcmp(sprnames[sprite],"TNT1");
}
static int eligible(mobj_t *m) { return !m->player && !(m->flags & MF_NOSECTOR) && !invisible(m->sprite); }
static spriteframe_t *frame(int sprite,int index) {
    if(sprite<0 || sprite>=num_sprites || index<0 || index>=sprites[sprite].numframes)
        I_Error("Invalid presentation sprite/frame %d/%d",sprite,index);
    return &sprites[sprite].spriteframes[index];
}
static void name(unsigned char **p,int lump) {
    if(lump<firstspritelump || lump>lastspritelump)I_Error("Invalid presentation sprite lump");
    memset(*p,0,8);memcpy(*p,lumpinfo[lump].name,8);*p+=8;
}
size_t ME_WritePresentation(void *out,size_t capacity) {
    uint32_t actors=0,weapons=0;
    for(thinker_t *t=thinkercap.next;t!=&thinkercap;t=t->next)
        if(t->function.p1==P_MobjThinker && eligible((mobj_t *)t))actors++;
    for(int i=0;i<NUMPSPRITES;i++)if(players[0].psprites[i].state && !invisible(players[0].psprites[i].state->sprite))weapons++;
    if(actors>1000000 || weapons>2)I_Error("Excessive presentation count");
    size_t size=32+(size_t)actors*40+(size_t)weapons*24;
    if(!out || capacity<size)return size;
    unsigned char *p=out;memcpy(p,"MSP2",4);p+=4;
    word(&p,2);word(&p,leveltime);word(&p,actors);word(&p,weapons);
    word(&p,players[0].readyweapon);
    int ammo=weaponinfo[players[0].readyweapon].ammo;
    word(&p,ammo==am_noammo ? -1:players[0].ammo[ammo]);word(&p,players[0].mo->interp > 0 ? 0:1);
    for(thinker_t *t=thinkercap.next;t!=&thinkercap;t=t->next) {
        if(t->function.p1!=P_MobjThinker)continue;
        mobj_t *m=(mobj_t *)t;if(!eligible(m))continue;
        spriteframe_t *f=frame(m->sprite,m->frame & FF_FRAMEMASK);
        unsigned rot=0;
        if(f->rotate) {
            angle_t angle=R_PointToAngle2(players[0].mo->x,players[0].mo->y,m->x,m->y);
            rot=(angle-m->angle+(unsigned)(ANG45/2)*9)>>29;
        }
        name(&p,firstspritelump+f->lump[rot]);
        word(&p,m->x);word(&p,m->y);word(&p,m->z);word(&p,m->floorz);
        int light=m->subsector->sector->lightlevel;
        word(&p,light>255?255:light<0?0:light);
        word(&p,(f->flip[rot]?1:0)|((m->frame & FF_FULLBRIGHT)?2:0)|((m->flags & MF_SHADOW)?4:0)|((m->flags & MF_TRANSLUCENT)?8:0));
        word(&p,m->info->doomednum);word(&p,m->state-states);
    }
    for(int i=0;i<NUMPSPRITES;i++) {
        pspdef_t *psp=&players[0].psprites[i];if(!psp->state || invisible(psp->state->sprite))continue;
        spriteframe_t *f=frame(psp->state->sprite,psp->state->frame & FF_FRAMEMASK);
        name(&p,firstspritelump+f->lump[0]);
        // Simulation offsets already include vanilla movement bob. The parent
        // interpolates presentation only; flash shares the weapon coordinates.
        word(&p,psp->sx);word(&p,psp->sy);
        int light=players[0].mo->subsector->sector->lightlevel+players[0].extralight*32;
        word(&p,light>255?255:light<0?0:light);
        word(&p,(f->flip[0]?1:0)|((psp->state->frame & FF_FULLBRIGHT)?2:0)|
            ((players[0].powers[pw_invisibility]>128 || (players[0].powers[pw_invisibility]&8))?4:0));
    }
    return size;
}
