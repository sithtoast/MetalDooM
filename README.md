# MetalDooM

A native Apple Silicon / Metal source-port project for classic Doom and Doom II.

**Current milestone: named maps, native save/load, and persistent quick saves.**
Original gameplay and exit routing run in the Doom engine, with Metal world,
weapon, HUD, and intermission rendering. Original finales remain.
The world is drawn as triangles by Metal. No software framebuffer, SDL, OpenGL, or
Vulkan presentation layer is used.

## Build and run

Requires Apple Silicon, macOS 14+, and Xcode command-line tools. Tested with Xcode
27 beta's Swift 6.4 compiler in Swift 5 language mode. Older Xcode versions have not
been verified. The engine builds from vendored C source without network access.

```sh
cd ~/Dev/MetalDooM
bash scripts/build.sh
open build/MetalDooM.app --args -iwad "$HOME/Downloads/doom1.WAD"
```

Or open the app and choose **Open WAD…**. `-warp E1M3` selects a map at startup.
Supply your own standalone IWAD. One IWAD is supported per session: restart the app
to change IWADs. Switching or restarting maps within that IWAD is supported.
No game WAD assets are included.

### Build numbers

`BUILD_NUMBER` records the last successful local build. Each successful build
increments it and sets the app's `CFBundleVersion`. The version/build appear in the
window title and About window; About includes a UTC build timestamp. Failed builds
preserve the previous app and counter. Concurrent builds are rejected. Marketing
version `0.1.0` is maintained separately in `Info.plist`. Commit `BUILD_NUMBER` with
releases; independent checkouts do not share a global numbering sequence.

## Controls

| Input | Action |
| --- | --- |
| W / S or up / down | Forward / backward |
| A / D | Strafe |
| Left / right | Turn |
| Shift | Run |
| E / Space | Use a door or switch |
| Click the viewport | Capture mouse; subsequent clicks/hold fire |
| F | Fire (also works without mouse capture) |
| 1–7 | Classic weapon slots; 1 fist/chainsaw, 2 pistol, 3 shotgun, etc. |
| Escape | Release mouse |
| R | Restart map with fresh starting inventory |
| Return / Enter | Intermission: skip counting, show destination, then skip the four-second map display |
| Command-O | Choose IWAD (restart first to change loaded IWAD) |
| Command-S / Command-L | Save Game… / Load Game… |
| Command-Shift-S / Command-Shift-L | Quick Save / Quick Load for this WAD |

Mouse capture releases and simulation/audio pause on focus loss. Aim uses classic
Doom horizontal targeting and vertical autoaim; looking up/down is cosmetic.
Weapon selection requires ownership. R restarts after death; it resets inventory.

## Saving and loading

Use **File → Save Game…** to choose a `.mdsave` file, or **Quick Save** for one
persistent slot per WAD. Quick saves live under
`~/Library/Application Support/MetalDooM/Saves/`, keyed by the WAD's SHA-256 digest.
Open the same WAD before loading; renaming an unchanged WAD does not invalidate saves.
Quick Save replaces that WAD's previous quick save. Named saves let you keep several.

Save while alive during a level. You can load from another map, after death, or at
intermission. Loading restores player/view, inventory, pickups and enemies, world
and moving-sector state, random state, and pending switch resets. The original
archive clears enemy target/tracer pointers; enemies reacquire targets as in
classic Doom saves. Some world coordinates use the original archive's integer
precision. This is not a frame-exact replay format.

Versioned containers check WAD identity and payload integrity before entering the
native loader. Atomic replacement preserves the previous file if saving fails.
Only MetalDooM `.mdsave` files are supported; arbitrary `.dsg` imports and guarantees
of compatibility with future format versions are outside this first implementation.
The original engine decoder has not been hardened for deliberately crafted payloads.

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
  screen with completed-level markers and a flashing destination pointer.
- Health, armor, weapons, and ammo carry across levels; keys and temporary powers
  clear through the original finish-level rules. Episode endings stop at a summary.
- Live upper/middle/lower switch textures, including timed reset, and sidedef offsets
  synchronized each tic. The Ultimate Doom starting-room pillar switch is verified.
- Original weapon state machines, ammo consumption, autoaim, melee, hitscan,
  projectiles, monster AI, damage, deaths, and automatic empty-ammo fallback.
- Metal held-weapon/muzzle-flash overlays, number-key switching, damage/pickup tint,
  and an accessible kill count.
- Original WAD music converted from MUS to MIDI in memory and played by Apple's
  native MIDI player, using the built-in General MIDI bank. Level, intermission
  and completion tracks loop; episode 4 uses the original reused tracks.
  Audio → Music (Cmd–Shift–M) toggles music and remembers the setting. Music pauses
  on focus loss and during file dialogs. Loading a save restarts its level track;
  music position is not saved. This is General MIDI synthesis, not AdLib emulation.
- Native AVAudioEngine sound effects decoded from the IWAD's DMX samples, with
  16 voices, distance attenuation, stereo pan, and focus pause/resume.
- Map switching/restarting, focus pause, and queued movement/use/fire/weapon taps.

## Current limitations

- Doom menus, demos, and networking are not connected.
- Sound positioning is sampled when an effect starts; continuous repositioning,
  original priority/pitch variation, PC-speaker sounds, and audio-device changes
  need further work. Native output has been validated through offline mixing;
  physical speaker output has not been independently recorded.
- Progression uses original completion/load-level functions rather than the full
  G_Ticker loop. Death requires R (fresh inventory). Menus, demos, networking, and
  original finale/story sequences are not connected. Episode endings show final
  stats; choose another episode with the map selector.
