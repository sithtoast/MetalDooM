# Validation history and regression checks

Historical results below describe the indicated builds, not complete compatibility guarantees.
See [TESTING.md](TESTING.md) for current tester instructions.

## 0.4.0, build 92 — Semantic version correction

The app rebuilt successfully. Source/bundled plist checks, current release-doc
consistency, plist lint and code-signature verification passed. The native window
visibly reports MetalDooM 0.4.0 (build 92). Gameplay source is unchanged from build
91, so this metadata/documentation correction did not rerun gameplay suites.

## Build 91 — Compact level stats and secret notifications

- `test-level-stats.sh` passed with the original Ultimate Doom IWAD: live item
  and secret counts, one discovery per sector, tic time, native save restoration,
  agreement with exit stats, next-map/restart reset and undefined episode-IV par.
- State/format tests passed after the final whole-second adjustment: no subsecond
  changes, minute/hour rollover, missing par, 105-tic notification expiry and
  refresh, and suppression when restoring/resetting counts.
- `test-combat.sh` passed for kills and existing combat behavior. `test-doom2.sh`
  passed all 32 maps with positive par lookups plus existing combat/progression.
- Native build 88 checks covered View and Options → HUD toggles, stats hide/show,
  paused time, and gold par after the target. Build 91 visually verified the
  smaller counters, whole-second time, persisted par preference and a gold
  SECRET FOUND! with S advancing from 0/4 to 1/4 in an ignored local IWAD fixture.
- Source WADs were unchanged. Generated fixture/game data and app bundles remain
  ignored. This is targeted validation, not a complete campaign playthrough.
## Ambient occlusion experiment — 2026-09-10

Final app: 0.3.0 build 84 on `codex/metal-experiments`. The preceding build 83
was used for the paired native benchmark; build 84 only adds submission of an
already-encoded acceleration-structure build if render-encoder creation fails.

- Real GPU regression with Metal API validation: Ultimate Doom E1M1 and Doom II
  MAP01 shade world pixels, leave the HUD identical, remain stable while paused,
  and exactly restore classic pixels when disabled. Map replacement and shutdown
  pass. Ultimate Doom also opens an original door and verifies mesh rebuilds
  during motion, with no additional rebuilds when paused.
- `scripts/test.sh` passes all 36 Ultimate Doom maps, malformed fixtures,
  material/patch decoding and sky/surface checks.
- Native build 83 View toggle was visually checked with original E1M1 artwork.
  Build 84 passed the final GPU regression and native menu/build check; the
  app was left open in E1M1 with AO enabled.
- At 1280×800, corrected single-frame readback tests sampled approximately
  4.8 ms AO / 0.18 ms classic for E1M1 and 4.0 ms AO / 0.19–0.31 ms classic for
  MAP01 (32 GPU command-duration samples each). These include API validation,
  and readback pacing affects GPU clocks; they are not gameplay FPS estimates.

Paired **native app build 83** DEMO1 runs, 5-second warm-up and 15-second sample:

| Rendering | Average FPS | 1% low FPS | Mean interval | p99 | Maximum |
| --- | ---: | ---: | ---: | ---: | ---: |
| Classic | 118.00 | 38.14 | 8.47 ms | 22.05 ms | 33.60 ms |
| Ray-traced AO | 118.80 | 44.50 | 8.42 ms | 18.53 ms | 28.93 ms |

Both use M5 Pro / macOS 27.0 (26A428), 2200×1400 drawable, 100% render scale,
120 FPS cap and 120 Hz display, windowed, Metal HUD off and Classic OPL.
The Ultimate Doom IWAD SHA-256 is
`6fdf361847b46228cfebd9f3af09cd844282ac75f3edbb61ca4cb27103ce2e7f`.
Reports are local ignored files `build/classic-benchmark-build83.txt` and
`build/ao-benchmark-build83.txt`. These measure capped CPU submission intervals;
the small difference is run-to-run variation, not evidence that AO improves
performance. Power mode/AC state were not recorded, and this is one paired run.

Other GPUs, full campaigns, worst-case moving-sector maps and forced GPU/resource
allocation failures are untested. Transparent surfaces and sprites are explicitly
excluded as occluders. See [Metal experiments](METAL_EXPERIMENTS.md).

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
3. Extend Doom II and Final Doom coverage with longer play sessions and less common sector actions.

See [ARCHITECTURE.md](ARCHITECTURE.md) for module boundaries.

See [CHANGELOG.md](../CHANGELOG.md) for the build-by-build history.

Intermission regression checks: `bash scripts/test-intermission.sh` covers original
counter timing, sound cues, skipping, map timeout, animated backgrounds, secret
markers, finale text timing and the bunny ending. `scripts/test-progression.sh`
checks all four normal episode chains and secret returns plus representative
lift, crusher and secret-sector behavior. `Tests/make_finale_fixture.py` generates
a local-only Ultimate Doom WAD fixture whose M8 maps use E1M1 exit geometry;
launch with `-warp E1M8` (or E2/E3/E4M8) and press E to inspect each finale.


Animation/expression validation: `bash scripts/test-presentation.sh /path/to/doom1.WAD`.
A local visual fixture can be generated with
`python3 Tests/make_animation_fixture.py /path/to/DOOM.WAD /tmp/doom-animation-check.wad`.
It replaces E1M1 floors/walls with animated nukage/fire and places invulnerability
at the start to exercise the god face. The generated IWAD stays outside Git.


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


Build 51 validation covers Doom II routes, inventory, MAP07 tag 666/667 triggers,
Icon of Sin monster spawning and brain death, cast cycle/deaths, all SIGIL maps,
materials, native sprite indices, Episode 5 saves, overlay precedence and load-order
identity. Native checks use a local exit-position PWAD for Doom II presentation;
actual special encounters are checked separately with the original maps in C.
Ultimate Doom geometry/progression/saves and loaded-WAD shutdown remain regressions.
These checks do not replace complete manual playthroughs.



Build 54 validation covers all 64 map geometries/materials, native sprite
snapshots and brief monster ticks, MIDI decoding, sky ranges, map names,
cross-map save restoration and wrong-campaign rejection. Native engine checks
cover every normal route, both secret routes and returns, inventory carryover,
exact campaign story text/backgrounds, the cast cycle and teleport height.
Native app checks cover both MAP01 scenes, campaign branding, and loaded-WAD
Quit/window-close exit status. Doom II, Ultimate Doom and rerelease SIGIL remain
regression checks. Complete manual campaign playthroughs remain outstanding.

