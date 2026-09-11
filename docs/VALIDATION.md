# Validation history and regression checks

Historical results below describe the indicated builds, not complete compatibility guarantees.
See [TESTING.md](TESTING.md) for current tester instructions.

## 0.8.0, build 112 — Classic/Enhanced shortcut

- Build 112 succeeds at semantic version 0.8.0. Native shortcut preview uses the
  generated E1M1 fixture; Command-Shift-E changes original world textures and
  lighting to Enhanced. Both directions and the corresponding preset notices
  are visually confirmed in an unobstructed fullscreen build-112 window; return
  the preview to windowed mode after inspection.
- `build/preset-shortcut-final/results.txt` runs the Ultimate Doom Metal
  suite plus installed-main-menu key-equivalent dispatch. Pass HDR-to-Classic,
  repeated Classic/Enhanced changes, two-second notice state, saved custom data,
  resolution/frame cap and benchmark locking. Command-modified E cannot queue Use.
- The synthetic event uses a lowercase `charactersIgnoringModifiers` value to
  match AppKit's stored key equivalent. Menu lookup uses the submenu's title,
  since the top-level NSMenuItem title is empty in the programmatic menu model.
- The background preview appeared frozen during automation. An exported build-111
  report confirms `View paused: false; window visible: true; unoccluded: false`:
  the renderer intentionally skipped frames due to macOS occlusion. This did not
  prove an engine stall. Retain background suppression; discard the speculative
  timer-reset workaround. Same-format switches now skip drawable reconfiguration.
- `AO_LIVE=1` exercises automatic frame delivery without explicit view.draw()
  calls across seven Classic/Enhanced/HDR transitions and preserves manual mode.
  Evidence: `build/preset-shortcut-live/results.txt`. This checks liveness, not
  sustained FPS. Diagnostic exports under build retain the occlusion evidence.
- Retain GPU checks for HDR limits/HUD colors, Ludicrous intensity controls,
  legacy presets, lighting and AO, cutouts, resize, save/load and shutdown.
  No new shader algorithms or ray budgets change in this refinement. This is
  not a sustained combat/performance soak or complete pre-merge compatibility run.

## 0.8.0, build 108 — Ludicrous and independent intensity controls

- `scripts/build.sh` succeeds at build 108; native title confirms **0.8.0
  (build 108)** on macOS 27.0 (26A428). Bundle signature and Info.plist checks pass.
- Native View menu exposes Ludicrous and independent light/bloom/HDR sprite
  controls. Inspect the final preset in the generated E1M1 lighting fixture.
  Stronger light and atmospheric haze remain visible, with room geometry readable
  and ordinary HUD/weapon artwork. An initial maximum-fog draft was visually
  excessive; the final preset uses the prior 0.003 Atmospheric density.
- Ultimate Doom (`build/ludicrous-final/results.txt`) and Doom II MAP01
  (`build/ludicrous-doom2/results.txt`) pass the native Metal API validation suite.
  New checks cover actual Ludicrous and Saved Custom menu routing, preset values,
  independent light/bloom/sprite pixel changes, gain sanitization, exact HUD
  preservation, Showcase reset, legacy decoding and custom intensity restoration.
- Existing checks retain alpha-tested shadow rays, deterministic AO/soft shadows,
  texture minification, one-sided emission, volumetric blockers, fixed-colormap
  handling, HDR transfer/headroom bounds, resize, save/load, map replacement and
  clean resource shutdown. New stable-image comparisons hold the HDR ceiling at
  1× because macOS changes live headroom between frames; fixed synthetic tests
  separately verify the 1×/2×/4×/8× transfer limits. Live Ludicrous stays finite and
  within its 8× configured cap. Screenshots cannot verify physical HDR luminance.
- Existing build-106 user game remains intact; build 108 is a separate preview.
  No new isolated performance comparison was run. The user's reported earlier
  mediaanalysisd spike was not reproduced: read-only process inspection found
  Apple's MediaAnalysis daemon at 0% CPU. Its earlier trigger and performance
  contribution remain unknown. Background load may affect prior native timing
  comparisons; do not interpret them as an OS-load-controlled attribution.

## 0.8.0, build 106 — Frame interval and ray-work reduction

- Native build 104 at the user's actual viewpoint showed 2200×1520, 19.82 FPS and
  50.45 ms frame interval. Saved a separate snapshot, loaded it in build 106,
  selected Showcase/Balanced without changing resolution, and observed 88.40 FPS
  / 11.31 ms in the native Metal HUD. Game progress and quick saves were preserved.
  These are observed HUD snapshots, not sustained campaign benchmarks.