- Intermission background animation remains. Doom II story breaks are
  not presented, and Doom II has not been validated.
- Manual doors have been validated. Other sector actions use upstream logic but
  lifts, crushers, switches, and special-case maps need dedicated validation.
- Lighting is approximate; world animations, scrolling behavior, and full palette
  effects remain (damage/pickup tint is implemented). Sky now follows the classic
  horizontal repeat and horizon, with clamping for the optional vertical look;
  extreme pitch and unusual sky-map tricks need further validation.
  Sprite animation is implemented; the pending animations are world textures/flats.
  The HUD face uses health bands, idle frames, and the new-weapon grin, not Doom's complete expression
  state machine. Power-up screen effects and fuzz rendering remain pending.
- Classic binary Doom maps only; no UDMF, Hexen format, extended/compressed nodes,
  Boom/MBF extensions, GZDoom mods, or IWAD+PWAD merging.
- All geometry is submitted each frame. Sector height/light changes rebuild geometry
  while retaining textures; visibility culling and selective updates are pending.
- Fatal engine errors require restarting the app. Malformed-file checks do not mean
  all upstream parsing has been hardened.

## Source and license

MetalDooM is GPL-2.0-or-later; see [LICENSE](LICENSE). The unchanged Chocolate Doom
snapshot is pinned in [UPSTREAM.md](Vendor/ChocolateDoom/UPSTREAM.md), with original
copyright/license notices retained. Native adaptation lives in `Engine/`.
The app bundles the license and upstream attribution. No SDL runtime or software
world-rendering function is needed by the native presentation path.

## Validation

```sh
bash scripts/test.sh "$HOME/Downloads/doom1.WAD"
bash scripts/test-engine.sh "$HOME/Downloads/doom1.WAD"
bash scripts/test-input.sh
bash scripts/test-combat.sh "$HOME/Downloads/doom1.WAD"
bash scripts/test-audio.sh "$HOME/Downloads/doom1.WAD"
bash scripts/test-music.sh "$HOME/Downloads/The_Ultimate_Doom/DOOM.WAD"
bash scripts/test-progression.sh "$HOME/Downloads/The_Ultimate_Doom/DOOM.WAD"
bash scripts/test-save.sh "$HOME/Downloads/The_Ultimate_Doom/DOOM.WAD" "$HOME/Downloads/doom1.WAD"
bash scripts/test.sh "$HOME/Downloads/The_Ultimate_Doom/DOOM.WAD"
```

The geometry suite checks an original generated room, sector lookup, malformed WAD
rejection, every supplied map, and texture decoding. Python 3 generates the fixture.
The engine suite currently targets Doom shareware: fixed-tic movement, closed-door
blocking, use/opening, walking through, reset, all nine maps, rejected loads,
health/armor/ammo collection, sprite removal/animation, red-key collection and
locked-door access, and inventory/item reset. Patch tests cover transparent gaps,
signed origins, malformed columns, all 483 sprite patches, and HUD artwork. The
input test delivers key-down/up before a tic and checks tap retention, holds,
queued use/fire/weapon changes, and focus-release cleanup. Combat tests cover
pistol ammo/damage/kills, weapon/flash animation, fist attacks, ownership checks,
monster attacks/player death, restart, and empty-ammo fallback. Native audio tests
use AVAudioEngine offline rendering to check original pistol PCM, pause/resume,
and malformed DMX rejection; they require access to macOS audio services.
Engine placement helpers exist only in the test build.

Validated: all nine maps and 146 world materials in the supplied shareware WAD;
engine movement/door/pickup tests; native visual sprites, status bar, collection,
locked-door messages, red-key HUD indicator, and passage through the unlocked door.
Build 12 restored E1M1's BRNBIG exit panels with transparent openings and verified
continuous outdoor sky while turning. Regression checks cover these surfaces and
seg-bounded planes even when unused vertices expand map bounds.
Build 11 additionally showed pistol rendering, enemy death, ammo/health changes,
and switching to the fist in the native combat fixture.
Visual fixtures change only THINGS records in temporary
WAD copies, never the user's original. Generated WADs are excluded from source control.
About 110–120 FPS was observed on an Apple M5 Pro during that check. This is a display
rate reading, not a GPU benchmark or proof of wider compatibility.

Build 14 validated all 36 Ultimate Doom maps (346 world materials and 764 sprite
patches). Progression tests use its real pillar and exit switches, verify inventory
carryover and key clearing, freeze stats between levels, check all four episodes'
secret-map routes and endings, and load/tick every map. Native checks showed Hangar
Finished, Entering Nuclear Plant, E1M2's updated selector/title, and the pillar
switch lighting up. The supplied Ultimate Doom WAD remains external to the project.

Build 17 save tests cover a cross-map round trip, player/view/tic and inventory,
enemy health and object frames/positions, removed pickups, sectors, timed switches,
loading from death/intermission, wrong WADs, corrupt/truncated files, and preserving
an existing save after failure. Native checks verified the Save/Load dialogs and
quick-loading restored position and ammo after movement and firing. After an app
restart into E1M2, Quick Load restored the persisted E1M1 save and its map title.

## Next milestones

1. Add Doom menus and refine the save-slot experience.
2. Add intermission background animations, finales, and respawning.
3. Verify Doom II, longer play sessions, texture effects, and less common sector actions.

See [ARCHITECTURE.md](ARCHITECTURE.md) for module boundaries.

See [CHANGELOG.md](CHANGELOG.md) for the build-by-build history.

Intermission regression checks: `bash scripts/test-intermission.sh` covers original
counter timing, sound cues, skipping, map timeout, episode endings and secret markers.
