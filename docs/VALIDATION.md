# Validation history and regression checks

## 2026-09-12 — 0.10.0 build 164: bundled presentation adapters

Candidate: `build/presentation-release-preview/MetalDooM.app`;
`build/build164.log`. Build161 remains in `build/presentation-preview`; earlier
bundles, running user games and private saves are preserved. Version remains
0.10.0 for this unreleased feature refinement. No push/merge was requested.

Deep/strict app signing passes, the bundle reports **0.10.0/build164**, and the
private ABI2 still exports exactly18 functions. The final executable is running
as PID4009 with its packaged worker PID4109, paused on Rust MAP06 with extras.
`build/presentation-native164.log` contains no reported errors. This verifies the
running executable path and bundle version, not an observed window/title.
Executable SHA-256: `4dc0ca5e3fdb456135ac68ca6972bed033ca2535edc2beae0b318c46e9ad6af2`.

Completed checks:

- `build/presentation-indexed-validation.log`: **1,548,288** exact GPU color
  samples, with selective brightmaps/custom tints, four primitive kinds, distance
  tables and fullbright/fixed-map/opaque/blended precedence.
- `build/presentation-assets-validation.log`: **49,152** independent sky pixels
  on fullscreen and sector pipelines, both layer mappings and index-zero
  transparency; all six effective bundled HUD definitions render distinct
  status-bar/fullscreen/native layouts. Recorded track/alias selection, muted
  AVAudioPlayer advance/pause, looping, non-looping completion, stale completion
  isolation and return to original MIDI pass.
- `build/presentation-resource-validation.log`: real engine normal/fire/layered
  skies, generated-column equality, copy/RNG invariance, authored texture/flat
  brightmaps and custom side/sector/plane/thing tint precedence.
- `build/presentation-sky-save-validation.log`: all three sky types preserve
  scroll/fire state through restore plus 28 exact future tics; four malformed sky
  save cases reject. The complete Rust save suite also passed in
  `build/presentation-save-validation.log`.
- `build/presentation-recorded-validation.log`: all 44 actual extras H_ tracks
  decode to non-silent mono/stereo PCM; truncated/malformed Ogg input rejects.
- `build/presentation-bundled-validation.log`: all 352 bundled map checks,
  distinct plan identities, component weapon pickup/firing, first/last-map saves
  and future state, texture packs and all 17 music-pack MIDIs pass.
- `build/presentation-metal-validation.log`: full classic-reference extended
  scene pixels, all 12 bundled first/last maps with extras, transfer/rotation,
  fake floors, translucent/fuzz ordering, scrolling, actor/weapon interpolation,
  actual door/lift motion and stopped-mover regressions pass.
- `build/presentation-classic-validation.log`: classic/AO/HDR effects, preset
  switching/restoration, HUD isolation, save/load and resource teardown pass.
- `build/presentation-control-validation.log` and
  `build/presentation-sky-rotation-validation.log`: 374,400 frozen fake-flat
  cases plus actual control sectors and sky/rotation/save/bounds checks pass.

- `build/presentation-worker-validation.log`: worker copy/protocol boundaries,
  all Rust scene snapshots, malformed packets, custom blend banks, per-map fixed
  row limits and hostile worker replies pass.

- `build/presentation-ui-validation.log`: UI complete-copy canaries, all Rust
  HUD/music snapshots, MIDI rendering/looping/pause, 24 malformed MUI4 packets
  and UI/view tic mismatch checks pass.
- `build/presentation-resources-final.log`: the new resource wrapper passes on
  the final worker, including all three sky types, future save state and all44
  recorded tracks.

The new repeatable entry points are `scripts/test-bundled-presentation.sh` and
`scripts/test-presentation-resources.sh`; existing test-presentation.sh remains
unchanged. The final HUD selection persistence check is recorded in
`build/presentation-save-app-validation.log`.

Native visual inspection is pending: the UI tool reported a locked Mac, and the
user has been asked to unlock it. Do not infer an observed running window/title
or final screenshot from bundle signing, offscreen GPU tests or process launch.
Full campaign playthroughs and exact software raster/stretch/fuzz parity remain
outside these targeted checks.


## 2026-09-12 — 0.10.0 build 160: indexed lighting and bundled picker

Candidate: `build/indexed-picker-preview/MetalDooM.app`; `build/build160.log`.
Bundle and running title report0.10.0/build160; deep/strict codesign verification
passes for app/helper/dylib. The private ABI2 export count stays18. Same feature
version; earlier bundles and private saves remain untouched.

- `build/indexed-lighting-validation.log`: 387,072 actual GPU samples versus an
  independent integer palette/light-table oracle, including plane/wall/actor/
  weapon depths, fixed maps, fullbright and custom blend-table precedence.
- `build/indexed-metal-validation.log`: first/last maps of all six bundled plans
  with extras use indexed lighting and match independent full geometry. Existing
  sky/rotation, control-sector, blend/fuzz, weapon and moving-surface regression
  oracles retain legacy RGB mode and pass. Separate indexed tests establish color
  correctness; neither suite is whole-frame software-renderer acceptance.
- `build/indexed-classic-metal-validation.log`: classic restoration, AO/light,
  shadows, HDR/EDR, bloom/volumetric effects, HUD isolation, presets, save/load,
  map changes and shutdown pass after the shared vertex/shader changes.
- `build/indexed-bundled-validation.log`:352 map starts/tic35 preparations across
  all content/extras plans, distinct identities, save/future state, merged texture
  and MIDI decoding, plus both component weapons' pickup/firing checks pass.
- `build/indexed-boss-validation.log`: native deaths of eight MAP13 Cyberdemons,
  one MAP14 tag666 boss and24 MAP14 tag667 bosses. Floors stay unchanged while
  a boss remains alive, then1/1,1/1 and2/2 tagged sectors lower. Test links native
  worker objects directly; production exports and gameplay remain unchanged.
- `build/indexed-control-validation.log`:374,400 frozen fake-flat/reference cases,
  actual transferred-light fixtures, copy/restore and malformed geometry checks.
- `build/indexed-save-validation.log`: native keyframes, continued simulation,
  malformed saves, copy canaries and envelope regressions pass.
- `build/indexed-save-app-validation.log`: Rust fixture plus actual MAP32 Doom II,
  weapons and music with extras. Repeated restore, music/HUD, corrupt-save/write
  recovery, Run/Pause, explicit focus-loss pause and close-during-restore pass.
  Earlier runs stopped at partial finite-step tics when desktop focus changed.
  This harness now suppresses unsolicited external focus events and deliberately
  invokes the production callback to test focus loss; production behavior stays.
- `build/indexed-picker-validation.log`: all six real picker callbacks, extras/
  base ordering, recognized Rust add-on routing, conflicting stacks and missing
  dependencies; existing folder/drop/reorder/classic callbacks also pass.

Native signed-app acceptance: build160 classic Doom II process91842 survived a
malformed `id1.wad` fixture launch; the visible alert confirmed the current game
remained available and the failed candidate exited. Selecting the real Rust plan
then launched process3898/helper3919 in id24res/Doom II/id1 order and retired91842.
Run/Pause reached MAP01tic149, health100/ammo50,283actors,25,344triangles, Sound/
Music enabled. Screenshot confirms indexed world rendering, actors, weapon and
HUD. Preview Cmd-O started a separate `--choose-wads` process6716 while Rust3898
remained paused. The UI automation binding remained attached to Rust, so the
new picker process is verified by command line rather than an additional UI grab.

Remaining full-playthrough and rendering/presentation limits are explicit in
BRANCH_ACCEPTANCE.md. No push, merge, notarization or distribution package claimed.

## 2026-09-12 — 0.10.0 build 159: bundled single-player profiles

Candidate: `build/bundled-preview-final/MetalDooM.app`; build log `build/build159.log`.
Same unreleased 0.10.0 feature version; all earlier bundles/private saves preserved.
The bundle and running window both report **0.10.0/build159**. Deep/strict
codesign verification passes for the app, helper and dylib; the dylib exposes the
same 18 private ABI2 functions. Native CLI launch uses weapons + extras on MAP01
(process **87178**, tool session **18975**). Run advanced to tic124; Pause restored
manual controls. Health100/ammo50, 43 actors, 2,384 triangles, Sound/Music checked.
A native screenshot shows the world, actors, pistol and HUD. Candidate log:
`build/bundled-preview-final/run159.log`. No claim of a full playthrough follows.

- `build/bundled-validation.log`: all six content plans with/without extras;
  352 maps at spawn/tic35, 12 distinct identities, first/last-map save/future-state
  checks (24 total, eight continued tics each), all 1,831 merged textures in each
  resource/weapon/texture plan, all 17 MIDI tracks, transparent extras TNT1A0.
  Separate id1-res/id1-weap pickup/firing fixtures exercise both replacement
  weapons, resource sprite decoding and ammo consumption with/without extras.
- `build/bundled-metal-validation.log`: native first/last maps of all six profiles
  with extras match independent full geometry; named-flat sky has 5,116 projected
  pixel probes. Existing blends/fuzz/weapon tables, transferred/control sectors,
  scrolling, camera/actor/door/lift interpolation and stopped-mover tests pass.
  These comparisons use native shaders, not software-renderer pixel acceptance.
- `build/bundled-worker-validation.log`, `build/bundled-protocol-validation.log`:
  existing Rust maps, sprites, weapons, audio, malformed snapshots and process
  deadline/boundary checks pass with the new worker.
- `build/bundled-save-validation.log`: Rust native keyframes/future state,
  malformed save, C copy canaries and Swift envelope regressions pass.
- `build/bundled-save-app-validation.log`: native Rust fixture plus actual MAP32
  Doom II, weapons and music plans with extras. Each passes two fresh-worker
  restores, HUD/music/paused controls, corrupt-save/write failure preservation,
  continued Run/Pause and close during restore. This catches the default Doom II
  lowercase music names and exercises the explicit music-pack audition track.
- `build/bundled-lifecycle-app-validation.log`: normal/secret completion, repeated
  restart, stories/credits/cast and teardown pass after resource-plan refactoring.
- `build/bundled-classic-music-validation.log`: all 35 original Doom II tracks,
  lowercase selection, native audible/silent mixer output, pitch reset, routing,
  pause/resume, mute and natural looping pass after music-name normalization.
