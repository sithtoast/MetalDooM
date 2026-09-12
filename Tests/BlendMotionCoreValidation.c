// SPDX-License-Identifier: GPL-2.0-or-later
// Private-core integration probe: exercise object tables unreachable in binary
// THINGS, without adding debug operations or mutation APIs to the shipped worker.
#include "ExtendedCore.h"
#include "NativeInternal.h"
#include "doomstat.h"
#include "p_tick.h"
#include "p_mobj.h"
#include "r_tranmap.h"
#include "w_wad.h"
#include "z_zone.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static unsigned word(const unsigned char *p){return p[0]|p[1]<<8|p[2]<<16|(unsigned)p[3]<<24;}
static void check(int ok){if(!ok){char e[2048];ME_CopyError(e,sizeof(e));fprintf(stderr,"FAIL %s\n",e);exit(1);}}
static unsigned char *snapshot(size_t *n){*n=ME_CopyPresentation(NULL,0);assert(*n);unsigned char *p=malloc(*n);check(ME_CopyPresentation(p,*n)==*n);return p;}
static mobj_t *actor(void){for(thinker_t *t=thinkercap.next;t!=&thinkercap;t=t->next)if(t->function.p1==P_MobjThinker && ((mobj_t *)t)->info->doomednum==9500)return (mobj_t *)t;abort();}
static void file(const char *path,void *bytes,size_t n,int writing){FILE *f=fopen(path,writing?"wb":"rb");assert(f);if(writing)assert(fwrite(bytes,1,n,f)==n);else {unsigned char *b=malloc(n);assert(fread(b,1,n,f)==n && fgetc(f)==EOF && !memcmp(b,bytes,n));free(b);}fclose(f);}
int main(int argc,char **argv){
    assert(argc==6);int writing=!strcmp(argv[1],"write");
    const char *paths[]={argv[3],argv[4]};
    ME_Config c={.abi_version=ME_ABI_VERSION,.wad_paths=paths,.wad_count=2,.cache_directory=argv[2],.skill=3,.map=1,.random_seed=1993};check(ME_Init(&c));
    mobj_t *m=actor();m->state->tranmap=NULL;
    unsigned char *custom=W_CacheLumpName("OBJECT_B",PU_STATIC);
    if(writing){
        m->tranmap=custom;m->spawnpoint.tranmap=GetNormalTranMap(33);
        players[0].mo->tranmap=custom;
        ME_LevelBlendTables();
        assert(ME_SaveBlend(custom)>=3 && ME_SaveBlend(m->spawnpoint.tranmap)==-34);
        assert(ME_RestoreBlend(ME_SaveBlend(custom))==custom);
        size_t n;unsigned char *p=snapshot(&n);assert(!memcmp(p,"MSP5",4));
        unsigned actors=word(p+12),flags=word(p+32+28),weapon=word(p+32+actors*56+20);
        assert((flags>>8)==ME_BlendTableIndex(custom) && (weapon>>8)==ME_BlendTableIndex(custom));free(p);
        state_t *state=players[0].psprites[0].state;
        state->tranmap=(unsigned char *)main_addimap;p=snapshot(&n);assert((word(p+32+actors*56+20)&24)==24);free(p);state->tranmap=NULL;
        players[0].powers[pw_invisibility]=129;p=snapshot(&n);assert(word(p+32+actors*56+20)==4);free(p);players[0].powers[pw_invisibility]=0;
        ME_Command tick={0};check(ME_Tick(&tick));
        p=snapshot(&n);assert(word(p+32+28)&32);assert((int)word(p+32+40)==m->x);free(p);
        // Simulate a newly spawned actor with no endpoint capture this tic.
        m->native_previous_tic=0;p=snapshot(&n);assert(!(word(p+32+28)&32));free(p);
        size_t bytes=ME_CopySave(NULL,0);assert(bytes);void *save=malloc(bytes);check(ME_CopySave(save,bytes)==bytes);file(argv[5],save,bytes,1);free(save);
    }else{
        FILE *f=fopen(argv[5],"rb");assert(f);fseek(f,0,SEEK_END);long bytes=ftell(f);rewind(f);void *save=malloc(bytes);assert(fread(save,1,bytes,f)==bytes);fclose(f);int restored=ME_RestoreSave(save,bytes);free(save);
        if(!strcmp(argv[1],"reject")){check(!restored);puts("PASS malformed object blend or endpoint rejected before restore");return 0;}
        check(restored);
        m=actor();assert(m->tranmap==custom && ME_SaveBlend(m->spawnpoint.tranmap)==-34 && players[0].mo->tranmap==custom);
    }
    ME_Command tick={0};for(int i=0;i<35;i++)check(ME_Tick(&tick));
    size_t n;unsigned char *p=snapshot(&n);char output[4096];snprintf(output,sizeof(output),"%s.future",argv[5]);file(output,p,n,writing);free(p);
    puts(writing?"PASS object/weapon precedence, fuzz, generated alpha, spawn endpoint suppression and save":"PASS fresh-worker object/respawn/weapon tables and exact 35-tic future presentation");
}
