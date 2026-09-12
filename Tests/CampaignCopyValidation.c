#include "ExtendedCore.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main(int argc,char **argv) {
    assert(argc==6 && ME_CopyCampaign(NULL,0)==0);
    const char *paths[]={argv[2],argv[3],argv[4],argv[5]};
    ME_Config config={.abi_version=ME_ABI_VERSION,.wad_paths=paths,.wad_count=4,.base_wad_index=1,.profile=1,.cache_directory=argv[1],.skill=3,.map=14,.random_seed=1993};
    assert(ME_EnableAudio() && ME_Init(&config));assert(ME_CopyCampaign(NULL,0)==0);
    ME_Command command={0};for(int i=0;i<3;i++)assert(ME_Tick(&command));
    command.buttons=2;assert(ME_Tick(&command));
    ME_Snapshot before,after;assert(ME_CopySnapshot(&before) && before.pending_exit);
    size_t audio=ME_CopyAudio(NULL,0),size=ME_CopyCampaign(NULL,0);assert(size && size<=1024*1024);
    unsigned char *data=malloc(size+16),*copy=malloc(size);memset(data,0xa5,size+16);
    assert(ME_CopyCampaign(data,size-1)==size);for(size_t i=0;i<size+16;i++)assert(data[i]==0xa5);
    assert(ME_CopyCampaign(data,size)==size && ME_CopyCampaign(copy,size)==size && !memcmp(data,copy,size));
    for(size_t i=size;i<size+16;i++)assert(data[i]==0xa5);
    assert(ME_CopySnapshot(&after) && !memcmp(&before,&after,sizeof(before)) && ME_CopyAudio(NULL,0)==audio);
    free(copy);free(data);puts("PASS campaign copy bounds, repeatability, canaries, unchanged simulation snapshot/RNG and undrained sound FIFO");
}
