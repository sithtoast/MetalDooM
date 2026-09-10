# MetalDooM 0.2.1 — Apple Silicon preview

A native Metal source port for classic Doom, powered by Chocolate Doom.
Requires Apple Silicon and macOS 14 or later. This is an early preview.

## Install

Download the macOS arm64 **unnotarized** ZIP, extract it, and drag MetalDooM.app to
Applications. This build is Developer ID signed but has **not** been notarized by
Apple. If macOS blocks it, use System Settings → Privacy & Security → Open Anyway
and confirm. See INSTALL.md inside the ZIP.

Supply your own Doom/Ultimate Doom, Doom II, TNT or Plutonia IWAD. Standard SIGIL
Episode 5 can be added with Ultimate Doom. No game WADs are included.

## Included in this preview

- Native Metal world, weapon and HUD rendering with classic gameplay.
- Saves, load-order support, Classic OPL/Apple MIDI music and native sound effects.
- KEX edition labels, WAD SHA-256 diagnostics, benchmark and session-log exports.
- Fixed phantom imps caused by drawing invisible teleport destinations.
- Shorter About credits and separate player, developer and testing guides.

Build: **73**. Multiplayer, general GZDoom/Boom/MBF mods, SIGIL II and Legacy of
Rust are not supported. Full manual campaign playthrough coverage remains ongoing.

Attach the binary ZIP, matching source ZIP and SHA-256 files to the GitHub release.
The source archive includes the vendored engine, build scripts and licenses.
For bugs, include Diagnostics → Copy Diagnostic Report and reproduction steps.
Never attach commercial WADs. See CHANGELOG.md in the repository and BUG_REPORT.md in the app ZIP for details.
