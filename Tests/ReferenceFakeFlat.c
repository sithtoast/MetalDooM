// SPDX-License-Identifier: GPL-2.0-or-later
// Frozen Woof acd1c7f84fdd0fae92d1c58643c14364a131c75a r_bsp.c oracle.
// Original R_FakeFlat by Lee Killough; see Vendor/Woof/COPYING and provenance.
#include "RenderSector.h"
#include "doomstat.h"
#include "p_mobj.h"
#include "r_state.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
player_t players[MAXPLAYERS],*viewplayer;
sector_t *sectors;
fixed_t viewz;
int skyflatnum;
int leveltime=1;
inline static const int16_t FloorLight(const sector_t *sec)
{
  const int16_t light = (sec->floorlightsec == -1)
                      ? sec->lightlevel
                      : sectors[sec->floorlightsec].lightlevel;

  return (sec->flags & SECF_ABS_LIGHT_FLOOR) ? sec->lightfloor
                                             : sec->lightfloor + light;
}

inline static const int16_t CeilingLight(const sector_t *sec)
{
  const int16_t light = (sec->ceilinglightsec == -1)
                      ? sec->lightlevel
                      : sectors[sec->ceilinglightsec].lightlevel;

  return (sec->flags & SECF_ABS_LIGHT_CEIL) ? sec->lightceiling
                                            : sec->lightceiling + light;
}

sector_t *R_FakeFlat(sector_t *sec, sector_t *tempsec,
                     int *floorlightlevel, int *ceilinglightlevel,
                     boolean back)
{
  if (floorlightlevel)
    *floorlightlevel = FloorLight(sec);

  if (ceilinglightlevel)
    *ceilinglightlevel = CeilingLight(sec); // killough 4/11/98

  if (sec->heightsec != -1)
    {
      const sector_t *s = &sectors[sec->heightsec];
      int heightsec = viewplayer->mo->subsector->sector->heightsec;
      int underwater = heightsec!=-1 && viewz<=sectors[heightsec].floorheight;

      // Replace sector being drawn, with a copy to be hacked
      *tempsec = *sec;

      // Replace floor and ceiling height with other sector's heights.
      tempsec->floorheight   = s->floorheight;
      tempsec->ceilingheight = s->ceilingheight;
      tempsec->interpfloorheight   = s->interpfloorheight;
      tempsec->interpceilingheight = s->interpceilingheight;

      // killough 11/98: prevent sudden light changes from non-water sectors:
      if (underwater && (tempsec->  floorheight = sec->floorheight,
			 tempsec->interpfloorheight = sec->interpfloorheight,
			 tempsec->interpceilingheight = s->interpfloorheight-1,
			 tempsec->ceilingheight = s->floorheight-1, !back))
        {                   // head-below-floor hack
          tempsec->floorpic    = s->floorpic;
          tempsec->interp_floor_xoffs = s->interp_floor_xoffs;
          tempsec->interp_floor_yoffs = s->interp_floor_yoffs;
          tempsec->floor_rotation = s->floor_rotation;

          if (underwater)
          {
            if (s->ceilingpic == skyflatnum)
              {
                tempsec->floorheight   = tempsec->ceilingheight+1;
                tempsec->interpfloorheight = tempsec->interpceilingheight+1;
                tempsec->ceilingpic    = tempsec->floorpic;
                tempsec->interp_ceiling_xoffs = tempsec->interp_floor_xoffs;
                tempsec->interp_ceiling_yoffs = tempsec->interp_floor_yoffs;
                tempsec->ceiling_rotation = tempsec->ceiling_rotation;
              }
            else
              {
                tempsec->ceilingpic    = s->ceilingpic;
                tempsec->interp_ceiling_xoffs = s->interp_ceiling_xoffs;
                tempsec->interp_ceiling_yoffs = s->interp_ceiling_yoffs;
                tempsec->ceiling_rotation = s->ceiling_rotation;
              }
          }

          tempsec->lightlevel  = s->lightlevel;

          if (floorlightlevel)
            *floorlightlevel = FloorLight(s); // killough 3/16/98

          if (ceilinglightlevel)
            *ceilinglightlevel = CeilingLight(s); // killough 4/11/98
        }
      else
        if (heightsec != -1 && viewz >= sectors[heightsec].ceilingheight &&
            sec->ceilingheight > s->ceilingheight)
          {   // Above-ceiling hack
            tempsec->ceilingheight = s->ceilingheight;
            tempsec->floorheight   = s->ceilingheight + 1;
            tempsec->interpceilingheight = s->interpceilingheight;
            tempsec->interpfloorheight   = s->interpceilingheight + 1;

            tempsec->floorpic    = tempsec->ceilingpic    = s->ceilingpic;
            tempsec->interp_floor_xoffs = tempsec->interp_ceiling_xoffs = s->interp_ceiling_xoffs;
            tempsec->interp_floor_yoffs = tempsec->interp_ceiling_yoffs = s->interp_ceiling_yoffs;
            tempsec->floor_rotation = tempsec->ceiling_rotation = s->ceiling_rotation;

            if (s->floorpic != skyflatnum)
              {
                tempsec->ceilingheight = sec->ceilingheight;
                tempsec->interpceilingheight = sec->interpceilingheight;
                tempsec->floorpic      = s->floorpic;
                tempsec->interp_floor_xoffs   = s->interp_floor_xoffs;
                tempsec->interp_floor_yoffs   = s->interp_floor_yoffs;
                tempsec->floor_rotation = s->floor_rotation;
              }

            tempsec->lightlevel  = s->lightlevel;

            if (floorlightlevel)
              *floorlightlevel = FloorLight(s); // killough 3/16/98

            if (ceilinglightlevel)
              *ceilinglightlevel = CeilingLight(s); // killough 4/11/98
          }
      sec = tempsec;               // Use other sector
    }
  return sec;
}


