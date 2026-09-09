// SPDX-License-Identifier: GPL-2.0-or-later
#include "Bridge.h"
#include <assert.h>
#include <stdio.h>
#include <math.h>
int main(int argc,char **argv) {
    assert(argc==2); assert(MD_Load(argv[1],1,1));
    assert(MD_Cheat("iddqd")); MD_TestDamagePlayer(20);assert(MD_GetHUD().health==100);
    assert(MD_Cheat("iddqd"));MD_TestDamagePlayer(20);assert(MD_GetHUD().health==80);
    assert(MD_Cheat("idfa"));assert(MD_GetHUD().armor==200 && MD_GetHUD().bullets==MD_GetHUD().maxBullets && !MD_GetHUD().keys);
    assert(MD_Cheat("idkfa"));assert(MD_GetHUD().keys);
    assert(MD_Cheat("idclip"));assert(MD_Cheat("idspispopd"));
    assert(MD_Cheat("idbeholdv"));assert(MD_GetHUD().faceIndex==40 || MD_GetHUD().damageFlash);
    assert(!MD_Cheat("garbage"));assert(MD_LoadSkill(argv[1],1,1,4));assert(!MD_Cheat("iddqd"));
    assert(MD_Load(argv[1],1,1));
    assert(!MD_StartDemo("TITLEPIC"));assert(!MD_DemoPlaying());
    assert(MD_StartDemo("DEMO1"));assert(!MD_Cheat("idkfa"));
    for(int i=0;i<200;i++) assert(MD_CombatTick(50,40,30000,1,1,6));
    MD_Player first=MD_GetPlayer();assert(MD_DemoPlaying());
    assert(MD_StartDemo("DEMO1"));
    for(int i=0;i<200;i++) assert(MD_Tick(0,0,0,0));
    MD_Player second=MD_GetPlayer();assert(first.x==second.x && first.y==second.y && first.angle==second.angle && first.health==second.health);
    int tics=200;while(MD_DemoPlaying() && tics<20000) { assert(MD_Tick(0,0,0,0));++tics; }
    assert(!MD_DemoPlaying());assert(tics<20000);
    for(int d=2;d<=4;d++) {
        char name[9];snprintf(name,sizeof(name),"DEMO%d",d);
        if(!MD_StartDemo(name)) { assert(d==4);break; }
        int ticks=0;while(MD_DemoPlaying() && ticks<20000) { assert(MD_Tick(0,0,0,0));++ticks; }
        assert(!MD_DemoPlaying());printf("PASS: %s completes in %d tics\n",name,ticks);
    }
    assert(MD_Load(argv[1],1,1));assert(!MD_DemoPlaying());assert(MD_Cheat("iddqd"));
    printf("PASS: cheats, Nightmare/demo rejection, malformed demo rejection, deterministic replay ignoring input, demo completion (%d tics), normal game reset\n",tics);
}
