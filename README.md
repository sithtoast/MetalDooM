# MetalDooM

A native Apple Silicon / Metal source-port project for classic Doom and Doom II.

**Current milestone: Final Doom (TNT: Evilution and The Plutonia Experiment), alongside Doom, Doom II and SIGIL Episode 5.**
Original gameplay and exit routing run in the Doom engine, with Metal world,
weapon, HUD, intermission and Doom episode-finale rendering.
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

## Music playback

**Audio → Classic OPL** (default) uses Chocolate Doom's Doom 1.9 OPL2/Sound
Blaster instrument mapping, the loaded WAD's GENMIDI bank and the pinned Nuked
OPL chip emulator. **Audio → Apple MIDI** uses Apple's General MIDI instruments.
The selection persists and switching restarts the current track. Neither is
labelled as a recreation of the original Macintosh QuickTime instrument bank.

OPL scores are rendered into temporary 44.1 kHz stereo PCM before native Core
Audio playback. Loading/switching may briefly pause while a score renders. Files
are removed when their player is released; title and level playback remain
independent. Tracks over ten minutes or missing/invalid GENMIDI are rejected;
choose Apple MIDI for those scores. Volume, mute, pause/resume and looping work
with both backends. No instrument banks or game music are bundled.

## Testing and diagnostics

Use **Diagnostics → Metal Performance HUD** to toggle Apple’s graphics overlay,
and **Copy Diagnostic Report** to copy hardware, build and game details plus SHA-256 hashes of every loaded WAD
for a bug report. Hashes use the loaded file contents and preserve base/add-on order. **Run Benchmark…** replays DEMO1 from the title screen; export completed
results or a bounded session log from the same menu. See [TESTING.md](TESTING.md) for setup, comparisons and reporting steps.

## Controls

| Input | Action |
| --- | --- |
| W / S or up / down | Forward / backward |
| A / D | Strafe |
| Left / right | Turn |
| Shift | Run |
| E / Space | Use a door or switch; restart after death; advance intermission/story |
| Click the viewport | Capture mouse; subsequent clicks/hold fire |
| F | Fire (also works without mouse capture) |
| 1–7 | Classic weapon slots; 1 fist/chainsaw, 2 pistol, 3 shotgun, etc. |
| Escape | Pause/open menu; back from submenus; resume from main menu |
| R | Restart map with fresh starting inventory |
| Return / Enter | Intermission: skip counting, show destination, then skip the four-second map display |
| Command-O | Choose IWAD (restart first to change loaded IWAD) |
| Command-S / Command-L | Save Game… / Load Game… |
| Command-Shift-S / Command-Shift-L | Quick Save / Quick Load for this WAD |

Mouse capture releases and simulation/audio pause on focus loss. Aim uses classic
Doom horizontal targeting and vertical autoaim; looking up/down is cosmetic.
Weapon selection requires ownership. After death, a fresh E, Space or Enter press
restarts with starting inventory after a short delay. Escape selects Load Game in
the pause menu. R remains an immediate fresh-inventory restart.

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
bash scripts/test-menu-engine.sh "$HOME/Downloads/The_Ultimate_Doom/DOOM.WAD"
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

1. Refine palette fidelity, automap exploration and visibility culling.
2. Play through full Ultimate Doom episodes and investigate remaining compatibility gaps.
3. Verify Doom II, longer play sessions, texture effects, and less common sector actions.

See [ARCHITECTURE.md](ARCHITECTURE.md) for module boundaries.

See [CHANGELOG.md](CHANGELOG.md) for the build-by-build history.

Intermission regression checks: `bash scripts/test-intermission.sh` covers original
counter timing, sound cues, skipping, map timeout, animated backgrounds, secret
markers, finale text timing and the bunny ending. `scripts/test-progression.sh`
checks all four normal episode chains and secret returns plus representative
lift, crusher and secret-sector behavior. `Tests/make_finale_fixture.py` generates
a local-only Ultimate Doom WAD fixture whose M8 maps use E1M1 exit geometry;
launch with `-warp E1M8` (or E2/E3/E4M8) and press E to inspect each finale.

## Pause menu and options

Escape pauses simulation, intermission timing, and audio. The menu supports mouse
buttons and arrows/Enter/Space/Tab. Left/right adjusts options; original Doom sound
cues accompany navigation even while gameplay audio is paused. New Game
offers the episodes present in the WAD and all five original difficulty settings.
Restart retains difficulty, and loading restores the difficulty saved in the slot.

Save Game and Load Game expose six named slots per WAD, separate from Quick Save.
Choose a save slot, type its bitmap name (up to 24 characters within the border),
then press Enter to save or Escape to cancel. Backspace edits the name. Saving to
an occupied slot replaces it. Earlier saves without names remain compatible. File menu import/export and
quick-save shortcuts are still available.

Options offers window sizes from 960×720 to 1920×1080 macOS points (clamped to
the screen), fullscreen, 50/75/100% Metal render scale, and 35/60/120 FPS limits.
The pixel dimensions shown reflect the actual drawable, including Retina scaling.
Fullscreen uses the current desktop display mode; it does not switch the monitor's
resolution. Window preset, render scale, frame limit, music enablement, and separate
music/effects volume levels persist.

