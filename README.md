# MetalDooM

A native Apple Silicon / Metal source-port project for classic Doom and Doom II.

**Current milestone: Chocolate Doom movement, collision, and doors rendered in Metal.**
This is a gameplay preview; actors, combat, audio, and level transitions are pending.
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
| Click the viewport | Capture mouse for looking |
| Escape | Release mouse |
| R | Restart map, including doors and player state |
| Command-O | Choose IWAD (restart first to change loaded IWAD) |

Mouse capture releases and simulation pauses on focus loss. Looking up/down is a
preview camera feature, not a decision about classic gameplay rules.

## Implemented

- ARM64 AppKit app, MetalKit viewport, direct Metal shaders.
- Classic WAD/map loading, BSP-derived floors/ceilings, textured walls and sky.
- PLAYPAL, PNAMES, TEXTURE1/TEXTURE2, patch compositing, and floor flats.
- Pinned Chocolate Doom engine with native memory and host services.
- Original player movement, momentum, sliding, collision, stairs, view height, and use logic.
- Fixed 35 Hz simulation with interpolated camera presentation.
- Engine-driven moving sector heights and lighting synchronized to Metal geometry.
- Map switching/restarting, focus pause, and queued use taps between tics.

## Current limitations

- Monsters are disabled and non-player things removed until sprite rendering lands;
  there are no invisible pickups or decorations. Combat, weapons/HUD, audio, saves,
  Doom menus, demos, and networking are not connected.
- The engine's full game-state loop is pending. Exits stop the preview with a status
  message; R restarts. Death also requires R. Locked doors require keys, which are
  not yet available.
- Manual doors have been validated. Other sector actions use upstream logic but
  lifts, crushers, switches, and special-case maps need dedicated validation.
- Lighting and sky projection are approximate; sky occlusion, texture pegging,
  masked middle walls, animations, scrolling textures, and palette effects remain.
- Classic binary Doom maps only; no UDMF, Hexen format, extended/compressed nodes,
  Boom/MBF extensions, GZDoom mods, or IWAD+PWAD merging.
- All geometry is submitted each frame. Sector height/light changes rebuild geometry
  while retaining textures; visibility culling and selective updates are pending.
- Fatal engine errors require restarting the app. Malformed-file checks do not mean
  all upstream parsing has been hardened. Doom II has not yet been tested.

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
```

The geometry suite checks an original generated room, sector lookup, malformed WAD
rejection, every supplied map, and texture decoding. Python 3 generates the fixture.
The engine suite currently targets Doom shareware: fixed-tic movement, closed-door
blocking, use/opening, walking through, reset, all nine maps, and rejected loads.
Engine placement helpers exist only in the test build.

Validated: all nine maps and 138 world materials in the supplied shareware WAD;
engine movement/door tests; native visual door opening and walking into the room
beyond. The visual fixture changes only the player start in a temporary WAD copy,
never the user's original. Generated WADs are excluded from source control.
About 110–120 FPS was observed on an Apple M5 Pro during that check. This is a display
rate reading, not a GPU benchmark or proof of wider compatibility.

## Next milestones

1. Render things, pickups, weapons, and HUD; enable actors and combat.
2. Connect exits/intermissions, full game-state progression, and respawning.
3. Add native audio/music, save/load, and menus.
4. Verify Doom II, longer play sessions, texture effects, and less common sector actions.

See [ARCHITECTURE.md](ARCHITECTURE.md) for module boundaries.