- Controlled GPU profiles use eight warm-up frames and 32 samples per preset,
  paused game time, 2200×1520, no image readback and Metal validation disabled.
  Build-104 baseline comes from archived source at `a442f0e` with the same new
  profile driver; the old running game was briefly suspended with guaranteed
  resume during each measurement to remove competing GPU submissions.

  | Preset | Build 104 median / p95 | Build 106 Balanced median / p95 |
  | --- | --- | --- |
  | Classic | 0.496 / 0.498 ms | 0.499 / 0.519 ms |
  | Enhanced | 18.844 / 20.591 ms | 6.156 / 6.447 ms |
  | HDR Showcase | 28.766 / 30.554 ms | 9.198 / 10.213 ms |

  Showcase High: 16.603 / 20.071 ms. GPU duration excludes display pacing;
  serialized fences and a fixed torch scene limit extrapolation to gameplay.
  Logs: `build/perf-isolated-build104`, `build/perf-isolated-balanced`.
  Earlier profile runs without process isolation were contaminated by the old
  build's background rendering and are not valid before/after comparisons.
- Ultimate Doom and Doom II suites pass with Metal API validation, including
  Classic restoration/zero AO, masked hits and grille coverage, first-blocker
  shadows, soft-shadow bounds, sprites, particles, HDR, fog, resize/save/load,
  world replacement and shutdown. Ultimate also retains all 48 ceiling captures.
  Logs: `build/performance-final`, `build/performance-doom2`.
- Balanced/High changes preserve paused stability and HUD, reuse the world mesh,
  restore exact pixels and survive custom saves; legacy presets decode as
  Balanced. A minimized live-mode window submits no GPU frames, then resumes
  correctly after restoration. Manual test draws retain focus independence.
- Visibility-first shading preserves the existing samples in High mode. Balanced
  additionally reduces sample counts while retaining filtering, restrained HDR,
  deterministic haze, all sources and the native resolution. Other Macs and
  sustained crowded combat remain untested.

## 0.8.0, build 104 — Preset grain and brightness refinement

- Native build 104 succeeds. Enhanced and HDR Showcase were visually compared
  against build 102 in the same generated original-geometry E1M1 torch scene.
  Floors/walls are smoother, lighting is more restrained, and Showcase has less
  washout. The user did not supply their exact new problem viewpoint.
- Native GPU suites pass on Ultimate Doom and Doom II with Metal API validation:
  original AO/alpha/light/sprite/particle regressions, power-up overrides, HUD
  preservation, toggles, presets, resize, save/load, map changes and shutdown.
  Outputs: `build/preset-polish`, `build/preset-polish-doom2` and
  `build/preset-polish-final` (final Ultimate Doom/ceiling coverage).
- A production-sampler GPU probe minifies a black/white checker: filtered color
  converges to its mean within 0.01 while Classic stays strictly nearest 0/1.
  The same probe verifies exact nearest alpha for a masked checker, no black
  fringes, and unchanged power-up sampling. Real world filtering changes visible
  pixels, preserves HUD bytes, remains stable, and restores Classic exactly.
- The EDR mapping test adds a near-white 1.01 input: output remains below 1.03
  even with an 8× peak request, preventing the former exaggerated contrast slope.
  Existing linear transfer, over-range output, headroom, HUD color and HDR/SDR
  switching tests pass. Production volumetric rays remain blocked by a partition.
- Ray budgets increase to 16 AO, eight soft-shadow samples and 32 haze steps.
  These are quality improvements with GPU cost, not performance gains. Timing
  samples include validation/readback and other live previews; they do not prove
  sustained performance. Other hardware/displays remain untested.

## 0.8.0, build 102 — HDR, volumetric lighting and presets

- Build 102 succeeds and its native window identifies **MetalDooM 0.8.0 (build 102)**.
  View menus contain separate graphics/effects presets, custom save/apply, HDR
  output/peak and volumetric density. Automatic tab commands are absent. HDR
  Showcase was inspected in a separate original-geometry torch fixture at
  `build/hdr-final/MetalDooM.app` using `build/advanced-preview.wad`.
- Ultimate Doom: `AO_CEILING=1`, `build/hdr-volume-final/results.txt`; Doom II:
  `build/hdr-volume-doom2/results.txt`. Both complete with Metal API validation.
  Existing AO/alpha, lighting, particles, power-up overrides, odd-size resize,
  save/load, map replacement and shutdown checks pass. Ultimate Doom retains
  all 48 ceiling images and the original-room light-shadow comparisons.