Launch the app by opening `~/Dev/MetalDooM/build/MetalDooM.app` in Finder. Save and
quit an older running build first. If no WAD is open, choose Open WAD and select
your IWAD; for example `~/Downloads/The_Ultimate_Doom/DOOM.WAD`.

## Developer console

Press backtick/tilde (`~`) to open the console; Escape or the same key closes it.
Gameplay pauses while it is open. Up/Down recalls command history; Tab completes
command names. Output and history remain available until the app exits.

Type `help` for commands. Examples:

```text
maps
map E1M2
status
volume 0.7
musicvolume 0.5
music on
render_scale 75
fps 60
fullscreen on
```

`map` and `restart` start a fresh level, so save progress first. Map names must
exist in the loaded WAD. `status` reports the game, map, player state, GPU, render
resolution and audio settings. `clear` clears output; `close` returns to the game
or the paused menu. The console runs only these game commands, never shell code.
Settings use the same persistence as the Options menu. Window fullscreen remains
a macOS window state. Parser validation: `bash scripts/test-console.sh`.

Animation/expression validation: `bash scripts/test-presentation.sh /path/to/doom1.WAD`.
A local visual fixture can be generated with
`python3 Tests/make_animation_fixture.py /path/to/DOOM.WAD /tmp/doom-animation-check.wad`.
It replaces E1M1 floors/walls with animated nukage/fire and places invulnerability
at the start to exercise the god face. The generated IWAD stays outside Git.

## Title screen, demos and cheats

Opening a WAD shows its original `TITLEPIC` with title music before the menu.
Leave it unattended for about 11 seconds to start an embedded demo. Title/credit
pages alternate with DEMO1–3 (also DEMO4 in Ultimate Doom). Press a key or click to
open the menu; Escape resumes the attract sequence. New Game or loading a save
starts normal play. File → Return to Title Screen returns to the sequence; save
current progress first. `-warp` launches directly into gameplay.

Playback supports bounded, single-player Doom 1.8/1.9 recordings from the loaded WAD,
using their recorded commands with the original gameplay thinkers. Multiplayer,
longtics, external demo files and demo recording are not supported. Unsupported or
missing demos are skipped. This does not establish compatibility with every vanilla
recording or its original executable. Playback pauses for menus, console and focus loss.

During gameplay, type these codes without opening the console:

| Code | Effect |
|---|---|
| `iddqd` | Toggle god mode |
| `idclip` / `idspispopd` | Toggle noclip |
| `idfa` / `idkfa` | Weapons, ammo and armor; `idkfa` also gives keys |
| `idclev12` | Warp to E1M2 (MAP12 for Doom II) |
| `idbeholdv/s/i/r/a/l` | Use one suffix: invulnerability, berserk, invisibility, suit, map, light |
| `idchoppers` | Give chainsaw |

Console aliases are `god`, `noclip`, `give all`, and `give ammo`; the classic codes
except `idclev` also work there (use `map` to warp). Cheats are disabled in attract
mode and on Nightmare. Weapon grants respect the loaded game's available weapons.
`idbeholda` reveals otherwise unexplored automap walls in gray. `idmus` and `iddt`
are not connected. Validate with `bash scripts/test-cheats-demos.sh /path/to/DOOM.WAD`.

## Automap and power-up presentation

Tab opens/closes the north-up automap. Gameplay continues: WASD moves, arrows pan,
+/- (or the mouse wheel) zoom, F toggles player follow, and 0 fits the level. Escape
closes the map before opening the menu. The HUD remains visible. Red walls, brown
floor changes, yellow ceiling changes and green teleport lines distinguish features;
unexplored map-power lines appear gray. Hidden lines stay hidden and secret doors
look like walls. Explored flags are retained by saves. Visibility uses original
sector sight tests around forward-facing line midpoints, an approximation of Doom's
software-renderer discovery behavior.

Invulnerability uses inverse grayscale, night vision removes scene dimming, the
radiation suit adds green, and berserk adds a fading red tint. Expiry blinking follows
the engine's timers. Spectres and the invisible weapon sample a displaced, darkened
scene through their sprite masks; they retain depth occlusion. These are Metal
approximations; exact COLORMAP/palette output and software fuzz patterns differ.

Validation: `bash scripts/test-effects-map.sh /path/to/doom1.WAD`. Options rows use
consistent bitmap text; the Ultimate menu caption uses tighter letter masks to
exclude stray title-background pixels.

Build 45 validation: isolated native app copies displayed all four episode ending
artworks, the full bunny panorama/END animation, changing E1 intermission frames,
and the larger Options rows. After an actual monster death, Escape selected Load
Game and E restarted with 100 health. Timing, progression, save/load, input and
classic-menu regression suites passed. Fixture exits exercise completion and
presentation, not the original M8 boss battles. Full manual episode playthroughs
and physical-speaker verification remain separate checks.

