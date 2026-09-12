// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <stddef.h>
_Noreturn void ME_Fatal(const char *prefix, const char *message);
const char *ME_CacheDirectory(void);
void ME_RecordSound(void);
size_t ME_WriteGeometry(void *out, size_t capacity);
