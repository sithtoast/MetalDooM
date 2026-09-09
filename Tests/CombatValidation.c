// SPDX-License-Identifier: GPL-2.0-or-later
#include "Bridge.h"
#include <assert.h>
#include <stdio.h>

static void ticks(int count, int attack, int weapon) {
    for (int i=0;i<count;++i) assert(MD_CombatTick(0,0,0,0,attack,i == 0 ? weapon : -1));
}
int main(int argc, char **argv) {
    assert(argc == 2);
    // Keep target tests isolated from the rest of E1M1's monsters.
    MD_TestMonsters(0); assert(MD_Load(argv[1],1,1)); ticks(25,0,-1);
    MD_WeaponSprite sprites[2]; assert(MD_CopyWeaponSprites(sprites,2) == 1);
    int idle = sprites[0].lump;
    MD_TestTarget(1,128); // MT_POSSESSED from the pinned upstream info.h.
    int health = MD_TestTargetHealth(), ammo = MD_GetHUD().bullets, flash = 0, animated = 0, sounds = 0;
    for (int i=0;i<70 && MD_TestTargetHealth()>0;++i) {
        ticks(1,1,-1);
        int count = MD_CopyWeaponSprites(sprites,2);
        if (count == 2) flash = 1;
        if (count && sprites[0].lump != idle) animated = 1;
        MD_SoundEvent event; while (MD_PopSound(&event)) if (event.lump >= 0) ++sounds;
    }
    assert(MD_GetHUD().bullets < ammo && MD_TestTargetHealth() < health);
    assert(MD_TestTargetHealth() <= 0 && MD_GetHUD().kills == 1);
    assert(flash && animated && sounds > 0);
    printf("PASS: pistol consumes ammo, animates weapon/flash, emits sounds, damages and kills a monster\n");
    ticks(40,0,0); assert(MD_GetHUD().readyWeapon == 0);
    MD_TestTarget(1,40); ammo = MD_GetHUD().bullets;
    ticks(110,1,-1); assert(MD_TestTargetHealth() <= 0 && MD_GetHUD().bullets == ammo);
    printf("PASS: switch to fist, melee damage and kill without consuming ammo\n");
    ticks(40,0,6); assert(MD_GetHUD().readyWeapon == 0); // unowned BFG
    ticks(40,0,1); assert(MD_GetHUD().readyWeapon == 1);
    printf("PASS: unowned weapon rejected and owned pistol can be selected again\n");
    assert(MD_Load(argv[1],1,1)); ticks(25,0,-1);
    MD_TestTarget(11,128); // MT_TROOP: original imp AI and projectiles.
    int damaged = 0;
    for (int i=0;i<1400 && MD_GetHUD().health>0;++i) {
        ticks(1,0,-1); if (MD_GetHUD().damageFlash > 0) damaged = 1;
    }
    assert(damaged && MD_GetHUD().health <= 0);
    for (int i=0;i<20;++i) assert(MD_CombatTick(0,0,0,1,1,-1));
    assert(MD_GetHUD().health <= 0);
    printf("PASS: original imp AI attacks, hurts and kills player; use cannot revive a dead player\n");
    assert(MD_Load(argv[1],1,1));
    assert(MD_GetHUD().health == 100 && MD_GetHUD().bullets == 50 && MD_GetHUD().kills == 0);
    ticks(25,0,-1); ticks(900,1,-1);
    assert(MD_GetHUD().bullets == 0 && MD_GetHUD().readyWeapon == 0);
    printf("PASS: empty pistol cannot consume negative ammo and falls back to fist\n");
    MD_TestMonsters(1); assert(MD_Load(argv[1],1,1));
    assert(MD_GetHUD().totalKills > 0);
    printf("PASS: restart restores live player/inventory; normal E1M1 spawns monsters (%d)\n",MD_GetHUD().totalKills);
    return 0;
}
