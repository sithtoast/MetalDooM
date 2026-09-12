# Chocolate Doom engine snapshot

- Source: https://github.com/chocolate-doom/chocolate-doom
- Commit: `895f581c5d91497bdda0516612da803fe5843e28`
- Retrieved: 2026-09-09
- License: GPL-2.0-or-later; see COPYING.md and individual source headers.

Contains the upstream top-level `src/*.[ch]` and `src/doom/` files.
Local change: `src/doom/g_game.c` exports a read-only `G_LevelParSeconds` lookup
using the original par tables, with bounds checks and no episode-IV overflow
emulation. The original completion behavior is unchanged.
Only files listed in ../../Engine/sources.txt are built. Native host adaptation is
outside this directory in Engine/. SDL, network, audio, and software presentation
are not linked. No game WAD assets are included.

Classic OPL adds unchanged `opl/opl.h`, `opl/opl3.c` and `opl/opl3.h` from
the same commit. Nuked OPL3 (including upstream fast modifications) is
LGPL-2.1-or-later; its license is in opl/COPYING.LESSER. Engine/OPLMusic.c
adapts the unmodified src/i_oplmusic.c sequencer to bounded offline PCM
rendering with the base/stack GENMIDI bank. Core Audio handles playback.
No SDL audio or hardware OPL access is used.

0.10.0 local integration: p_spec.c shares the animation layout from
Engine/ResourceTables.h and allows a dynamically allocated ANIMATED table;
p_switch.c accepts the dynamic SWITCHES table through the same module. Absent
lumps retain the original built-in tables. Original ticker and switch/button
activation logic remain unchanged. Engine/ResourceTables.c implements bounded
packed decoding; Woof's p_spec.c/p_switch.c at acd1c7f84fdd0fae92d1c58643c14364a131c75a
were consulted for Boom replacement, missing-resource and episode semantics.
The prior 0.9.0 p_enemy.c A_BossDeath integration delegates recognized campaign
boss overrides to Bridge.c; other campaigns retain upstream behavior.