- `build/bundled-lighting-audit.json`: 13,659 of 13,824 modeled palette/plane-light
  samples differ from pinned Woof COLORMAP output. This is a modeled baseline,
  not GPU measurement; see EXTENDED_LIGHTING.md.

During test development, the new native profile case omitted initial scene/GPU
state before a delta; it now exercises the proper initial-load/update sequence.
The save-app script initially ran the new cases before recompiling its injected
fixture harness; this caused a test-only forced-unwrap trap. The script now
compiles first and injects an optional fixture only for the Rust fixture case.
Both app harnesses were updated to inject resources through the new plan.
Native MAP32 startup then found lowercase engine music names (D_ultima);
MusicPlayer now performs case-insensitive WAD lookup. Build158 remains an
intermediate signed candidate; build159 contains the music fix.

Full campaign/boss playtesting, sustained performance, extras carousel/SBARDEF/
H_ music selection, layered/fire skies, software sky stretch and ordinary native
lighting parity remain open. Multiplayer is deferred. No new notarization,
distribution package or push is claimed.

## 2026-09-12 — 0.10.0 build 157: blending and world interpolation

Final candidate: `build/blend-motion-final/MetalDooM.app`; `build/build157.log`.
Same unreleased 0.10.0 feature version. Earlier bundles and private saves remain
preserved; no push, package or notarization was performed.

- `build/blend-motion-metal-final-validation.log`: native Metal API validation passes.
  Independent lookup oracles cover normal/additive/custom weapons and mixed
  weapon/flash slot order; 59,258 foreground-fuzz samples and 54,769 crossing
  fuzz/wall samples verify fresh backgrounds and shared ordering. Both actor
  enumeration orders, cutouts, opaque occlusion, palette/fixed-map interactions,
  all prior sky/flat/control-sector checks and 21 real Rust map/reference frames
  pass. Actual manual-door and lift fixtures render distinct start/mid/end frames;
  midpoint pixels match manually averaged planes rebuilt by the independent full
  mesher, including a pickup riding the lift. Pause restores the exact endpoint,
  and drawing never advances physics. Camera-only movement retains world buffers.
- `build/blend-motion-classic-metal-validation.log`: classic native AO, lighting,
  particles, emissive surfaces, bloom, HDR/SDR, resize, save/load, HUD isolation,
  preset persistence and restoration checks pass.
- `build/blend-motion-core-validation.log`: private-core probe verifies custom
  object/respawn tables, generated alpha references, weapon table precedence,
  fuzz priority and exclusion of uncaptured spawn endpoints. Fresh-worker restore
  produces identical presentation after 35 future tics. Invalid object/respawn
  references and malformed endpoint arrays reject before restoring the arena.
- `build/blend-motion-interpolation-validation.log`: actor/feet and front/back
  plane/clip midpoints, unbounded clips, discrete fake-flat/jump handling, camera
  and weapon discontinuities, real short teleports and saved bob continuation pass.
- `build/blend-motion-copy-validation.log`: normal/custom-bank sprite, material
  and blend complete-copy canaries pass.
- `build/blend-motion-worker-validation.log` and
  `build/blend-motion-protocol-validation.log`: all-map presentation, resource,
  real weapon, malformed packet/reference and protocol regression checks pass.
- `build/blend-motion-save-validation.log`: all sixteen Rust maps, real weapon
  states and 140 future tics remain deterministic after restore. Campaign history,
  transition saves, malformed keyframes, boundary/canary and envelope checks pass.

The final bundle and running window both report **0.10.0/build157**. Deep/strict
signature verification passes; the packaged helper library retains exactly18
private exports. Native process49468/tool session8982 runs the final executable
with actual Rust MAP14. Run, Up, Right and Escape ended paused at tic6; the manual
Step1second ended paused at tic41. The inspected screenshot shows the transferred
green sky, buildings, raised pistol and HUD, health100/ammo50,645actors and
74,768triangles. Sound and Music remain enabled. Final candidate stays paused;
launch log: `build/blend-motion-final-app.log`. Earlier processes12011/build155
and24681/build156 remain running and preserved.
Build156 remains preserved at `build/blend-motion-preview/MetalDooM.app`, paused
MAP14 tic39, process24681/tool session3209. It passed the initial native tests;
final review found a stopping-mover buffer handoff edge case, fixed in157 with
an added native regression that excludes that mover from the next geometry delta.


MSP5 extends actor40 to56 bytes and adds pose-valid flag32; header32 and weapon24
remain. Weapon records now accept blend IDs. MGE5/MBL3/MUI3/MVW5 and ABI2 remain.
Object and respawn blend references and presentation endpoints are preserved in
native saves; engine fingerprints distinguish older private saves. Actor and
surface interpolation is conservative at discontinuities. Animation/rotation,
scrolling and sky phases remain discrete. Large-map simultaneous-mover cost,
full campaign/boss playtesting, layered/procedural skies and software sky-stretch
parity remain open; this is not full campaign or software-pixel acceptance.


## 2026-09-12 — 0.10.0 build 155: sky transfers and flat rotation

Final candidate: `build/sky-rotation-release/MetalDooM.app`; `build/build155.log`.
Builds153/154 remain preserved intermediate candidates. The final version stays
on unreleased0.10.0, ad-hoc signed without notarization, packaging or push.

- `build/sky-rotation-validation.log`: seven real special271/272/2051–2056
  fixtures; sector-local sky IDs/textures/direction/offsets, scrolling, floor and
  ceiling quarter-turn UVs, combined offsets, copied-state canaries, fresh restore
  and35 future tics, stable topology and malformed full/cached sky records.
- `build/sky-rotation-metal-final-validation.log`: independent ray-projected
  texture sampling at spawn/tic35:5132 pixels for each sky orientation,5136 for
  scrolling,5112 each for floor/ceiling/both rotation and5034 for combined offsets.
  Channel tolerance is one byte for native RGB rounding; near-texel boundaries
  are excluded. Existing actor/clipping, translucent-wall, palette, seven fake-
  sector scenes,21 real-map frames, HUD, scrolling/save and interpolation checks
  also pass under Metal API validation.
- `build/sky-rotation-control-validation.log`:374,400 pinned Woof reference cases
  now include inherited control-sector rotations, plus real fake-sector/light,
  saved-continuation and selective-mesh checks.
- `build/sky-rotation-geometry-validation.log`: all32 original Doom II and16 Rust
  map geometry exports/decodes, XNOD references and14 malformed snapshots.
  Actual transferred sky planes occur on MAP01(79), MAP14(31) and MAP15(16).
- `build/sky-rotation-mesh-validation.log`, `build/sky-rotation-worker-validation.log`
  and `build/sky-rotation-save-validation.log`: retained topology/material buffers,
  exact reference meshes, all-map presentation/protocol and saved-future-state
  regressions, copied RNG/audio state and save-envelope/atomic-write checks.
- `build/sky-rotation-classic-metal-validation.log`: native classic/AO/lighting
  regression. It caught the earlier palette change's missing two-argument
  powerColor overload and stale AO buffers at plain-sprite/weapon transitions.
  Both are corrected before the final candidate. The test covers lighting/AO
  toggles, HUD isolation, geometry updates, saved effects and classic restoration.

Host deep/strict verification passes for the final app, helper and dylib. Source
Info.plist, bundled version/build, BUILD_NUMBER and the running title agree on
0.10.0/build155. Exactly eighteen private engine exports remain. Actual MAP14
launch, Run, Up/Right input, Escape pause, manual turn and stepping were exercised;
the native world, green transferred sky, raised pistol and HUD were inspected.
Left paused at tic40, health100, ammo50,645 actors, Music/Sound enabled. Earlier bundles and
paused sessions remain preserved.

MGE5 retains header120 and non-sector strides, extending sectors to140 bytes.
MBL3/MUI3/MSP4/MVW5 and the eighteen-export ABI2 remain unchanged. Native sky
perspective differs from optional software sky stretching; layered/procedural
transferred skies reject pending their adapters. Full campaign acceptance remains
separate from these controlled pixel and live preview checks.

## 2026-09-12 — 0.10.0 build 152: fake floors and transferred lighting

Candidate: `build/control-sector-preview/MetalDooM.app`; `build/build152.log`.
Final source/bundle version and build are0.10.0/152. Host deep/strict verification
passes for app/helper/dylib; eighteen exported private functions remain. No
notarization, distribution package or push; this is the same unreleased feature.

- `build/control-sector-validation.log`:374,400 cases against a frozen pinned Woof
  R_FakeFlat oracle, comparing front/back heights, texture names, offsets and
  lighting across camera boundaries and sky branches; source sectors unchanged.
  Seven actual special242/213/261 rooms check resolved values, spawn eye height,
  real collision step blocking, averaged actor light, immutable copies, fresh
  restore and35 future tics, malformed full/cached light fields and a selective
  plane-light update that rebuilds one flat chunk and retains wall materials.
- `build/control-metal-validation.log`: exact framebuffer clipping/rejection
  oracles for opaque, normal/additive/custom translucent and fuzz actors; seven
  actual control-sector frames match manually specified reference planes/lights.
  Previous wall/actor and palette oracles,21 actual Rust reference frames, HUD,
  four scroll/save phases and interpolation endpoints pass with Metal API validation.
- `build/control-geometry-validation.log`: all32 original and16 Rust map exports
  plus XNOD byte/reference checks. An initial exact reference-vertex comparison
  failed without location detail. The diagnostic rebuild and full decoder rerun
  in `build/control-geometry-final-validation.log` pass all48 maps and14 malformed
  cases; the initial mismatch was not reproduced. Exact GPU and mesh comparisons
  pass independently.
- `build/control-mesh-validation.log`: stable topology over140 tics, exact
  triangle/UV/light/sky multisets and selective-change/malformed-data checks.
- `build/control-worker-validation.log`: all16 maps and prior actor/table, palette,
  wall, weapon, audio, protocol and timeout regressions.
- `build/control-save-validation.log`: all-map future-state/keyframe regression,
  copy/RNG/audio canaries and save envelope/fingerprint/atomic-write checks.

