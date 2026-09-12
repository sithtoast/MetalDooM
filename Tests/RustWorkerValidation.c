// SPDX-License-Identifier: GPL-2.0-or-later
#include "ExtendedCore.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static void check(int ok) {
    if (ok) return;
    char error[2048]; ME_CopyError(error,sizeof(error));
    fprintf(stderr,"FAILED: %s\n",error); exit(1);
}
int main(int argc,char **argv) {
    if (argc < 6) return 2;
    ME_Config c = {.abi_version=ME_ABI_VERSION, .wad_paths=(const char *const *)argv+5,
        .wad_count=(uint32_t)(argc-5), .cache_directory=argv[1], .skill=3,
        .map=(uint32_t)atoi(argv[2]), .random_seed=1993,
        .base_wad_index=(uint32_t)atoi(argv[3]), .profile=(uint32_t)atoi(argv[4])};
    check(ME_Init(&c));
    ME_Snapshot s; ME_Session session; check(ME_CopySnapshot(&s)); check(ME_CopySession(&session));
    printf("SESSION profile=%u base=%u files=%u declared=%u options=%u title=%s version=%s sha256=%s\n",
        session.profile,session.base_wad_index,session.wad_count,session.declared_feature,
        session.option_count,session.title,session.version,session.content_sha256);
    const char *scenario=getenv("ME_TEST_SCENARIO");
    ME_Command cmd={0};
    if(scenario) {
        cmd.forward_move=25;
        for(int i=0;i<3;i++)check(ME_Tick(&cmd));
        cmd.forward_move=0; check(ME_CopySnapshot(&s));
        if(!strcmp(scenario,"rust-fuel") || !strcmp(scenario,"rust-tank")) {
            int expected=!strcmp(scenario,"rust-fuel")?10:50;
            assert(s.ammo[2]==expected);
            assert(!strcmp(s.message,expected==10?"Picked up a fuel can.":"Picked up a fuel tank."));
            printf("PASS %s ammo=%d message=%s\n",scenario,s.ammo[2],s.message); return 0;
        }
        int weapon=!strcmp(scenario,"rust-incinerator")?5:6;
        int full=!strcmp(scenario,"rust-blade-full");
        assert(s.ammo[2]==(full?70:20));
        if(!full) assert(!strcmp(s.message,weapon==5?"You got the incinerator!":"You got the calamity blade! Hot damn!"));
        cmd.buttons=(uint8_t)(4 | (weapon<<3));check(ME_Tick(&cmd));cmd.buttons=0;
        for(int i=0;i<70;i++)check(ME_Tick(&cmd));
        check(ME_CopySnapshot(&s));assert(s.ready_weapon==weapon);
        int before=s.ammo[2],max_missiles=0;
        int hold=full?85:weapon==5?12:!strcmp(scenario,"rust-blade-charge")?25:1;
        for(int tic=0;tic<hold+100;tic++) {
            cmd.buttons=tic<hold?1:0;check(ME_Tick(&cmd));
            ME_Thing things[256];size_t count=ME_CopyThings(things,256);assert(count<=256);
            int missiles=0;for(size_t i=0;i<count;i++)if(things[i].flags & 65536)missiles++;
            if(missiles>max_missiles)max_missiles=missiles;
        }
        check(ME_CopySnapshot(&s));assert(s.ammo[2]<before && s.ammo[2]>=0 && max_missiles>0);
        if(weapon==6)assert(s.ammo[2]==(full?20:hold==1?10:0));
        printf("PASS %s hold=%d ammo=%d->%d max_projectiles=%d health=%d\n",scenario,hold,before,s.ammo[2],max_missiles,s.health);
        return 0;
    }
    for (int i=0;i<35;i++) check(ME_Tick(&cmd));
    check(ME_CopySnapshot(&s));
    printf("PASS MAP%02u tic=%u actors=%zu types=%u states=%u health=%d ammo=%d/%d/%d/%d message=%s\n",
        c.map,s.tic,ME_CopyThings(NULL,0),s.thing_type_count,s.state_count,s.health,
        s.ammo[0],s.ammo[1],s.ammo[2],s.ammo[3],s.message);
    if (session.declared_feature==8 && session.wad_count==3) {
        assert(s.state_count==1543 && s.thing_type_count==203);
        assert(s.level_name[0]);
        if(c.map==2) assert(!strcmp(s.secret_map,"MAP15"));
        if(c.map==10) assert(!strcmp(s.secret_map,"MAP16"));
        if(c.map==13) assert(s.boss_action_count==1);
        if(c.map==14) {assert(s.boss_action_count==2);assert(!strcmp(s.end_finale,"XFINALE1"));}
        if(c.map==15) assert(!strcmp(s.next_map,"MAP03"));
        if(c.map==16) assert(!strcmp(s.next_map,"MAP11"));
    }
    return 0;
}
