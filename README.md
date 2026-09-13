# MetalDooM

Classic Doom on Apple Silicon, with native Metal rendering and gameplay powered
by Chocolate Doom. Built for macOS 14 or later; Intel Macs are not supported.

**Version 0.10.0 · experimental source preview · local builds are not notarized.**

Build 160 adds [indexed preview lighting](docs/EXTENDED_LIGHTING.md) and
[bundled content choices in the WAD picker](docs/EXTENDED_BUNDLED.md). Select Rust
or a resource/weapon/texture/music plan with the appropriate rerelease files.
Failed startup preserves the current game. See [branch acceptance](docs/BRANCH_ACCEPTANCE.md)
for validated behavior and remaining full-playthrough/rendering limits.
Build 157 adds object/weapon blending, shared fuzz/translucent ordering and
[actor/moving-surface interpolation](docs/EXTENDED_INTERPOLATION.md) during Run.
Build 155 added [sky transfers and flat rotation](docs/EXTENDED_SKIES_ROTATION.md).
Build 152 added [fake floors and transferred lighting](docs/EXTENDED_CONTROL_SECTORS.md).
Build 151 added translucent walls and [palette effects](docs/EXTENDED_PALETTES.md).
Build 150 added per-state custom blend tables, including state changes and Save/Load.
Build 149 added [normal/additive actor translucency](docs/EXTENDED_TRANSLUCENCY.md)
using copied engine blend tables, with sprite cutouts and opaque-world occlusion.
Build 148 smooths camera movement and weapon bob during Run with
[presentation interpolation](docs/EXTENDED_INTERPOLATION.md). Build 146 added [scrolling floors and ceilings](docs/EXTENDED_SCROLLING.md),
including correct saved phase and updates limited to flat meshes. Build 145 added [Rust Save/Load](docs/EXTENDED_SAVES.md) to the explicit
[Rust preview](docs/EXTENDED_PREVIEW.md). Restore inventory, actors, moving sectors,
weapon state and campaign progress into a fresh paused worker. Private `.mdrust`
saves require the same engine and WAD resources. Animated intermissions, finales,
HUD, music and Restart/Continue remain available. Full campaign gameplay acceptance
is ahead; extended builds expose explicitly labelled preview choices. See the [roadmap](docs/LEGACY_OF_RUST.md).
The previous 0.9.0 build 124 was separately notarized; that release is preserved.

This branch adds independently switchable AO, test/torch/projectile/muzzle
lighting, sprite light reception, hard/soft world shadows, emissive surface
lighting, bloom, embers, projectile trails, volumetric haze, optional smooth world
textures and HDR display output.
Try **View → Effects Presets → Medium HDR**, or adjust individual switches.
World scaling now includes optional MetalFX and 150/200% supersampling with a native-resolution HUD, adjustable size and a transparent Minimal style ([details](docs/RESOLUTION.md)).
Separate graphics presets set world resolution/frame cap, and custom effects can be
saved. Effects start in Classic. Local builds are ad-hoc signed; release packages
use the separate signing workflow. See [Metal experiments](docs/METAL_EXPERIMENTS.md).

## Get started

1. Download the macOS arm64 ZIP from this repository's **Releases** page when available.
2. Extract it and drag **MetalDooM.app** to **Applications**.
3. Open the app. If macOS blocks it because it is not notarized, open
   **System Settings → Privacy & Security → Open Anyway**, then confirm.
4. Choose **Open WAD…** and select your own Doom IWAD. Add supported PWADs in the
   load-order dialog if needed, then choose Play.

No game WADs, music or instrument banks are included. You must supply your own
legally obtained game data. See [INSTALL.md](INSTALL.md) for package details.

## Supported games

- Doom / The Ultimate Doom
- Doom II
- Final Doom: TNT: Evilution and The Plutonia Experiment
- Standard SIGIL Episode 5, loaded with Ultimate Doom
- Validated KEX rerelease editions of No Rest for the Living, Master Levels and SIGIL II ([loading and limits](docs/KEX_SUPPORT.md))

Supported rerelease IWADs are labelled **KEX Edition**. Classic binary Doom maps
are the focus. Extended builds also offer bounded Legacy of Rust/bundled previews.
General GZDoom/Boom/MBF/ID24 mod support and multiplayer are not claimed. Full campaign playthrough coverage is still in progress.

## Playing

**WASD** moves, **Shift** runs, clicking captures the mouse and fires, **E/Space**
uses doors and switches, **1–7** selects weapons, **Esc** opens the menu and **Tab**
opens the automap. Save/load is available in the game menu and the macOS File menu.

The Audio menu offers **Classic OPL** and **Apple MIDI** music. The Diagnostics
menu provides the Metal HUD, WAD hashes, benchmarks and session-log exports.

## Documentation

- [Player guide](PLAYER_GUIDE.md) — controls, saves, music, demos and WAD load order
- [Bug reports](BUG_REPORT.md) · [Contributor testing](docs/TESTING.md)
- [Build and development notes](docs/DEVELOPMENT.md) · [Architecture](docs/ARCHITECTURE.md)
- [Validation history](docs/VALIDATION.md) · [Changelog](CHANGELOG.md)
- [Release packaging](docs/RELEASING.md) · [GitHub Actions setup](docs/GITHUB_SETUP.md)

## Credits and license

MetalDooM is **GPL-2.0-or-later**. Its gameplay engine is based on **Chocolate Doom**,
with code by **id Software, Simon Howard and contributors**. Classic OPL music uses
**Nuked OPL3** by **Nuke.YKT and contributors**, licensed LGPL-2.1-or-later.

See [LICENSE](LICENSE), [upstream attribution](Vendor/ChocolateDoom/UPSTREAM.md)
and [Nuked OPL3's license](Vendor/ChocolateDoom/opl/COPYING.LESSER).
Doom and the supported game data belong to their respective owners; this is an
independent source-port project.
