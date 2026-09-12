# MetalDooM handoff — 2026-09-12

## Where to resume

Current development checkout: `/Users/wmh/.codex/worktrees/c0e4/MetalDooM`, branch
**codex/legacy-of-rust**, based on fetched origin/main merge **afd7357**. Preserve
`/Users/wmh/Dev/MetalDooM` and its release artifacts. Current feature version is
**0.10.0**, final successful build **139**. This remains the same unreleased Rust
feature; do not bump the minor version for each refinement.

The explicit Rust preview now has **cached geometry and selective Metal updates**,
plus Run/Pause and keyboard/mouse controls, with
one-tic world/actor/weapon/material/audio presentation. Manual buttons show every
tic too. Keep the ordinary Rust picker guard until full campaign acceptance.
No speedrun/demo/upload work was requested; that idea remains a future aside.

Read [preview/process contract](docs/EXTENDED_PREVIEW.md),
[incremental geometry](docs/EXTENDED_MESH.md), [audio](docs/EXTENDED_AUDIO.md), [materials/cache](docs/EXTENDED_MATERIALS.md),
[sprites](docs/EXTENDED_SPRITES.md), [geometry](docs/EXTENDED_GEOMETRY.md),
[worker](docs/EXTENDED_ENGINE.md), [validation](docs/VALIDATION.md) and
[roadmap](docs/LEGACY_OF_RUST.md).

Build with `METALDOOM_EXTENDED_PREVIEW=1 METALDOOM_BUILD_DIR="$PWD/build/mesh-final" bash scripts/build.sh`.
Launch with `--rust-preview /path/to/rerelease --map MAP01` (through MAP16).
Only the explicit option packages/signs the helper/dylib and notices. Standard
builds remain classic. Ordered resources are id24res → Doom II → id1, base index 1;
the parent verifies their identity. WADs/generated bundles stay private/ignored.

Controls: Run, WASD movement/strafe, arrows turn/move, Shift run, E/Space Use, F
Fire, 1–7 weapons, click captures horizontal mouse aim and subsequent clicks fire.
Escape or Pause stops playback/audio and clears input. Focus loss/minimizing also
pauses. Build 137 adds a local Escape monitor for manual/button-focused steps;
continuous input still uses GameView, with no classic gameplay code changes.
No vertical look, interpolation or weapon bob. Manual buttons retain their prior
8/1/35 tic counts and turn size; Run uses normal turn acceleration.

`ExtendedPlaybackClock` permits only one in-flight worker request, targets 35
simulation tics/s and discards elapsed wall-time debt when late. Slow work slows
simulation rather than queuing commands or skipping tics. Pause cancels wakeups;
a pending reply may still present its already-computed tic silently. Run stays
unavailable until that reply settles. Resume clears input and starts a new deadline.
The native audio `present` path accepts tic 0 then consecutive single tics, applies
events immediately with the scene and rejects replay/gaps. This is tic-aligned
presentation, not sample-accurate hardware timing. Old timed `play` remains for
diagnostics only. Finite steps allow natural sample tails; explicit pause stops
voices/mixer. Closing/error cancels future work; termination reaps the child and
removes scratch. Sound mute stops/skips voices; unmute only plays future starts.

**Build 139 completes the first geometry optimization.** `ExtendedGeometry` reuses
validated static arrays only after exact identity/count/static-byte matches and
validates changed side/sector records. `GeometryTopology` caches BSP clipping,
stitched flat triangles and wall-edge points; `ExtendedMesh` rebuilds affected
linedef/sector chunks (including neighbors), assembling changed materials only.
`changedMaterials` tells Metal which vertex/sky buffers need replacement;
unchanged buffers retain identity, changed buffers allocate fresh memory for GPU
safety. Static arrays or side-sector membership changes rebuild topology. No wire
or engine-source changes; all existing compatibility boundaries remain.

The final 140-tic worker/CPU check averages **2.12 ms MAP01, 20.56 ms MAP13,
0.87 ms MAP16**, versus **12.52, 210.57, 4.27 ms** previously. MAP13 p95 24.03 ms,
max 28.16 ms; static topology builds once across 140 changing snapshots. Native
scene loading separately averages **3.39 ms MAP13**, with 21/21 exact reference
GPU images across MAP01/13/16. Initial prototype was 17.64 ms CPU; final sample
had the live preview open. Do not present this as sustained full campaign rate.
Full MGE1 copy/compare and whole changed-material uploads remain future costs.

