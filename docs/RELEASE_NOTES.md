# MetalDooM 0.4.0 — Apple Silicon preview

A native Metal source port for classic Doom, powered by Chocolate Doom.
Requires Apple Silicon and macOS 14 or later. This is an early preview.

## Install

Download the macOS arm64 **unnotarized** ZIP, extract it, and drag MetalDooM.app to
Applications. This build is Developer ID signed but has **not** been notarized by
Apple. If macOS blocks it, use System Settings → Privacy & Security → Open Anyway
and confirm. See INSTALL.md inside the ZIP.

Supply your own Doom/Ultimate Doom, Doom II, TNT or Plutonia IWAD. Standard SIGIL
Episode 5 can be added with Ultimate Doom. No game WADs are included.

## New in 0.4.0

- Compact live kills/items/secrets counters and a calmer whole-second level clock.
- Independent secret-found notifications and optional campaign par time.
- Remembered controls in View and Options → HUD.
- On `codex/metal-experiments`: optional ray-traced AO with strength/radius
  controls, masked-grille intersections and repaired ceiling seams, rebased onto
  the 0.4.0 HUD release. Classic rendering remains the default.

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

Local experimental integration build: **93**, version **0.4.0**. Level-stats,
secret timing/save tests and the AO/48-view ceiling GPU regression pass. The
native HUD and AO controls were verified together. Build 92's main-release and
earlier Doom II results remain recorded in docs/VALIDATION.md. GitHub
artifacts use their own CI build number. Multiplayer, general GZDoom/Boom/MBF mods,
SIGIL II and Legacy of Rust are not supported. Full manual campaign playthrough coverage remains ongoing.

Attach the binary ZIP, matching source ZIP and SHA-256 files to the GitHub release.
The source archive includes the vendored engine, build scripts and licenses.
For bugs, include Diagnostics → Copy Diagnostic Report and reproduction steps.
Never attach commercial WADs. See CHANGELOG.md in the repository and BUG_REPORT.md in the app ZIP for details.
