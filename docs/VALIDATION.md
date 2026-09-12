# Validation history and regression checks

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
