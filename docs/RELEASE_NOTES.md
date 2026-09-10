# MetalDooM 0.6.0 — Apple Silicon preview

A native Metal source port for classic Doom, powered by Chocolate Doom.
Requires Apple Silicon and macOS 14 or later. This is an early preview.

## Install

Download the macOS arm64 **unnotarized** ZIP, extract it, and drag MetalDooM.app to
Applications. Release packaging uses Developer ID signing; local source builds
are ad-hoc signed. Neither is notarized by this workflow. If macOS blocks it, use System Settings → Privacy & Security → Open Anyway
and confirm. See INSTALL.md inside the ZIP.

Supply your own Doom/Ultimate Doom, Doom II, TNT or Plutonia IWAD. Standard SIGIL
Episode 5 can be added with Ultimate Doom. No game WADs are included.

## New in 0.6.0

- **View → More Metal Effects** adds independent torch/lamp, projectile and muzzle
  lights, gameplay light shadows, emissive surfaces and bloom. All start off.
- Torch flicker and weapon flashes follow game time. Nearby colored lights use
  the shared world ray mesh with a 16-light budget; AO/test-light controls remain
  separate. Decorative lamps and bright liquid/computer pixels can self-illuminate.
- Restrained bloom softens bright world highlights before drawing the weapon/HUD.
  Settings survive map/save loads within the session and appear in diagnostics.
- This is an experimental branch preview, not a published release. Light receivers
  and shadow casters are world surfaces; billboard sprites do not receive or cast
  dynamic lighting/shadows. Bloom is LDR, not HDR or indirect surface lighting.

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

Local experimental build: **96**, version **0.6.0**. GPU checks cover analytic
wall/grille shadows, real light sources and flash timing, independent/combined
toggles, HUD/classic restoration, resize, power-ups, the ceiling regression, doors,
native save/load, map replacement and shutdown.
Native controls and lighting were inspected on the M5 Pro; other GPUs and sustained
frame-rate comparisons remain untested. Details are in docs/VALIDATION.md. GitHub
artifacts use their own CI build number. Multiplayer, general GZDoom/Boom/MBF mods,
SIGIL II and Legacy of Rust are not supported. Full manual campaign playthrough coverage remains ongoing.

Attach the binary ZIP, matching source ZIP and SHA-256 files to the GitHub release.
The source archive includes the vendored engine, build scripts and licenses.
For bugs, include Diagnostics → Copy Diagnostic Report and reproduction steps.
Never attach commercial WADs. See CHANGELOG.md in the repository and BUG_REPORT.md in the app ZIP for details.
