// SPDX-License-Identifier: GPL-2.0-or-later
#include "Bridge.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
int main(int argc,char **argv) {
    assert(argc==2); int counts[5];
    for(int skill=0;skill<5;skill++) {
        assert(MD_LoadSkill(argv[1],1,1,skill)); assert(MD_GetSkill()==skill);
        counts[skill]=MD_GetHUD().totalKills;
        MD_TestDamagePlayer(20);
        assert(MD_GetHUD().health==(skill==0 ? 90 : 80));
    }
    assert(counts[0]==counts[1] && counts[2]>counts[1] && counts[3]>counts[2] && counts[4]==counts[3]);
    assert(MD_LoadSkill(argv[1],1,1,3));
    char path[]="/tmp/metaldoom-skill-XXXXXX"; int fd=mkstemp(path);assert(fd>=0);close(fd);
    assert(MD_WriteSave(path)); assert(MD_LoadSkill(argv[1],1,1,0));
    assert(MD_ReadSave(path)); assert(MD_GetSkill()==3);unlink(path);
    int tick=MD_GetPlayer().tick;
    assert(!MD_LoadSkill(argv[1],1,1,-1) && !MD_LoadSkill(argv[1],1,1,5));
    assert(MD_GetPlayer().tick==tick && MD_GetSkill()==3);
    puts("PASS: five skill settings, original spawn filters and baby damage, saved difficulty restoration, invalid difficulty preserves game");
}
