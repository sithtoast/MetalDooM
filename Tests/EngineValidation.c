// SPDX-License-Identifier: GPL-2.0-or-later
#include "Bridge.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static MD_Thing findThing(int type) {
    int count = MD_CopyThings(NULL,0,0,0);
    assert(count > 0);
    MD_Thing *things = calloc(count,sizeof(*things)); assert(things);
    assert(MD_CopyThings(things,count,0,0) == count);
    for (int i=0; i<count; ++i) if (things[i].doomedType == type) {
        MD_Thing result = things[i]; free(things); return result;
    }
    fprintf(stderr,"Missing test thing %d\n",type); abort();
}

static int thingPresent(MD_Thing target) {
    int count = MD_CopyThings(NULL,0,0,0), found = 0;
    MD_Thing *things = calloc(count ? count : 1,sizeof(*things)); assert(things);
    MD_CopyThings(things,count,0,0);
    for (int i=0; i<count; ++i) if (things[i].doomedType == target.doomedType && things[i].x == target.x && things[i].y == target.y) found = 1;
    free(things); return found;
}

static void collect(MD_Thing item) {
    assert(MD_TestPlacePlayer(item.x,item.y,0));
    assert(MD_Tick(25,0,0,0));
    assert(!thingPresent(item));
}

static void validatePickups(const char *wad) {
    assert(MD_Load(wad,1,1));
    MD_HUD initial = MD_GetHUD();
    assert(initial.health == 100 && initial.armor == 0 && initial.bullets == 50 && initial.keys == 0);
    MD_Thing bonus = findThing(2014); collect(bonus);
    MD_HUD health = MD_GetHUD();
    assert(health.health > initial.health && health.bonusFlash > 0 && health.messageSerial > 0);
    assert(health.message[0]);
    MD_Thing armor = findThing(2015); collect(armor);
    MD_HUD armored = MD_GetHUD(); assert(armored.armor > 0 && armored.messageSerial > health.messageSerial);
    MD_Thing clip = findThing(2007); int bullets = MD_GetHUD().bullets; collect(clip);
    assert(MD_GetHUD().bullets > bullets);
    printf("PASS: health/armor/ammo pickups update HUD and disappear from sprite snapshots\n");
    // Repeated animation snapshots remain valid and change with original thinker tics.
    MD_Thing animated = findThing(2014); int changed = 0;
    assert(MD_TestPlacePlayer(1056,-3616,0));
    for (int i=0; i<24; ++i) {
        assert(MD_Tick(0,0,0,0));
        MD_Thing next = findThing(2014); if (next.lump != animated.lump) changed = 1;
    }
    assert(changed);
    printf("PASS: pickup frames animate from engine state\n");
    assert(MD_Load(wad,1,2));
    float x,y,angle; int sector;
    assert(MD_TestKeyDoor(2,&x,&y,&angle,&sector) >= 0);
    float closed = MD_GetSector(sector).ceiling;
    assert(MD_TestPlacePlayer(x,y,angle));
    assert(MD_Tick(0,0,0,1));
    for (int i=0; i<10; ++i) assert(MD_Tick(0,0,0,0));
    assert(MD_GetSector(sector).ceiling == closed);
    assert((MD_GetHUD().keys & 4) == 0 && strstr(MD_GetHUD().message,"red"));
    MD_Thing key = findThing(13); collect(key);
    assert(MD_GetHUD().keys & 4);
    assert(MD_TestPlacePlayer(x,y,angle));
    assert(MD_Tick(0,0,0,1));
    for (int i=0; i<50; ++i) assert(MD_Tick(0,0,0,0));
    assert(MD_GetSector(sector).ceiling > closed+56);
    printf("PASS: red door rejects use without key, then opens after collecting original key\n");
    assert(MD_Load(wad,1,2));
    assert(MD_GetHUD().keys == 0 && MD_GetHUD().armor == 0 && MD_GetHUD().bullets == 50);
    assert(thingPresent(key));
    printf("PASS: map restart clears inventory and restores pickups\n");
}

int main(int argc, char **argv) {
    assert(argc == 2);
    MD_TestMonsters(0);
    if (!MD_Load(argv[1],1,1)) { fprintf(stderr,"%s\n",MD_LastError()); return 1; }
    MD_Player start = MD_GetPlayer();
    printf("Spawn: %.2f %.2f eye %.2f angle %.3f sector %d\n",start.x,start.y,start.eyeZ,start.angle,start.sector);
    for (int i=0; i<12; ++i) assert(MD_Tick(25,0,0,0));
    MD_Player moved = MD_GetPlayer();
    assert(hypotf(moved.x-start.x,moved.y-start.y) > 10);
    assert(moved.tick == start.tick+12);
    printf("PASS: engine movement and fixed tic progression\n");
    assert(MD_Load(argv[1],1,1));
    MD_Player reset = MD_GetPlayer();
    assert(reset.x == start.x && reset.y == start.y && reset.tick == start.tick);
    printf("PASS: map restart restores spawn\n");
    float x,y,angle; int sector;
    int line = MD_TestDoor(0,&x,&y,&angle,&sector);
    assert(line >= 0);
    printf("Door line %d sector %d approach %.2f %.2f angle %.3f\n",line,sector,x,y,angle);
    assert(MD_TestPlacePlayer(x,y,angle));
    float closed = MD_GetSector(sector).ceiling;
    for (int i=0; i<16; ++i) assert(MD_Tick(25,0,0,0));
    MD_Player blocked = MD_GetPlayer();
    assert(blocked.sector != sector);
    assert(MD_GetSector(sector).ceiling == closed);
    assert(MD_Tick(0,0,0,1));
    for (int i=0; i<50; ++i) assert(MD_Tick(0,0,0,0));
    float opened = MD_GetSector(sector).ceiling;
    printf("Door ceiling: %.2f -> %.2f\n",closed,opened);
    assert(opened > closed+56);
    int entered = 0;
    for (int i=0; i<24; ++i) {
        assert(MD_Tick(25,0,0,0));
        if (MD_GetPlayer().sector == sector) entered = 1;
    }
    assert(entered);
    printf("PASS: closed door blocks, use opens it, player walks through\n");
    assert(MD_Load(argv[1],1,1));
    assert(MD_GetSector(sector).ceiling == closed);
    printf("PASS: restart restores closed door\n");
    for (int map=1; map<=9; ++map) {
        assert(MD_Load(argv[1],1,map));
        assert(MD_SectorCount() > 0);
        for (int tic=0; tic<10; ++tic) assert(MD_Tick(0,0,0,0));
        MD_Player player = MD_GetPlayer();
        assert(isfinite(player.x) && isfinite(player.y) && isfinite(player.eyeZ));
        printf("PASS: engine E1M%d, %d sectors\n",map,MD_SectorCount());
    }
    assert(MD_Load(argv[1],1,1));
    assert(!MD_Load("/different-iwad.wad",1,1));
    assert(MD_Tick(0,0,0,0));
    assert(!MD_Load(argv[1],1,99));
    assert(MD_Tick(0,0,0,0));
    printf("PASS: rejected IWAD/map change preserves active engine\n");
    validatePickups(argv[1]);
    return 0;
}
