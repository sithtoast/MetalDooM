// SPDX-License-Identifier: GPL-2.0-or-later
#include "ExtendedCore.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static void check(int ok) {
    if (ok) return; char e[2048]; ME_CopyError(e,sizeof(e)); fprintf(stderr,"FAIL %s\n",e); exit(1);
}
static ME_Thing actor(void) {
    ME_Thing all[64]; size_t count=ME_CopyThings(all,64); assert(count<=64);
    for(size_t i=0;i<count;i++) if(all[i].editor_number==9500) return all[i];
    assert(0); return (ME_Thing){0};
}
int main(int argc,char **argv) {
    assert(argc>=5); const char *mode=argv[1]; int respawn=strstr(mode,"respawn")!=NULL;
    ME_Config c={.abi_version=ME_ABI_VERSION,.wad_paths=(const char *const *)argv+3,.wad_count=(uint32_t)(argc-3),
        .cache_directory=argv[2],.map=1,.skill=respawn?5:3,.random_seed=1993,.profile=ME_PROFILE_RUST_PROBE};
    check(ME_Init(&c)); ME_Command cmd={0}; ME_Snapshot before,after;
    check(ME_CopySnapshot(&before));
    if(respawn) {
        int wait=!strcmp(mode,"respawn-fast")?64:!strcmp(mode,"respawn-slow")?2100:420;
        ME_Thing initial=actor(); assert(initial.min_respawn_tics==wait);
        assert(initial.respawn_dice==(!strcmp(mode,"respawn-default")?4:!strcmp(mode,"respawn-slow")?64:255));
        int death=-1,reborn=-1;
        for(int tic=1;tic<wait+20000;tic++) {
            check(ME_Tick(&cmd)); ME_Thing a=actor();
            if(death<0 && a.health<=0) death=tic;
            if(death>=0 && a.health>0) {reborn=tic;break;}
        }
        assert(death>0 && reborn>=death+wait);
        printf("PASS %s death=%d reborn=%d minimum=%d dice=%d\n",mode,death,reborn,wait,initial.respawn_dice);
    } else {
        cmd.forward_move=25;
        for(int i=0;i<3;i++)check(ME_Tick(&cmd));
        check(ME_CopySnapshot(&after)); assert(after.ammo[2]==before.ammo[2]+20);
        assert(!strcmp(after.message,!strcmp(mode,"pickup-bex")?"Custom fuel pickup.":"Picked up a fuel can."));
        printf("PASS %s cells=%d->%d message=%s\n",mode,before.ammo[2],after.ammo[2],after.message);
    }
    return 0;
}