Actual MAP01 ran in final build152. Run, Up/Right input, Escape pause and manual
Forward were exercised. Left paused at tic13, health100, ammo50,283 actors;
Music/Sound enabled. Running title confirms0.10.0/build152; screenshot shows world,
pistol and HUD intact. Earlier bundles and paused sessions remain preserved.
Control-effect pixel acceptance comes from synthetic fixtures; this does not
establish full live campaign or boss-playthrough acceptance.

MGE4 sectors now carry resolved front/back presentation, two plane lights and
actor clip limits. Existing other packet versions and ABI2 stay. Native lighting
and tic-discrete sector presentation retain the limits in EXTENDED_CONTROL_SECTORS.md.

## 2026-09-12 — 0.10.0 build 151: translucent walls and palette effects

Candidate: `build/wall-palette-preview/MetalDooM.app`; `build/build151.log`.
Source and bundled version/build are 0.10.0/151. Host deep/strict verification
passes for app/helper/dylib; eighteen private engine exports remain. The feature
stays on its unreleased 0.10.0 version, ad-hoc signed without a release package.

- `build/wall-palette-worker-validation.log` and final
  `build/wall-palette-worker-final-validation.log`: default/custom/tagged wall
  assignment, indexed meshes, restart and fresh restore; damage, bonus, berserk,
  suit, invulnerability and light-amplification selection plus saved continuation;
  twelve malformed blend/color packets and missing wall/palette/map references;
  existing custom actor tables, sixteen maps, weapon, material, audio and protocol
  cases. Final rerun includes the added resource-boundary cases.
- `build/wall-palette-metal-validation.log`: Metal API validation; exact palette
  flash/removal and fixed-map/translucent oracles; crossing wall/billboard ordering
  with 27,403 actor-front and 28,122 wall-front pixels; previous 25,724 actor overlap
  and 104,636 opaque-occluder checks. Twenty-one actual Rust reference images,
  real HUD palette probes/removal, four scrolling/save frames and interpolation
  endpoints pass without Metal errors.
- `build/wall-palette-geometry-validation.log`: all32 original Doom II and all16
  Rust maps, XNOD geometry and malformed snapshots with MGE3 line stride24.
- `build/wall-palette-mesh-validation.log`: exact reference meshes, stable topology
  over140 tics, selective changes and malformed cached data. An initial compile
  overlapped a documentation-comment edit; the clean rerun passes.
- `build/wall-palette-ui-native-validation.log`: all16 tracks/HUD states, native
  MIDI PCM, controls and24 malformed MUI3 packets. Initial sandbox AVMIDIPlayer
  initialization failed; the compiled test passes on the native host. Physical
  speaker audibility was not separately established.
- `build/wall-palette-save-validation.log`: all-map future-tic/keyframe regression,
  copied-state/RNG/audio checks and save envelope/atomic file replacement.

Final build151 launched on actual MAP01. Run, Up/Right, manual Forward/Turn/Step
and Escape pause were exercised. World, pistol and HUD screenshot inspected;
left paused at tic18, health100, ammo50, 283actors, Music/Sound enabled.
Running title confirms151.
The effect pixel evidence comes from controlled fixtures; full live campaign
acceptance remains outstanding. Earlier bundles and paused sessions are preserved.

MGE3/MBL3/MUI3 replace their earlier versions. MVW5/MSP4 and ABI2 stay unchanged.
This engine change alters private-save fingerprints; keep old bundles for old
saves. Remaining presentation limits are documented in EXTENDED_TRANSLUCENCY.md
and EXTENDED_PALETTES.md.

## 2026-09-12 — 0.10.0 build 150: custom per-state actor tables

Candidate: `build/custom-blend-preview/MetalDooM.app`; `build/build150.log`.
Same unreleased 0.10.0 feature version, ad-hoc signed and not notarized/packaged.
Host deep/strict verification passes for app/helper/dylib; source and bundle
version, BUILD_NUMBER and running title agree. Exactly 18 private exports remain.

- `build/custom-blend-worker-validation.log`: copied-buffer canaries for a custom
  bank; exact custom table bytes and shared IDs; custom state precedence over
  opaque/default-additive flags, with fuzz taking precedence; a second table
  first used after two tics; fresh restore plus eight subsequent state/ID checks;
  restart; maximum 64-table bank/ID; invalid IDs, absent references, short/long
  tables and excessive count rejection. All sixteen actual Rust maps and existing
  gun-frame, rotation, material, audio and framed-worker regressions pass.
- `build/custom-blend-metal-validation.log`: Metal API validation, exact
  normal/additive/custom pixel oracles with 25,724 overlapping pixels and both
  actor enumeration orders, shaded foregrounds, cutouts, 104,636 opaque occluder
  pixels, walls and fuzz precedence. Also 21 exact real-map reference images,
  HUD hide/restore, four scrolling/save-phase comparisons and camera/weapon
  interpolation endpoint checks. No Metal validation errors.
- `build/custom-blend-save-validation.log`: full private-save regression, including
  all sixteen maps and 140 future tics each, campaign/death/malformed keyframes,
  copied-state/RNG/audio checks, fingerprint/envelope checks and atomic writes.

Final bundle launched with the explicit Rust command on actual MAP01. Native
Run, Up/Right input and Pause were exercised; left paused at tic164, health100,
ammo50, 283 actors, Music/Sound enabled. The running title shows 0.10.0/build150;
world geometry, pistol and HUD were inspected in the screenshot. Earlier bundles
and sessions remain preserved. Custom table pixel evidence is from controlled
fixtures, not a claim that a full live Rust campaign has been accepted.

MBL2 now contains 2–64 tables, bounded to 4,195,088 bytes. MSP4 retains strides,
using actor flag bits 8–15 for custom IDs. Per-object tables and weapon/wall
blending remain unadapted, as do palette/fixed-colormap effects and other world
presentation gaps. See EXTENDED_TRANSLUCENCY.md for exact scope and contract.

## 2026-09-12 — 0.10.0 build 149: Rust translucent actors

Candidate: `build/translucency-preview/MetalDooM.app`; `build/build149.log`.
Same unreleased 0.10.0 feature version; ad-hoc signed, not notarized or packaged.
Host deep/strict signature verification passed, including helper/dylib. Source
Info.plist, bundled version/build, BUILD_NUMBER and the running title agree.
The final dylib exposes exactly the 18 names in Engine/Extended/exports.txt.

- `build/translucency-worker-validation.log`: complete-copy/short-buffer canaries
  for sprite/material/blend packets; exact supplied TRANMAP bytes, a distinct
  additive table, normal/fullbright-additive/shadow selection, seven malformed
  blend packets, and rejection of malformed/custom tables. Existing protocol,
  all-sixteen-map startup/tic35, rotations, Rust gun frames and audio checks pass.
- `build/translucency-metal-validation.log`: native Metal with API validation,
  exact normal/additive palette-oracle output across 25,724 overlapping pixels,
  both actor enumeration orders, source-index and shaded-foreground paths,
  cutouts, 104,636 opaque occluder pixels, wall occlusion and fuzz precedence.
  Also 21 exact real Rust reference-frame comparisons, HUD hide/restore,
  floor/ceiling/both/reverse scrolling and saved phase, and distinct interpolated
  start/mid/end with exact Pause pixels. No Metal validation errors.
- `build/translucency-save-validation.log`: private-save/campaign/death/malformed
  snapshot regressions, all sixteen maps and 140 future tics per restored map,
  unchanged copied state/RNG/audio, envelope fingerprints and atomic file writes.

The first diagnostic GPU oracle disagreed on four pixels because opaque test
colors coincided with their background, making the test's visibility mask
ambiguous. Distinct RGB control colors removed that ambiguity; original palette
indices still select the intended blend colors. The final oracle passes exactly.

Native app verification used the final bundle's explicit `--rust-preview` mode
on actual MAP01. Running title is 0.10.0/build149. Run, Up/Right input and Pause
were exercised; left paused at tic48, health100, ammo50, 283 actors, Music/Sound on.
The screenshot shows intact world geometry, pistol and HUD. Older candidates and
saved sessions were preserved. Translucency's detailed visual evidence comes from
the controlled GPU checks, not a claimed live Rust campaign playthrough.

Normal/additive actor blending is implemented. Native RGB lighting still differs
from software colormap rendering. Custom actor tables, wall/weapon blending,
palette powerups, fake-floor/control-sector/sky effects and actual campaign/boss
acceptance remain ahead; see EXTENDED_TRANSLUCENCY.md.

## 2026-09-12 — 0.10.0 build 148: Rust camera/weapon interpolation

Candidate: `build/interpolation-final/MetalDooM.app`; `build/build 148.log`.
Local ad-hoc build, unnotarized and unpackaged. Previous bundles/saves are preserved.

- `build/interpolation-validation.log`: exact midpoint camera/weapon/flash
  coordinates, shortest 359°→1° yaw, clamped endpoint, pause/resume and nine
  discontinuity cases. A real short walk-over teleport sets MSP2's snap flag.
  Actual MAP01 walking exhibits existing view/weapon bob, restoring the same phase
  and continuing identically for 35 more tics.
- `build/interpolation-metal.log`: a deterministic test clock renders distinct
  start/middle/end images from two real movement snapshots. Pause equals the
  endpoint image and remains fixed; world buffers retain identity and the worker
  tic is unchanged. The previous 21 Rust reference comparisons, HUD restoration,
  four scrolling pixel/readback cases and saved phase checks also pass.
- `build/interpolation-native.log`: actual app Run/Pause after repeated save loads,
  paused controls/music, corrupt-save and write-failure preservation, subsequent
  audio/stepping and close during pending restore all pass.
- `build/interpolation-worker-regression.log`: updated MSP2 malformed version/flag
  rejection, all-map worker/render/audio and transport/cancellation checks.
- `build/interpolation-save-regression.log`: all-map and weapon/transition save
  continuation, malformed files, copied state and envelope boundaries.
- `build/interpolation-clock.log`: existing one-tic playback pacing and pause/
  in-flight boundary behavior.

The earlier handoff incorrectly described basic bob as absent: G_BindWeapVariables
already enables engine bob and the copied psprite coordinates carry it. This
change interpolates presentation; it adds no simulation bob or engine commands.
MSP2's marker reads the existing player mobj interpolation flag, including actual
short teleports. The parent needs no distance-only guess for those transitions.

