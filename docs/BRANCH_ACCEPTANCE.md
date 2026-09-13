# Legacy of Rust branch acceptance — 0.10.0 build 160

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
- World effects include scrolling/rotation, normal transferred/named skies, fake
  floors, transferred lighting, palette effects, indexed translucency and shared
  fuzz/transparent ordering. Run interpolates camera, weapons, actors and moving
  sectors; discontinuities snap.
- Ordinary preview lighting uses original palette indices and discrete plane/
  wall/sprite light tables, directional contrast, extra light and fixed/fullbright
  precedence. 387,072 independent GPU samples cover opaque and custom-blended
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

Known rendering boundaries remain: layered/procedural fire skies, software sky
stretch/rasterization/fuzz matching, per-color brightmaps and custom sector/thing
colormap tints. Ordinary lighting table selection is implemented; whole-frame
software parity is not claimed. Do not conflate that remaining parity work with
missing gameplay simulation.

Extras resources are available in the selected load order. KEX carousel/menu
presentation, arbitrary SBARDEF layouts and alternate H_ music selection remain
unimplemented. The native HUD/menu and explicit MIDI audition are the supported
presentation. A picker entry or a readable WAD never means all optional features
inside that file are supported.

See VALIDATION.md for concrete command logs, candidate version and native launch
results. No push, merge, notarization or distribution release is implied by this
acceptance record.
