# MetalDooM

Classic Doom on Apple Silicon, with native Metal rendering and gameplay powered
by Chocolate Doom. Built for macOS 14 or later; Intel Macs are not supported.

**Version 0.2.1 · early preview · Developer ID signed, not notarized.**

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

Supported rerelease IWADs are labelled **KEX Edition**. Classic binary Doom maps
are the focus; GZDoom mods, Boom/MBF extensions, SIGIL II, Legacy of Rust/ID24 and
multiplayer are not supported. Full campaign playthrough coverage is still in progress.

## Playing

**WASD** moves, **Shift** runs, clicking captures the mouse and fires, **E/Space**
uses doors and switches, **1–7** selects weapons, **Esc** opens the menu and **Tab**
opens the automap. Save/load is available in the game menu and the macOS File menu.

The Audio menu offers **Classic OPL** and **Apple MIDI** music. The Diagnostics
menu provides the Metal HUD, WAD hashes, benchmarks and session-log exports.

## Documentation

- [Player guide](PLAYER_GUIDE.md) — controls, saves, music, demos and WAD load order
- [Testing and bug reports](TESTING.md)
- [Build and development notes](DEVELOPMENT.md) · [Architecture](ARCHITECTURE.md)
- [Validation history](VALIDATION.md) · [Changelog](CHANGELOG.md)
- [Release packaging](RELEASING.md) · [GitHub Actions setup](GITHUB_SETUP.md)

## Credits and license

MetalDooM is **GPL-2.0-or-later**. Its gameplay engine is based on **Chocolate Doom**,
with code by **id Software, Simon Howard and contributors**. Classic OPL music uses
**Nuked OPL3** by **Nuke.YKT and contributors**, licensed LGPL-2.1-or-later.

See [LICENSE](LICENSE), [upstream attribution](Vendor/ChocolateDoom/UPSTREAM.md)
and [Nuked OPL3's license](Vendor/ChocolateDoom/opl/COPYING.LESSER).
Doom and the supported game data belong to their respective owners; this is an
independent source-port project.