Continuous presentation can lag by up to one tic. Actors, moving surfaces, weapon
animation frames, audio and HUD still update on their original tics; this is not
whole-world interpolation or sustained full-campaign performance acceptance.
Manual buttons remain exact snapshots. See EXTENDED_INTERPOLATION.md for limits.

## 2026-09-12 — 0.10.0 build 146: Scrolling Rust floors/ceilings

Final candidate: `build/scroll-preview/MetalDooM.app`; `build/build146.log`.
Host deep/strict signature verification passes. Bundle plist and running window
report 0.10.0/build146. Actual MAP01 Step 1 second reaches tic35, health100,
ammo50 and283 actors; the native screenshot shows intact world, pistol and HUD.
It remains paused with Music/Sound on. Build145 and its earlier save remain
preserved. This local candidate is ad-hoc signed, unnotarized and unpackaged.

- `build/scroll-validation.log`: five original rooms cover floor-only, ceiling-only,
  combined, reverse-direction and carry scrollers. Check per-tic offset direction/
  speed, signed/fractional periodic UVs, cached/full decode parity, one rebuilt flat
  chunk per tick and no wall changes, idle copies, save phase/future continuation,
  restart and MGE1 rejection. Texture-only scrolling leaves player position fixed;
  carry still moves the player.
- `build/scroll-metal.log`: real Metal readbacks for all four texture-scroll cases
  differ from an identical stationary-flat scene, match full reference meshes,
  and restore pixel-for-pixel from a save. Wall buffer identities remain unchanged.
  At 1280x800, floor-only changes 837,941 bytes, ceiling-only 776,939, combined
  1,614,880 and reverse 1,615,394. The existing 21 sampled MAP01/MAP13/MAP16 images
  also match the reference; HUD hide/restore checks pass.
- `build/scroll-mesh.log`: existing 140-tic cache/full-mesh comparisons and dynamic
  sector/side/topology mutation tests pass, retaining one BSP build per map.
- `build/scroll-geometry.log`: 32 classic Doom II and16 Rust maps, all XNOD reference
  checks and14 malformed full/cached packet cases. Updated the old bad-version
  fixture from version2 (now valid) to version3.
- `build/scroll-worker-regression.log` and `build/scroll-save-regression.log` retain
  all-map worker/render/audio/protocol checks, save continuation and malformed
  file/copy boundaries with MGE2.

Simulation already advanced scroller offsets; MGE1 omitted them. MGE2 carries
four extra sector words. The plane UV signs follow pinned Woof r_plane.c; period64
wrapping retains texture phase while reducing large UV additions. Constant and
carry fixtures are covered; displacement/accelerative scrollers share these
fields but do not yet have dedicated moving-control-sector tests. The classic
Sector defaults stay zero. The full-mesh oracle retains its original triangulation
with only the new plane-offset expression added.

Remaining: flat rotation, interpolation/bob, palette/TRANMAP translucency,
control-sector/fake-floor/sky effects, full boss/campaign playthrough acceptance,
and ordinary picker support. No extras.wad or sibling-pack support is implied.
See EXTENDED_SCROLLING.md for wire layout, lifecycle and compatibility limits.

## 2026-09-12 — 0.10.0 build 145: Native Rust save/restore

Final candidate: `build/save-preview/MetalDooM.app`; `build/build145.log`.
The bundle passes host `codesign --verify --deep --strict`; plist and running title
report **0.10.0/build 145**. It is ad-hoc signed, unnotarized, with no distribution
package. Previous 144 and older bundles remain intact.

Actual MAP01 file-dialog validation: Fire 1 second reached tic 35/ammo 48. Save…
wrote `build/save-test/build145-MAP01.mdrust` (1,098,261 bytes); independent parsing
confirmed MRS1, tic/map/ammo, payload checksum and the packaged engine fingerprint.
Another Fire 1 second reached tic 70/ammo 46. Load… restored tic 35 paused; the
raised native-window screenshot showed the matching world, firing pistol frame,
health 100 and 48 bullets. Sound/Music remained enabled. The app is left at that
restored state. The save stays private/ignored under build/.

Automated evidence:

- `build/save-validation.log`: all sixteen maps, Incinerator and Calamity Blade
  fixtures, and a MAP16 Use sequence. Each compares complete geometry, materials,
  actor/weapon/UI state immediately after load and after another 140 tics.
- Five post-transition saves cover actual pickups, normal routes, both secret
  entries and secret returns. Inventory/history and different global/level clocks
  survive a new worker. Future-state comparisons pass. These are exit-room probes.
- Thirteen malformed raw JSON cases bypass the parent checksum to test worker
  validation. Late/repeated restore rejects. C size/short-buffer/full-copy canaries
  and repeated saves prove no snapshot/RNG mutation or drained audio. Swift tests
  cover eight envelope failures, resource/engine fingerprints, checksum, bounded
  file reading, round trip and atomic replacement.
- `build/save-native.log`: actual app code with fixture resources passes repeated
  independent worker loads, subsequent audio/stepping, paused controls/music,
  corrupt-save and write-failure preservation, and closing during pending restore.
- `build/save-core.log`: 17 private exports, native dependency isolation, original
  core movement/combat/conveyor and patch rejection regressions.
- `build/save-worker-regression.log`: existing copied audio/render/UI, all-map
  worker checks and malformed packet/cancellation regressions, plus invalid save
  body and empty/oversized/truncated restore protocol requests.

The first-frame test caught missing upstream material-translation arrays; native
save fields now preserve them. The Calamity Blade case caught valid removed arena
objects outside the active thinker list; only deletion types may be unlinked.
Brain-target and MUSINFO references are repaired after thinker arena replacement.
The upstream JSON file was imported from the existing pinned Woof commit.

These tests do not establish full campaign/boss playthrough acceptance, arbitrary
save fuzzing coverage, cross-build compatibility or physical speaker audibility.
Saves are live-level only; loading clears old sample tails/input and restarts the
selected music track. Autosaves, demo/upload work and ordinary picker acceptance
remain outside this milestone. See EXTENDED_SAVES.md for the full contract.

## 2026-09-12 — 0.10.0 build 144: Native Rust intermissions and finales

Final candidate: `build/campaign-preview/MetalDooM.app`; `build/build144.log`.
Host deep/strict signature verification passes for app, helper and dylib; bundled
plist and native window title both report **0.10.0/build 144**. Actual MAP01 Fire
1 second completes at tic35/ammo48/284 actors. Restart returns to tic0/health100/
ammo50/283 actors, Paused, Sound/Music on. Raising the native window confirms the
refreshed Metal world/HUD; the app remains open in that fresh paused state.

- `build/campaign-validation.log`: C metadata size/short-buffer/full-copy canaries,
  deterministic repeated JSON, unchanged simulation snapshot/RNG and undrained
  gameplay audio FIFO. All sixteen normal and both secret exits with original
  campaign metadata in small test rooms. Correct names/pictures, visited markers,
  statistics completion, selected arrow directions, 23/11 blink timing and 140-tic
  entering duration. Both stories, CREDIT, all seven custom cast alive/death
  cycles and looping back to Ghoul. D_DM2INT/D_SHORES/D_DEJAVU selection and the
  declared nonlooping finale flag. Six malformed metadata mutations per route and
  thirteen malformed interlevel/finale schema/frame/condition/sound cases reject.
- `build/campaign-test/*.png`: native AppKit bitmap readbacks, including secret
  entering maps, both story screens, credits and each cast member. Inspected
  orientation, palette, original pixel aspect, patch anchoring and legibility.
  Rust's TNT1A0 transparent sentinel is handled for both interlevels and cast.
- `build/campaign-native.log`: actual app controller with injected fixture stack,
  native statistics/entering controls, independent presentation pause/resume,
  Continue to paused MAP02, death/restart, MAP07 story/credits and MAP14 story/cast,
  patched cast effects scheduled through Core Audio, correct MIDI selections,
  repeated restart/step and close during pending world replacement.
- `build/campaign-protocol.log`: framed request validation, including op5 during
  play and nonempty op5 rejection. Existing view/command packet versions remain.
- `build/campaign-worker-regression.log`: existing all-map worker/sprite/material
  and sound tests, malformed packets, no replay after geometry requests, and
  timeout/oversized/wrong-sequence/truncated-reply cancellation checks pass.
- `build/campaign-core.log`: exactly fifteen private exports, native dependencies,
  repeatable ticks, patched combat, Boom conveyor and explicit rejection cases.

No full campaign or boss-kill playthrough is claimed by these exit-room fixtures.
Nonlooping finale music is checked as declared/selected; no new duration/pitch
measurement is claimed. Full death-camera playback, broader ID24 presentation,
extended save/restore and ordinary picker acceptance remain pending. Older app
bundles and the notarized 0.9.0/build124 release are preserved. No game data or
release package is committed, and nothing is pushed or uploaded.

## 2026-09-12 — 0.10.0 build 143: Death/restart and native campaign transitions

Final candidate `build/lifecycle-complete/MetalDooM.app`, **0.10.0/build 143**,
`build/build143.log`; host deep/strict signature and bundled plist pass, and running
CUA title agrees. Preserve intermediate 141 (`build/lifecycle-preview`) and 142
(`build/lifecycle-final`), the previous 140, and the primary notarized 124 release.
This remains the same unreleased 0.10.0 Rust feature refinement.

Passed logs under build/:

- `lifecycle-validation.log`: original rooms with real normal/secret exit switches,
  using unmodified Rust UMAPINFO. All 16 normal routes and both secret routes pass;
  MAP02→15→03, MAP10→16→11 and MAP07/MAP14 endings are explicit. Pickups establish
  health 200/armor 100/shotgun/ammo/key state; Continue preserves inventory and clears
  keys, loads full new-map geometry at tic 0 and resets counters. Repeated Restart
  restores health 100/armor 0/pistol 50 and identical initial world bytes. A real
  damaging floor causes death at 129; batches stop and Restart restores tic 0.
  Invalid Continue during play rejects.
- Secret-route tests exposed native bootstrap's missing haswolflevels flag; set
  from MAP31 presence exactly as upstream d_main does. Normal-route testing also
  caught upstream default-on autosave; the native Continue wrapper disables it.
  These fixes are in final143. No save format or files are introduced.
