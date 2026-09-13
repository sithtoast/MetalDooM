#include "ExtendedCore.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static unsigned word(const unsigned char *p){return p[0]|p[1]<<8|p[2]<<16|p[3]<<24;}
int main(int argc,char **argv){
 assert(argc==4 && ME_CopyUI(NULL,0)==0);
 const char *paths[]={argv[2],argv[3]};
 ME_Config config={.abi_version=ME_ABI_VERSION,.wad_paths=paths,.wad_count=2,.cache_directory=argv[1],.skill=3,.map=1,.random_seed=1993};
 assert(ME_Init(&config));size_t size=ME_CopyUI(NULL,0);assert(size==144);
 unsigned char data[160];memset(data,0xa5,sizeof(data));assert(ME_CopyUI(data,143)==144);
 for(int i=0;i<160;i++)assert(data[i]==0xa5);
 assert(ME_CopyUI(data,144)==144 && !memcmp(data,"MUI4",4));
 for(int i=144;i<160;i++)assert(data[i]==0xa5);
 assert(word(data+12)==100 && word(data+16)==0 && !memcmp(data+68,"D_UITEST",8));
 ME_Command cmd={.forward_move=25};for(int i=0;i<3;i++)assert(ME_Tick(&cmd));
 assert(ME_CopyUI(data,144)==144 && word(data+16)==100 && (word(data+28)&3)==3);
 ME_Snapshot state;assert(ME_CopySnapshot(&state) && word(data+12)==(unsigned)state.health);
 puts("PASS UI complete-copy canaries, initial music, live armor and two key pickups");
}