**Next: music/HUD and campaign presentation**, alongside targeted monster/map
special parity. Keep measuring actual continuous scenes before promising 35 tics/s
across maps. Scrolling flats, interpolation/bob, palette/translucency/control-sector/
sky effects, death/restart, episode/boss/secret routes and saves remain outstanding.

Final tests: `mesh139-performance.log`, `mesh139-parity.log`,
`mesh139-geometry.log`, `mesh139-worker.log`, `mesh139-metal.log`,
`mesh139-classic.log`, all under build/. Reference parity covers 32 Doom II + 16
Rust maps, six dynamic samples on each of MAP01/13/16, synthetic height/light/
offset/material/sky changes/restoration and cached malformed/static mutation.
The old reference's Set ordering occasionally changes ~1e-15 near-zero values:
CPU tests normalize only sub-micro-unit zeros; the optimized code has deterministic
ties. Native GPU tests compare actual unmodified vertices and match every pixel.
Unchanged material buffers retain identity; MAP13 retains 6,130/7,776 observations.

Final candidate `build/mesh-final/MetalDooM.app`, **139**, log `build/build139.log`.
Host deep/strict signature and bundled plist pass; native CUA title matches.
MAP13 shows all **508,713 triangles**, Step displays tic 12 then exactly 35,
Run/E/F reaches 46/ammo 49 and Escape pauses at 280. Left **MAP13 tic 280,
health 100, ammo 49, Sound on, Paused**. Host identity: app PID 17906, bundled worker PID 17939.
The earlier 137 preview was preserved.
Intermediate 138 is in `build/mesh-preview`; do not replace older bundles.

The following 137 playback/audio evidence remains applicable to unchanged code.

Tests pass: `build/continuous136-validation.log` (clock deadlines/backpressure,
exact finite lengths, pause/resume, 140 consecutive scene/audio tics and firing
on MAP01/13/16) and `build/continuous136-audio-validation.log` (native synchronized
pistol PCM tics 39/53/67, duplicate rejection, silent pending reply after pause,
mute/resume, prior cancellation and both Rust weapons/pickups/switches/stereo/stop,
live device-output tap peak 0.49497473). Physical speaker hearing is unverified.
Build 137 only changes the parent Escape handler; tested clock/audio/worker code
is unchanged from those logs. Prior all-16-map/core logs remain
`build/audio134-worker-validation.log`, `build/rust134-validation.log`; prior
classic PCM regression is `build/classic135-audio-validation.log`.

Live build 136: intermediate manual frame at tic 14 then exact 35, MAP16 Run + E/F
switch opening/ammo 50→49, Escape pause, subsequent combat and minimize pause.
Closed test app/worker 9761/9782 exit and scratch disappears. Command-Tab/AX Raise
did not prove app focus transfer in CUA; minimizing did exercise automatic pause.
Raise the preview before screenshots to avoid an occluded Metal surface.
Previous native candidate is `build/continuous-final/MetalDooM.app` (137), with
`build/build137.log`. Host deep/strict signature verification and bundled plist
confirm 0.10.0/build 137. Final CUA title agrees: manual Step + Escape stops at
tic 4, another Step shows tic 18 then exactly 39, muted Fire 1 second shows tic 49
then exactly 74/ammo 47, Sound on + Run advances to 87 and Escape pauses at 91.
That earlier app was left **MAP01 tic 91, health 100, ammo 47, Sound on, Paused**.
Host process identity: app PID 40471, its bundled worker PID 40500.
Run is ready for the user; do not automatically leave combat running.

Worker ABI 2 remains twelve private exports; engine source and wire layouts are
unchanged. The Swift geometry decoder adds the validated cache described above. Opt-in `ME_EnableAudio` precedes init and `ME_CopyAudio` copies/drains MSA1
only on complete copy. MVW4 header52 has optional MGE1, required MSP1/MMT1/MSA1.
One separate process owns each session; never load its dylib in the Swift app.
Existing capture has 32 origin/singularity channels, DMX samples, fixed normal
pitch, Euclidean attenuation and safe unlink positions. Capture consumes no RNG.
Missing/invalid samples, ambient/random/loop definitions and overflow fail.
Music/ambient playback remains absent; sound_events is requests, not audibility.

Next complete music/HUD/campaign presentation, scrolling
flats, bob/interpolation, palette/TRANMAP translucency, control-sector/fake-floor/
sky effects, targeted monster/map-special parity, boss/secret routes, JSON
presentation and versioned saves. Death/restart and full campaign play remain
unaccepted; use a fresh explicitly launched session for now.