- `lifecycle-native.log`: same AppKit/Metal preview source with original fixture
  paths/helper injected only in test copies. Real completion/death panels disable
  gameplay and expose appropriate actions. Continue updates map/geometry/HUD/music
  to MAP02/D_SHORES, paused at0. Repeated restart/step resets HUD, input, music and
  sound sequencing. Closing during a queued replacement drains the worker and
  suppresses its eventual UI reply. The initial test's immediate Use was correctly
  ignored by upstream spawn debounce; test now advances release tics before Use.
- `lifecycle-worker.log`: current wire/copy/cancellation/deadline tests and all 16
  map resources, sprites/materials, audio FIFO/order/RNG regression checks. Adds
  invalid lifecycle action and malformed action-length requests.
- `lifecycle-ui.log`: all 16 map music/HUD selections, native MIDI PCM and lifecycle,
  inventory/copy canaries,24 malformed MUI2 packets and view/tic mismatch. Native
  music PCM peak 0.07998366; physical speaker audibility is unverified.
- `lifecycle-core-regression.log`: fourteen private exports, native dependencies,
  MBF21 movement/combat/conveyor/rejections, session/ID24 fields, all 16 real Rust
  map startups and actual Rust weapon/fuel pickup probes.

Signed native143 MAP01: Fire1second finishes at 35, ammo 48 and 284 actors. Clicking
Restart level returns to0, ammo 50 and 283 actors with health 100/armor 0 and the initial
world/camera/pistol HUD. Music/Sound remain enabled and playback stays Paused.
The running screenshot verifies the controls and reset presentation. Death and
completion UI are exercised in the native fixture harness; full actual-map exits
and boss kills are not inferred from these route tests.

No classic simulation, rendering or music implementation changed in this milestone;
build 140's native classic/GPU evidence remains recorded below. The lifecycle adapter
reuses the same extended simulation routines, without general G_Ticker demo/save/UI
dispatch. Full camera-fall/death animation, XWINTER/XFINALE/CREDIT presentation,
actual boss-trigger/campaign playthroughs and versioned saves remain ahead. No push
or release packaging. Contract: EXTENDED_LIFECYCLE.md.

## 2026-09-12 — 0.10.0 build 140: Rust HUD and native level MIDI

Final candidate `build/ui-preview/MetalDooM.app`, **0.10.0/build 140**,
`build/build140.log`. Host deep/strict signature verification covers the app,
worker and dylib; bundled plist and running CUA title agree. Version remains
0.10.0 as a refinement of the unreleased Rust feature. Previous candidates and
the primary notarized 0.9.0/build 124 release remain preserved.

Passed checks (logs under build/):

- `ui140-native.log`: all 16 worker track names match independently read UMAPINFO;
  every supplied score decodes into Apple's MIDI player with positive duration;
  initial HUD health100/armor0/ammo50/keys0 and stable music generation after 35
  tics. The original pickup fixture adds armor100 and two key bits. C complete-copy
  canaries and sixteen malformed MUI1 cases plus view/tic mismatch pass.
- The same suite renders a short original MIDI fixture through the native mixer,
  peak **0.07998366**. Nonloop completion, natural looping, paused position,
  resume, independent enablement and unchanged classic Apple/OPL preference pass.
  Physical speaker audibility and every complete Rust score playback are unverified.
- `ui140-metal.log`: native **1280×800** HUD-visible/hidden/restored readbacks;
  28,316 changed health/armor pixels and 17,860 weapon/ammo pixels, confined to
  the bottom HUD region, with exact restoration. All **21** optimized/full-reference
  GPU comparisons across MAP01/13/16 pass with Metal API validation. Unchanged
  material buffers retain identity. Native load means 0.50/3.22/0.25 ms respectively;
  these remain isolated scene-load measurements, not full frame timing.
- The new HUD test initially caught its own conflicting requested 640×400 versus
  GameView's restored 1280×800 Retina drawable. It now settles layout, uses native
  resolution, releases stale drawables, asserts dimensions and reads actual pixels.
  No application change was needed for that test failure.
- `ui140-worker.log`: current MVW5 protocol, deadline/cancellation, all-map resources,
  sprite/material/audio malformed boundaries, FIFO/canaries and capture RNG parity.
  `ui140-core.log`: exact thirteen private exports and MBF21/session/ID24/all-map/
  actual Rust weapon and fuel pickup regressions.
- `ui140-effects.log`: actual Rust Incinerator/Blade PCM, pickups, MAP16 switches,
  stereo/stop/mute/cancellation, one-tic synchronization and pending-reply pause;
  native device-output tap peak **0.49497473**.
- `ui140-classic-music.log`: all 35 Doom II tracks, native PCM/volume, measured
  controller/pitch reset, pause/resume/mute/track change/natural looping.
  `ui140-classic-opl.log`: deterministic OPL PCM, invalid bank, native pause/resume,
  mute and track-preserving Apple/OPL switching.
- `ui140-classic-hud.log`: Classic/Minimal layouts, health/armor/ammo and six keys,
  all face states and portrait toggle, HUD sizing, world-scale independence,
  MetalFX/supersampling, HDR/SDR transitions and exact restoration.

Native CUA MAP01: Step shows tic14 then stops at35. Music off with Sound on plus
Fire 1 second ends at70, bullets50→47; the rendered HUD and diagnostic state agree.
Music on, Run and weapon1 switch to FIST; Escape pauses at179 with the ammo group
hidden. Final state: health100/armor0, Sound/Music enabled, Paused. The toolbar fits
and weapon/world presentation remains visible. Tests establish the sequencer's
pause/mute behavior; screenshots alone do not establish audibility.

New protocol/presentation details: EXTENDED_UI.md. Full SBARDEF/sky/palette effects,
MUSINFO triggers, intermission/finale/campaign routing, death/restart and versioned
saves remain unaccepted. The ordinary Rust picker guard stays. No push/package.

## 2026-09-12 — 0.10.0 build 139: Incremental geometry and Metal reuse

Final candidate `build/mesh-final/MetalDooM.app`, **0.10.0/build 139**,
`build/build139.log`; host deep/strict signature and bundled plist pass. Preserve
intermediate 138 (`build/mesh-preview`) and prior 137. The semantic version remains
0.10.0 as another refinement of the unreleased Rust feature.

The first profile separated MAP13's roughly 37 ms worker/decode cost from 183 ms
mesh construction. The first three tics changed 13 sector lights and 920 side
UV offsets, with no floor/ceiling movement. Cached wire decoding, static clipping/
stitching, affected line/sector chunks and selective material uploads address
those costs without reducing the triangle set. Full static mutation invalidates
and rebuilds the cache. New details are in EXTENDED_MESH.md.

Final 140-tic worker/CPU means/p95/max (`build/mesh139-performance.log`):

| Map | Old mean | New mean | New p95 | New maximum |
| --- | ---: | ---: | ---: | ---: |
| MAP01 | 12.52 ms | 2.12 ms | 2.69 ms | 4.52 ms |
| MAP13 | 210.57 ms | 20.56 ms | 24.03 ms | 28.16 ms |
| MAP16 | 4.27 ms | 0.87 ms | 1.06 ms | 2.33 ms |

All 140 tics per map change geometry; static topology builds once. MAP13 improves
about 10.2×. The earlier prototype measured 17.64 ms; final measurement includes
the live preview open. These CPU samples exclude Metal and do not prove sustained
35-tic/s full campaign play. Full wire copies and whole changed-material buffers
remain possible future optimization targets.

Passed checks:

- `mesh139-geometry.log`: 32 Doom II + 16 Rust maps compared with a frozen build-137
  full-mesh implementation, MAP13 XNOD export parity, fourteen malformed cases
  with and without cached decode. The baseline Set/single-axis sort can produce
  ~1e-15 near-zero differences between identical runs; CPU comparison normalizes
  only sub-micro-unit zeros. The new algorithm uses deterministic tie breaks.
- `mesh139-parity.log`: six sampled tics each on MAP01/13/16 match reference
  triangle/UV/light/sky multisets; synthetic height, pegging/offset/material/sky/
  light changes and restoration; cached invalid names/references reject; static
  mutation rebuilds; unchanged explicit geometry request changes no materials.
- `mesh139-metal.log`: Metal API validation enabled, **21 exact GPU image matches**
  to unmodified reference meshes at 640×400. Unchanged GPU buffers preserve object
  identity. Native scene load means: MAP01 0.40 ms, MAP13 3.39 ms (max 4.15), MAP16
  0.18 ms. MAP13 retains 6,130 of 7,776 observed material buffers. No in-flight
  buffer mutation is used: changed materials get fresh buffers.
- `mesh139-worker.log`: complete worker/protocol, all sixteen scene/material/
  sprite/weapon, audio/copy/queue and malformed/deadline regressions pass.
- `mesh139-classic.log`: synthetic malformed WAD checks, original Ultimate Doom
  nine-map geometry/material checks and 483 sprite/HUD patches pass.

Native CUA build 139 MAP13: initial 508,713 triangles, 1,412 actors, health 100;
Step displays tic 12 then exactly 35; Run/E/F reaches 46/ammo 49; Escape pauses at
280 with geometry retained. Raised screenshot shows the rendered corridor/pistol.
Final app is left there, Sound enabled. One short observed continuous interval
advanced 234 tics over about 7.7 seconds including tool overhead; this is not an
instrumented sustained-rate benchmark. Prior preview instances are preserved.

Music/HUD, full presentation, campaign/restart/save acceptance and ordinary picker
support remain unchanged. No push, packaging, data upload or speedrun work.

## 2026-09-12 — 0.10.0 build 137: Continuous Rust scene/audio playback

Final candidate: `build/continuous-final/MetalDooM.app`, **0.10.0/build 137**,
`build/build137.log`. Intermediate 136 is preserved at `build/continuous-preview`.
Version remains 0.10.0 as a refinement of the unreleased Rust feature. Worker
source/ABI/protocol and classic renderer/audio are unchanged. The final app adds
a local Escape handler so button-focused manual steps can be interrupted too.

`scripts/test-extended-playback.sh` passes (`build/continuous136-validation.log`):