- Volumetrics without sources are byte-identical to Classic. Adding the moving
  test light produces visible haze; density zero and disabling haze restore the
  source-only frame exactly. Paused frames are stable; HUD bytes stay unchanged.
  An isolated production march/resolve probe puts an opaque partition between
  view-ray samples and a light: shadowed scattering is zero, bypass restores it.
- Actual RGBA16Float GPU readback validates sRGB-to-linear transfer, standard white,
  monotonic over-range highlights and 1×/2×/4×/8× headroom bounds. Live Ultimate
  Doom capture reports about 3.32× current headroom and 2.38× maximum output;
  Doom II reports about 3.45× / 2.41×. Potential display headroom reports 16×.
  These are relative EDR components, not measurements of panel luminance. Current
  headroom changes with display/system conditions and EDR activation.
- HDR HUD values stay at or below 1 and match decoded SDR colors within 0.002.
  Showcase selection, manual overrides, JSON custom persistence/restoration,
  odd-size HDR resize, save/load and repeated HDR/SDR switches pass. All four
  graphics presets apply/persist scale and cap, update checkmarks and preserve
  effects. The harness restores preexisting graphics and custom preferences.
- Diagnostics tests pass separately with and without a WAD. Shader/API checks
  and native previews use the M5 Pro on macOS 27 beta. Other GPUs/displays,
  monitor migration, physical brightness, HDR capture fidelity and sustained
  crowded-combat performance remain unverified. Harness timings are not a
  controlled native-resolution benchmark.

## 0.7.0, build 100 — Sprite/surface lighting, soft shadows and particles

- Native GPU suites pass for Ultimate Doom E1M1 and Doom II MAP01 with Metal API
  validation. Original AO, hard-shadow and alpha/grille tests remain intact.
  The analytic soft-shadow probe produces partial visibility at masked edges,
  never exceeds unshadowed energy, stays deterministic, and verifies one-sided
  emitters illuminate the front side only.
- Real engine-spawned imp frames receive the test light when Sprite Lighting is
  on, while enabling reception without a light source leaves classic pixels
  unchanged. Switching it off restores world-only lighting; HUD bytes stay exact.
- Independent surface lighting changes 260,738 world pixels in original E1M1's
  nukage room at (2848,-2960), eye 17, facing south with pitch 0.2; the LITE5
  doorway at (800,504), eye 137 in MAP01 changes 436,988 pixels. Self-emission
  is off for these comparisons. Large triangles are subdivided before grouping
  sources, and source representatives remain on actual triangles.
- Soft-shadow toggles preserve paused pixels and reuse the world mesh. Particles
  work with light categories off, change with game time, restore exact pixels
  when disabled and obey the 128-particle cap. A real rocket firing sequence
  supplies copied velocity and verifies sparks trail behind the projectile.
- All ten scene switches combine with AO/test lighting, survive native save/load,
  lock during benchmarks and retain checked state. Fixed-colormap power-ups
  override the added effects, invisibility/fuzz works with bloom, odd-size resize
  and return is stable, map replacement rebuilds the shared mesh, and shutdown
  succeeds after queued GPU frames. Level-stat/secret/save and diagnostics tests pass.
- Full final geometry/shader coverage in build 99 includes all 48 original ceiling
  captures and twelve room/light-phase comparisons. Outputs:
  `build/advanced-effects-final`, `build/advanced-effects-doom2-final`.
  Build 100 changes only torch ember origins relative to their flame tips; its
  Ultimate Doom suite is `build/advanced-effects-build100`.
- Native identity verified as **0.7.0 build 100**. New menu switches, green/blue
  light reception on pickups/props, gameplay soft shadows, surface-light controls
  and animated embers were inspected across builds 99/100. Final flame-tip ember
  placement was checked with lighting off. The weapon, HUD and time/par/counters
  remain crisp. A separate build 100 preview remains open; commercial WAD data
  and generated fixture files are ignored and must not be committed.
- Build 99 sampled full-command all-effect means of 3.57 ms (E1M1) and 7.66 ms
  (MAP01), 1280×800, eight warm-up and 32 measured frames. These validation/readback
  runs shared the GPU with other desktop work and are not isolated effect costs,
  sustained FPS, or worst-case light/particle benchmarks. Other GPUs, long campaign
  sessions and crowded combat remain untested. Four-sample shadows can show bands;
  bounded source selection can pop, and trails approximate four tics of motion.

## 0.6.0, build 96 — Gameplay lights, emission and bloom

- Final Ultimate Doom run: `AO_CEILING=1`, output `build/scene-effects-final`.
  Doom II MAP01 run: `build/scene-effects-doom2`. Both pass Metal API validation,
  analytical mask/shadow/falloff checks, original AO/test-light checks, individual
  torch/projectile/emissive/bloom image changes and exact off restoration.
