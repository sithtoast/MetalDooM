// SPDX-License-Identifier: GPL-2.0-or-later
// One session per child. Protocol stdout is isolated from engine diagnostics.
#include "ExtendedCore.h"
#include <errno.h>
#include <limits.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
static FILE *output;
static uint32_t get(const unsigned char *p) {
    return (uint32_t)p[0]|(uint32_t)p[1]<<8|(uint32_t)p[2]<<16|(uint32_t)p[3]<<24;
}
static void put(unsigned char *p,uint32_t v) { for(int i=0;i<4;i++)p[i]=(unsigned char)(v>>(8*i)); }
static int send_frame(uint32_t seq,uint32_t error,const void *body,size_t length) {
    unsigned char h[16]; memcpy(h,"MER1",4);put(h+4,seq);put(h+8,error);put(h+12,(uint32_t)length);
    return fwrite(h,1,16,output)==16 && fwrite(body,1,length,output)==length && fflush(output)==0;
}
static int fail(uint32_t seq,const char *text) { send_frame(seq,1,text,strlen(text));return 1; }
static int state(uint32_t seq,int geometry) {
    ME_View view;
    if(!ME_CopyView(&view))return 0;
    size_t size=geometry?ME_CopyGeometry(NULL,0):0;
    if((geometry && !size) || size>160*1024*1024)return 0;
    unsigned char *body=calloc(1,44+size); if(!body)return 0;
    memcpy(body,"MVW1",4);put(body+4,view.tic);put(body+8,view.x);put(body+12,view.y);
    put(body+16,view.eye_z);put(body+20,view.angle);put(body+24,view.health);
    memcpy(body+28,view.sky,8);put(body+36,(uint32_t)size); // 40..43 reserved zero
    if(geometry && ME_CopyGeometry(body+44,size)!=size){free(body);return 0;}
    int result=send_frame(seq,0,body,44+size);free(body);return result;
}
static unsigned number(const char *s) {
    char *end;errno=0;unsigned long v=strtoul(s,&end,10);
    if(errno || !*s || *end || *s=='-' || v>UINT_MAX)exit(2);
    return (unsigned)v;
}
int main(int argc,char **argv) {
    if(argc<7)return 2; // cache, map, base index, profile, skill, ordered files
    signal(SIGPIPE,SIG_IGN);
    int protocol=dup(STDOUT_FILENO);
    if(protocol<0 || dup2(STDERR_FILENO,STDOUT_FILENO)<0)return 2;
    output=fdopen(protocol,"wb");if(!output)return 2;
    ME_Config config={.abi_version=ME_ABI_VERSION,.cache_directory=argv[1],.map=number(argv[2]),
        .base_wad_index=number(argv[3]),.profile=number(argv[4]),.skill=number(argv[5]),
        .random_seed=1993,.wad_count=(uint32_t)(argc-6),.wad_paths=(const char *const *)argv+6};
    if(!ME_Init(&config)){char error[2048];ME_CopyError(error,sizeof(error));return fail(0,error);}
    if(!state(0,1))return 1;
    uint32_t expected=1;
    for(;;) {
        unsigned char header[16],payload[210];
        size_t got=fread(header,1,16,stdin);
        if(!got && feof(stdin))return 0;
        if(got!=16)return fail(expected,"Truncated request header");
        uint32_t seq=get(header+4),op=get(header+8),length=get(header+12);
        if(memcmp(header,"MEQ1",4) || seq!=expected || !expected || length>sizeof(payload))
            return fail(expected,"Invalid request header, sequence or length");
        if(fread(payload,1,length,stdin)!=length)return fail(seq,"Truncated request body");
        if(op==3 && !length)return send_frame(seq,0,"",0)?0:1;
        if(op==1 && length && length%6==0) {
            for(uint32_t i=0;i<length;i+=6) {
                if(payload[i+5])return fail(seq,"Nonzero reserved command byte");
                ME_Command c={.forward_move=(int8_t)payload[i],.side_move=(int8_t)payload[i+1],
                    .angle_turn=(int16_t)((uint16_t)payload[i+2]|(uint16_t)payload[i+3]<<8),.buttons=payload[i+4]};
                if(!ME_Tick(&c)){char error[2048];ME_CopyError(error,sizeof(error));return fail(seq,error);}
            }
        } else if(op!=2 || length) return fail(seq,"Invalid request operation/body");
        if(!state(seq,op==2))return 1;
        expected++;
    }
}
