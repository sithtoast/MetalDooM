// SPDX-License-Identifier: GPL-2.0-or-later
// Offline, main-thread adapter around the pinned Chocolate Doom OPL sequencer.
// Gameplay WAD/zone state is never touched; GENMIDI is supplied by the caller.
#include "Bridge.h"
#include "opl3.h"
#include "i_oplmusic.c"

static opl3_chip chip;
static uint64_t clock_us;
static struct { uint64_t at; opl_callback_t callback; void *data; } callbacks[1024];
static int callback_count, render_failed;
int snd_samplerate = 44100;
void OPL_WriteRegister(int reg,int value) { OPL3_WriteRegBuffered(&chip,reg,value); }
void OPL_SetSampleRate(unsigned int rate) {}
opl_init_result_t OPL_Init(unsigned int port) { return OPL_INIT_OPL2; }
void OPL_Shutdown(void) {}
void OPL_Lock(void) {}
void OPL_Unlock(void) {}
void OPL_SetPaused(int paused) {}
void OPL_ClearCallbacks(void) { callback_count=0; }
void OPL_SetCallback(uint64_t us,opl_callback_t callback,void *data) {
    if(callback_count==1024) { render_failed=1;return; }
    int i=callback_count++;
    callbacks[i].at=clock_us+us;callbacks[i].callback=callback;callbacks[i].data=data;
}
void OPL_AdjustCallbacks(float factor) {
    for(int i=0;i<callback_count;i++) callbacks[i].at=clock_us+(uint64_t)((callbacks[i].at>clock_us ? callbacks[i].at-clock_us : 0)/factor);
}
void OPL_InitRegisters(int mode) {
    for(int r=OPL_REGS_LEVEL;r<=OPL_REGS_LEVEL+OPL_NUM_OPERATORS;r++) OPL_WriteRegister(r,0x3f);
    for(int r=OPL_REGS_ATTACK;r<=OPL_REGS_WAVEFORM+OPL_NUM_OPERATORS;r++) OPL_WriteRegister(r,0);
    for(int r=1;r<OPL_REGS_LEVEL;r++) OPL_WriteRegister(r,0);
    OPL_WriteRegister(OPL_REG_TIMER_CTRL,0x60);OPL_WriteRegister(OPL_REG_TIMER_CTRL,0x80);
    OPL_WriteRegister(OPL_REG_WAVEFORM_ENABLE,0x20);OPL_WriteRegister(OPL_REG_FM_MODE,0x40);
}
static void le32(FILE *f,uint32_t value) { for(int i=0;i<4;i++) fputc((value>>(8*i))&255,f); }
static void le16(FILE *f,uint16_t value) { fputc(value&255,f);fputc(value>>8,f); }
static void header(FILE *f,uint32_t frames) {
    rewind(f);fwrite("RIFF",1,4,f);le32(f,36+frames*4);fwrite("WAVEfmt ",1,8,f);
    le32(f,16);le16(f,1);le16(f,2);le32(f,44100);le32(f,176400);le16(f,4);le16(f,16);
    fwrite("data",1,4,f);le32(f,frames*4);
}
int MD_RenderOPL(const void *genmidi,int length,const char *midiPath,const char *wavPath) {
    if(!genmidi || length<8+175*(36+32) || memcmp(genmidi,"#OPL_II#",8)) return 0;
    midi_file_t *file=MIDI_LoadFile((char *)midiPath);if(!file)return 0;
    if(MIDI_NumTracks(file)>64 || MIDI_GetFileTimeDivision(file)==0) { MIDI_FreeFile(file);return 0; }
    FILE *out=fopen(wavPath,"wb");if(!out) { MIDI_FreeFile(file);return 0; }
    header(out,0);OPL3_Reset(&chip,44100);clock_us=0;callback_count=0;render_failed=0;
    opl_opl3mode=0;num_opl_voices=9;opl_stereo_correct=false;opl_drv_ver=opl_doom_1_9;
    main_instrs=(genmidi_instr_t *)((const byte *)genmidi+8);percussion_instrs=main_instrs+128;
    main_instr_names=(char (*)[32])(percussion_instrs+47);percussion_names=main_instr_names+128;
    current_music_volume=127;OPL_InitRegisters(0);InitVoices();music_initialized=true;
    I_OPL_PlaySong(file,false);
    uint32_t frames=0;unsigned events=0;
    while(running_tracks && !render_failed && frames<44100*600) {
        int next=-1;
        for(int i=0;i<callback_count;i++) if(next<0 || callbacks[i].at<callbacks[next].at)next=i;
        if(next<0) { render_failed=1;break; }
        if(callbacks[next].at<=clock_us) {
            opl_callback_t cb=callbacks[next].callback;void *data=callbacks[next].data;
            memmove(&callbacks[next],&callbacks[next+1],(--callback_count-next)*sizeof(callbacks[0]));
            cb(data);if(++events>2000000)render_failed=1;continue;
        }
        uint64_t target=(callbacks[next].at*44100+999999)/1000000;
        unsigned count=(unsigned)(target-frames);if(count>512)count=512;
        if(count>44100*600-frames)count=44100*600-frames;
        int16_t samples[1024];OPL3_GenerateStream(&chip,samples,count);
        if(fwrite(samples,4,count,out)!=count) { render_failed=1;break; }
        frames+=count;clock_us=(uint64_t)frames*1000000/44100;
    }
    int ok=!render_failed && !running_tracks && frames>0;
    I_OPL_StopSong();MIDI_FreeFile(file);music_initialized=false;
    if(ok)header(out,frames);
    if(fclose(out))ok=0;
    if(!ok)remove(wavPath);
    return ok;
}