Preserve all older candidates: `build/mesh-preview` (138), `build/continuous-final`
(137), `build/continuous-preview` (136), `build/audio-final`
(135), `build/audio-preview` (134), `build/material-preview` (133), `build/actor-preview`
(132), `build/geometry-milestone` (129), `build/rust-milestone` (128),
`build/extended-milestone` (127), `build/MetalDooM.app` (126).
The 0.9.0 build 124 release was separately notarized in a prior task (Apple request
121f1db9-34a4-4f5f-aeb3-599a59de0727); release ZIP remains in primary checkout
`build/releases/MetalDooM-0.9.0-build124/`. Builds 126–139 are ad-hoc signed,
unnotarized and unpackaged. No push/publish/upload/Apple submission performed.

The remaining sections are historical.

## Latest refinement — Optional Minimal HUD portrait (build 124)

Options → HUD → Doomguy portrait and View → Doomguy Portrait in Minimal HUD control
a remembered, default-off portrait. It uses the engine faceIndex and the same
42 face patches as Classic, drawn with a shadow beside health. Counters shift right
when enabled; disabling restores the prior Minimal pixels. It scales with HUD size,
leaving world and weapon unchanged. Classic ignores this preference. Version stays
0.9.0 as another refinement of the unreleased HUD/resolution feature milestone.

## Latest refinement — Transparent Minimal HUD (build 123)

Options → HUD → HUD style and View → HUD Style select remembered Classic / Minimal.
Classic remains the default. Minimal overlays native WAD health/armor on the left,
current ammo on the right and both owned cards/skulls above it, with black pixel
shadows and no background panel. The world fills the entire bottom strip. The
shared 25/50/75/100% setting controls artwork only in Minimal; its weapon uses a
bottom-anchored 200-line canvas independent of HUD size. Original Classic rendering
restores exactly. This is another refinement within unreleased 0.9.0.

## Latest refinement — HUD status-bar size (build 122)

The user found the health/status bar too large in fullscreen. Options → HUD and
View → HUD Status Bar Size now offer persistent 25/50/75/100% sizes. Default 100%
restores the original; smaller sizes keep the complete bar centered and reclaim
vertical world space. Nearest-sampled artwork stays native-output sized regardless
of world scale. The minimum is one output pixel per source pixel. This refines
unreleased 0.9.0; no new semantic release/tag was made.

## Resolution enhancements

The user chose **both** sharper output and upscaling performance. Implemented:

- Native-size drawable and native weapon/HUD/menu/intermission composition.
- World scales 50/75/100/150/200%; optional device-gated MetalFX spatial below
  native, nearest fallback, four-tap filtered supersampling above native.
- HDR linearization around MetalFX, preserving the existing final EDR mapping;
  native weapon invisibility snapshot, world effects before scaling, original
  camera aspect, buffer replacement on resize/format/mode changes.
- Esc → Options → Display and View → Graphics Presets controls; console scale
  values and benchmark identity updated. No temporal scaling/frame generation.

See `docs/RESOLUTION.md`. Pixel tests preserve the HUD exactly and restore Classic
exactly. Full Metal/effects/ceiling regressions pass. Local 2200×1520 Medium HDR
GPU medians: native 5.672 ms; MetalFX 75% 4.571 ms; 50% 3.119 ms. Small-scene
MetalFX overhead can be slower than native. These are paused-scene GPU samples,
not sustained gameplay FPS. Physical HDR and cross-display backing-scale changes
remain unverified. API/device checks used the local macOS 27 SDK and M5 Pro.

## Additional KEX campaigns

The user explicitly chose **bundled single-player content**; multiplayer and the
online add-on catalog are outside this work. Three dedicated rerelease profiles
are implemented: **No Rest for the Living**, **Master Levels**, **SIGIL II**.
Load Doom II + nerve.wad/masterlevels.wad, or Ultimate Doom + sigil2.wad, one
campaign add-on at a time. All 39 maps pass resource, music-decoding, progression,
secret-route and save tests. Boss tests cover disabled MAP07 behavior, Master
Levels tag-666 floors and SIGIL II's 9,000-health spider/disabled boss exit.
SIGIL II's extra FLMWAL01–03 animation is registered in the engine animation table.

The profiles use full-file hashes of the installed rerelease editions; renamed
files work, other/edited editions stay rejected. Metadata supplies names, music,
skies and ending text; this is not general UMAPINFO/DeHackEd support. Campaign maps
are filtered in selectors and engine loads/saves. Inherited base demos are disabled
for these profiles. See `docs/KEX_SUPPORT.md` for the complete inventory and limits.

