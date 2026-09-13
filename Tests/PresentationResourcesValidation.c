// Independent access to real worker state; production ABI remains unchanged.
#include "ExtendedCore.h"
#include "NativeInternal.h"
#include "doomstat.h"
#include "r_sky.h"
#include "r_data.h"
#include "r_state.h"
#include "r_main.h"
#include "r_bmaps.h"
#include "m_array.h"
#include "m_random.h"
#include "p_mobj.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static unsigned word(const unsigned char *p){return p[0]|p[1]<<8|p[2]<<16|(unsigned)p[3]<<24;}
static void check(int ok){if(ok)return;char e[2048];ME_CopyError(e,sizeof(e));fprintf(stderr,"FAIL %s\n",e);exit(1);}
static unsigned char *copy(size_t (*fn)(void*,size_t),size_t *size){*size=fn(NULL,0);assert(*size>0);unsigned char *p=malloc(*size);assert(fn(p,*size)==*size);return p;}
int main(int argc,char **argv) {
 assert(argc==4);const char *paths[]={argv[2],argv[3]};
 ME_Config c={.abi_version=ME_ABI_VERSION,.wad_paths=paths,.wad_count=2,.cache_directory=argv[1],.skill=3,.map=1,.random_seed=1993};check(ME_Init(&c));
 assert(numcolormaps==2);assert(ME_BrightMask(R_BrightmapForTexName("STARTAN3"))>0);assert(ME_BrightMask(R_BrightmapForFlatNum(R_FlatNumForName("FLOOR0_1")))>0);
 size_t n;unsigned char *packet=copy(ME_CopyMaterials,&n);assert(!memcmp(packet,"MMT2",4));unsigned char *sky=packet+20+word(packet+12)*20;assert(word(sky)==levelskies[0].type);
 if(levelskies[0].type==SkyType_Fire) {
  int tex=levelskies[0].background.texture,w=texturewidth[tex],h=textureheight[tex]>>16;assert(word(sky+60)==w && word(sky+64)==h);
  for(int x=0;x<w;x++)for(int y=0;y<h;y++)assert(sky[68+y*w+x]==R_GetColumn(tex,x)[y]);
 }
 rng_t before=rng;size_t n2;unsigned char *again=copy(ME_CopyMaterials,&n2);assert(n==n2 && !memcmp(packet,again,n) && !memcmp(&rng,&before,sizeof(rng)));free(again);
 ME_Command cmd={0};for(int i=0;i<7;i++)check(ME_Tick(&cmd));again=copy(ME_CopyMaterials,&n2);assert(n==n2 && memcmp(packet+16,again+16,n-16));free(again);free(packet);
 sectors[0].colormap=1;assert(ME_RenderTint(-1)==1);assert(ME_RenderTint(0)==0);assert(ME_ThingTint(players[0].mo)==1);
 sectors[0].tint=1;sectors[0].tintfloor=0;sectors[0].tintceiling=1;sides[0].tint=0;
 packet=copy(ME_CopyGeometry,&n);assert(!memcmp(packet,"MGE6",4));unsigned offset=120+word(packet+28)*8+word(packet+32)*24;
 assert(word(packet+offset+36)==0);offset+=word(packet+36)*40;assert(word(packet+offset+140)==1 && word(packet+offset+144)==0 && word(packet+offset+148)==1);free(packet);
 players[0].mo->tint=0;assert(ME_ThingTint(players[0].mo)==0);
 packet=copy(ME_CopyBlendTables,&n);assert(!memcmp(packet,"MBL4",4));offset=24+word(packet+8)+word(packet+16)+word(packet+12)*65536;
 assert(word(packet+offset)==1 && word(packet+offset+4)>1 && word(packet+offset+8)>=2);
 for(int i=0;i<8704;i++)assert(packet[offset+12+i]==(unsigned char)(i+17));free(packet);
 puts("PASS authoritative sky columns/scrolling, read-only RNG, authored texture/flat/sprite brightmaps, tint precedence and copied banks");
}
