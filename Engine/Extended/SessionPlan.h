// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include "ExtendedCore.h"
void ME_PlanSession(const ME_Config *config);
const ME_Session *ME_CurrentSession(void);
int ME_RustProbeEnabled(void);
void ME_ApplySessionOptions(void);
