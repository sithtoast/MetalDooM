// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include "d_think.h"
void ME_RunActorAction(actionf_t action, struct mobj_s *actor);
void ME_RunWeaponAction(actionf_t action, struct player_s *player, struct pspdef_s *weapon);