#define CHECK(x) do {if(!(x)){fprintf(stderr,"FAIL reference line %d case %d\n",__LINE__,count);return 1;}}while(0)
int main(void) {
 sector_t pool[4];sectors=pool;skyflatnum=9;
 mobj_t player={0};subsector_t sub={0};player.subsector=&sub;sub.sector=&pool[3];
 players[0].mo=&player;viewplayer=&players[0];int count=0;
 for(int control=-1;control<=1;control+=2)for(int phs=-1;phs<=2;phs++)
 for(int floor=-32;floor<=128;floor+=32)for(int ceil=32;ceil<=160;ceil+=32)
 for(int eye=-33;eye<=161;eye++)for(int sky=0;sky<4;sky++)for(int back=0;back<2;back++) {
  for(int i=0;i<4;i++) {
   sector_t *s=&pool[i];memset(s,0,sizeof(*s));
   s->heightsec=-1;s->floorlightsec=s->ceilinglightsec=-1;
   s->floorheight=s->interpfloorheight=0;s->ceilingheight=s->interpceilingheight=128*FRACUNIT;
   s->floorpic=1;s->ceilingpic=2;s->lightlevel=192-i*32;
   s->floor_xoffs=s->interp_floor_xoffs=i*FRACUNIT;s->floor_yoffs=s->interp_floor_yoffs=-i*FRACUNIT;
   s->ceiling_xoffs=s->interp_ceiling_xoffs=2*i*FRACUNIT;s->ceiling_yoffs=s->interp_ceiling_yoffs=-2*i*FRACUNIT;
  }
  pool[0].heightsec=control;pool[3].heightsec=phs;
  pool[0].floorlightsec=2;pool[1].ceilinglightsec=2;
  pool[0].lightfloor=-13;pool[1].lightceiling=27;
  if(count&1){pool[1].flags|=SECF_ABS_LIGHT_FLOOR;pool[1].lightfloor=21;}
  pool[1].floorheight=pool[1].interpfloorheight=floor*FRACUNIT;
  pool[1].ceilingheight=pool[1].interpceilingheight=ceil*FRACUNIT;
  pool[1].floorpic=sky&1?9:3;pool[1].ceilingpic=sky&2?9:4;
  viewz=players[0].viewz=eye*FRACUNIT;
  sector_t before[4];memcpy(before,pool,sizeof(pool));
  sector_t out,temp;int fl,cl,rfl,rcl;
  ME_RenderSector(&pool[0],back,&out,&fl,&cl);
  sector_t *ref=R_FakeFlat(&pool[0],&temp,&rfl,&rcl,back);
  CHECK(out.floorheight==ref->floorheight && out.ceilingheight==ref->ceilingheight);
  CHECK(out.floorpic==ref->floorpic && out.ceilingpic==ref->ceilingpic);
  CHECK(out.lightlevel==ref->lightlevel && fl==rfl && cl==rcl);
  CHECK(out.floor_xoffs==ref->interp_floor_xoffs && out.floor_yoffs==ref->interp_floor_yoffs);
  CHECK(out.ceiling_xoffs==ref->interp_ceiling_xoffs && out.ceiling_yoffs==ref->interp_ceiling_yoffs);
  CHECK(!memcmp(before,pool,sizeof(pool)));count++;
 }
 printf("PASS %d frozen Woof fake-flat/front-back/light/sky/boundary cases; source sectors unchanged\n",count);
}