- The test engine spawns an original blue torch, plasma and rocket actor to verify
  source classification and GPU lighting. A real pistol firing sequence verifies
  light presence during its flash and absence afterward. A 100-source collection
  fixture confirms the 16-light cap. Torch time and paused frames remain stable.
- Individual effects leave HUD bytes unchanged. All effects combine with AO and
  the test light; shadow switches reuse the same world mesh. Odd-sized 641×403
  resize and return to 1280×800 preserve the final image after drawable replacement.
  Native save/load retains all switches; enabled map replacement and shutdown pass.
- Actual invulnerability/light-amplification cheats produce identical pixels with
  effects on/off; invisibility/fuzz renders stably with bloom. Menu check states
  reflect individual choices and benchmark mode disables every new switch.
- MAP01 starts away from known emissive materials, so its emissive comparison uses
  the original LITE5 doorway at (800,504), eye height 137. E1M1 uses its original
  computer panels. These checks do not broaden material classification to make
  arbitrary surfaces emit. Torch actors are test fixtures, not map edits in the app.
- All 48 original E1M1 ceiling captures pass with classic/maximum AO. Twelve
  original room/phase comparisons still show hard world shadows; door motion
  updates the shared ray mesh and paused geometry stops rebuilding.
- Level stats/secret timing/save regression passes after extending engine snapshots.
  Diagnostics pass with no WAD and Ultimate Doom loaded, including clipboard
  restoration, report context, benchmark cancellation and window shutdown.
- Native app identity verified as **0.6.0 build 96** in a separate preview bundle.
  Original E1M1 pillar/stairs geometry with three added test torches visibly shows
  blue/green illumination, gameplay shadows, selective emission, bloom and AO
  together; weapon, HUD and existing time/par/counters remain intact. Preview:
  `build/effects-preview/MetalDooM.app`, local WAD `build/effects-preview.wad`.
- Full GPU command means with all switches selected were 6.59 ms (final E1M1)
  and 4.06 ms (MAP01), 1280×800, 8 warm-up + 32 samples. Earlier E1M1 was 3.92 ms.
  These are validation/readback samples amid other desktop GPU work, not isolated
  effect cost, sustained FPS or a worst-case 16-source benchmark. Other GPUs,
  crowded combat and long campaign sessions remain untested.

## 0.5.0, build 94 — Moving light and shadows

- Native GPU checks with Metal API validation pass on original Ultimate Doom
  E1M1 and Doom II MAP01. The analytic shader fixture verifies squared falloff,
  grille bars/holes, 127/128 alpha cutoff, animated/UV masks, a wall before the
  light, a wall beyond the light, and the unshadowed comparison path.
- Actual frames change as the light's game-time phase advances and remain stable
  while paused. AO and light toggle independently, share the same ray resource,
  and release it when both are disabled. Movement/shadow toggles do not rebuild
  geometry; disabling both restores exact classic pixels. HUD pixels are unchanged.
- Twelve E1M1 room/phase pairs compare shadows with unshadowed light; the pillar
  room has 9,753–26,456 red-channel pixels occluded across its four phases. All
  48 original ceiling captures still pass. Original door motion updates the shared
  mesh; enabled effects, game-time phase, map replacement and shutdown survive
  native save/load and queued GPU frames.
- Final E1M1 light measurements at 1280×800, 8 warm-up + 32 samples per mode:
  unshadowed light 1.09 ms, shadowed light 1.23 ms, AO plus shadowed light 3.05 ms.
  These use the zigzag viewpoint after the ceiling tests, not the initial AO-only
  spawn viewpoint. Earlier same-view light samples were 1.20/1.82 ms, illustrating
  run-to-run variation. Doom II MAP01 sampled 1.52/1.83 ms without/with shadows.
  All are full-command durations with validation/readback and are not sustained
  FPS, isolated shader cost, or evidence that combined effects outperform AO.
- Native 0.5.0 build 94: View light/shadow controls, an orbiting pool of amber
  light, shadows, AO together, and existing counters/time/par were inspected near
  the original E1M1 pillar/stairs. A separate local fixture changes player start
  and disables monsters; original source WADs remain untouched. That preview was
  left open with AO and shadowed lighting enabled; the user's original game remains.
- Diagnostics/export regression passes both without a WAD and with original
  E1M1, including report context, clipboard restoration, benchmark cancellation
  and shutdown. Effect settings also change the benchmark identity in GPU tests.
- Other GPUs, exhaustive maps/camera paths, GPU fault injection, sustained frame
  rates and sprite lighting/shadow casting remain untested or unimplemented.