- Deadline pacing, one in-flight request, late-work backpressure without catch-up
  debt, exactly 35 finite commands, pause during pending work and fresh resume.
- 140 consecutive scene/audio tics and firing on real MAP01, MAP13 and MAP16.
  Every sampled tic changes copied geometry and rebuilds the mesh.

| Map | Worker + CPU preparation mean | p95 | Maximum |
| --- | ---: | ---: | ---: |
| MAP01 | 12.52 ms | 13.93 ms | 15.98 ms |
| MAP13 | 210.57 ms | 227.59 ms | 250.40 ms |
| MAP16 | 4.27 ms | 5.11 ms | 6.37 ms |

These are 140-tic local samples after startup, excluding native Metal upload and
rendering. They do not establish full-rate gameplay. MAP13 is decisively over the
28.57 ms simulation budget; incremental geometry/light updates are the next task.
Playback slows instead of stacking requests, dropping tics or bursting old input.

Native `scripts/test-extended-audio.sh` passes
(`build/continuous136-audio-validation.log`):

- One-tic audio presentation immediately schedules each scene's starts and renders
  PCM at exact pistol event tics 39/53/67. There are no delayed preview callbacks.
- Duplicate snapshots reject. A pending reply after pause advances the cursor
  silently without restarting the mixer; mute suppresses starts, resume/unmute
  accepts later tics and future starts. Prior batch cancellation tests still pass.
- Incinerator/Blade/pickup/switch/movement, stereo, mute and stop checks pass.
  The native device tap measures peak 0.49497473; physical hearing is unverified.

Live build 136 checks (same playback/audio code, before the final Escape handler):
manual Step shows intermediate tic 14 and stops at exactly 35. Run + keyboard E/F
opens MAP16 geometry and consumes ammo 50→49. Escape pauses at tic 249; another
run accepts movement/turn/weapon input and proceeds into combat. Minimizing pauses
at tic 906. Command-Tab/AX Raise did not reliably transfer native focus in CUA, so
those actions are not accepted as app-switch evidence. Closing exits app 9761
and child 9782 and removes their private scratch directory. Final 137 native
verification confirms bundled plist/CUA title 0.10.0/build 137 and host deep/strict
signature. Manual Step + Escape interrupts at tic 4, the next Step displays 18
then stops at 39, muted firing displays 49 then stops at 74/ammo 47. Sound on +
Run advances to 87 and Escape pauses at 91. Final MAP01 stays paused, health 100,
Sound on, with Run ready. No death/restart or full campaign acceptance implied.

Continuous controls are still an explicit development preview. Full HUD/music,
interpolation/palette/ID24 presentation, campaign transitions, restart and saves
are not accepted. The ordinary picker guard stays in place. No push or packaging.

## 2026-09-12 — 0.10.0 build 135: Rust sound effects and native playback

`scripts/test-extended-worker.sh` passes the previous 16-map scene/sprite/material/
weapon/transport checks plus MSA1 FIFO canaries, undersized-query preservation,
complete-copy drain, explicit 4096-event overflow, no replay on geometry requests,
independent left/right pistol channels, and thirteen malformed audio/order packets.
Two processes produce byte-identical player/actor snapshots across 200 combat tics
with capture disabled/enabled. `scripts/test-rust-worker.sh` passes all prior
MBF21/session/ID24/map/weapon checks with twelve private exports. Logs:
`build/audio134-worker-validation.log`, `build/rust134-validation.log`; the worker
code is unchanged in final 135, which refines parent-side explicit mute.

Native `scripts/test-extended-audio.sh` passes (`build/audio135-native-validation.log`):

- Three pistol starts at exact tics 39/53/67 after attack begins at 35, including
  the upstream four-tic wind-up. Native PCM is nonzero and bounded; stereo energy
  follows left/right pan, explicit mute prevents playback, and stop clears a voice.
  Cancelling a scheduled batch suppresses pending start/completion callbacks and
  leaves the mixer paused.
- Actual Incinerator events render DSINCBRN, DSINCFI1–2, DSINCHT1–3 and DSWPNUP.
  Full-charge Blade events render DSHETCHG, DSHETSHT, DSHETXPL, DSITEMUP and DSWPNUP.
- Actual MAP16 switch/movement events render DSSWTCHN and DSSTNMOV.
- A short live pistol produces device-output tap peak **0.49497473** while the
  AVAudioEngine is running. This proves output data, not physical speaker audibility.

An intermediate gain-only mute check returned peak 0.6746114 despite the offline
mixer reporting outputVolume=0. Final mute explicitly stops voices and suppresses
new starts, so it does not rely on that gain behavior. Existing classic/menu PCM,
pause/resume and malformed-DMX regression passes in the native host context
(`build/classic135-audio-validation.log`, pistol peak 0.49468824).

Final app: `build/audio-final/MetalDooM.app`, **0.10.0/build 135**;
`build/build135.log`. Host deep/strict signature verification covers app/helper/
dylib, and bundled plist/CUA title agree. CUA verifies Sound on, MAP16 Step → Use
→ Step (35→36→71), Sound off, firing to 106/ammo 47, and controls disabled during
batch playback then restored. Sound is left on. Raise the preview before visual
inspection: an occluded Metal window can retain its previous rendered surface.
Intermediate 134's separate bundle is preserved; only its test instance was closed.

Playback presents the completed scene then auditions the batch's timed events;
sound tails finish naturally while simulation is stopped. Normal pitch, simplified
channel priority/attenuation and DMX-only samples are explicit limits. Music,
ambient loops, alternate sound formats, synchronized continuous play, full
presentation and campaign/save acceptance remain ahead. No game data, generated
bundles or fixtures are committed; no upload or distribution package was produced.

## 2026-09-12 — 0.10.0 build 133: Rust material animation and scene reuse

`scripts/test-extended-worker.sh original-doom2.wad /path/to/rerelease` passes
all 16 initial/tic-35 scenes and actor/weapon decodes, rotation/firing regressions,
C complete-copy canaries for sprite/material records, nine malformed sprite and
ten malformed material packets, material/view tic mismatch and existing process/
deadline/error/cancellation checks. The original static room verifies every tic
through 65: NUKAGE1–3 and FIREBLU1–2 match the engine's phase, no geometry is sent,
one mesh is built and repeated snapshots leave image/sprite decode counts stable.

MAP16's switch test verifies changed floor/ceiling heights and four mesh builds
(startup, released tics, press, later motion). The fixture must first release the
spawn use latch; pressing Use on the very first tic is intentionally ignored by
the upstream player logic. Comparing triangle count alone did not establish motion;
the final assertion compares heights. Logs: `build/material133-validation.log`.
The full MBF21/private-symbol/session/ID24/all-map/weapon suite passes with ten
exports (`build/rust133-validation.log`). Classic Doom II checks pass all 32 maps,
502 materials and 1381 sprite/HUD patches (`build/classic133-validation.log`).

The separate explicit build succeeds as **0.10.0/build 133** at
`build/material-preview/MetalDooM.app` (`build/build133.log`). Host deep/strict
signature verification passes; bundled plist and CUA running title agree. Native
checks cover classic MAP01 monsters/pistol/HUD, Rust MAP01 console-art changes
at the unchanged camera across tics 0/35/70/105, and MAP16 switch opening after
Step → Use → Step (35→36→71). The preview is left on MAP16. The native check does
not independently prove every animated flat/frame; those have decoding/phase tests.

Unchanged scenes now reuse CPU/GPU resources. This is not a frame-rate benchmark:
worker comparison still traverses full geometry, and any geometry change rebuilds
the complete mesh. Partial moving-sector updates, scrolling flats, full sky/control-
sector/palette/translucency effects, audio and continuous campaign/save acceptance
remain ahead. No WADs, bundles or generated fixtures are committed; older previews
and the primary release are preserved. Nothing pushed or packaged for distribution.

## 2026-09-12 — 0.10.0 build 132: native Rust actor and weapon frames

`scripts/test-extended-worker.sh original-doom2.wad /path/to/rerelease` passes
complete-copy C canaries, worker request/error/deadline/cancellation checks, all
sixteen scene/material/sky and actor/weapon decodes at startup/tic 35, eight
camera-relative rotations and mirrored pairs, and nine malformed MSP1 packets.
Actual Rust test rooms decode 16 Incinerator frames (ammo 20→16, up to four visible
projectiles) and 31 full-charge Blade frames (ammo 70→20, separate flash, up to
15 visible actors). Absent TNT1 invisible helpers do not contribute to presentation
counts. Log: `build/presentation132-validation.log`.

`scripts/test-rust-worker.sh` passes the full MBF21/private-symbol/session/ID24/
all-map/weapon suite with nine private exports (`build/rust132-validation.log`).
`scripts/test.sh /Users/wmh/Downloads/doom2.wad` passes all 32 classic maps,
502 materials and 1381 sprite/HUD patches (`build/classic132-validation.log`).

The explicit preview build succeeds (`build/build132.log`) at
`build/actor-preview/MetalDooM.app`. Host deep/strict signature verification and
bundled Info.plist confirm 0.10.0/build 132; CUA confirms the running title.
Native visual checks cover classic MAP01 monsters/pistol/Minimal HUD, Rust MAP01's
corpse and raised pistol at tic 35, and firing/muzzle flash at tic 70 with ammo
50→47. MAP16's starting switch at tic 5 opens the surrounding geometry by tic 40;
the resulting world/sprite/weapon scene is left awaiting manual input.

These checks do not prove every monster/new-gun animation, palette/TRANMAP
translucency, fake-floor clipping, weapon bob/interpolation, audio or continuous
play. New Rust guns have automated decoding evidence only. Full campaign, saves
and moving-world performance remain ahead. Prior preview bundles and the primary
0.9.0 release are preserved; no upload or distribution package was produced.

## 2026-09-12 — 0.10.0 build 131: isolated worker and native Rust world preview

`scripts/test-extended-worker.sh original-doom2.wad /path/to/rerelease` passes:
framed startup, movement/tic/geometry identity, cancellation, EOF/graceful quit,
sequence/length/operation/truncation/reserved-byte rejection and client deadline/
bad-reply handling. All sixteen Rust maps resolve every world material and sky
through the ordered resource plan. Incorrect base identity rejects. Flat/patch
name collisions TCMFLRE/F resolve separately. Log: `build/worker130-validation.log`.
The final 131 refinement only adds the Use button to the same tested transport.

