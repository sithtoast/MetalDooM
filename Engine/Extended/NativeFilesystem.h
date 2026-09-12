// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
typedef struct { int type; uint64_t size; int64_t modify_time; } MEFS_PathInfo;
enum { MEFS_PATHTYPE_FILE, MEFS_PATHTYPE_DIRECTORY };
typedef enum { MEFS_ENUM_CONTINUE } MEFS_EnumerationResult;
#define MEFS_NS_TO_SECONDS(x) ((x)/1000000000)
bool MEFS_GetPathInfo(const char *,MEFS_PathInfo *);
const char *MEFS_GetError(void);
bool MEFS_CreateDirectory(const char *);
bool MEFS_RemovePath(const char *);
bool MEFS_RenamePath(const char *,const char *);
bool MEFS_CopyFile(const char *,const char *);
bool MEFS_SaveFile(const char *,const void *,size_t);
bool MEFS_EnumerateDirectory(const char *,MEFS_EnumerationResult (*)(void *,const char *,const char *),void *);
