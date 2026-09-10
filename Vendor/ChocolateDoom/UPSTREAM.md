# Chocolate Doom engine snapshot

- Source: https://github.com/chocolate-doom/chocolate-doom
- Commit: `895f581c5d91497bdda0516612da803fe5843e28`
- Retrieved: 2026-09-09
- License: GPL-2.0-or-later; see COPYING.md and individual source headers.

Contains the upstream top-level `src/*.[ch]` and `src/doom/` files, unchanged.
Only files listed in ../../Engine/sources.txt are built. Native host adaptation is
outside this directory in Engine/. SDL, network, audio, and software presentation
are not linked. No game WAD assets are included.

Classic OPL adds unchanged `opl/opl.h`, `opl/opl3.c` and `opl/opl3.h` from
the same commit. Nuked OPL3 (including upstream fast modifications) is
LGPL-2.1-or-later; its license is in opl/COPYING.LESSER. Engine/OPLMusic.c
adapts the unmodified src/i_oplmusic.c sequencer to bounded offline PCM
rendering with the base/stack GENMIDI bank. Core Audio handles playback.
No SDL audio or hardware OPL access is used.
