// SPDX-License-Identifier: GPL-2.0-or-later
#include "Bridge.h"
#include "info.h"
#include <assert.h>
#include <stdlib.h>
#include <stdio.h>
static void ticks(int n,int attack,int slot) {
    for(int i=0;i<n;i++) assert(MD_CombatTick(0,0,0,0,attack,i==0 ? slot:-1));
}
int main(int argc,char **argv) {
    assert(argc==2);
    for(int map=1;map<=32;map++) {
        assert(MD_Load(argv[1],1,map)); assert(MD_GetProgress().commercial);
        assert(MD_GetHUD().parSeconds>0);
        ticks(5,0,-1); assert(MD_SectorCount()>0);
        int n=MD_CopyThings(NULL,0,0,0); assert(n>0);
        MD_Thing *things=calloc(n,sizeof(*things)); MD_CopyThings(things,n,0,0);
        for(int i=0;i<n;i++) assert(things[i].lump>=0);
        free(things);
    }
    puts("PASS: all 32 Doom II maps load, tick and export native sprite snapshots");
    MD_TestMonsters(0); assert(MD_Load(argv[1],1,1)); ticks(25,0,-1);
    ticks(40,0,2); assert(MD_GetHUD().readyWeapon==1);
    assert(MD_Cheat("idfa")); ticks(40,0,2); assert(MD_GetHUD().readyWeapon==8);
    MD_TestTarget(MT_POSSESSED,128); int shells=MD_GetHUD().shells;
    ticks(1,1,-1); ticks(65,0,-1);
    assert(MD_GetHUD().shells==shells-2 && MD_TestTargetHealth()<=0);
    MD_WeaponSprite weapon[2]; assert(MD_CopyWeaponSprites(weapon,2)>0 && weapon[0].lump>=0);
    MD_SoundEvent event; int sounds=0; while(MD_PopSound(&event)) if(event.lump>=0) sounds++;
    assert(sounds>=3);
    ticks(40,0,2); assert(MD_GetHUD().readyWeapon==2);
    ticks(40,0,2); assert(MD_GetHUD().readyWeapon==8);
    puts("PASS: super shotgun ownership, slot-3 toggle, two-shell shot, target kill, reload sounds and weapon sprite");
    const int monsters[]={MT_VILE,MT_UNDEAD,MT_FATSO,MT_CHAINGUY,MT_KNIGHT,MT_BABY,MT_PAIN,MT_WOLFSS};
    for(unsigned i=0;i<sizeof(monsters)/sizeof(*monsters);i++) {
        assert(MD_Load(argv[1],1,1)); assert(MD_Cheat("iddqd"));
        MD_TestTarget(monsters[i],128); assert(MD_TestTargetHealth()>0);
        ticks(140,0,-1); assert(MD_CopyThings(NULL,0,0,0)>0);
    }
    puts("PASS: eight Doom II monster types spawn and run original thinkers (smoke coverage)");
    assert(MD_Load(argv[1],1,1)); assert(MD_Cheat("idfa"));
    MD_HUD before=MD_GetHUD(); MD_TestExit(0); ticks(1,0,-1);
    assert(MD_GetProgress().nextMap==2 && MD_Continue());
    assert(MD_GetHUD().weapons==before.weapons && MD_GetHUD().shells==before.shells);
    puts("PASS: MAP01 to MAP02 carries the super shotgun and ammo");
    for(int map=1;map<=32;map++) for(int secret=0;secret<=1;secret++) {
        if(secret && map!=15 && map!=31) continue;
        assert(MD_Load(argv[1],1,map));assert(MD_Cheat("idfa"));
        before=MD_GetHUD();MD_TestExit(secret);ticks(1,0,-1);
        assert(MD_GetProgress().phase==1);
        int story=(map==6 || map==11 || map==20 || map==30 || secret);
        assert(MD_BeginStory()==story);
        if(story) assert(MD_GetProgress().phase==3 && MD_StoryText()[0] && MD_StoryFlat()[0]);
        if(map==30) {
            assert(!MD_Continue());assert(MD_StartCast());
            int seen[17]={0};
            for(int member=0;member<18;member++) {
                MD_Cast cast=MD_GetCast();assert(cast.member>=0 && cast.member<17 && cast.patch[0]);seen[cast.member]=1;
                assert(MD_CastTick(1));assert(MD_GetCast().dying);
                for(int i=0;i<500 && MD_GetCast().member==cast.member;i++) assert(MD_CastTick(0));
                assert(MD_GetCast().member!=cast.member);
            }
            for(int i=0;i<17;i++) assert(seen[i]);
        } else {
            int next=secret ? (map==15 ? 31:32) : (map>=31 ? 16:map+1);
            assert(MD_GetProgress().nextMap==next);assert(MD_Continue());
            assert(MD_GetProgress().map==next && MD_GetHUD().weapons==before.weapons && MD_GetHUD().shells==before.shells);
        }
    }
    puts("PASS: all Doom II routes, six story triggers, secret-map returns, inventory carryover and 17-member cast deaths/wrap");
    MD_TestMonsters(1);assert(MD_Load(argv[1],1,7));assert(MD_Cheat("iddqd"));
    int n=MD_SectorCount();float *heights=calloc(n,sizeof(*heights));
    for(int i=0;i<n;i++) heights[i]=MD_GetSector(i).floor;
    assert(MD_TestDamageType(MT_FATSO,10000,1)==1);ticks(100,0,-1);
    for(int i=0;i<n;i++) if(MD_TestSectorTag(i)==666) assert(heights[i]==MD_GetSector(i).floor);
    assert(MD_TestDamageType(MT_FATSO,10000,100)>0);ticks(350,0,-1);
    int moved=0;for(int i=0;i<n;i++) if(MD_TestSectorTag(i)==666 && heights[i]>MD_GetSector(i).floor) moved++;
    assert(moved>0);for(int i=0;i<n;i++) heights[i]=MD_GetSector(i).floor;
    assert(MD_TestDamageType(MT_BABY,10000,100)>0);ticks(350,0,-1);
    moved=0;for(int i=0;i<n;i++) if(MD_TestSectorTag(i)==667 && heights[i]<MD_GetSector(i).floor) moved++;
    assert(moved>0);free(heights);
    puts("PASS: MAP07 waits for the last mancubus, lowers tag 666 and raises tag 667 after arachnotrons die");
    assert(MD_Load(argv[1],1,30));assert(MD_Cheat("iddqd"));
    assert(MD_TestWakeBrain()>0);ticks(1400,0,-1);
    int spawned=0;
    const int spawnTypes[]={MT_TROOP,MT_SERGEANT,MT_SHADOWS,MT_PAIN,MT_HEAD,MT_VILE,MT_UNDEAD,MT_BABY,MT_FATSO,MT_KNIGHT,MT_BRUISER};
    for(unsigned i=0;i<sizeof(spawnTypes)/sizeof(*spawnTypes);i++) if(MD_TestHealthForType(spawnTypes[i])>0) spawned++;
    assert(spawned>0);
    assert(MD_TestDamageType(MT_BOSSBRAIN,10000,1)==1);ticks(300,0,-1);
    assert(MD_GetProgress().phase==1 && MD_BeginStory() && MD_StartCast());
    puts("PASS: MAP30 brain cubes spawn monsters and brain death reaches stats, final story and cast");
}