**Legacy of Rust remains unsupported.** Its GAMECONF declares ID24, extended
actors/states/weapons, MBF21 rules, animated/switch resources and intermission
animation. Do not assume the id1* family is one additive load order; GAMECONF's
pwadfiles/dehfiles are null. Audit id24res/extras and optional resource/music
replacements before defining the next implementation milestone. There are 17 map
blocks in installed id1.wad despite its 16-level description. Do not claim complete
KEX support or relax rejection guards based on loading a level.

Installed data remains under:
`/Users/wmh/Library/Application Support/CrossOver/Bottles/Steam/drive_c/Program Files (x86)/Steam/steamapps/common/Ultimate Doom/rerelease/`.
Never commit these files, generated fixtures or bundles.

## Validation and workflow

Build 124 at `build/hud-portrait-preview/MetalDooM.app` is the current NRFTL MAP01
preview, fullscreen with remembered Minimal style, 50% size and portrait enabled.
Native menu layout, on/off controls and portrait persistence after restart were
checked. Existing game instances were preserved; older preview notes are historical.
Original Ultimate Doom and KEX Doom II GPU suites pass, including all 42 faces,
portrait toggle/Classic restoration, native pixel masks across sizes/scales, HDR
and invisibility. Evidence is in `build/hud-portrait*-validation`.

See the newest `docs/VALIDATION.md` entry. Useful commands:

```sh
bash scripts/build.sh
bash scripts/test-kex-campaign.sh BASE.wad CAMPAIGN.wad
AO_RESOLUTION=1 bash scripts/test-ambient-occlusion.sh IWAD.wad
AO_PROFILE=1 AO_RESOLUTION_PROFILE=1 AO_VALIDATION_LAYER=0 bash scripts/test-ambient-occlusion.sh IWAD.wad
```

Native icon generation and Metal GPU access required permitted host execution;
sandbox failures were environment boundaries. KEX tests report normal exit-code
failures rather than Swift top-level crash dialogs. The early Master Levels test
incorrectly expected a tag-667 floor in MAP20; the installed map has none, and the
test was corrected to recognize the declared no-op. This was a test correction,
not a gameplay fix.

Honor AGENTS.md: update CHANGELOG and current docs, validate final running version/
build and commit locally for each change. New feature milestone = minor version;
refinements stay on the chosen release. Do not push unless asked. Keep unrelated
work intact; no WADs, generated bundles, or signing material in Git.

The following sections retain historical implementation and validation context.
Their branch/release/preview statements describe those earlier steps; the current
checkout and next priorities above take precedence. Do not assume old preview
processes are still running.

Main also supplies the compact level-stats HUD (kills/items/secrets and a whole-second
clock), optional campaign par time and independent secret notifications. Keep its
View and Options → HUD controls and persistent preferences.

The experiment branch was rebased onto main commit `771625e`. Its three original
experiment commits were replayed; `codex/metal-experiments-before-771625e` preserves
the old tip `1730d4c` locally. Main and remotes were not modified. Build 93 passes
the level-stats/secret/save tests and the AO/48-view ceiling GPU suite, and its
native window was checked with live counters/par time and AO together. The
separate validation instance was closed afterward.

## Latest maintenance — pre-merge checks (build 115)

The user pushed the branch and reported GitHub's no-WAD input check failing with
missing renderer/effects types. `test-input.sh` had a stale explicit source list.
GameView now lives unchanged in `Sources/GameView.swift`; the input check compiles
that view alone. `test-audio.sh` likewise compiles only its WAD/audio dependencies.
Input, console, testing-metrics and Ultimate Doom audio checks pass locally, as
does the full 0.8.0 build 115. Fix commit `b7d6441` is now included in local main
through merge `c47a4a2`. Hosted CI results have not been independently inspected.
No gameplay/version change was made for that test-maintenance fix.
Native build 115 loads E1M1 and opens its pause menu with Escape; the isolated
validation preview was then closed.

## In-game effects presets (build 114)

Esc → Options → Effects now offers Classic, Medium, High, Medium HDR and Ludicrous
with highlight descriptions, current preset/Custom status, Enter/click application
and Escape back. Unavailable choices remain readable; the shared apply guard
preserves benchmark/display/ray capability restrictions. The native shortcut is
now labelled Classic / Medium (same ⌘⇧E). Graphics settings/custom data are preserved.
Enhanced → Medium, Atmospheric → High and HDR Showcase → Medium HDR are label-only
changes: Medium HDR still includes High's effects with restrained 4× HDR output.
This remains a refinement of 0.8.0. Heretic/Hexen support was discussed, not added.
The final Ultimate Doom Metal suite and classic-menu tests pass. Native CUA checks
confirm build 114, readable descriptions, Enter/click application, live Custom
status, shortcut and Back. Preview remains paused on Options in Classic.
See `docs/VALIDATION.md` and `build/presets-114-validation/results.txt`.

