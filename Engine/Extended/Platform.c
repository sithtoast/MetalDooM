// SPDX-License-Identifier: GPL-2.0-or-later
// Native headless worker services. Presentation hooks intentionally have no UI.
// Simulation remains upstream code; optional audio capture lives in AudioEvents.c.
#include "NativeInternal.h"
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <limits.h>
#include "doomstat.h"
#include "am_map.h"
#include "d_iwad.h"
#include "g_umapinfo.h"
#include "f_wipe.h"
#include "g_rewind.h"
#include "hu_obituary.h"
#include "hu_command.h"
#include "i_system.h"
#include "i_printf.h"
#include "i_timer.h"
#include "i_video.h"
#include "i_exit.h"
#include "i_gamepad.h"
#include "i_input.h"
#include "i_rumble.h"
#include "i_richpresence.h"
#include "i_sound.h"
#include "mn_menu.h"
#include "st_carousel.h"
#include "st_widgets.h"
#include "st_stuff.h"
#include "s_sound.h"
#include "ws_stuff.h"
#include "r_swirl.h"
#include "wi_stuff.h"
#include "w_wad.h"
boolean automapactive,EpiCustom,followplayer,full_sounds,hud_time_use,menu_pause_demos,menuactive,message_colorized,r_swirl,show_obituary_messages,show_pickup_messages=true,show_toggle_messages=true,snd_ambient,uncapped,wi_overlay;
int ddt_cheating,idmusnum=-1,savepage,screenblocks=10,speedometer;
secretmessage_t hud_secret_message;
pal_change_t palette_changes;
const char *skill_strings[]={"Easy","Easy","Normal","Hard","Nightmare"};
void AM_ApplyColors(boolean force){}
void AM_SetMapCenter(fixed_t x,fixed_t y){}
void AM_Stop(void){automapactive=false;}
void AM_clearMarks(void){}
boolean D_CheckNetConnect(void){return false;}
int D_GetPlayersInNetGame(void){return 1;}
const char *D_DoomPrefDir(void){return ME_CacheDirectory();}
void F_SetWipe(void){}
void G_ResetRewind(boolean force){}
void HU_Obituary(struct mobj_s *a,struct mobj_s *b,struct mobj_s *c,method_t d){}
void HU_ResetCommandHistory(void){}
void HU_UpdateTurnFormat(void){}
void I_BeginRead(unsigned int bytes){}
void I_EndRead(void){}
void I_ErrorInternal(const char *prefix, const char *error, ...)
{
    char message[2048];
    va_list args;
    va_start(args, error);
    vsnprintf(message, sizeof(message), error, args);
    va_end(args);
    ME_Fatal(prefix, message);
}
void I_MessageBox(const char *message,...){va_list a;va_start(a,message);vfprintf(stderr,message,a);va_end(a);}
void I_Printf(verbosity_t priority,const char *message,...){va_list a;va_start(a,message);vfprintf(stderr,message,a);va_end(a);fputc('\n',stderr);}
void I_PutChar(verbosity_t priority,int c){}
void *I_Realloc(void *p,size_t n){void *r=realloc(p,n);if(!r && n)I_Error("allocation");return r;}
boolean I_GetMemoryValue(unsigned int offset,void *value,int size){const byte data[]={0x57,0x92,0x19,0,0xF4,6,0x70,0,0x16,0};if(size<1 || size>4 || offset>sizeof(data) || size>sizeof(data)-offset)return false;memcpy(value,data+offset,size);return true;}
byte I_GetNearestColor(byte *p,int r,int g,int b){int best=INT_MAX,result=0;for(int i=0;i<256;i++){int x=r-p[3*i],y=g-p[3*i+1],z=b-p[3*i+2],d=x*x+y*y+z*z;if(d<best){best=d;result=i;}}return result;}
int I_GetTime_RealTime(void){return gametic;}
void I_FlushGamepadSensorEvents(void){}
void I_ResetAllRumbleChannels(void){}
void I_ResetGamepadState(void){}
void I_ResetRelativeMouseState(void){}
void I_SafeExit(int rc){I_Error("Unexpected worker exit: %d",rc);}
void I_SetFastdemoTimer(boolean on){}
void I_UpdateDiscordPresence(const char *state,const char *status){}
void MN_DisableBrightmapsItem(void){}
void MN_UpdateFreeLook(void){}
void ST_ResetCarousel(void){}
void ST_ResetMessages(void){}
void ST_Start(void){}
void WS_Reset(void){}
void S_InitListener(const struct mobj_s *listener){}
void S_Reset(void){}
void S_ResumeMusic(void){}
boolean S_StartAmbientSound(const struct mobj_s *origin,int id,struct ambient_s *ambient){I_Error("Ambient sound adapter is not implemented");}
void S_StopAmbientSounds(void){}
// Episode menu hooks retain the simulation flag; the worker has no menu.
void MN_ClearEpisodes(void) { EpiCustom = true; }
void MN_AddEpisode(const char *map, const char *gfx, const char *txt, char key) { EpiCustom = true; }
