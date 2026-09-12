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
static unsigned char *previous_geometry;
static size_t previous_size;
static int state(uint32_t seq,int force_geometry) {
    ME_View view;
    if(!ME_CopyView(&view))return 0;
    size_t size=ME_CopyGeometry(NULL,0);
    if(size<120 || size>160*1024*1024)return 0;
    unsigned char *geometry=malloc(size);if(!geometry)return 0;
    if(ME_CopyGeometry(geometry,size)!=size){free(geometry);return 0;}
    // Within a level, ignore tic/player fields; compare counts,
    // content identity and every geometry value exactly, without hash collisions.
    int changed=force_geometry || previous_size!=size || !previous_geometry ||
        memcmp(geometry+28,previous_geometry+28,size-28);
    free(previous_geometry);previous_geometry=geometry;previous_size=size;
    if(!changed)size=0;
    size_t presentation=ME_CopyPresentation(NULL,0),materials=ME_CopyMaterials(NULL,0),audio=ME_CopyAudio(NULL,0),ui=ME_CopyUI(NULL,0);
    if(!presentation || !materials || !audio || !ui || size+presentation+materials+audio+ui>160*1024*1024)return 0;
    unsigned char *body=calloc(1,56+size+presentation+materials+audio+ui);if(!body)return 0;
    memcpy(body,"MVW5",4);put(body+4,view.tic);put(body+8,view.x);put(body+12,view.y);
    put(body+16,view.eye_z);put(body+20,view.angle);put(body+24,view.health);
    memcpy(body+28,view.sky,8);put(body+36,(uint32_t)size);put(body+40,(uint32_t)presentation);put(body+44,(uint32_t)materials);put(body+48,(uint32_t)audio);put(body+52,(uint32_t)ui);
    if(size)memcpy(body+56,geometry,size);
    if(ME_CopyPresentation(body+56+size,presentation)!=presentation ||
       ME_CopyMaterials(body+56+size+presentation,materials)!=materials ||
       ME_CopyAudio(body+56+size+presentation+materials,audio)!=audio ||
       ME_CopyUI(body+56+size+presentation+materials+audio,ui)!=ui){free(body);return 0;}
    int result=send_frame(seq,0,body,56+size+presentation+materials+audio+ui);free(body);return result;
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
    if(!ME_EnableAudio())return fail(0,"Cannot enable sound capture");
    if(!ME_Init(&config)){char error[2048];ME_CopyError(error,sizeof(error));return fail(0,error);}
    if(!state(0,1)){char e[2048];ME_CopyError(e,sizeof(e));return fail(0,e[0]?e:"Cannot copy initial presentation");}
    uint32_t expected=1;
    for(;;) {
        unsigned char header[16],small[210],*payload=small;
        size_t got=fread(header,1,16,stdin);
        if(!got && feof(stdin))return 0;
        if(got!=16)return fail(expected,"Truncated request header");
        uint32_t seq=get(header+4),op=get(header+8),length=get(header+12);
        if(memcmp(header,"MEQ1",4) || seq!=expected || !expected || length>(op==7 ? 64u*1024*1024:sizeof(small)))
            return fail(expected,"Invalid request header, sequence or length");
        if(op==7 && length){payload=malloc(length);if(!payload)return fail(seq,"Restore allocation failed");}
        if(fread(payload,1,length,stdin)!=length)return fail(seq,"Truncated request body");
        if(op==3 && !length)return send_frame(seq,0,"",0)?0:1;
        if((op==5 || op==6 || op==8) && !length) {
            size_t (*copy)(void *,size_t)=op==5 ? ME_CopyCampaign:op==6 ? ME_CopySave:ME_CopyBlendTables;
            size_t size=copy(NULL,0);
            if(!size || size>(op==8 ? 4456472:op==5 ? 1024*1024:64*1024*1024)){char e[2048];ME_CopyError(e,sizeof(e));return fail(seq,e[0]?e:"Snapshot unavailable at this lifecycle phase");}
            void *body=malloc(size);if(!body)return fail(seq,"Snapshot allocation failed");
            if(copy(body,size)!=size){free(body);return fail(seq,"Cannot copy snapshot");}
            int sent=send_frame(seq,0,body,size);free(body);if(!sent)return 1;
            expected++;continue;
        }
        if(op==1 && length && length%6==0) {
            for(uint32_t i=0;i<length;i+=6) {
                if(payload[i+5])return fail(seq,"Nonzero reserved command byte");
                ME_Command c={.forward_move=(int8_t)payload[i],.side_move=(int8_t)payload[i+1],
                    .angle_turn=(int16_t)((uint16_t)payload[i+2]|(uint16_t)payload[i+3]<<8),.buttons=payload[i+4]};
                if(!ME_Tick(&c)){char error[2048];ME_CopyError(error,sizeof(error));return fail(seq,error);}
                ME_Snapshot snapshot;if(!ME_CopySnapshot(&snapshot))return fail(seq,"Cannot copy lifecycle state");
                if(snapshot.health<=0 || snapshot.pending_exit)break;
            }
        } else if(op==7 && length) {
            if(!ME_RestoreSave(payload,length)){char error[2048];ME_CopyError(error,sizeof(error));return fail(seq,error);}
            free(payload);
        } else if(op==4 && length==4) {
            if(!ME_Advance(get(payload))){char error[2048];ME_CopyError(error,sizeof(error));return fail(seq,error);}
        } else if(op!=2 || length) return fail(seq,"Invalid request operation/body");
        if(!state(seq,op==2 || op==4 || op==7)){char e[2048];ME_CopyError(e,sizeof(e));return fail(seq,e[0]?e:"Cannot copy presentation");}
        expected++;
    }
}