## 0.4.0, build 93 — Rebase onto main `771625e`

- Replayed all three Metal experiment commits atop the level-stats/secret feature
  and its 0.4.0 version correction. Preserved both sets of View items and the new
  renderer HUD callbacks, secret reset/update hooks and native overlay.
- `test-level-stats.sh` passes: counts, one discovery per sector, clock, save
  restoration, exit-stat agreement, map/reset behavior, missing par, and secret
  expiry/refresh and restore suppression.
- `AO_CEILING=1 ... test-ambient-occlusion.sh` passes on original Ultimate Doom:
  alpha rays, settings, exact classic restoration, stable paused/HUD pixels,
  all 48 ceiling captures, moving door, map replacement and shutdown.
- Native 0.4.0 build 93 visibly shows time/par and K/I/S with AO enabled; the View
  menu includes stats, par, secret notifications and AO strength/radius. The test
  instance was closed without replacing the user's running game.
- No new lighting effect, full campaign playthrough or performance benchmark was
  included. Earlier Doom II/map-wide results remain historical.

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

## Zigzag ceiling seams — build 87

- Reproduced the user's build 86 bright ceiling slit in original E1M1 at
  `(2848,-2960)`, yaw 45 degrees, pitch 1.05. It occurs with AO disabled too.
  The old renderer failed the new synthetic rounded-seg fixture: flat area
  16416 instead of 16448. Correcting linedef clipping removed the long slit;
  shared flat/wall vertices also removed the remaining single-pixel leaks.
- `AO_CEILING=1` validates 24 upward viewpoints at 1280×800 in both classic and
  maximum AO (100% strength, 96-unit radius): no bright sky-leak pixels in any of
  the 48 captures. Final GPU checks pass on original E1M1 and Doom II MAP01,
  including alpha rays, settings, classic restoration, stable HUD/paused output,
  moving doors (E1M1), map replacement and clean shutdown.
- All 36 Ultimate Doom and 32 Doom II geometry/material/sprite checks pass,
  alongside the original fixture, rounded-seg fixture and malformed-data checks.
- Native build 87 was independently opened with a local ceiling fixture and
  visually checked looking up with AO disabled and at 100%/96 units. The original
  build 86 game was kept running; the separate validation copy was then closed.
- Shared edge subdivisions increase E1M1's visible world mesh from 1969 to 3063
  triangles. Final paused GPU samples with validation/readback averaged about
  4.85 ms with AO and 0.17–0.19 ms classic on E1M1/MAP01. No sustained gameplay
  performance comparison or exhaustive camera sweep across every map was run.
- The native File → Load Game picker did not enable Open for the generated
  `.mdsave` fixture on this Mac. The native visual check instead used the isolated
  fixture WAD's Quick Save/Load with an upward pitch. Picker behavior remains
  outside this ceiling correction.

## AO controls, alpha testing and validator repair — build 86

- Native build 86: View strength/radius controls were exercised at 100%/96 units,
  visually checked, then returned to 50%/48 units with AO enabled in E1M1.
- Final GPU regression passes on original Ultimate Doom E1M1, Doom II MAP01 and
  a generated E1M1 MIDGRATE portal fixture. Analytic rays hit bars at distance 2,
  see the backing wall through holes at distance 4, or miss at distance 8. Tests
  verify alpha values 127/128, negative repeat UVs, changed texture masks and
  UV-only updates without rebuilding unchanged geometry.
- Strength/radius change GPU pixels and benchmark identity; zero strength and
  disabling AO both restore classic pixels. HUD remains identical, paused output
  stays stable, moving doors rebuild the mesh, and map replacement/shutdown pass.
- Sampled GPU command means at 1280×800 with Metal API validation/readback were
  about 3.8 ms on E1M1, 2.6 ms on MAP01 and 3.6 ms on the grille fixture with AO.
  These are exploratory paused-scene timings, not sustained or uncapped FPS.
  Build 83's paired benchmark below remains historical; it was not repeated here.
- The grille fixture also passes all 36 Ultimate Doom geometry/material checks.
- User report for validate-ao PID 62595 at 16:29:08 matches the harness's Swift
  focus assertion (SIGTRAP). The door fixture now drives engine tics through a
  test-only renderer bridge, independent of keyboard focus. Expected test errors
  print FAIL and exit nonzero; an intentional failing check was verified to
  exit status 1, not a signal. Native load errors no longer wait on modal alerts,
  and missing IWAD paths are rejected before compilation.

Sky and billboard sprites remain excluded as occluders. Other GPU families,
all animated WAD material combinations, GPU fault injection and complete campaign
playthroughs remain untested.

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
