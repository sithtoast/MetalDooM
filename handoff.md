# MetalDooM handoff — 2026-09-12

## Where to resume

Current development checkout: `/Users/wmh/.codex/worktrees/c0e4/MetalDooM`, branch
**codex/legacy-of-rust**, based on fetched origin/main merge **afd7357** (includes
6171c87 and completed 0.9.0 build 124). Preserve `/Users/wmh/Dev/MetalDooM` and its
release artifacts. The previous resolution/KEX branch description is historical.

Current feature version is **0.10.0**, final successful app build **135**. The
explicit Rust preview now plays native sound effects from gameplay calls, with
stereo positioning and a Sound checkbox. Actors, weapons, material animation and
scene reuse remain available. **Rust is not playable through the ordinary picker**;
keep its guard until full native campaign acceptance.

Read [preview/process contract](docs/EXTENDED_PREVIEW.md),
[audio](docs/EXTENDED_AUDIO.md), [materials/cache](docs/EXTENDED_MATERIALS.md),
[sprites](docs/EXTENDED_SPRITES.md), [geometry](docs/EXTENDED_GEOMETRY.md),
[worker](docs/EXTENDED_ENGINE.md) and [roadmap](docs/LEGACY_OF_RUST.md).
ABI 2 now has twelve private exports. `ME_EnableAudio` opts in before initialization;
`ME_CopyAudio` copies/drains bounded MSA1 events only on a complete-buffer copy.
Headless callers remain capture-free by default. Existing struct/MGE1/MSP1/MMT1
layouts are unchanged. MVW4 has a 52-byte header and optional MGE1, required MSP1,
MMT1, MSA1. One dedicated process owns each session; never load the extended dylib
into the Swift app process.

Build with `METALDOOM_EXTENDED_PREVIEW=1 METALDOOM_BUILD_DIR="$PWD/build/audio-final" bash scripts/build.sh`.
Launch with `--rust-preview /path/to/rerelease --map MAP01` (through MAP16).
Only the explicit option packages/signs the helper/dylib and notices. Standard
builds remain classic. Ordered resources are id24res → Doom II → id1, base index 1;
the parent verifies their content identity. Missing artwork/samples fail; WADs and
generated bundles stay private/ignored.

Controls submit eight movement tics, a 45-degree turn, one Use tic, one/35 attack
tics, or 35 idle tics. Step after spawn raises the weapon and releases the initial
use latch. Sound starts enabled. Each completed batch displays its scene, then
plays copied sound events at 1/35-second offsets; command buttons wait for the
event timeline. Empty-event batches finish immediately. Sound tails finish
naturally while simulation is stopped. This is manual audition, not synchronized
continuous gameplay. Sound off explicitly stops voices/suppresses starts; unmute
does not replay skipped starts. Closing/error invalidates pending callbacks,
stops/pauses audio and cancels/reaps the worker/removes scratch.

The native sound adapter resolves extended/BEX sound names and aliases, tracks 32
origin/singularity channels, updates position/attenuation and safely detaches
removed origins. Capture consumes no RNG; normal pitch, Euclidean attenuation,
DMX-only samples and simplified priorities are deliberate limits. Missing/invalid
samples, random/ambient/loop definitions and queue overflow fail explicitly.
Music and ambient playback remain absent. The snapshot sound_events counter is
still request count, not audible output count.

Worker tests pass in `build/audio134-worker-validation.log`: all sixteen scenes,
prior sprite/material/weapon checks, FIFO/canary/drain/4096-event overflow, no
replay on geometry query, independent left/right sources, thirteen malformed
sound packets, and identical player/actor bytes over 200 tics with capture off/on.
`build/rust134-validation.log` passes the prior MBF21/session/ID24/map/weapon suite
with twelve exports. Worker code is unchanged in 135; it refines parent mute.
Native audio log `build/audio135-native-validation.log` verifies pistol timing
39/53/67, PCM/stereo/mute/stop, pending-callback cancellation, actual Incinerator/Blade/pickup/switch/movement samples
and a live device-output tap. Classic sound/menu PCM and pause/resume regressions
pass in `build/classic135-audio-validation.log`. Prior geometry/material evidence
remains in VALIDATION.md, including MAP13 XNOD byte parity.

Native candidate: `build/audio-final/MetalDooM.app`, **0.10.0/build 135**;
`build/build135.log`. Host deep/strict signature verification passes, and bundled
plist/CUA title agree. Final CUA checks Sound on, MAP16 Step → Use → Step
(35→36→71), Sound off, firing to 106/ammo 47, playback blocking/re-enabling controls,
and restoring Sound on. The visible preview is left there, with a firing pose
and active monster. Raise the window before visual inspection: an occluded Metal
window may retain its previous surface. A live device tap measured nonzero PCM;
physical speaker audibility remains unverified.

Intermediate build 134 is preserved at `build/audio-preview/MetalDooM.app`; its
test instance was closed. Its gain-only mute offline check returned PCM despite
reported mixer volume zero. Final 135 uses explicit stop/suppress behavior, which
passes. Preserve build 133 `build/material-preview/MetalDooM.app`, build 132
`build/actor-preview/MetalDooM.app` and earlier bundles. Rust-specific gun artwork
still has automated frame evidence only, despite native PCM acceptance.

Next: more granular moving-world updates and synchronized continuous playback;
then music/campaign presentation. Worker comparison still traverses full geometry,
and any geometry change rebuilds the whole mesh. This is not proven real-time
performance. Complete scrolling flats, weapon bob/interpolation, palette/TRANMAP
translucency, control-sector/fake-floor/sky effects, targeted monster/map-special
parity, campaign/boss/secret routes, JSON presentation and versioned saves. Keep
the ordinary Rust guard until native campaign play is validated.

Older previews are preserved: build 126 `build/MetalDooM.app`, 127
`build/extended-milestone/MetalDooM.app`, 128 `build/rust-milestone/MetalDooM.app`,
129 `build/geometry-milestone/MetalDooM.app`. The user's speedrun demo/upload idea
remains a future aside, with no implementation or upload authorization implied.

The **0.9.0 build 124** release was notarized by the user in the preceding task:
Apple accepted `121f1db9-34a4-4f5f-aeb3-599a59de0727`; stapler, codesign and
Gatekeeper were verified in the host context. ZIP location remains the primary
checkout's `build/releases/MetalDooM-0.9.0-build124/`. This is prior-task evidence.
Builds 126–135 are ad-hoc signed, unnotarized, and unpackaged. GitHub workflow outputs
remain unnotarized. No push, publish, upload or Apple submission was performed.

The remaining sections are historical and describe earlier branches/previews.

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
