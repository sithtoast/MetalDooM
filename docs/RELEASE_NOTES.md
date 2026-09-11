# MetalDooM 0.7.0 — Apple Silicon preview

A native Metal source port for classic Doom, powered by Chocolate Doom.
Requires Apple Silicon and macOS 14 or later. This is an early preview.

## Install

Download the macOS arm64 **unnotarized** ZIP, extract it, and drag MetalDooM.app to
Applications. Release packaging uses Developer ID signing; local source builds
are ad-hoc signed. Neither is notarized by this workflow. If macOS blocks it, use System Settings → Privacy & Security → Open Anyway
and confirm. See INSTALL.md inside the ZIP.

Supply your own Doom/Ultimate Doom, Doom II, TNT or Plutonia IWAD. Standard SIGIL
Episode 5 can be added with Ultimate Doom. No game WADs are included.

## New in 0.7.0

- Add independent **Sprite Lighting**, **Emissive Surface Lighting**, **Soft
  Shadows** and **Embers & Projectile Trails** switches under View → More Metal
  Effects. All start off and combine with the existing lighting, AO and bloom.
- Monsters and pickups receive existing colored lights with world occlusion;
  original fullbright frames, invisibility, the weapon and HUD keep their paths.
- Selected lamp/computer/liquid materials illuminate nearby surfaces through
  bounded, one-sided source patches. Self-emission remains a separate switch.
- Four fixed shadow samples soften edges without temporal noise. Torch embers and
  projectile sparks follow game time and freeze while paused.
- Keep a 16-light budget (up to four emissive patches) and 128-particle budget.
  Sprites remain billboards and do not cast shadows. Surface lighting and trails
  are approximations; crowded combat and other GPUs still need broader testing.

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

Local experimental build: **100**, version **0.7.0**. GPU checks cover analytic
wall/grille/soft shadows, one-sided surface emission, sprite reception, real light
sources, flash timing and rocket trails, independent/combined toggles, HUD/classic
restoration, resize, power-ups, the ceiling regression, doors,
native save/load, map replacement and shutdown.
Native controls and lighting were inspected on the M5 Pro; other GPUs and sustained
frame-rate comparisons remain untested. Details are in docs/VALIDATION.md. GitHub
artifacts use their own CI build number. Multiplayer, general GZDoom/Boom/MBF mods,
SIGIL II and Legacy of Rust are not supported. Full manual campaign playthrough coverage remains ongoing.

Attach the binary ZIP, matching source ZIP and SHA-256 files to the GitHub release.
The source archive includes the vendored engine, build scripts and licenses.
For bugs, include Diagnostics → Copy Diagnostic Report and reproduction steps.
Never attach commercial WADs. See CHANGELOG.md in the repository and BUG_REPORT.md in the app ZIP for details.
