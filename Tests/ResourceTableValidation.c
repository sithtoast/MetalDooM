// SPDX-License-Identifier: GPL-2.0-or-later
#include "Bridge.h"
#include "ResourceTables.h"
#include "doomstat.h"
#include "p_local.h"
#include "r_data.h"
#include "r_state.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#define CHECK(x) do { if (!(x)) { fprintf(stderr,"FAIL line %d: %s (%s)\n",__LINE__,#x,MD_LastError()); exit(1); } } while(0)
static void tick(int n) { while(n--) CHECK(MD_Tick(0,0,0,0)); }
int main(int argc,char **argv) {
    CHECK(argc==3); MD_TestMonsters(0);
    int loaded=MD_Load(argv[1],1,1);
    if (!strcmp(argv[2],"reject")) {
        CHECK(!loaded); CHECK(strstr(MD_LastError(),"ANIMATED") || strstr(MD_LastError(),"SWITCHES"));
        printf("PASS bounded rejection: %s\n",MD_LastError()); return 0;
    }
    CHECK(loaded);
    if (!strcmp(argv[2],"empty")) {
        CHECK(MD_CopyAnimatedMaterials(NULL,0)==0); CHECK(MD_CopySwitchMaterials(NULL,0)==0);
        tick(50); puts("PASS empty tables replace vanilla defaults"); return 0;
    }
    if (!strcmp(argv[2],"absent-start")) {
        CHECK(MD_CopyAnimatedMaterials(NULL,0)==0); tick(50);
        puts("PASS absent animation start skipped"); return 0;
    }
    if (!strcmp(argv[2],"classic")) {
        CHECK(lastanim-anims>0 && lastanim-anims<32);
        CHECK(numswitches==(gamemode==commercial ? 40:gamemode==shareware ? 19:29));
        puts("PASS absent tables preserve classic defaults"); return 0;
    }
    if (!strcmp(argv[2],"rust-materials")) {
        CHECK(lastanim-anims==49 && numswitches==85);
        int fast=0,slow=0;
        for (MD_EngineAnim *a=anims; a<lastanim; ++a) { fast+=a->speed==4; slow+=a->speed==32; }
        CHECK(fast==1 && slow==3);
        CHECK(anims[0].numpics==4); // Rust replaces vanilla NUKAGE's three frames.
        tick(64);
        int count=MD_CopyAnimatedMaterials(NULL,0);
        MD_Material *materials=calloc(count,sizeof(*materials)); CHECK(materials);
        CHECK(MD_CopyAnimatedMaterials(materials,count)==count);
        for(int i=0;i<count;i++) CHECK(MD_TranslatedMaterial(materials[i].index,materials[i].flat)>=0);
        free(materials);
        puts("PASS installed Rust resource pack: 49 animations, 85 pairs, 4/8/32 rates, four-frame NUKAGE, engine ticks");
        return 0;
    }
    CHECK(lastanim-anims==41); CHECK(numswitches==(gamemode==commercial ? 86:85));
    CHECK(MD_CopySwitchMaterials(NULL,0)==numswitches*2);
    MD_Material pair[3]; memset(pair,0xa5,sizeof(pair));
    CHECK(MD_CopySwitchMaterials(pair,2)==numswitches*2);
    CHECK(!strcmp(pair[0].name,"STARTAN2") && !strcmp(pair[1].name,"STARTAN3"));
    CHECK((unsigned char)pair[2].name[0]==0xa5); // capacity contract
    CHECK(MD_CopyAnimatedMaterials(NULL,0)==123); // 40*3 flats + FIREWALA, FIREWALB, FIREWALL
    int flat=anims[0].basepic, wall=anims[40].basepic;
    tick(3); int f=MD_TranslatedMaterial(flat,1), w=MD_TranslatedMaterial(wall,0);
    tick(4); CHECK(MD_TranslatedMaterial(flat,1)!=f); CHECK(MD_TranslatedMaterial(wall,0)==w);
    tick(32); CHECK(MD_TranslatedMaterial(wall,0)!=w);
    // Use original button code with deliberately non-SW1/SW2 texture names.
    int line=0, side=lines[line].sidenum[0]; CHECK(side>=0);
    sides[side].toptexture=0; sides[side].midtexture=R_TextureNumForName("STARTAN2"); sides[side].bottomtexture=0;
    P_ChangeSwitchTexture(&lines[line],1);
    CHECK(sides[side].midtexture==R_TextureNumForName("STARTAN3"));
    tick(5);
    int phase=MD_TranslatedMaterial(flat,1), wallphase=MD_TranslatedMaterial(wall,0);
    int remaining=buttonlist[0].btimer; CHECK(remaining==BUTTONTIME-5);
    char path[]="/tmp/metaldoom-resources-XXXXXX"; int fd=mkstemp(path);CHECK(fd>=0);close(fd);
    CHECK(MD_WriteSave(path)); tick(40); CHECK(sides[side].midtexture==R_TextureNumForName("STARTAN2"));
    CHECK(MD_Load(argv[1],1,2)); CHECK(MD_ReadSave(path)); unlink(path);
    CHECK(MD_TranslatedMaterial(flat,1)==phase && MD_TranslatedMaterial(wall,0)==wallphase);
    CHECK(buttonlist[0].btimer==remaining && sides[side].midtexture==R_TextureNumForName("STARTAN3"));
    tick(remaining-1); CHECK(sides[side].midtexture==R_TextureNumForName("STARTAN3"));
    tick(1); CHECK(sides[side].midtexture==R_TextureNumForName("STARTAN2"));
    // Vanilla pair is absent from replacement table; it must not activate.
    sides[side].midtexture=R_TextureNumForName("SW1COMP");
    P_ChangeSwitchTexture(&lines[line],1);
    CHECK(sides[side].midtexture==R_TextureNumForName("SW1COMP"));
    puts("PASS dynamic tables, precedence, scope, rates, arbitrary switch names, capacity, cross-map save and exact button reset");
}