The prior MBF21/session/ID24/map/weapon suite passes with eight private exports
(`build/rust130-validation.log`). Classic Doom II's 32-map geometry/material/sprite
suite passes (`build/classic130-validation.log`). Build 131's app/helper/dylib
signature and bundled 0.10.0/build 131 version are verified in the host context;
CUA window title confirms the running final build. Log: `build/build131.log`.

Native CUA acceptance: intermediate 130 renders classic Doom II MAP01 and Rust
MAP01 (23,396 textured triangles, SKYX1) plus MAP13 (508,713 triangles, SKYX4).
MAP01 Forward updates tic 0→8 and changes the rendered camera; left turn reaches
9 and visibly rotates. Closing its window exits helper PID 30630 and removes the
observed private worker scratch directory. Final 131 renders MAP13 and handles
Forward 0→8→16, Use→17 and Step 1 second→52. The panel in front of this spawn is
solid scenery; no door-open success is claimed. The preview remains on MAP13.

This is world-only rendering: no actor/weapon/HUD/audio presentation, complete
Boom/ID24 visual parity, campaign or save acceptance. All geometry is rebuilt on
manual actions, so screenshots/GPU overlay samples are not real-time simulation
performance results. Normal picker Rust guard and earlier build 126–129 previews
remain; primary 0.9.0/build 124 is preserved. No package/upload/speedrun work.

## 2026-09-12 — 0.10.0 build 129: shared geometry and XNOD parity

`scripts/test-extended-geometry.sh original-doom2.wad /path/to/rerelease` passes:
all 32 original Doom II maps agree between the classic and worker paths on wall
endpoints, BSP partitions/children, subsector sectors and native triangle counts.
All sixteen Rust maps decode into the shared map and produce finite CPU meshes.
MAP13: 37,547 vertices, 76,284 segs, 32,993 leaves, 32,992 nodes, 508,713 triangles
with default texture heights. Independent byte-level XNOD checks verify references
and original wall endpoints. Engine-projected split vertices are intentionally
retained. Fourteen malformed snapshot cases reject; copied-buffer capacity,
nonmutation, repeated equality and canaries pass. Full contract/limits:
[EXTENDED_GEOMETRY.md](EXTENDED_GEOMETRY.md). Log: `build/geometry129-validation.log`.

The existing classic geometry/material/sprite suite passes for all 32 Doom II
maps (`build/geometry-classic.log`). The full MBF21/session/ID24/map/weapon suite
passes again with seven private exports (`build/rust129-validation.log`). No
live Rust visuals, audio, moving-sector presentation or frame-time acceptance.

Native host build/signature verification succeeds. The bundled plist and CUA
window/menu footer show **0.10.0/build 129**, with rendered classic Doom II MAP01.
`build/geometry-milestone/MetalDooM.app` is left paused, preserving previews
126–128 and the primary 0.9.0/build 124 release. Log: `build/build129.log`.
No package, upload or speedrunning work; GUI Rust guard remains.

## 2026-09-12 — 0.10.0 build 128: Rust sessions, fields and native worker probes

`scripts/test-rust-worker.sh original-doom2.wad /path/to/rerelease` passes. It
rebuilds the native worker, reruns the full existing MBF21 suite, then verifies:

- Base identity independent of resource position; GAMECONF null/max/order behavior;
  content hashes invariant under relocation but sensitive to order, base role and
  profile; malformed WAD/configuration and unsupported dependency/translation/
  option/feature rejection. ID24 remains gated behind the explicit Rust profile.
- Correct pickup amounts/default and BEX-replaced messages, invalid field values,
  unknown mnemonic rejection; corpse delay/dice defaults and Rust values. With
  seed 1993, death tic 4 gives respawn tics 97 (64/255), 2145 (2100/64), and 1601
  (420/4). The reference comparison/prose discrepancy is documented.
- Actual installed Rust 1.2 stack (id24res → Doom II → id1, base index 1): 203 actor
  types/1543 states; 35 idle tics in each of the sixteen campaign maps. MAP13 uses
  XNOD and has 1437 live actor snapshots. Selected UMAPINFO secret/return routes,
  boss-action counts and MAP14 XFINALE1 metadata match the campaign declarations.
- Actual Rust patch/resources on original fixture geometry: fuel can/tank +10/+50;
  Incinerator 12-tic fire 20→16 fuel/4 maximum concurrent projectiles; Blade tap
  20→10/6 projectiles, 25-tic hold 20→0/12, and full 85-tic charge 70→20/30.
  These fixtures retain player health 100. They are not complete combat parity.

Primary log: `build/rust128-validation.log`. Per-case logs and generated fixtures
are in `build/extended/`, excluded from Git. The separate worker has six private
API exports and only system dependencies. Full ID24, all monster/map behaviors,
Swift XNOD geometry, native Rust graphics/audio, boss/exit execution, campaign
presentation and extended saves remain unverified/unimplemented as detailed in
[EXTENDED_ENGINE.md](EXTENDED_ENGINE.md). The GUI Rust guard is unchanged.

Native build 128 succeeds in `build/rust-milestone/MetalDooM.app`; host signature
verification passes, and bundled plist/CUA title/footer show 0.10.0/build 128.
CUA inspected rendered classic Doom II MAP01 and the open menu; it is left paused.
This is classic app validation, not a native Rust playthrough. Builds 126/127 and
the primary notarized 0.9.0 build 124 release remain preserved. Build log:
`build/build128.log`. No release packaging, upload or speedrunning work was done.


## 2026-09-12 — 0.10.0 build 127: extended-worker bootstrap

`scripts/test-extended-engine.sh /path/to/original/doom2.wad` passes on arm64:
private exports/system-only dependencies, two-worker actor snapshot determinism,
35-tic movement, extended Thing 500/Frames 1100–1201, flags 518/1, patched pistol
ammo 50→48 and target health 200→193, Boom conveyor motion without input, both
wrong-signature callback directions, and targeted malformed/unsupported rejection.
The installed Rust campaign rejects at GAMECONF/ID24. Logs are
`build/extended-validation.log` and `build/extended-rust-rejection.log`.

The worker is a separate headless target. This evidence does not establish Rust
playability, native rendering/audio, extended saves or full Boom/MBF21/ID24
compatibility. [EXTENDED_ENGINE.md](EXTENDED_ENGINE.md) records the exact boundary.

`scripts/test-presentation.sh` passes with original Ultimate Doom, including wall/
flat animation phase restoration and face-state behavior. A native host app build
in `build/extended-milestone/MetalDooM.app` succeeds as 0.10.0/build 127; host
codesign verification passes. CUA inspected rendered Doom II MAP01 and its open
menu, with version/build visible in both title and footer. The app remains paused.
The separate build 126 resource preview process remains running. Build logs:
`build/build127.log`, `build/classic-presentation127.log`. No packaging or upload.


## 2026-09-12 — 0.10.0 build 126: Rust resource foundation

The isolated `codex/legacy-of-rust` branch starts at main merge afd7357. This is
the first resource milestone, not playable Rust or general ID24 support.

- Read-only audit: `python3 scripts/audit-rust.py RERELEASE_DIRECTORY` produced
  `build/rust-audit.json`. Hashes, sibling comparisons, MAP99 classification,
  XNOD MAP13 and engine requirements are recorded in `LEGACY_OF_RUST.md`.
- `test-resource-tables.sh` passed on original Ultimate Doom and rerelease Doom II:
  absent/default and empty/replacement tables, last-lump precedence, 41 animations,
  85/86 active pairs, game scopes, absent resources, arbitrary pair names, copied
  output capacity, 4/32-tic phases, original button activation, cross-map save
  restoration and reset on the exact remaining tic. Thirteen malformed cases per
  base return ordinary errors: zero/negative/swirl rates, bad kinds/cycles/endpoints,
  truncation, absent terminators, invalid names and switch scopes. One-byte and
  four-byte ANIMATED terminators also pass. Log: `build/resource-tables-results.txt`.
- With `RUST_BASE` and `RUST_TEXTURES` pointing to Doom II and installed id1-tex,
  the same script generates a private resource-only IWAD. All actual 49 animations,
  85 switch pairs, four-frame NUKAGE and 4/8/32 rates initialize/tick successfully.
  This fixture uses classic base maps and has no Rust actors, patches or maps;
  it does not establish Rust gameplay compatibility.
- `test-kex-campaign.sh` passes all 9 NRFTL, 21 Master Levels and 9 SIGIL II maps,
  including resource/music decoding, boss rules, normal/secret routes and saves.
  Logs: `build/kex-*.wad.txt`. SIGIL II exercises its real four-byte ANIMATED
  terminator and flame definition; no hardcoded flame table remains.
- `test-stack.sh` passes all nine standard SIGIL maps plus ordered override/save
  identities and namespace/partial-map guards (`build/stack-results.txt`).
  `test-presentation.sh` passes classic animation/face/save checks
  (`build/presentation-results.txt`).
- Native `test-ambient-occlusion.sh` passes the full existing Metal/effects suite,
  including masked geometry, all optional effects, HUD isolation, exact classic
  restoration, HDR/SDR transitions, save/load, resize, map replacement and shutdown.
  Evidence: `build/resource-metal-validation/results.txt` and image captures.
- `AO_RESOURCES=1 test-ambient-occlusion.sh build/resource-native-fixtures/preview.wad`
  passes a focused native GPU test. A non-SW1/SW2 switch counterpart absent from
  sidedef geometry is preloaded; paused frames match; four tics change 626,964
  readback bytes; save/load restores identical animation pixels. Captures/save/log:
  `build/resource-specific-metal/`. Fixture generator: `Tests/make_resource_fixture.py`.
- Full native build 126 succeeds; bundle and live native title/menu footer both
  show 0.10.0/build 126. CUA inspected the private E1M1 fixture's rendered walls,
  floor, HUD and pause menu. Preview remains paused in the isolated worktree.

