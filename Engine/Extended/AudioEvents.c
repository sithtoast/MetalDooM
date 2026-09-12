// SPDX-License-Identifier: GPL-2.0-or-later
// Bounded native preview adapter, using the upstream sound identities/origins.
#include "ExtendedCore.h"
#include "NativeInternal.h"
#include "doomstat.h"
#include "p_mobj.h"
#include "sounds.h"
#include "s_sound.h"
#include "r_main.h"
#include "w_wad.h"
#include "z_zone.h"
#include "i_system.h"
#include <math.h>
#include <stdio.h>
#include <string.h>
#define CHANNELS 32
#define EVENTS 4096
static int enabled;
typedef struct { uint32_t tic,channel,operation;char name[8];int volume,pan; } event_t;
static event_t events[EVENTS];static size_t count;
typedef struct { const mobj_t *origin;fixed_t x,y;int active,positioned,singularity,priority,volume,pan;uint64_t until; } channel_t;
static channel_t channels[CHANNELS];
void ME_AudioEnable(void) { enabled=1; }
static void event(int channel,int operation,const char *name,int volume,int pan) {
    if(count==EVENTS)I_Error("Preview sound queue overflow");
    event_t *e=&events[count++];memset(e,0,sizeof(*e));e->tic=leveltime;e->channel=channel;e->operation=operation;
    if(name)memcpy(e->name,name,8);e->volume=volume;e->pan=pan;
}
static int params(channel_t *c,int *volume,int *pan) {
    *volume=127;*pan=0;const mobj_t *listener=players[0].mo;
    if(!c->positioned || !listener || c->origin==listener)return 1;
    if(c->origin){c->x=c->origin->x;c->y=c->origin->y;}
    // Match MBF's 200/1200-unit attenuation range; fixed normal pitch, no RNG.
    double dx=((double)c->x-listener->x)/FRACUNIT,dy=((double)c->y-listener->y)/FRACUNIT;
    double distance=hypot(dx,dy);if(distance>=1200)return 0;
    if(distance>200)*volume=(int)(127*(1200-distance)/1000);
    if(distance>0) {
        angle_t angle=R_PointToAngle2(listener->x,listener->y,c->x,c->y)-listener->angle;
        *pan=-(int)(((int64_t)96*finesine[angle>>ANGLETOFINESHIFT])/FRACUNIT);
    }
    return *volume>0;
}
static void stop(int i) { if(channels[i].active){event(i,0,NULL,0,0);channels[i].active=0;} }
void ME_AudioTick(void) {
    if(!enabled)return;
    for(int i=0;i<CHANNELS;i++)if(channels[i].active) {
        channel_t *c=&channels[i];
        if((uint64_t)leveltime>=c->until){c->active=0;continue;}
        int volume,pan;if(!params(c,&volume,&pan)){stop(i);continue;}
        if(volume!=c->volume || pan!=c->pan){c->volume=volume;c->pan=pan;event(i,2,NULL,volume,pan);}
    }
}
static unsigned read16(const byte *p){return p[0]|(unsigned)p[1]<<8;}
static uint32_t read32(const byte *p){return p[0]|(uint32_t)p[1]<<8|(uint32_t)p[2]<<16|(uint32_t)p[3]<<24;}
static void start(const mobj_t *origin,int id) {
    ME_RecordSound();if(!enabled || !id)return;
    if(id<0 || id>=num_sfx)I_Error("Invalid preview sound id");
    sfxinfo_t *sfx=&S_sfx[id];channel_t next={.origin=origin,.positioned=origin!=NULL,.singularity=sfx->singularity,.priority=sfx->priority};
    if(origin){next.x=origin->x;next.y=origin->y;}
    if(!params(&next,&next.volume,&next.pan))return;
    for(int links=0;sfx->link;links++){if(links>=num_sfx)I_Error("Cyclic sound link");sfx=sfx->link;}
    if(!sfx->name || (sfx->flags & (SFX_Random|SFX_Ambient)) || sfx->looping)I_Error("Unsupported preview sound definition");
    char name[9]={0};snprintf(name,sizeof(name),(sfx->flags&SFX_NoPrefix)?"%.8s":"DS%.6s",sfx->name);
    int lump=W_CheckNumForName(name);if(lump<0)I_Error("Missing preview sound: %s",name);
    size_t length=W_LumpLength(lump);const byte *bytes=W_CacheLumpNum(lump,PU_CACHE);
    if(length<8 || read16(bytes)!=3 || !read16(bytes+2) || read32(bytes+4)<=48 || read32(bytes+4)>length-8)I_Error("Unsupported or invalid DMX sound: %s",name);
    uint64_t duration=((uint64_t)(read32(bytes+4)-32)*35+read16(bytes+2)-1)/read16(bytes+2);
    next.until=(uint64_t)leveltime+duration;next.active=1;
    int slot=-1;
    for(int i=0;i<CHANNELS;i++)if(channels[i].active && channels[i].origin==origin && channels[i].positioned==next.positioned && channels[i].singularity==next.singularity){slot=i;break;}
    if(slot<0)for(int i=0;i<CHANNELS;i++)if(!channels[i].active || (uint64_t)leveltime>=channels[i].until){slot=i;break;}
    if(slot<0){slot=0;for(int i=1;i<CHANNELS;i++)if(channels[i].priority>channels[slot].priority)slot=i;if(next.priority>channels[slot].priority)return;}
    channels[slot]=next;event(slot,1,lumpinfo[lump].name,next.volume,next.pan);
}
void S_Start(void){count=0;memset(channels,0,sizeof(channels));}
void S_StopSound(const mobj_t *origin){if(enabled)for(int i=0;i<CHANNELS;i++)if(channels[i].active && channels[i].origin==origin){stop(i);break;}}
void S_UnlinkSound(mobj_t *origin){if(enabled && origin)for(int i=0;i<CHANNELS;i++)if(channels[i].active && channels[i].origin==origin){channels[i].x=origin->x;channels[i].y=origin->y;channels[i].origin=NULL;}}
void S_StartSoundPitch(const mobj_t *origin,int id,pitchrange_t range){start(origin,id);}
void S_StartSoundPitchEx(const mobj_t *origin,int id,pitchrange_t range){start(origin,id);}
void S_StartSoundPreset(const mobj_t *origin,int id,pitchrange_t range){start(origin,id);}
#define SOUND2(name) void name(const mobj_t *origin,int id){start(origin,id);}
SOUND2(S_StartSoundBFG) SOUND2(S_StartSoundCGun) SOUND2(S_StartSoundHitFloor) SOUND2(S_StartSoundPain) SOUND2(S_StartSoundPistol) SOUND2(S_StartSoundSSG) SOUND2(S_StartSoundShotgun)
#define SOUND3(name) void name(const mobj_t *source,const mobj_t *origin,int id){start(origin,id);}
SOUND3(S_StartSoundMissile) SOUND3(S_StartSoundOrigin) SOUND3(S_StartSoundSource)
static void word(unsigned char **p,uint32_t v){for(int i=0;i<4;i++)*(*p)++=(unsigned char)(v>>(8*i));}
size_t ME_WriteAudio(void *out,size_t capacity) {
    if(!enabled)return 0;
    size_t size=16+count*28;if(!out || capacity<size)return size;
    unsigned char *p=out;memcpy(p,"MSA1",4);p+=4;word(&p,1);word(&p,leveltime);word(&p,(uint32_t)count);
    for(size_t i=0;i<count;i++){event_t *e=&events[i];word(&p,e->tic);word(&p,e->channel);word(&p,e->operation);memcpy(p,e->name,8);p+=8;word(&p,e->volume);word(&p,e->pan);}
    count=0;return size;
}
