// SPDX-License-Identifier: GPL-2.0-or-later
#include "Bridge.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>

int main(int argc, char **argv) {
    assert(argc == 2);
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
    return 0;
}
