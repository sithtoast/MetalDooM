// Actual bundled boss deaths, linked only into this test from worker objects.
// No test hooks or new exports are added to the production worker.
#include "ExtendedCore.h"
#include "doomstat.h"
#include "g_umapinfo.h"
#include "m_array.h"
#include "p_mobj.h"
#include "p_inter.h"
#include "p_tick.h"
#include "r_state.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
static void check(int ok) {
    if(ok)return;char error[2048];ME_CopyError(error,sizeof(error));fprintf(stderr,"FAIL %s\n",error);exit(1);
}
int main(int argc,char **argv) {
    assert(argc==7);
    ME_Config config={.abi_version=ME_ABI_VERSION,.wad_paths=(const char *const *)argv+4,.wad_count=3,
        .cache_directory=argv[1],.map=(uint32_t)atoi(argv[2]),.skill=3,.base_wad_index=1,.profile=1,.random_seed=1993};
    check(ME_Init(&config));players[0].cheats|=CF_GODMODE;
    int action=atoi(argv[3]);assert(gamemapinfo && action<(int)array_size(gamemapinfo->bossactions));
    bossaction_t boss=gamemapinfo->bossactions[action];
    mobj_t **actors=NULL;fixed_t *before=calloc(numsectors,sizeof(*before));int sectors_found=0;
    for(int i=0;i<numsectors;i++)if(sectors[i].tag==boss.tag){before[i]=sectors[i].floorheight;sectors_found++;}
    assert(sectors_found>0);
    for(thinker_t *t=thinkercap.next;t!=&thinkercap;t=t->next)if(t->function.p1==P_MobjThinker) {
        mobj_t *m=(mobj_t *)t;if(m->type==boss.type && m->health>0)array_push(actors,m);
    }
    int count=(int)array_size(actors);assert(count>0);ME_Command command={0};
    for(int i=0;i<count-1;i++){P_DamageMobj(actors[i],NULL,players[0].mo,actors[i]->health);assert(actors[i]->health<=0);}
    for(int i=0;i<140;i++)check(ME_Tick(&command));
    assert(actors[count-1]->health>0);
    for(int i=0;i<numsectors;i++)if(sectors[i].tag==boss.tag)assert(sectors[i].floorheight==before[i]);
    P_DamageMobj(actors[count-1],NULL,players[0].mo,actors[count-1]->health);assert(actors[count-1]->health<=0);
    for(int i=0;i<350;i++)check(ME_Tick(&command));
    int lowered=0;for(int i=0;i<numsectors;i++)if(sectors[i].tag==boss.tag && sectors[i].floorheight<before[i])lowered++;
    assert(lowered>0);
    printf("PASS actual MAP%02u boss type%d, %d deaths through native states, tag%d: last-boss guard and %d/%d lowered sectors\n",config.map,boss.type,count,boss.tag,lowered,sectors_found);
    free(before);array_free(actors);return 0;
}
