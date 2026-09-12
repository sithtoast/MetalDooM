# MetalDooM 0.10.0 — Apple Silicon preview

A native Metal source port for classic Doom, powered by Chocolate Doom.
Requires Apple Silicon and macOS 14 or later. This is an early preview.

## Install

The current local development app is **0.10.0 build 135**, ad-hoc signed and
unnotarized. No new release package was produced. The previous **0.9.0 build 124**
distribution was separately Developer ID signed, accepted by Apple and stapled.
GitHub workflow assets remain unnotarized. For unnotarized previews, macOS may
require System Settings → Privacy & Security → Open Anyway. See INSTALL.md.

Supply your own Doom/Ultimate Doom, Doom II, TNT or Plutonia IWAD. Standard SIGIL
Episode 5 can be added with Ultimate Doom. No game WADs are included.

## New in 0.10.0 — Rust development foundations

Final successful local build: **135**.

Build 135 adds native [sound effects](EXTENDED_AUDIO.md) to the explicit Rust
preview. Actual worker events drive firing, charge/impact, pickup, switch and
moving-sector samples, with stereo positioning and a Sound toggle. Manual batches
retain event spacing; music and synchronized continuous play remain ahead.
All sixteen scene checks, actual Rust weapon PCM and classic audio regressions
pass. Actors, weapons, animated materials and cached scene updates remain available.
The ordinary picker still rejects Rust pending full campaign/save acceptance.

ANIMATED and SWITCHES now drive engine material animation and native switch
texture preload, including pairs without SW1/SW2 names. SIGIL II's flame sequence
uses its WAD table. Animation and pressed-button timing survive save/load.
Classic built-in tables remain the fallback. Existing add-on acceptance is
unchanged; **Legacy of Rust is not playable yet**. See docs/LEGACY_OF_RUST.md for
installed-data evidence, engine evaluation and the remaining milestones.

## Previous 0.9.0 release

Final local build: **124**.

Minimal HUD now has an optional remembered Doomguy portrait beside health. Toggle
it in Options → HUD or View → Doomguy Portrait in Minimal HUD; original face
expressions and the selected HUD size apply.

Choose Classic or Minimal under Options → HUD or View → HUD Style. The remembered
Minimal style draws health, armor, ammo and keys over the full-height world, with
shadowed WAD artwork and the same adjustable sizes.

Options → HUD and View → HUD Status Bar Size now provide remembered 25/50/75/100%
bar sizes for windowed/fullscreen play, reclaiming game-view height at smaller sizes.

World-only MetalFX spatial upscaling and 150/200% supersampling preserve native
HUD, weapon and menu resolution. No Rest for the Living, Master Levels and SIGIL II
have dedicated profiles for the validated rerelease files, including progression,
music, skies, saves and campaign-specific engine rules. See docs/RESOLUTION.md and
docs/KEX_SUPPORT.md. Legacy of Rust/ID24 remains unsupported.

## Previous 0.8.0 release

Build 115 repairs the pre-merge input check and audio test's source dependencies.
Gameplay and effects settings are unchanged.

Build 114 adds **Esc → Options → Effects** with descriptions that follow the
highlighted preset, explicit Enter/click application and current setup status.
The presets are now **Classic, Medium, High, Medium HDR and Ludicrous**; these
names preserve the existing settings, and ⌘⇧E now reads Classic / Medium.
Medium HDR retains High's effects with restrained HDR highlights. Unavailable
choices explain their requirements. Resolution, frame cap and custom data stay set.

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

Historical 0.8.0 build-106 validation: GPU checks cover the existing
AO/lighting regressions plus fog sources, density, wall occlusion, HUD isolation,
linear EDR mapping, live headroom, preset restoration, resize and HDR/SDR switches.
Native controls and HDR Showcase were inspected on the M5 Pro. Haze is a bounded
single-scattering approximation; other displays/GPUs and sustained crowded-combat
frame rates remain untested. Details are in docs/VALIDATION.md. GitHub
artifacts use their own CI build number. Multiplayer, general GZDoom/Boom/MBF mods,
Legacy of Rust is not supported. Full manual campaign playthrough coverage remains ongoing.

Attach the binary ZIP, matching source ZIP and SHA-256 files to the GitHub release.
The source archive includes the vendored engine, build scripts and licenses.
For bugs, include Diagnostics → Copy Diagnostic Report and reproduction steps.
Never attach commercial WADs. See CHANGELOG.md in the repository and BUG_REPORT.md in the app ZIP for details.
