// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include "m_json.h"
void ME_CheckSaveIndex(int index,const char *base);
int ME_SaveInteger(json_t *value);
int ME_SaveIntegerValue(json_t *object,const char *key);
json_t *ME_SaveObject(json_t *object,const char *key);
// The private format has no optional numeric fields. Fail before dereferencing
// a missing/mistyped pointer index instead of using upstream's default zero.
#define JS_GetInteger ME_SaveInteger
#define JS_GetIntegerValue ME_SaveIntegerValue
#define JS_GetObject ME_SaveObject
