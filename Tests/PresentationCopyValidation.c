#include "ExtendedCore.h"
#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
int main(int argc,char **argv) {
    assert(argc==3 && ME_CopyPresentation(NULL,0)==0);
    const char *paths[]={argv[2]};
    ME_Config c={.abi_version=ME_ABI_VERSION,.wad_paths=paths,.wad_count=1,.cache_directory=argv[1],.skill=3,.map=1,.random_seed=1993};
    assert(ME_Init(&c));
    size_t size=ME_CopyPresentation(NULL,0);assert(size>32);
    unsigned char *data=malloc(size+16),*copy=malloc(size);assert(data && copy);
    memset(data,0xa5,size+16);assert(ME_CopyPresentation(data,size-1)==size);
    for(size_t i=0;i<size+16;i++)assert(data[i]==0xa5);
    assert(ME_CopyPresentation(data,size)==size && ME_CopyPresentation(copy,size)==size);
    assert(!memcmp(data,copy,size));for(size_t i=size;i<size+16;i++)assert(data[i]==0xa5);
    free(data);free(copy);puts("PASS sprite snapshot complete-copy bounds, stable values and canaries");
}
