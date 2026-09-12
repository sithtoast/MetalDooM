#include "ExtendedCore.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static unsigned word(const unsigned char *p){return p[0]|(unsigned)p[1]<<8|(unsigned)p[2]<<16|(unsigned)p[3]<<24;}
int main(int argc,char **argv) {
    assert(argc==5 && ME_CopyAudio(NULL,0)==0 && ME_EnableAudio());
    const char *paths[]={argv[2],argv[3]};ME_Config c={.abi_version=ME_ABI_VERSION,.wad_paths=paths,.wad_count=2,.cache_directory=argv[1],.skill=3,.map=1,.random_seed=1993};
    assert(ME_Init(&c) && !ME_EnableAudio());ME_Command tick={0};
    if(!strcmp(argv[4],"overflow")) {
        int failed=0;for(int i=0;i<5000;i++)if(!ME_Tick(&tick)){failed=1;break;}
        char error[256];ME_CopyError(error,sizeof(error));assert(failed && strstr(error,"queue overflow"));
        puts("PASS audio queue overflow reports a bounded engine error");return 0;
    }
    for(int i=0;i<35;i++)assert(ME_Tick(&tick));
    size_t size=ME_CopyAudio(NULL,0);assert(size>16 && size==ME_CopyAudio(NULL,0));
    unsigned char *data=malloc(size+16);memset(data,0xa5,size+16);
    assert(ME_CopyAudio(data,size-1)==size);for(size_t i=0;i<size+16;i++)assert(data[i]==0xa5);
    assert(ME_CopyAudio(data,size)==size && !memcmp(data,"MSA1",4));
    for(size_t i=size;i<size+16;i++)assert(data[i]==0xa5);
    assert(word(data+12)>0 && ME_CopyAudio(NULL,0)==16);
    puts("PASS audio size/undersized queries preserve FIFO, complete copy drains, canaries intact");free(data);
}