## Latest refinement — preset shortcut (build 112)

View → Toggle Classic / Enhanced uses ⌘⇧E. Any active effects go to Classic;
effects-off rendering goes to Enhanced, with a two-second preset notice.
The benchmark lock, graphics scale/cap, saved custom setup and gameplay inputs
are preserved. Holding the shortcut does not repeat expensive preset changes.
Other manually tuned setups need explicit Save Current as Custom before toggling.
Same-format changes reuse drawable configuration. Automation made the preview
appear frozen, but build-111 diagnostics confirmed macOS marked it occluded; this
was expected background frame suppression, not a proven engine stall. Keep that
optimization. AO_LIVE=1 checks automatic frame delivery across seven transitions.
This continues the 0.8.0 presets refinement. The user asked for pre-merge ideas;
named custom slots and optional effects persistence were suggested, not authorized
or implemented. No merge or push is requested.

## Ludicrous (build 108)

View → Effects Presets → Ludicrous restores the heavier optional choices while
Enhanced/Atmospheric/Showcase remain restrained. It selects all twelve effects,
High (16/8/32), AO 50%/48, Atmospheric haze, 2× added light, 30% bloom, 1.5× HDR
fullbright world sprites and an 8× HDR ceiling. Independent View intensity controls
and custom snapshots include every new choice; legacy custom files still decode.
The HDR shoulder, filtering, fixed sampling and visibility optimizations remain.
This continues the 0.8.0 HDR/presets refinement; see validation notes for evidence.

The user reported high mediaanalysisd CPU after upgrading to macOS 27. Read-only
inspection found Apple's system daemon idle at 0% CPU at that moment. No direct
mediaanalysis invocation was made during development, but native captures and
build/render validation did occur. The earlier spike's trigger and contribution
to game performance are unverified; do not attribute all measured speedup to code
or disable system daemons. The existing build-106 game was kept intact during
build-108 validation.

## Where the experiment stands

Read [Metal experiments](docs/METAL_EXPERIMENTS.md). The user selected AO controls
and correct grille handling; both are now implemented. View offers strength
0–100% and radius 16–96 units, defaulting to 50%/48 units. AO starts disabled each
launch, while choices persist through toggles and map changes within a session.

`AmbientOcclusion.swift` uses sixteen hemisphere rays against world triangles.
Masked hits interpolate UVs and check the current animated texture's texel alpha;
holes let rays continue. Position/topology changes rebuild the structure, UV-only
changes replace attributes, and mask changes replace material mappings. All
submitted resources remain immutable. Sky and billboard sprites do not occlude.

Build 86 native controls/presentation were verified. GPU checks passed on
Ultimate Doom, Doom II and a generated MIDGRATE fixture, including analytic alpha
rays, settings effects, classic restoration, HUD stability, moving doors, map
replacement and shutdown.

Build 87 fixes the user's bright ceiling slit in E1M1's zigzag room. It was also
present with AO off: flats were clipped to rounded seg endpoints. Geometry now
uses original directed linedefs, Double intersections and shared flat/wall edge
vertices. All 68 Ultimate Doom/Doom II geometry/art checks pass. The opt-in
`AO_CEILING=1` GPU regression covers 24 viewpoints in classic and stronger AO;
local images and a loadable `ceiling.mdsave` go in `AO_OUTPUT`. The user's existing
build 86 game was preserved while the fix was tested separately.

The user saw validate-ao crash dialogs from the old focus assertion. The harness
now drives the original door fixture independently of focus using a bridge added
only to its copied Renderer source. Checks and top-level/native load errors print
FAIL and exit nonzero; an intentional failure was verified as exit 1, not SIGTRAP.
Do not restore the old focus precondition or modal test error path.

M5 Pro capability probes report Metal 4, ray tracing in render shaders and
MetalFX spatial/temporal/denoised upscaling and frame interpolation support.
These optional MetalFX paths are not implemented. Other GPUs remain untested.
The prior build 83 benchmark is historical; see validation docs for timing limits.

The first moving shadow-casting light is implemented.
View → Moving Test Light (Experimental) enables an amber camera-relative light;
Test Light Shadows compares masked world shadows with unshadowed lighting. It is
independent of AO, shares its pipeline/mesh, starts off, and uses the level clock
for an eight-second orbit. Doors/grilles participate; sky and billboard sprites
still do not cast shadows. Sprite reception is now optional (0.7.0); weapon, HUD and power-up
fullbright rendering retain their original paths. See docs/METAL_EXPERIMENTS.md for details and boundaries.

