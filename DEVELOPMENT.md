# Building and developing MetalDooM

Commands below run from the repository root.

## Build and run

Requires Apple Silicon, macOS 14+, and Xcode command-line tools. Tested with Xcode
27 beta's Swift 6.4 compiler in Swift 5 language mode. Older Xcode versions have not
been verified. The engine builds from vendored C source without network access.

```sh
cd ~/Dev/MetalDooM
bash scripts/build.sh
open build/MetalDooM.app --args -iwad "$HOME/Downloads/doom1.WAD"
```

Or open the app and choose **Open WAD…**. `-warp E1M3` selects a map at startup. `-file first.wad second.wad` adds ordered PWADs.
Supply your own IWAD. The load-order dialog accepts optional PWADs, with later
files taking priority. One fixed stack is supported per session: restart to
change its files or ordering. Maps within that stack can be switched or restarted.
No game WAD assets are included.

Supported Doom, Doom II, TNT and Plutonia rerelease IWADs display **(KEX Edition)**
in the title bar. Identification uses the base IWAD's campaign resources and
GAMECONF identity metadata, so renamed files work and add-ons cannot change the
base label. Diagnostics, benchmark/export context and console status include the
edition. This is an identity label, not KEX engine emulation or support for its
GAMECONF load directives, ID24, or Legacy of Rust.

### Build numbers

`BUILD_NUMBER` records the last successful local build. Each successful build
increments it and sets the app's `CFBundleVersion`. The version/build appear in the
window title and About window; About includes a UTC build timestamp. Failed builds
preserve the previous app and counter. Concurrent builds are rejected. Marketing
version `0.2.1` is maintained separately in `Info.plist`. Commit `BUILD_NUMBER` with
releases; independent checkouts do not share a global numbering sequence.

## Implemented

- ARM64 AppKit app, MetalKit viewport, direct Metal shaders.
- Canonical map names in titles and status text, plus native save/load and quick saves.
- Classic WAD/map loading, BSP/seg-clipped floors and ceilings, textured walls.
- Two-sided middle textures with transparent openings, distinct front/back faces,
  opening-height clipping, sidedef offsets, and upper/lower/middle pegging rules.
- Cylindrical Doom sky projection with depth-writing sky planes and wall curtains
  to mask distant geometry at outdoor boundaries and differing sky heights.
- PLAYPAL, PNAMES, TEXTURE1/TEXTURE2, patch compositing, and floor flats.
- Pinned Chocolate Doom engine with native memory and host services.
- Original player movement, momentum, sliding, collision, stairs, view height, and use logic.
- Fixed 35 Hz simulation with interpolated camera presentation.
- Engine-driven moving sector heights and lighting synchronized to Metal geometry.
- Camera-facing sprite quads with transparent edges, depth occlusion, original patch
  origins, engine animation frames, rotation/mirroring, and fullbright states.
- Original pickups and decorations restored: item collection/removal, inventory,
  key-gated doors, and engine pickup/locked-door messages.
- Original status-bar artwork drawn by Metal: health, armor, active ammo, ammo
  reserves/capacity, weapons owned, key cards/skulls, and a health-based face.
- Original normal/secret exit routing, classic intermission artwork and final
  kills/items/secrets/time/par count-up with original sounds, followed by an Entering
  screen with completed-level markers, a flashing destination pointer and original
  episode background animations.
- Health, armor, weapons, and ammo carry across levels; keys and temporary powers
  clear through the original finish-level rules. Doom episodes end with original
  story text, tiled backgrounds, music and ending artwork, including the Episode 3
  bunny panorama and animated THE END. Use/Enter reveals text, then advances to art;
  original automatic timing also works. Escape opens the menu at any time.
- Live upper/middle/lower switch textures, including timed reset, and sidedef offsets
  synchronized each tic. The Ultimate Doom starting-room pillar switch is verified.
- Original weapon state machines, ammo consumption, autoaim, melee, hitscan,
  projectiles, monster AI, damage, deaths, and automatic empty-ammo fallback.
- Metal held-weapon/muzzle-flash overlays, number-key switching, damage/pickup tint,
  and an accessible kill count.
- Original WAD music converted from MUS to MIDI in memory and played through
  Classic OPL (default) or Apple's native General MIDI synth. Level, intermission
  and completion tracks loop; episode 4 uses the original reused tracks.
  Audio → Music (Cmd–Shift–M) toggles music and remembers the setting. Music pauses
  on focus loss and during file dialogs. Loading a save restarts its level track;
  music position is not saved. The Audio menu selects the music backend.
- Native AVAudioEngine sound effects decoded from the IWAD's DMX samples, with
  16 voices, distance attenuation, stereo pan, and focus pause/resume.
- Map switching/restarting, focus pause, and queued movement/use/fire/weapon taps.

## Current limitations

- Networking is not connected. The main, episode and difficulty menus use original Doom artwork and layout
  with an animated skull. Ultimate Doom combines its title caption with the Doom
  menu logo; a small footer shows the MetalDooM version/build. Options and save slots
  use matching bitmap controls.
- Sound positioning is sampled when an effect starts; continuous repositioning,
  original priority/pitch variation, PC-speaker sounds, and audio-device changes
  need further work. Native output has been validated through offline mixing;
  physical speaker output has not been independently recorded.
- Progression uses original completion/load-level functions rather than the full
  G_Ticker loop. Networking is not connected.
- Doom II has original story breaks and the interactive cast ending. All 32 maps,
  MAP07 boss triggers and MAP30 spawning/death have focused checks. Full manual
  playthroughs remain unvalidated.
- Automated checks cover all Ultimate Doom map loads, normal and secret episode
  routes, plus representative doors, lifts, crushers, switches, secrets and saves.
  This does not replace full manual episode playthroughs or cover every map special.
- Lighting is approximate; scrolling behavior and full palette
  effects remain (damage/pickup tint is implemented). Sky now follows the classic
  horizontal repeat and horizon, with clamping for the optional vertical look;
  extreme pitch and unusual sky-map tricks need further validation.
  World textures/flats follow the engine animation tables. The HUD supports idle,
  weapon grin, directional hurt, heavy-damage ouch, sustained-fire, invulnerability
  and death expressions across health bands. Power-up scene effects and spectre/weapon
  fuzz are implemented as Metal approximations rather than exact palette/software output.
- Classic binary Doom maps only; no UDMF, Hexen format, extended/compressed nodes,
  Boom/MBF extensions or GZDoom mods. General MAPINFO/UMAPINFO and DeHackEd
  behavior are unsupported; standard SIGIL v1.23 uses a dedicated Episode 5 profile.
  SIGIL COMPAT, SIGIL II and compressed/MP3 music are outside this implementation.
- All geometry is submitted each frame. Sector height/light changes rebuild geometry
  while retaining textures; visibility culling and selective updates are pending.
- Fatal engine errors require restarting the app. Malformed-file checks do not mean
  all upstream parsing has been hardened.


See [ARCHITECTURE.md](ARCHITECTURE.md), [VALIDATION.md](VALIDATION.md) and [RELEASING.md](RELEASING.md).
