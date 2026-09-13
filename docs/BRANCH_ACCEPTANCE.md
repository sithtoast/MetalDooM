# Legacy of Rust branch acceptance — 0.10.0 build 164

This branch delivers an extended single-player preview alongside the classic
engine. The picker now routes bounded bundled content plans to the isolated
worker; it does not send those packs to Chocolate Doom. Multiplayer, demo
recording/uploads and a general online add-on catalog remain outside scope.

## Implemented and exercised

- Rust's 16 maps and the bundled Doom II component plans load, simulate and render.
  The six plans with/without extras have 352 map-start/tic35 checks, component
  weapon pickup/firing tests and first/last-map save/future-state coverage.
- The picker offers explicit content roles, assembles dependencies and recognizes
  supported bundled files selected as add-ons. Missing or conflicting resources
  stay in the picker with an explanation. Standard builds without the worker do
  not offer enabled bundled modes.
- The classic app waits for a successfully initialized new session before exiting;
  a failed launch keeps the current game. The preview's Choose WADs menu opens a
  separate picker while preserving its paused, potentially unsaved session.
- World effects include scrolling/rotation, normal, layered and procedural transferred/named skies, fake
  floors, transferred lighting, palette effects, indexed translucency and shared
  fuzz/transparent ordering. Run interpolates camera, weapons, actors and moving
  sectors; discontinuities snap.
- Ordinary preview lighting uses original palette indices and discrete plane/
  wall/sprite light tables, directional contrast, extra light and fixed/fullbright
  precedence, authored brightmaps and custom colormap tints. 1,548,288 independent GPU samples cover opaque and custom-blended
  colors. Native rendering keeps its own projection/rasterization.
- Actual MAP13 Cyberdemons and both MAP14 patched boss types die through their
  native states. Tagged floors remain closed until the last boss and then lower:
  eight MAP13 bosses, one MAP14 tag666 boss and 24 MAP14 tag667 bosses.
- Save/Load, Run/Pause, focus-loss pause, music, normal/secret transitions,
  intermission/story/credits/cast, death and restart have focused automated checks.

## Still required for full campaign acceptance

Play both Rust episodes normally, including secret routes, inventory progression,
combat/boss arenas and endings. Record visual problems, long-session timing and
save/restore behavior from the signed candidate. Scripted boss deaths and short
map runs are strong targeted checks, not a complete player playthrough. Keep the
preview designation until that acceptance is recorded.

Known rendering boundaries remain: software sky stretch/rasterization/fuzz
matching and whole-frame software projection parity. Fire/layered skies and
brightmaps/custom side, sector, plane and actor tints are implemented and tested.
Do not conflate pixel-level software parity with missing gameplay simulation.

The effective bundled SBARDEF now drives native status-bar/fullscreen layout,
conditions, numbers and artwork. Native controls choose that layout or the minimal
HUD; weapon changes display the supplied carousel icons. Recorded H_ music is
selected when available, with original MIDI selection/fallback. The KEX frontend
itself is not reproduced. SBARDEF animation/translation/tranmap extensions outside
the authored bundled trees remain unsupported, and a general ID24/mod catalog is
not claimed. See EXTENDED_PRESENTATION.md for the exact supported contract.

See VALIDATION.md for concrete command logs, candidate version and native launch
results. No push, merge, notarization or distribution release is implied by this
acceptance record.