Build 94's GPU validation covers analytical falloff/blockers, finite shadow rays,
animated masks, independent effects, paused/moving light, original-room shadows,
shared-resource lifecycle, doors, save/load, map replacement and shutdown. Native
View controls and the moving light were checked in a separate original-geometry
pillar-room fixture. The subsequent 0.6.0 work adds View → More Metal Effects:
independent torch/lamp, projectile, muzzle-flash, gameplay-shadow, emissive-surface
and bloom switches, all off by default. Scene lights have a shared 16-source cap;
world surfaces receive/cast light, billboard sprites do not. Emission uses known
material families and selective color thresholds; bloom is a world-only LDR pass
before the weapon/HUD. Those were the 0.6.0 boundaries; the additions below supersede them.
Build 96 passes Ultimate Doom/Doom II GPU toggles, real flash/expiry, fixed-colormap
powerups, invisibility, resize, save/load, map replacement/shutdown, the 48 ceiling
captures, level stats and diagnostics. A separate build 96 preview remains open at
`build/effects-preview/MetalDooM.app`, using `build/effects-preview.wad`; the generated
fixture adds three torches to original pillar-room geometry. Native controls and
combined torch/shadow/emission/bloom/AO were inspected. See docs/VALIDATION.md for
performance limits and evidence. No push was requested.

The approved next sequence is complete in 0.7.0 build 100: Sprite Lighting,
Emissive Surface Lighting, Soft Shadows and Embers & Projectile Trails, all
independently toggleable and off at launch. Sprites receive the shared lights but
do not cast shadows. Surface lights use one-sided, subdivided 128-unit patches,
with up to four reserved within the total 16-light budget. They always use world
occlusion and are independent of self-emission. Soft shadows use four fixed
samples; particles use a 128-particle cap, current velocity and level time, with
no simulation/save history. Fullbright/fuzz/weapon/HUD paths remain separate.

Final GPU results are in `build/advanced-effects-build100` (Ultimate Doom),
`build/advanced-effects-final` (full ceiling regression, build 99) and
`build/advanced-effects-doom2-final` (Doom II, build 99). Build 100 only refines
ember origins relative to flame tips. Native build 100 is open in
`build/advanced-final/MetalDooM.app` using `build/advanced-preview.wad`; the latter
adds torches, a medikit and barrel to original E1M1 geometry. New controls,
sprite reception/soft shadows and final ember placement were inspected. See
`docs/VALIDATION.md` for exact coverage and performance limits. Nothing pushed.

## Latest feature milestone — 0.8.0 build 102

HDR/EDR display output, volumetric lighting and graphics/effects presets are now
implemented. See docs/METAL_EXPERIMENTS.md for budgets and color management.
HDR uses an RGBA16Float scene and linear-sRGB EDR drawable with live headroom
mapping, standard-white HUD/weapon, and 2×/4×/8× peak choices. Volumetrics use twelve
samples at quarter resolution, four nearest sources, world shadow rays, raster
depth and depth-aware upsampling. It is additive lit haze with no temporal history.

View has separate graphics presets (scale/cap) and effects presets (Classic,
Enhanced, Atmospheric, HDR Showcase), plus Save Current as Custom / Apply Saved
Custom. Effects still start Classic; custom storage is opt-in, graphics settings
persist. Changes to individual switches remove the built-in preset checkmark.
Automatic AppKit window tabbing is disabled globally and on the game window.

Final GPU evidence lives in `build/hdr-volume-final` and
`build/hdr-volume-doom2`. Native HDR preview: `build/hdr-final/MetalDooM.app`, using
`build/advanced-preview.wad`; generated fixtures remain private and ignored.
Screenshots cannot prove physical HDR luminance. Test float readback measured
headroom and enforces it; no system brightness changes or pushes were requested.

## Latest refinement — grain and unnatural brightness, build 104

The user reported Enhanced and Showcase looked grainy/unnatural. Enhanced is SDR,
so HDR was not the sole contributor. Both presets now enable optional Smooth
World Textures (trilinear mipmaps, 4× anisotropy, nearest binary alpha, crisp
sprites/sky/weapon/HUD). Direct lights add restrained linear-space energy;
bloom is reduced to 12%, and HDR removes the near-white contrast multiplier and
blanket fullbright-sprite boost. AO uses 16 rays at gentler preset strengths,
soft shadows use eight samples, fog uses 32 fixed midpoints and Light Haze in
Atmospheric/Showcase. Custom saves keep previous settings; reselect a built-in.

