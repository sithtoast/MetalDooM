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
}
