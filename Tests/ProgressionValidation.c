// SPDX-License-Identifier: GPL-2.0-or-later
#include "Bridge.h"
#include <assert.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
static void ticks(int n) { while(n--) assert(MD_Tick(0,0,0,0)); }
static void collect(int type) {
    int n=MD_CopyThings(NULL,0,0,0); MD_Thing *things=calloc(n,sizeof(*things)); MD_CopyThings(things,n,0,0);
    int found=0;
    for(int i=0;i<n;++i) if(things[i].doomedType==type) { assert(MD_TestPlacePlayer(things[i].x,things[i].y,0));assert(MD_Tick(25,0,0,0));found=1;break; }
    free(things);assert(found);
}
int main(int argc,char **argv) {
    assert(argc==2);MD_TestMonsters(0);assert(MD_Load(argv[1],1,1));
    float x,y,angle;int side;
    assert(MD_TestSwitch(63,&x,&y,&angle,&side)>=0);
    assert(!strcmp(MD_GetSide(side).lower,"SW1COMP"));
    assert(MD_TestPlacePlayer(x,y,angle));assert(MD_Tick(0,0,0,1));
    assert(!strcmp(MD_GetSide(side).lower,"SW2COMP"));
    ticks(40);assert(!strcmp(MD_GetSide(side).lower,"SW1COMP"));
    puts("PASS: Ultimate Doom pillar switch changes SW1COMP to SW2COMP and resets");
    collect(2001);collect(2018);collect(2014);MD_TestDamagePlayer(20);ticks(70);
    MD_HUD before=MD_GetHUD();assert(before.armor>0 && (before.weapons&4));
    assert(MD_TestSwitch(11,&x,&y,&angle,&side)>=0);assert(MD_TestPlacePlayer(x,y,angle));
    assert(MD_Tick(0,0,0,1));MD_Progress result=MD_GetProgress();
    assert(result.phase==1 && result.map==1 && result.nextMap==2 && result.items>0 && result.seconds>=2);
    assert(!strcmp(MD_GetSide(side).middle,"SW2STRTN"));
    MD_SoundEvent event; while(MD_PopSound(&event)) {}
    for(int sound=0;sound<3;++sound) {
        MD_IntermissionSound(sound); int heard=0;
        while(MD_PopSound(&event)) if(event.lump>=0) heard=1;
        assert(heard);
    }
    MD_IntermissionSound(-1); MD_IntermissionSound(3); assert(!MD_PopSound(&event));
    puts("PASS: all three intermission sounds emit native playback events; invalid IDs ignored");
    int tick=MD_GetPlayer().tick;ticks(70);assert(MD_GetPlayer().tick==tick);
    assert(MD_Continue());MD_HUD after=MD_GetHUD();
    assert(MD_GetProgress().phase==0 && MD_GetProgress().map==2);
    assert(before.health==after.health && before.armor==after.armor && before.weapons==after.weapons);
    assert(before.bullets==after.bullets && before.shells==after.shells && after.keys==0);
    assert(MD_GetProgress().map==2 && !MD_Continue());
    puts("PASS: real exit switch freezes stats, then E1M2 preserves health/armor/weapons/ammo");
    collect(13);assert(MD_GetHUD().keys!=0);MD_TestExit(0);ticks(1);assert(MD_Continue());assert(MD_GetHUD().keys==0);
    puts("PASS: keys are cleared when advancing to E1M3");
    assert(MD_Load(argv[1],1,1));
    int count=MD_SectorCount(); MD_Sector *sectors=calloc(count,sizeof(*sectors));
    for(int i=0;i<count;++i) sectors[i]=MD_GetSector(i);
    assert(MD_TestCrossSpecial(88));ticks(35);
    int moved=0;for(int i=0;i<count;++i) if(MD_GetSector(i).floor!=sectors[i].floor) moved=1;
    assert(moved);ticks(350);
    for(int i=0;i<count;++i) assert(MD_GetSector(i).floor==sectors[i].floor);
    free(sectors);
    assert(MD_Load(argv[1],4,7)); count=MD_SectorCount();sectors=calloc(count,sizeof(*sectors));
    for(int i=0;i<count;++i) sectors[i]=MD_GetSector(i);
    assert(MD_TestCrossSpecial(25));ticks(35);
    moved=0;for(int i=0;i<count;++i) if(MD_GetSector(i).ceiling<sectors[i].ceiling) moved=1;
    assert(moved);free(sectors);
    assert(MD_Load(argv[1],1,1));assert(MD_TestFindSecret(&x,&y));
    assert(MD_TestPlacePlayer(x,y,0));ticks(35);MD_TestExit(0);ticks(1);assert(MD_GetProgress().secrets==1);
    puts("PASS: real map lift lowers and returns, crusher descends, secret counts once");
    int returns[]={4,6,7,3};
    for(int episode=1;episode<=4;++episode) {
        assert(MD_Load(argv[1],episode,3));MD_TestExit(1);ticks(1);assert(MD_GetProgress().nextMap==9);assert(MD_Continue());
        MD_TestExit(0);ticks(1);assert(MD_GetProgress().nextMap==returns[episode-1] && MD_GetProgress().didSecret);assert(MD_Continue());
        assert(strlen(MD_FinaleText(episode))>100);
        assert(MD_Load(argv[1],episode,1));
        for(int map=1;map<=8;++map) {
            assert(MD_GetProgress().map==map); MD_TestExit(0);ticks(1);
            if(map<8) { assert(MD_GetProgress().phase==1 && MD_GetProgress().nextMap==map+1);assert(MD_Continue()); }
            else { assert(MD_GetProgress().phase==2 && !MD_Continue()); }
        }
    }
    puts("PASS: all four episodes route to secret maps, return correctly, and run the complete M1-M8 chain into episode completion");
    for(int episode=1;episode<=4;++episode) for(int map=1;map<=9;++map) {
        assert(MD_Load(argv[1],episode,map));ticks(2);assert(MD_GetProgress().map==map);
    }
    puts("PASS: all 36 Ultimate Doom maps load and tick");
}
