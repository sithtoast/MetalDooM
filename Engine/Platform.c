// SPDX-License-Identifier: GPL-2.0-or-later
// Explicit host services for the movement/doors milestone. No SDL or software video.
#include <stdlib.h>
#include <string.h>
#include "doomstat.h"
#include "i_system.h"
#include "s_sound.h"
#include "m_argv.h"
#include "Bridge.h"
#include "sounds.h"
#include "w_wad.h"
#include <math.h>
#include <stdio.h>

boolean nomonsters, respawnparm, fastparm, devparm;
boolean menuactive, automapactive;
gamestate_t wipegamestate = GS_DEMOSCREEN;
int gametic, ticdup = 1;
int myargc;
char **myargv;
int M_CheckParmWithArgs(const char *check, int count) {
    for (int i=1; i<myargc-count; ++i) if (!strcasecmp(myargv[i],check)) return i;
    return 0;
}
int M_CheckParm(const char *check) { return M_CheckParmWithArgs(check,0); }
boolean M_ParmExists(const char *check) { return M_CheckParm(check) != 0; }

byte *I_ZoneBase(int *size) {
    *size = 64*1024*1024;
    byte *memory = malloc(*size);
    if (!memory) I_Error("Cannot allocate Doom's memory arena.");
    return memory;
}
void *I_Realloc(void *pointer, size_t size) {
    void *result = realloc(pointer,size);
    if (!result && size) I_Error("Cannot resize Doom allocation.");
    return result;
}
boolean I_GetMemoryValue(unsigned int offset, void *value, int size) {
    // Chocolate Doom's default DOS 6.22 compatibility bytes.
    const unsigned char bytes[] = {0x57,0x92,0x19,0x00,0xF4,0x06,0x70,0x00,0x16,0x00};
    if (size < 1 || size > 4 || offset > sizeof(bytes) || (unsigned)size > sizeof(bytes)-offset) return false;
    memcpy(value,bytes+offset,size); return true;
}
void I_BeginRead(void) {}
// Bounded command queue consumed on the main thread after each simulation tic.
// Voice ownership stays inside C; Swift sees only a slot number and copied values.
static MD_SoundEvent soundEvents[256];
static int soundRead, soundWrite, nextVoice;
static void *voiceOrigins[16];
static void SoundEvent(int channel, int lump, float volume, float pan) {
    if (soundWrite-soundRead == 256) ++soundRead;
    soundEvents[soundWrite++ % 256] = (MD_SoundEvent){channel,lump,volume,pan};
}
int MD_PopSound(MD_SoundEvent *output) {
    if (!output || soundRead == soundWrite) return 0;
    *output = soundEvents[soundRead++ % 256];
    if (soundRead == soundWrite) soundRead = soundWrite = 0;
    return 1;
}
void S_Start(void) {
    soundRead = soundWrite = nextVoice = 0;
    memset(voiceOrigins,0,sizeof(voiceOrigins));
    for (int i=0;i<16;++i) SoundEvent(i,-1,0,0);
}
void S_StartSound(void *origin, int sound) {
    if (sound <= 0 || sound >= NUMSFX) return;
    sfxinfo_t *sfx = &S_sfx[sound]; if (sfx->link) sfx = sfx->link;
    char name[9]; snprintf(name,sizeof(name),"ds%.6s",sfx->name);
    int lump = W_CheckNumForName(name); if (lump < 0) return;
    float volume = 0.7f, pan = 0;
    mobj_t *listener = players[consoleplayer].mo;
    if (origin && listener && origin != listener) {
        // Sector sound origins share mobj's leading x/y/z fields.
        mobj_t *source = origin;
        float dx = ((double)source->x-listener->x)/FRACUNIT;
        float dy = ((double)source->y-listener->y)/FRACUNIT;
        float distance = hypotf(dx,dy);
        if (distance >= 1200) return;
        volume *= fminf(1,(1200-distance)/1040);
        double yaw = listener->angle*(2*M_PI/4294967296.0);
        if (distance > 0) pan = (dx*sin(yaw)-dy*cos(yaw))/distance*0.8f;
    }
    int slot = -1;
    if (origin) for (int i=0;i<16;++i) if (voiceOrigins[i] == origin) { slot = i; break; }
    if (slot < 0) { slot = nextVoice; nextVoice = (nextVoice+1)%16; }
    voiceOrigins[slot] = origin;
    SoundEvent(slot,lump,volume,pan);
}
void S_StopSound(mobj_t *origin) {
    for (int i=0;i<16;++i) if (voiceOrigins[i] == origin) {
        voiceOrigins[i] = NULL; SoundEvent(i,-1,0,0);
    }
}
void S_ResumeSound(void) {}
void ST_Start(void) {}
void HU_Start(void) {}
void AM_Stop(void) { automapactive = false; }
boolean I_ConsoleStdout(void) { return false; }
void I_Tactile(int on, int off, int total) {}
void V_BeginRead(size_t bytes) {}
