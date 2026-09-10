// SPDX-License-Identifier: GPL-2.0-or-later
#include "Bridge.h"
#include "doomstat.h"
#include "d_englsh.h"
#include "p_local.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main(int argc,char **argv) {
    assert(argc==3); int tnt=atoi(argv[2])==1;
    const char *texts[]={tnt?T1TEXT:P1TEXT,tnt?T2TEXT:P2TEXT,tnt?T3TEXT:P3TEXT,tnt?T4TEXT:P4TEXT,tnt?T5TEXT:P5TEXT,tnt?T6TEXT:P6TEXT};
    const char *flats[]={"SLIME16","RROCK14","RROCK07","RROCK17","RROCK13","RROCK19"};
    MD_TestMonsters(0);
    for(int map=1;map<=32;map++) for(int secret=0;secret<=1;secret++) {
        if(secret && map!=15 && map!=31) continue;
        assert(MD_Load(argv[1],1,map));
        assert(gamemission==(tnt?pack_tnt:pack_plut) && gameversion==exe_final);
        assert(MD_Cheat("idfa")); MD_HUD before=MD_GetHUD();
        MD_TestExit(secret);assert(MD_Tick(0,0,0,0));
        assert(MD_GetProgress().phase==1 && MD_GetProgress().commercial);
        int story=map==6?0:map==11?1:map==20?2:map==30?3:secret?(map==15?4:5):-1;
        assert(MD_BeginStory()==(story>=0));
        if(story>=0) { assert(!strcmp(MD_StoryText(),texts[story]));assert(!strcmp(MD_StoryFlat(),flats[story])); }
        if(map==30) {
            assert(!MD_Continue());assert(MD_StartCast());int seen[17]={0};
            for(int n=0;n<18;n++) {
                MD_Cast c=MD_GetCast();assert(c.member>=0 && c.member<17 && c.patch[0]);seen[c.member]=1;
                assert(MD_CastTick(1) && MD_GetCast().dying);
                for(int i=0;i<500 && MD_GetCast().member==c.member;i++) assert(MD_CastTick(0));
                assert(MD_GetCast().member!=c.member);
            }
            for(int i=0;i<17;i++) assert(seen[i]);
        } else {
            int next=secret?(map==15?31:32):map>=31?16:map+1;
            assert(MD_GetProgress().nextMap==next && MD_Continue());
            assert(MD_GetProgress().map==next && MD_GetHUD().weapons==before.weapons && MD_GetHUD().shells==before.shells);
        }
    }
    puts("PASS: Final Doom mission/version, all routes, six exact campaign stories/flats, inventory carryover and cast cycle");
    // Exercise the original Final Doom teleporter-height quirk, requested by
    // the rerelease's comp_finaldoomteleport setting, through EV_Teleport.
    assert(MD_Load(argv[1],1,1));mobj_t *player=players[0].mo;
    sector_t *sector=player->subsector->sector;int oldtag=sector->tag;sector->tag=32760;
    mobj_t *destination=P_SpawnMobj(player->x,player->y,ONFLOORZ,MT_TELEPORTMAN);
    line_t line={0};line.tag=32760;player->z=player->floorz+16*FRACUNIT;fixed_t before=player->z;
    assert(EV_Teleport(&line,0,player));assert(player->z==before);
    P_RemoveMobj(destination);sector->tag=oldtag;
    puts("PASS: original Final Doom teleport height behavior");
    return 0;
}
