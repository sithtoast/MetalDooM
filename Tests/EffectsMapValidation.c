// SPDX-License-Identifier: GPL-2.0-or-later
#include "Bridge.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
static void ticks(int n) { for(int i=0;i<n;i++) assert(MD_Tick(0,0,0,0)); }
static int mapped(void) {
 int n=MD_CopyMapLines(NULL,0),result=0;assert(n>0);MD_MapLine *l=calloc(n,sizeof(*l));MD_CopyMapLines(l,n);
 for(int i=0;i<n;i++) if(l[i].mapped) ++result;free(l);return result;
}
int main(int argc,char **argv) {
 assert(argc==2);MD_TestMonsters(0);assert(MD_Load(argv[1],1,1));
 ticks(5);int seen=mapped();assert(seen>0 && seen<MD_CopyMapLines(NULL,0));
 assert(MD_Cheat("idbeholdv"));ticks(1);assert(MD_GetHUD().fixedColorMap==32);
 ticks(30*35-130);int blinkOn=0,blinkOff=0;
 for(int i=0;i<120;i++){ticks(1);if(MD_GetHUD().fixedColorMap==32)blinkOn++;else blinkOff++;}assert(blinkOn && blinkOff);
 assert(MD_Load(argv[1],1,1));assert(MD_Cheat("idbeholdl"));ticks(1);assert(MD_GetHUD().fixedColorMap==1);
 assert(MD_Cheat("idbeholdr"));ticks(1);assert(MD_GetHUD().suitFlash);
 assert(MD_Cheat("idbeholds"));ticks(1);assert(MD_GetHUD().berserkFlash>0);
 assert(MD_Cheat("idbeholda"));assert(MD_GetHUD().allmap);
 assert(MD_Cheat("idbeholdi"));ticks(1);MD_WeaponSprite weapon[2];assert(MD_CopyWeaponSprites(weapon,2)>0);assert(weapon[0].shadow);
 ticks(5);seen=mapped();char path[]="/tmp/metaldoom-effects-XXXXXX";int fd=mkstemp(path);assert(fd>=0);close(fd);
 assert(MD_WriteSave(path));ticks(10);assert(MD_ReadSave(path));unlink(path);assert(mapped()==seen);assert(MD_GetHUD().allmap);
 assert(MD_Load(argv[1],1,1));assert(!MD_GetHUD().allmap && !MD_GetHUD().invisibility);
 puts("PASS: explored map subset/save restoration, power-up flags, inverse/light maps, expiry blinking, invisibility weapon and reset");
}
