# Woof simulation source for the experimental MetalDooM worker

Source: https://github.com/fabiangreffrath/woof
Pinned commit: `acd1c7f84fdd0fae92d1c58643c14364a131c75a` (imported 2026-09-12).

This is a source subset, not a Woof application distribution. `src` contains
upstream headers and only the C translation units listed in
`Engine/Extended/sources.txt`. The native target dead-strips unused presentation,
startup, demo and save entry points. No upstream base WAD, game assets, SDL
implementation, audio mixer or launcher is imported. The normal MetalDooM app
continues to use its Chocolate Doom core.

Copyright notices remain in each source file. Main engine code is GPL-2.0-or-later;
see COPYING and the retained upstream README's per-file attribution. Included
support libraries are miniz (MIT), yyjson (MIT), spng (BSD-2-Clause), SHA-1
(GPL-2.0-or-later) and MD5 (public domain). Their notices/licenses remain alongside
source. README also lists components of the full upstream tree that are not
included here; it is retained for provenance, not as this subset's build guide.

Local changes from the pin:

- `m_io.c`, `m_misc.c`, `i_glob.c`: replace SDL filesystem calls with the native
  `MEFS_` implementation in Engine/Extended. Other desktop/input services are
  native worker hooks; NativeHeaders supplies endian definitions and excludes
  unused SDL input/rumble declarations.
- `p_spec.c`, `p_switch.c`: fall back to vanilla tables derived from this project's
  GPL Chocolate Doom source when ANIMATED/SWITCHES are absent. No generated WAD
  supplies defaults. The worker validates custom table bounds before initialization.
- `r_data.c`: allow the default COLORMAP when no extended colormap group exists.
- `p_mobj.c`, `p_pspr.c`: dispatch actions through typed allowlists. A callback of
  the wrong kind fails at the guarded C boundary before invocation. The allowlists
  in ActionSafety.c derive from this pinned `p_action.h`; update them with upstream.
- `deh_mapping.c`, `deh_ammo.c`, `deh_main.c`, `deh_io.c`: reject unsupported fields,
  unknown sections and warning/error diagnostics, instead of silently accepting a
  partially applied patch. This deliberately accepts less input than upstream.

- `info.h`, `dsdh_mobjinfo.c`, `deh_thing.c`, `p_mobj.c`: add defaulted and validated
  pickup-message/minimum-respawn/dice fields under the explicit Rust probe profile;
  use the per-actor respawn values with the reference comparison. Other ID24 fields
  remain rejected. See the documented prose/reference discrepancy.
- `deh_bex_strings.c`, `p_inter.c`, `g_game.c`: register four specification-defined
  pickup mnemonics, apply successful-pickup message overrides and bound message
  formatting. Source: ID24HACKED 0.99.2 at the pin in docs/LEGACY_OF_RUST.md.
- `w_wad.c`: use the explicit base index for IWAD identity even when supporting
  resources precede it. The native worker also invokes upstream UMAPINFO parsing
  and preserves its episode flag without a presentation frontend.

- `g_game.c`: add three narrow native wrappers around upstream completion,
  restart/load and world-done routines. The Continue wrapper disables unsupported
  autosaves. The parent supplies the completion UI; general G_Ticker dispatch is
  still excluded. See docs/EXTENDED_LIFECYCLE.md.

- `dsdh_sounds.c`, `dsdh_main.h`: add a read-only external sound-ID lookup for
  copied campaign metadata. Unlike DSDH_SoundTranslate it never allocates an ID
  or changes the sound table. See docs/EXTENDED_CAMPAIGN.md.

Native integration, limitations and reproduction: `docs/EXTENDED_ENGINE.md`.
Future upstream updates must reapply/review this list and rerun the worker suite.
