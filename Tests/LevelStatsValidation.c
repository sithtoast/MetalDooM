// SPDX-License-Identifier: GPL-2.0-or-later
#include "Bridge.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
static void ticks(int n) { while(n--) assert(MD_Tick(0,0,0,0)); }
static void collect(int type) {
    int n=MD_CopyThings(NULL,0,0,0), found=0;
    MD_Thing *things=calloc(n,sizeof(*things)); MD_CopyThings(things,n,0,0);
    for(int i=0;i<n;i++) if(things[i].doomedType==type) {
        assert(MD_TestPlacePlayer(things[i].x,things[i].y,0)); assert(MD_Tick(25,0,0,0));found=1;break;
    }
    free(things);assert(found);
}
int main(int argc,char **argv) {
    assert(argc==3); MD_TestMonsters(0);assert(MD_Load(argv[1],1,1));
    MD_HUD start=MD_GetHUD(); assert(start.parSeconds==30 && start.totalSecrets==3);
    assert(start.items==0 && start.secrets==0 && start.kills==0);
    ticks(35); assert(MD_GetHUD().levelTics==start.levelTics+35);
    collect(2014); assert(MD_GetHUD().items>0 && MD_GetHUD().totalItems==start.totalItems);
    float x,y;assert(MD_TestFindSecret(&x,&y));assert(MD_TestPlacePlayer(x,y,0));ticks(1);
    assert(MD_GetHUD().secrets==1);ticks(105);assert(MD_GetHUD().secrets==1);
    MD_HUD saved=MD_GetHUD();assert(MD_WriteSave(argv[2]));ticks(40);assert(MD_ReadSave(argv[2]));
    MD_HUD restored=MD_GetHUD(); assert(restored.levelTics==saved.levelTics && restored.items==saved.items && restored.secrets==saved.secrets);
    MD_TestExit(0);ticks(1);MD_Progress progress=MD_GetProgress();MD_HUD end=MD_GetHUD();
    assert(progress.kills==end.kills && progress.items==end.items && progress.secrets==end.secrets && progress.seconds==end.levelTics/35 && progress.parSeconds==end.parSeconds);
    assert(MD_Continue());MD_HUD next=MD_GetHUD();assert(next.items==0 && next.kills==0 && next.secrets==0 && next.levelTics<35 && next.parSeconds==75);
    assert(MD_Load(argv[1],4,1));assert(MD_GetHUD().parSeconds==-1);
    assert(MD_Load(argv[1],1,1));assert(MD_GetHUD().secrets==0 && MD_GetHUD().levelTics<35);
    unlink(argv[2]);puts("PASS: live counts, one secret per sector, tic clock, save restoration, intermission agreement, next-map/reset and missing par");
}
