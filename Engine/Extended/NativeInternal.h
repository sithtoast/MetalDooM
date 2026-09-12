// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <stddef.h>
_Noreturn void ME_Fatal(const char *prefix, const char *message);
const char *ME_CacheDirectory(void);
void ME_RecordSound(void);
size_t ME_WriteGeometry(void *out, size_t capacity);

size_t ME_WritePresentation(void *out, size_t capacity);

size_t ME_WriteMaterials(void *out, size_t capacity);
size_t ME_WriteBlendTables(void *out, size_t capacity);
void ME_InitBlendTables(void);
unsigned ME_BlendTableIndex(const unsigned char *table);

void ME_AudioEnable(void);
void ME_AudioTick(void);
size_t ME_WriteAudio(void *out,size_t capacity);

void ME_StartLevelMusic(void);
size_t ME_WriteUI(void *out,size_t capacity);
void G_NativeComplete(void);
void G_NativeRestart(void);
void G_NativeContinue(void);
int ME_LevelPhase(void);

size_t ME_WriteCampaign(void *out,size_t capacity);

#include "m_json.h"
size_t ME_WriteSave(void *out,size_t capacity);
int ME_ReadSave(const void *data,size_t size);
void ME_ValidateKeyframe(json_t *root);
void ME_ArchiveNativeUI(json_mut_doc_t *doc,json_mut_t *root);
void ME_UnArchiveNativeUI(json_t *root);
void ME_ResetRestoredAudio(void);