Build 47 begins Doom II validation: all 32 maps load and tick, geometry/materials
and sprite patches decode, and eight additional monster types run thinker smoke
checks. Super shotgun tests cover ownership, slot-3 toggling, two-shell firing,
damage, reload sounds, and inventory carryover from MAP01 to MAP02. Native build
46 showed the title, demo playback, MAP01, and a super shotgun shot taking shells
from 50 to 48 and killing a target. Final build 47 retains the MIDI bend/controller
reset; measured A4 returns from a bent 496 Hz to 441 Hz on track selection.
Ultimate Doom map, progression, and music regressions pass. These are focused
checks, not full playthroughs or verification of the reported startup music timbre.

```sh
bash scripts/test-doom2.sh "$HOME/Downloads/doom2.wad"
bash scripts/test-music.sh "$HOME/Downloads/doom2.wad"
```

## SIGIL and WAD load order

Open WAD… selects the base IWAD, then shows a load-order dialog. Add PWAD… adds
files; Move Up / Move Down changes priority. Play starts the chosen stack. The
files remain separate and are never modified. Sprites and flats use merged
namespaces with exact-name overrides; maps must supply complete classic map blocks.
This does not promise compatibility with every mod or sprite-rotation replacement.

For the supplied standard SIGIL v1.23, select Ultimate Doom's DOOM.WAD as the base
and SIGIL_V1_23.wad as the add-on. New Game lists SIGIL as Episode 5 alongside the
original four episodes. Its nine map names, MIDI music, SKY5, SIGIL intermission
art, E5M6 secret exit/E5M9 return and story/credit ending are supported.

```sh
open build/MetalDooM.app --args \
  -iwad "$HOME/Downloads/The_Ultimate_Doom/DOOM.WAD" \
  -file "$HOME/Downloads/SIGIL_V1_23/SIGIL_V1_23.wad"
bash scripts/test-stack.sh "$HOME/Downloads/The_Ultimate_Doom/DOOM.WAD" \
  "$HOME/Downloads/SIGIL_V1_23/SIGIL_V1_23.wad"
```

Saves and quick slots identify every file's contents and the load order. A save
from a different stack is rejected. Existing single-IWAD saves retain their
identity and format. Save destinations cannot overwrite any file in the stack.

Doom II now shows stats before story breaks after MAP06, MAP11, MAP20, MAP30 and
the secret exits from MAP15/MAP31. Enter/Use reveals the text, then continues.
MAP30 proceeds to the original 17-member cast: Fire/Enter plays each death;
Escape opens the menu. Cast attacks, deaths and sounds use the upstream state machine.

Build 51 validation covers Doom II routes, inventory, MAP07 tag 666/667 triggers,
Icon of Sin monster spawning and brain death, cast cycle/deaths, all SIGIL maps,
materials, native sprite indices, Episode 5 saves, overlay precedence and load-order
identity. Native checks use a local exit-position PWAD for Doom II presentation;
actual special encounters are checked separately with the original maps in C.
Ultimate Doom geometry/progression/saves and loaded-WAD shutdown remain regressions.
These checks do not replace complete manual playthroughs.


## Final Doom

Open `tnt.wad` or `plutonia.wad` as the base IWAD, with no add-on required.
MetalDooM identifies the campaign from its base resource set, including when the
file is renamed, and selects the original Final Doom engine behavior. Add-on
resources do not change the base campaign. The rerelease IWADs supplied for this
milestone are the validated versions; other releases still need regression runs.

Both campaigns have their own 32 map names, menu/title artwork, music and skies,
six story breaks, secret exits and cast ending. Music uses each IWAD's original
Doom II-style track slots; skies change at MAP12 and MAP21. Gameplay uses the
original Final Doom executable profile, including its teleporter-height quirk
(the rerelease also requests this through `comp_finaldoomteleport`).

```sh
open build/MetalDooM.app --args -iwad /path/to/tnt.wad
open build/MetalDooM.app --args -iwad /path/to/plutonia.wad
bash scripts/test-final-doom.sh /path/to/tnt.wad /path/to/plutonia.wad
```

Quit before switching base games. Saves identify IWAD contents, so TNT and
Plutonia saves cannot be mixed, and renaming an identical IWAD preserves saves.

Build 54 validation covers all 64 map geometries/materials, native sprite
snapshots and brief monster ticks, MIDI decoding, sky ranges, map names,
cross-map save restoration and wrong-campaign rejection. Native engine checks
cover every normal route, both secret routes and returns, inventory carryover,
exact campaign story text/backgrounds, the cast cycle and teleport height.
Native app checks cover both MAP01 scenes, campaign branding, and loaded-WAD
Quit/window-close exit status. Doom II, Ultimate Doom and rerelease SIGIL remain
regression checks. Complete manual campaign playthroughs remain outstanding.

This is dedicated Final Doom support, not general GAMECONF/UMAPINFO or DeHackEd
support. Classic/enhanced mode selection, SIGIL II, Legacy of Rust/ID24 and Doom 64
remain future milestones.
