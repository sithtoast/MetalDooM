# MetalDooM 0.10.0 β1 — build 165

An experimental Apple Silicon beta, published from `codex/legacy-of-rust` without
merging into main. Requires macOS 14 or later. Supply your own game WADs.

The app and its native simulation helper are Developer ID signed with Hardened
Runtime and secure timestamps. Apple notarization is accepted and the ticket is
stapled. The download includes guides and license notices; matching source and
SHA-256 checksums accompany it.

## What's included

- Experimental single-player Legacy of Rust and bundled `id*` content plans,
  selected through the WAD picker with automatic companion/load-order checks.
- Native Metal rendering of scrolling and moving surfaces, transferred lighting,
  fire/layered skies, brightmaps, tints and palette-indexed translucency.
- Smooth camera, actor, weapon and moving-surface interpolation.
- Authored WAD HUD layouts, supplied weapon carousel artwork and recorded extras
  music, with original MIDI selection.
- Save/Load, restart, normal/secret transitions, intermissions, stories and cast.
- Existing classic Doom, Doom II, Final Doom and supported campaign add-ons.

## Beta limits and testing

Full campaign playthrough acceptance and exact software-renderer parity remain
open. Rust uses a separate bounded preview with native controls. This is not a
general ID24/GZDoom mod loader; multiplayer, external demos and demo recording are
not included. Private preview saves require matching WADs and the worker build.
Keep earlier app versions if you need their saves.

Automated coverage includes 352 bundled map checks, 1,548,288 indexed-lighting
samples, 49,152 sky pixels, all44 recorded tracks, save/restore continuation and
classic/extended Metal regressions. Native beta smoke checks and final signing
receipts are recorded in docs/VALIDATION.md. Normal campaign playtesting and a
separate-Mac download/Gatekeeper check remain useful acceptance work.

Report reproduction steps and the exact beta/build; never attach commercial WADs.
See INSTALL.md, PLAYER_GUIDE.md and BUG_REPORT.md in the app ZIP.
