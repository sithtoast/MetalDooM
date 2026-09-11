# MetalDooM 0.8.0 — Apple Silicon preview

A native Metal source port for classic Doom, powered by Chocolate Doom.
Requires Apple Silicon and macOS 14 or later. This is an early preview.

## Install

Download the macOS arm64 **unnotarized** ZIP, extract it, and drag MetalDooM.app to
Applications. Release packaging uses Developer ID signing; local source builds
are ad-hoc signed. Neither is notarized by this workflow. If macOS blocks it, use System Settings → Privacy & Security → Open Anyway
and confirm. See INSTALL.md inside the ZIP.

Supply your own Doom/Ultimate Doom, Doom II, TNT or Plutonia IWAD. Standard SIGIL
Episode 5 can be added with Ultimate Doom. No game WADs are included.

## New in 0.8.0

Build 112 adds **⌘⇧E** to toggle Classic/Enhanced in place, with a brief preset
message. Other active effects switch to Classic first. Resolution, frame cap and
saved custom setups are preserved; the shortcut is disabled during benchmarks.
Same-format preset transitions reuse drawable configuration; diagnostics now
include view visibility, paused state and frame counts.

Build 108 adds **Ludicrous**, an opt-in preset with High ray quality, stronger AO,
Atmospheric haze, brighter lights, heavier bloom, boosted fullbright world sprites and
an 8× HDR ceiling. Light strength, bloom strength and sprite boost have independent
controls. Existing presets stay restrained; all modes retain the recent visibility
optimizations and correct HDR tone mapping.

Build 106 adds visibility-first ray shading, early-exit shadow rays and separate
Balanced/High ray quality. Presets other than Ludicrous use Balanced to reduce frame intervals;
minimized/covered windows stop submitting GPU work.

Build 104 refines Enhanced and Showcase: optional smooth world textures reduce
aliasing, linear-light blending and restrained bloom reduce harsh brightness,
HDR no longer exaggerates highlight contrast, and lighter haze uses steadier
sampling. AO and soft shadows use more samples. Classic remains unchanged;
reselect a built-in preset to adopt its new settings.

- Add **HDR Display Output** for extended highlights on compatible displays.
  Lights, flames, emissive surfaces and bloom retain brightness beyond standard
  white; HUD and weapon artwork stay at standard white. Peak choices of 2×, 4×
  and 8× adapt to the display's current EDR headroom.
- Add independent **Volumetric Lighting** with four haze densities. Existing
  sources scatter light through the room, with world shadows and depth-aware
  edges. No sources means no haze glow; weapons and HUD are drawn afterward.
- Add separate graphics and effects presets. Choose Classic, Enhanced,
  Atmospheric, HDR Showcase or Ludicrous, keep individual controls, and save/apply a
  custom effects setup. Classic effects still start each launch.
- Remove macOS automatic window tab commands, which had no game function.

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

Local experimental build: **106**, version **0.8.0**. GPU checks cover the existing
AO/lighting regressions plus fog sources, density, wall occlusion, HUD isolation,
linear EDR mapping, live headroom, preset restoration, resize and HDR/SDR switches.
Native controls and HDR Showcase were inspected on the M5 Pro. Haze is a bounded
single-scattering approximation; other displays/GPUs and sustained crowded-combat
frame rates remain untested. Details are in docs/VALIDATION.md. GitHub
artifacts use their own CI build number. Multiplayer, general GZDoom/Boom/MBF mods,
SIGIL II and Legacy of Rust are not supported. Full manual campaign playthrough coverage remains ongoing.

Attach the binary ZIP, matching source ZIP and SHA-256 files to the GitHub release.
The source archive includes the vendored engine, build scripts and licenses.
For bugs, include Diagnostics → Copy Diagnostic Report and reproduction steps.
Never attach commercial WADs. See CHANGELOG.md in the repository and BUG_REPORT.md in the app ZIP for details.
