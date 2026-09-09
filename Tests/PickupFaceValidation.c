// SPDX-License-Identifier: GPL-2.0-or-later
#include "Bridge.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
static void tick(void) { assert(MD_Tick(1,0,0,0)); }
int main(int argc,char **argv) {
    assert(argc==2); MD_TestMonsters(0); assert(MD_Load(argv[1],1,2));
    int n=MD_CopyThings(NULL,0,0,0); MD_Thing *things=calloc(n,sizeof(*things));
    MD_CopyThings(things,n,0,0);
    for(int i=0;i<n;i++) if(things[i].doomedType==2018) printf("Armor %.0f %.0f floor %.0f\n",things[i].x,things[i].y,things[i].floorZ);
    free(things);
    assert(MD_TestPlacePlayer(0,900,1.57079632679));
    printf("Hall floor %.0f\n",MD_GetPlayer().eyeZ-41);
    for(int i=0;i<30;i++) assert(MD_Tick(25,0,0,0));
    assert(MD_GetHUD().armor==100);
    puts("PASS: E1M2 hall armor collected by walking into the raised ledge");
    assert(MD_Load(argv[1],1,2)); assert(!MD_GetHUD().weaponGrin);
    assert(MD_TestPlacePlayer(-176,496,0)); tick();
    assert(MD_GetHUD().weapons & (1u<<2)); assert(MD_GetHUD().weaponGrin);
    for(int i=0;i<69;i++) tick(); assert(MD_GetHUD().weaponGrin);
    tick(); assert(!MD_GetHUD().weaponGrin);
    assert(MD_TestPlacePlayer(240,432,0)); tick();
    assert(MD_GetHUD().armor==100); assert(!MD_GetHUD().weaponGrin);
    assert(MD_Load(argv[1],1,2)); assert(!MD_GetHUD().weaponGrin);
    assert(MD_TestPlacePlayer(-176,496,0)); tick(); assert(MD_GetHUD().weaponGrin);
    MD_TestDamagePlayer(1000); tick(); assert(!MD_GetHUD().weaponGrin);
    puts("PASS: new weapon grin lasts 70 tics, armor does not grin, reset/death clear it");
}