GPU evidence: `build/preset-polish` (Ultimate Doom), `build/preset-polish-doom2`
(including minification/alpha and HDR contrast probes), `build/preset-polish-final`
(final Ultimate Doom/ceiling run). Native build 104 Enhanced and HDR Showcase were
compared with build 102 in the same torch fixture. The old comparison preview was
closed; `build/polish-preview/MetalDooM.app` is left open with the revised Showcase.
The user's exact viewpoint was not supplied. The smoother sampling costs more GPU
time; avoid claiming a sustained FPS improvement. Still on release version 0.8.0.

## Latest performance fix — build 106

The user's build 104 window showed ~50.45 ms / 19.82 FPS at 2200×1520. Preserve
that game: a separate snapshot was saved through File → Save Game to
`build/frame-interval-build104.mdsave` (advanced-preview.wad stack). It was loaded
into build 106, with Showcase/Balanced and the Metal HUD enabled. That restored
view showed ~11.31 ms / 88.40 FPS. Only the new app remains running, at
`build/performance-preview/MetalDooM.app`; the old process was resumed after each
profiling suspension, then closed only after its snapshot was verified saved.
Quick saves were not touched.

Changes: world alpha/depth visibility pass before equal-depth early-tested ray
shading; first-valid-blocker shadow queries; Balanced/High sample budgets
(8/4/16 versus 16/8/32 for AO/soft shadows/haze); skip GPU work for fully occluded
or minimized windows. Presets other than Ludicrous use Balanced. Shader tests, legacy custom decoding,
quality restoration/mesh reuse and minimized-window suppression pass. Manual GPU
harness drawing still bypasses visibility gating, preserving focus independence.

Isolated profiles at 2200×1520: archived build-104 source `a442f0e`,
`build/perf-isolated-build104` (Enhanced 18.844, Showcase 28.766 ms median);
new `build/perf-isolated-balanced` (6.156 / 9.198 ms; High Showcase 16.603 ms).
The old game process was suspended with an EXIT/INT/TERM resume trap during these
comparisons. Earlier uncontended-looking results were actually polluted by its
background rendering and should not be quoted. Final GPU regressions:
`build/performance-final` (Ultimate + ceiling), `build/performance-doom2`.
No pushes requested; release stays 0.8.0 as a refinement of the experiment.

## Current behavior and important boundaries

- Chocolate Doom supplies authoritative gameplay; AppKit handles the UI and
  Metal renders the world, sprites and classic HUD. Preserve classic Doom/Doom II
  behavior and appearance as the baseline.
- Current supported campaigns include Doom/Ultimate Doom, Doom II, TNT, Plutonia
  and standard SIGIL with Ultimate Doom. General Boom/MBF/GZDoom compatibility,
  SIGIL II and Legacy of Rust are not implemented. Do not remove rejection checks
  and call a WAD supported without implementing and validating its requirements.
- `Sources/WAD.swift` rejects unsupported metadata/DeHackEd changes and Episode 6.
  GAMECONF is used for identity/title display, not executed as loading directives.
- A process owns one fixed engine WAD stack. Open WAD switches through a fresh
  app instance, with a temporary-file ready acknowledgement before terminating
  the previous instance. Invalid selections and cancellation preserve the old
  game. Launch-failure and timeout paths have not been deliberately induced.
- Shutdown cancels timers/callbacks before window teardown; preserve that ordering.
- Classic OPL music is the default; Apple MIDI remains optional. Do not claim an
  exact historical Macintosh sound match. OPL generation can briefly delay load.
- The former frozen SIGIL "imps" were invisible teleport destinations accidentally
  rendered as sprites. `Engine/Bridge.c` excludes `MF_NOSECTOR` objects. Preserve
  real imp/corpse rendering and the SIGIL sprite regression.

## Recent work

- `407cc57`: Open WAD switches games during a session using the handoff above.
- `09e24a9`: Removed top toolbar; map picker moved beside bottom status text.
  View → Show Status Bar remembers visibility; classic Doom HUD is independent.
- `301f4dc`: One two-column WAD picker: remembered main-IWAD folder on the left,
  ordered PWADs on the right, separate file/folder drop areas, type checks,
  canonical-path duplicate prevention, and move/remove controls.
- `ec3c753`: Recognized game names and KEX labels above filenames; SIGIL and
  declared GAMECONF add-on titles recognized, unknown add-ons use filenames.
