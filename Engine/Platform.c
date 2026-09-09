// SPDX-License-Identifier: GPL-2.0-or-later
// Explicit host services for the movement/doors milestone. No SDL or software video.
#include <stdlib.h>
#include <string.h>
#include "doomstat.h"
#include "i_system.h"
#include "s_sound.h"
#include "m_argv.h"

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
void S_Start(void) {}
void S_StartSound(void *origin, int sound) {}
void S_StopSound(mobj_t *origin) {}
void S_ResumeSound(void) {}
void ST_Start(void) {}
void HU_Start(void) {}
void AM_Stop(void) { automapactive = false; }
boolean I_ConsoleStdout(void) { return false; }
void I_Tactile(int on, int off, int total) {}
void V_BeginRead(size_t bytes) {}
