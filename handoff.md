# MetalDooM handoff — 2026-09-10

## Where to resume

The active repository is `/Users/wmh/Dev/MetalDooM`, on `codex/metal-experiments`.
The saved project for this conversation points to
`/Users/wmh/Documents/ChatGPT/MetalDooM`, a separate outer repository used for
staging. Do not commit that outer repository or copy its staging tree over newer
source. Open the active Dev repository in the next chat and inspect its status.

The active experiment is on `codex/metal-experiments`; check Git status/log before
continuing. The user selected **ray-traced ambient occlusion**. It is implemented
as a per-session View menu option, with classic rendering still the default.

Current version: **0.8.0**, successful local app **build 106**. `Info.plist` owns
the semantic version; `scripts/build.sh` increments `BUILD_NUMBER` for app builds.
This is an experimental branch, not a published release. No push was requested.

Main also supplies the compact level-stats HUD (kills/items/secrets and a whole-second
clock), optional campaign par time and independent secret notifications. Keep its
View and Options → HUD controls and persistent preferences.

The experiment branch was rebased onto main commit `771625e`. Its three original
experiment commits were replayed; `codex/metal-experiments-before-771625e` preserves
the old tip `1730d4c` locally. Main and remotes were not modified. Build 93 passes
the level-stats/secret/save tests and the AO/48-view ceiling GPU suite, and its
native window was checked with live counters/par time and AO together. The
separate validation instance was closed afterward.

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
`AO_CEILING=1` GPU regression covers 24 viewpoints in classic and maximum AO;
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
or minimized windows. Presets use Balanced. Shader tests, legacy custom decoding,
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

The remote is the user's GitHub repository, `sithtoast/MetalDooM`. The assistant
has not pushed these changes. The user may have pushed independently; live remote
state, current tags and hosted Actions completion have not been checked here.

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
