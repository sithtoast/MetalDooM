#include "ExtendedCore.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main(int argc,char **argv) {
    assert(argc==6);if(atoi(argv[4]))assert(ME_EnableAudio());
    const char *paths[]={argv[2],argv[3]};ME_Config c={.abi_version=ME_ABI_VERSION,.wad_paths=paths,.wad_count=2,.cache_directory=argv[1],.skill=3,.map=1,.random_seed=1993};assert(ME_Init(&c));
    FILE *out=fopen(argv[5],"wb");assert(out);
    for(int i=0;i<200;i++) {
        ME_Command cmd={.buttons=i>35?1:0,.angle_turn=i%13==0?512:0};assert(ME_Tick(&cmd));
        ME_Snapshot snapshot;assert(ME_CopySnapshot(&snapshot));assert(fwrite(&snapshot,1,sizeof(snapshot),out)==sizeof(snapshot));
        size_t count=ME_CopyThings(NULL,0);ME_Thing *things=calloc(count?count:1,sizeof(*things));assert(things);assert(ME_CopyThings(things,count)==count);
        assert(fwrite(things,sizeof(*things),count,out)==count);free(things);
        if(atoi(argv[4])){size_t size=ME_CopyAudio(NULL,0);void *bytes=malloc(size);assert(bytes && ME_CopyAudio(bytes,size)==size);free(bytes);}
    }
    assert(!fclose(out));puts("PASS captured simulation state for audio on/off comparison");
}