- `850d74b`: Balanced picker controls/drop areas and bumped the feature preview
  to 0.3.0, build 81. Current docs/version references updated.
- `279ed70`: Added version-aware publishing helper and offline integration tests.

The picker lives in `Sources/WADStackPanel.swift`; lifecycle, native menus,
status-bar preference and WAD switching live in `Sources/main.swift`.
`Sources/Renderer.swift`, `Geometry.swift`, and `SpriteRenderer.swift` are the
main rendering entry points. Read [architecture](docs/ARCHITECTURE.md) before
changing engine/render boundaries.

## Validation and useful commands

Run these from the active repository as appropriate to the selected change:

```sh
bash scripts/build.sh
bash scripts/test-wad-picker.sh
python3 scripts/test-publish.py
```

The picker test needs a logged-in macOS pasteboard service. It uses synthetic
WAD fixtures and file-URL pasteboard data to exercise actual destination
callbacks, wrong-side rejection, duplicate prevention, order and Play handoff.
It passed, but an actual mouse drag from Finder was not manually tested.
The publishing integration test uses disposable local bare remotes only.

Native checks completed in this conversation:

- Ultimate Doom to Doom II game switching; old process exited, one app remained.
- Invalid WAD rejection preserved the current game; file chooser cancellation.
- Bottom map selection E1M1 → E1M2; status-bar hide/show, persistence after relaunch,
  viewport expansion, independent classic HUD and empty-screen Open WAD button.
- Rerelease folder discovery and persistence; Doom + SIGIL selection and launch;
  reopening the current stack; recognized titles; final build 81 alignment/version.

These are focused checks, not complete campaign playthroughs or other-Mac testing.
The final alignment change was visually checked; the picker regression last ran
successfully at build 80. WAD-dependent tests include `test-wad-edition.sh`,
`test-stack.sh`, `test-sigil-sprites.sh`, `test-doom2.sh`, `test-final-doom.sh` and
`test-shutdown.sh`. Inspect each script's arguments; do not guess them.
See [testing](docs/TESTING.md) and [validation](docs/VALIDATION.md).

Local WAD sources, never to be committed or packaged:

- Original Ultimate Doom: `/Users/wmh/Downloads/The_Ultimate_Doom/DOOM.WAD`.
- Doom II used in switching checks: `/Users/wmh/Downloads/doom2.wad`.
- KEX data under `$HOME/Library/Application Support/CrossOver/Bottles/Steam/drive_c/Program Files (x86)/Steam/steamapps/common/Ultimate Doom/rerelease/`.
  Inspect the current files before choosing an experimental target; filename
  presence or picker identification does not prove gameplay compatibility.

In this session, active-repo writes/builds required sandbox escalation. Icon
building and native pasteboard access can fail inside the sandbox; distinguish
permission failures from app bugs. Validate UI changes in the running app and
confirm its build number, not just compiler success.

## Publishing and signing

The remote is the user's GitHub repository, `sithtoast/MetalDooM`. The user pushed the experiment branch; local main now contains merge `c47a4a2`
and local tag `v0.8.0`. Remote tag/release state and hosted Actions completion
have not been independently checked. The assistant has not pushed this handoff.

On clean `main`:

```sh
bash scripts/publish.sh --dry-run
bash scripts/publish.sh
```

The script reads `Info.plist` and the actual push destination's tags. A new version
creates an annotated tag and atomically pushes it with main. An already-published
version pushes main alone. Dirty trees, other branches, downgrades and conflicting
tags stop it. It does not bump versions, commit, force-push or move published tags.
A failed push retains any local tag for inspection/retry.

The existing Actions workflow builds main and publishes a signed prerelease for
matching `v*` tags. CI build numbers are `10000 + GITHUB_RUN_NUMBER`; they do not
replace the local counter. A successful push is not proof that Actions or signing
passed. See [GitHub setup](docs/GITHUB_SETUP.md) and [releasing](docs/RELEASING.md).

The user has Developer ID signing configured locally and a Keychain notary profile
named `MetalDooM-notary`, but chose to defer notarization. Do not submit to Apple
without a new request. No credentials belong in source or this document.

## Workflow expectations

Read [AGENTS.md](AGENTS.md): validate each implementation, update the changelog
with the actual successful app build, and make a local commit before replying.
No push unless requested; do not infer permission from release bookkeeping.
Do not bump the semantic version for every build. Fixes can be patches; a coherent
new feature milestone can justify a minor version. Leave prior changelog entries
intact. Keep WADs, app bundles, signing material and generated artifacts out of Git.
