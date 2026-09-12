#include "ExtendedCore.h"
#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
int main(int argc,char **argv) {
    assert(argc==5 && ME_CopySave(NULL,0)==0);
    const char *paths[]={argv[2],argv[3],argv[4]};
    ME_Config config={.abi_version=ME_ABI_VERSION,.cache_directory=argv[1],.wad_paths=paths,.wad_count=3,.base_wad_index=1,.profile=1,.skill=3,.map=1,.random_seed=1993};
    assert(ME_EnableAudio() && ME_Init(&config));ME_Command command={.buttons=1};
    for(int i=0;i<35;i++)assert(ME_Tick(&command));
    ME_Snapshot before,after;assert(ME_CopySnapshot(&before));size_t audio=ME_CopyAudio(NULL,0),size=ME_CopySave(NULL,0);
    assert(size>0 && size<=64*1024*1024);unsigned char *first=malloc(size+16),*second=malloc(size);memset(first,0xa5,size+16);
    assert(ME_CopySave(first,size-1)==size);for(size_t i=0;i<size+16;i++)assert(first[i]==0xa5);
    assert(ME_CopySave(first,size)==size && ME_CopySave(second,size)==size && !memcmp(first,second,size));
    for(size_t i=size;i<size+16;i++)assert(first[i]==0xa5);
    assert(ME_CopySnapshot(&after) && !memcmp(&before,&after,sizeof(before)) && ME_CopyAudio(NULL,0)==audio);
    free(first);free(second);puts("PASS native save size/short-buffer/full-copy canaries, deterministic copies, unchanged RNG/snapshot and undrained audio");
}
