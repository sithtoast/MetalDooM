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
    if (argc < 7) return 2;
    ME_Config c={.abi_version=ME_ABI_VERSION,.cache_directory=argv[1],.map=(uint32_t)atoi(argv[2]),
        .base_wad_index=(uint32_t)atoi(argv[3]),.profile=(uint32_t)atoi(argv[4]),
        .skill=3,.random_seed=1993,.wad_count=(uint32_t)(argc-6),.wad_paths=(const char *const *)argv+6};
    assert(ME_CopyGeometry(NULL,0)==0);
    check(ME_Init(&c));
    size_t size=ME_CopyGeometry(NULL,0); check(size>=120);
    unsigned char *data=malloc(size+16),*second=malloc(size); assert(data && second);
    memset(data,0xa5,size+16);
    assert(ME_CopyGeometry(data,size-1)==size);
    for(size_t i=0;i<size+16;i++)assert(data[i]==0xa5);
    check(ME_CopyGeometry(data,size)==size);
    assert(ME_CopyGeometry(second,size)==size && !memcmp(data,second,size));
    for(size_t i=size;i<size+16;i++)assert(data[i]==0xa5);
    FILE *file=fopen(argv[5],"wb"); assert(file);
    assert(fwrite(data,1,size,file)==size); assert(fclose(file)==0);
    printf("PASS MAP%02u geometry %zu bytes; complete bounded copies and stable repeated snapshot\n",c.map,size);
    free(data); free(second);
    return 0;
}
