// SPDX-License-Identifier: GPL-2.0-or-later
#include "Bridge.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
int main(int argc,char **argv) {
    assert(argc==2); MD_TestMonsters(0); assert(MD_Load(argv[1],1,1));
    int count=MD_CopyAnimatedMaterials(NULL,0); assert(count>3);
    MD_Material *m=calloc(count,sizeof(*m)); assert(MD_CopyAnimatedMaterials(m,count)==count);
    int flat=-1,wall=-1;
    for(int i=0;i<count;i++) { if(!strcmp(m[i].name,"NUKAGE1")) flat=m[i].index; if(!m[i].flat) wall=m[i].index; }
    assert(flat>=0 && wall>=0);
    int a=MD_TranslatedMaterial(flat,1),b=MD_TranslatedMaterial(wall,0);
    for(int i=0;i<8;i++) assert(MD_Tick(0,0,0,0));
    assert(MD_TranslatedMaterial(flat,1)!=a); assert(MD_TranslatedMaterial(wall,0)!=b);
    int saved=MD_TranslatedMaterial(flat,1);
    char path[]="/tmp/metaldoom-presentation-XXXXXX"; int fd=mkstemp(path);assert(fd>=0);close(fd);
    assert(MD_WriteSave(path)); for(int i=0;i<16;i++) assert(MD_Tick(0,0,0,0));
    assert(MD_ReadSave(path));unlink(path);assert(MD_TranslatedMaterial(flat,1)==saved);
    assert(MD_TranslatedMaterial(-1,1)==-1);free(m);
    puts("PASS: wall/flat animation advances after 8 tics and save/load restores phase");
    assert(MD_Load(argv[1],1,1)); MD_TestFaceState(70,30,0,0,0);assert(MD_GetHUD().faceIndex%8==5);
    MD_TestFaceState(70,29,0,0,0);assert(MD_GetHUD().faceIndex%8==5);
    assert(MD_Load(argv[1],1,1)); MD_TestFaceState(99,10,0,0,1);assert(MD_GetHUD().faceIndex%8==4);
    assert(MD_Load(argv[1],1,1)); MD_TestFaceState(99,10,0,0,-1);assert(MD_GetHUD().faceIndex%8==3);
    assert(MD_Load(argv[1],1,1)); for(int i=0;i<72;i++) MD_TestFaceState(100,0,1,0,0);assert(MD_GetHUD().faceIndex%8==7);
    assert(MD_Load(argv[1],1,1)); MD_TestFaceState(100,0,0,1,0);assert(MD_GetHUD().faceIndex==40);
    MD_TestFaceState(0,0,0,0,0);assert(MD_GetHUD().faceIndex==41);
    assert(MD_Load(argv[1],1,1));assert(MD_GetHUD().faceIndex<3);
    puts("PASS: ouch persistence, left/right hurt, sustained fire, invulnerability, death and reset");
}