The initial fixture wrongly named BRNBIG (and assumed a flame frame count); direct
texture-directory inspection corrected it to shared STARTAN2/STARTAN3 and the
three actual FIREWALA/FIREWALB/FIREWALL frames. The first reader required a full
ANIMATED terminator and failed SIGIL II; support for its short marker fixed that
regression before build 126. Sandboxed icon generation failed; the native host
build succeeded. Neither issue is being reported as a passing intermediate build.

No full Rust campaign run, extended engine build, ID24 conformance, new Apple
notarization or distribution package was completed. Original classic archive
format is unchanged; extended simulation saves remain a later milestone.


Historical results below describe the indicated builds, not complete compatibility guarantees.
See [TESTING.md](TESTING.md) for current tester instructions.

## 0.9.0 refinement, build 124 — Optional Minimal HUD portrait

- Full build and strict signature verification pass; native window and bundle
  plist confirm 0.9.0 build 124. Same unreleased feature milestone/version.
- Original Ultimate Doom and KEX Doom II `AO_RESOLUTION=1` suites pass with Metal
  API validation: all 42 face indices render; god/dead faces differ from neutral;
  portrait on/off restores exact pixels; the setting leaves Classic unchanged.
  Portrait-inclusive masks preserve native artwork at all four HUD sizes and all
  world scales, including HDR, with unchanged world/weapon geometry. Preference
  writes, transparency, resize, effects and invisibility checks pass.
- Evidence: `build/hud-portrait-validation`, `build/hud-portrait-kex-validation`.
  These are renderer checks, not new gameplay/face-state logic; the existing engine
  supplies faceIndex. Physical HDR brightness and other GPUs remain untested.
- Native NRFTL preview confirms readable Options → HUD layout, portrait toggle,
  transparent face beside health, and persisted enabled state after relaunch.
  `build/hud-portrait-preview/MetalDooM.app` is left fullscreen at Minimal 50% with
  portrait on. Other game instances were preserved.

## 0.9.0 refinement, build 123 — Transparent Minimal HUD

- Full build and strict bundle-signature verification pass; native app title and
  bundle plist confirm 0.9.0 build 123. This continues the unreleased resolution
  feature milestone, so its semantic version remains 0.9.0.
- `AO_RESOLUTION=1` passes with Metal API validation for original Ultimate Doom
  and the KEX Doom II IWAD on M5 Pro. The test-only copied renderer can suppress
  HUD drawing to compare the identical full-height world against actual overlay
  pixels. All four sizes preserve world/weapon pixels, show the bottom-edge world,
  and preserve foreground artwork through 50/75% upscaling and 150/200%
  supersampling. Classic restores exactly. Synthetic HUD captures cover six keys,
  health/armor, ammo, zero values and melee without ammo. Minimal HDR foreground
  equality, finite HDR bounds, resizing and invisibility rendering pass.
- Evidence: `build/minimal-hud-validation` and `build/minimal-hud-kex-validation`.
  Screenshots were inspected; timing output is not a performance claim. Physical
  HDR brightness, other GPUs and cross-display transitions remain unverified.
- Native CUA checks in NRFTL MAP01 verify the actual fullscreen and windowed
  transparent overlay, readable menu layout, in-game style selection, native size
  selection, and remembered Minimal/50% settings after relaunch. A separate
  `build/minimal-hud-preview/MetalDooM.app` preserves existing game instances.

## 0.9.0 refinement, build 122 — Adjustable HUD status bar

- `AO_RESOLUTION=1` passes with Metal API validation on the M5 Pro. All four
  status-bar sizes produce the expected geometry, reclaim world height, preserve
  exact resized HUD pixels across native/MetalFX/supersampled world scales, and
  restore the original pixels at 100%. The preference writes and invalid-value
  fallback are checked. Compact HDR HUD equality, HDR/SDR changes, effects,
  weapon invisibility and resize also pass. Evidence: `build/hud-scale-validation`
  and `build/hud-scale-validation.log`. Timing output is not a performance claim.
- Build 122 is signed and its plist is valid. Native CUA confirms the running
  version/build, Options → HUD control, native View menu, 50% KEX bar in fullscreen,
  return to windowed presentation, and the persisted choice on preview restart.
  Original 320-wide art is covered by GPU tests; the native preview uses the wide
  KEX STBAR in No Rest for the Living.
- The first validation launch caught preference initialization before Renderer
  existed (build 121). Build 122 initializes the renderer first and passes startup.
- A separate `build/hud-size-preview/MetalDooM.app` was used; the previous game
  instance was preserved. Preview is left paused with 50% HUD size. The underlying
  setting is shared by normal launches. Other displays/GPUs remain untested.
- This is a refinement of the unreleased 0.9.0 resolution feature milestone;
  semantic version stays 0.9.0 and historical changelog entries are retained.

## 0.9.0, build 120 — World resolution and bundled KEX profiles

- Final local app build 120, version 0.9.0; bundle signature and plist validated.
  Native inspection covered NRFTL MAP01 (build 116), Master Levels MAP20 (119),
  SIGIL II E6M1 and its episode menu (119/120). World scale 50% MetalFX and 200%
  supersampling retained native 2200×1520 output and sharp HUD/menu artwork.
  Build 120 only aligns the filtered episode menu beneath its heading.
- `AO_RESOLUTION=1` passes on the M5 Pro with Metal API validation: 50/75% nearest
  and MetalFX, 150/200% supersampling, exact HUD equality, stable paused output,
  exact Classic restoration, all effects, weapon invisibility, HDR/SDR changes,
  finite bounded HDR and resize. Evidence: `build/resolution-validation`.
- The existing full Ultimate Doom Metal suite including `AO_CEILING=1` passes:
  alpha rays/grilles, 48 ceiling views, lighting/particles/bloom/volume, HDR transfer,
  presets/custom settings, menu controls, save/load, map replacement and shutdown.
  Evidence: `build/resolution-full-regression` and its `.log`.
- At equal 2200×1520 output with Medium HDR, fixed paused E1M1 and API validation
  off, 32 GPU samples give native median/p95 5.672/7.076 ms, 75% MetalFX
  4.571/6.094 ms and 50% 3.119/5.451 ms. The 1280×800 Medium test with API validation
  enabled was slower with MetalFX than native. See `docs/RESOLUTION.md` and
  `build/resolution-profile`; no universal or sustained gameplay FPS claim.
- `test-kex-campaign.sh` passes for all nine NRFTL, 21 Master Levels and nine
  SIGIL II maps: geometry, material/sprite resolution, sky/music/name metadata,
  MUS/MIDI data, normal/secret routing, inventory continuation, story/cast or
  episode ending, every-map save round trip, modified-edition and base-map rejection.
  It additionally verifies disabled MAP07 boss actions, Master Levels boss floors,
  SIGIL II spider health/disabled boss exit and its extra flame-wall animation.
  Logs: `build/kex-{nerve,masterlevels,sigil2}-validation.txt`.
- Master Levels MAP20 has no sector tagged 667, despite declaring that boss action;
  the test initially failed by expecting one. The correction verifies the actual
  map's no-op rather than inventing floor movement. Existing engine REJECT-padding
  notices are printed for some Master Levels maps; map/resource/save tests pass.
- Doom II gameplay/progression/boss checks, SIGIL stack/sprites/routes/saves,
  all TNT/Plutonia maps/routes/music/stories/saves and native input/console parsing
  regressions pass. WADs, binaries, captures and local logs remain ignored.
- Remaining boundaries: full manual campaign playthroughs, every original sound
  mix, other rerelease revisions, other GPUs/OS releases, physical HDR luminance
  and cross-display scale/headroom transitions have not been established.
  Legacy of Rust/ID24 and optional resource-pack precedence are still incomplete;
  multiplayer/catalog features are outside the user's selected single-player scope.

## 0.8.0, build 115 — Pre-merge test dependencies

- The supplied GitHub log fails while compiling `test-input.sh`: its explicit
  source list included Renderer but omitted newer effects and level-stats types.
  Extract GameView unchanged into its own production file, and compile only that
  file for the input test. Remove unused renderer dependencies from test-audio.
- All three exact no-WAD workflow commands pass locally: `test-input.sh`,
  `test-console.sh`, `test-testing-metrics.sh`. Input assertions exercise actual
  AppKit events, queued taps/holds, Escape, focus clearing and drawable scaling.
- `test-audio.sh` with Ultimate Doom passes pistol/menu PCM, pause/resume and
  malformed DMX checks. The full app build succeeds as 0.8.0 build 115. Compare
  the extracted GameView class against HEAD: its body is byte-for-byte unchanged.
- An isolated native build-115 preview loads E1M1 and responds to Escape with the
  pause menu; window and menu footer both display the expected version/build.
  Close the temporary preview afterward. No full GPU rerun was needed for this
  unchanged class move. GitHub Actions must rerun after the fix is pushed;
  local validation does not establish hosted runner success.

## 0.8.0, build 114 — In-game effects presets

- Build and signed bundle report 0.8.0 / 114; `codesign --verify --deep --strict`
  and Info.plist lint pass. `scripts/test-classic-menu.sh` passes existing sound,
  keyboard, disabled-row navigation, editing and scaled hit-target checks.
- `build/presets-114-validation/results.txt` passes the Ultimate Doom Metal API
  validation suite. Added actual pause-menu routing, names, keyboard highlight
  without application, changing descriptions/accessibility help, explicit Enter
  and mouse-button application, paused HDR/SDR transitions, benchmark guard and
  explanation, preserved graphics/custom data, live Custom status and Escape back.
  Existing AO/shadow/HDR bounds, HUD isolation, save/load, mesh replacement and
  shutdown checks pass. Build 113 also passed before the live status refinement.
- CUA verifies the running build-114 title and Options/Effects layout in E1M1.
  Confirm all five labels and readable descriptions, Classic remaining active
  while Medium is highlighted, Enter applying Medium, click applying Medium HDR,
  and View → HDR Fullbright Sprite Boost changing the current label to Custom.
  Command-Shift-E restores Classic; Escape returns to Options. The paused native
  preview is left on Options in Classic. Screenshots do not establish HDR luminance.
- Preset settings are unchanged: Enhanced → Medium, Atmospheric → High,
  HDR Showcase → Medium HDR. Medium HDR keeps High's effects, not Medium's set.
  The in-game scope is the five built-ins; individual effect controls and saved
  custom actions remain in View. No new controlled performance comparison.

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
