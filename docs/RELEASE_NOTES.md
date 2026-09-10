# MetalDooM 0.5.0 — Apple Silicon preview

A native Metal source port for classic Doom, powered by Chocolate Doom.
Requires Apple Silicon and macOS 14 or later. This is an early preview.

## Install

Download the macOS arm64 **unnotarized** ZIP, extract it, and drag MetalDooM.app to
Applications. Release packaging uses Developer ID signing; local source builds
are ad-hoc signed. Neither is notarized by this workflow. If macOS blocks it, use System Settings → Privacy & Security → Open Anyway
and confirm. See INSTALL.md inside the ZIP.

Supply your own Doom/Ultimate Doom, Doom II, TNT or Plutonia IWAD. Standard SIGIL
Episode 5 can be added with Ultimate Doom. No game WADs are included.

## New in 0.5.0

- Optional moving amber test light with ray-traced world shadows and a separate
  shadow comparison toggle. Grille holes transmit light; solid bars block it.
- AO and the light share one ray mesh but have independent on/off controls.
  Light motion follows game time and freezes with gameplay; classic launch mode,
  weapon/HUD rendering and the existing stats/secret features are preserved.
- This is an experimental branch preview, not a published release. Sprite lights,
  sprite shadow casting, emissive materials and bloom remain future work.

## Included in this preview

- Two-column WAD picker with folder browsing, drag-and-drop, recognized game names
  and ordered add-ons. Open WAD can switch games during play.
- Optional bottom status bar with the map picker and a remembered visibility setting.
  The classic Doom HUD remains independent.
- Native Metal world, weapon and HUD rendering with classic gameplay.
- Saves, load-order support, Classic OPL/Apple MIDI music and native sound effects.
- KEX edition labels, WAD SHA-256 diagnostics, benchmark and session-log exports.
- Fixed phantom imps caused by drawing invisible teleport destinations.
- Shorter About credits and separate player, developer and testing guides.

Local experimental build: **94**, version **0.5.0**. GPU checks cover analytic
wall/grille shadows, finite light distance, motion, independent toggles, unchanged
HUD/classic restoration, doors, native save/load, map replacement and shutdown.
Native controls and lighting were inspected on the M5 Pro; other GPUs and sustained
frame-rate comparisons remain untested. Details are in docs/VALIDATION.md. GitHub
artifacts use their own CI build number. Multiplayer, general GZDoom/Boom/MBF mods,
SIGIL II and Legacy of Rust are not supported. Full manual campaign playthrough coverage remains ongoing.

Attach the binary ZIP, matching source ZIP and SHA-256 files to the GitHub release.
The source archive includes the vendored engine, build scripts and licenses.
For bugs, include Diagnostics → Copy Diagnostic Report and reproduction steps.
Never attach commercial WADs. See CHANGELOG.md in the repository and BUG_REPORT.md in the app ZIP for details.
