// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <stddef.h>
_Noreturn void ME_Fatal(const char *prefix, const char *message);
const char *ME_CacheDirectory(void);
void ME_RecordSound(void);
size_t ME_WriteGeometry(void *out, size_t capacity);

size_t ME_WritePresentation(void *out, size_t capacity);

size_t ME_WriteMaterials(void *out, size_t capacity);

void ME_AudioEnable(void);
void ME_AudioTick(void);
size_t ME_WriteAudio(void *out,size_t capacity);
