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

Current version: **0.4.0**, successful local app **build 92**. `Info.plist` owns
the semantic version; `scripts/build.sh` increments `BUILD_NUMBER` for app builds.
This is an experimental branch, not a published release. No push was requested.

Main also supplies the compact level-stats HUD (kills/items/secrets and a whole-second
clock), optional campaign par time and independent secret notifications. Keep its
View and Options → HUD controls and persistent preferences.

## Where the experiment stands

Read [Metal experiments](docs/METAL_EXPERIMENTS.md). The user selected AO controls
and correct grille handling; both are now implemented. View offers strength
0–100% and radius 16–96 units, defaulting to 50%/48 units. AO starts disabled each
launch, while choices persist through toggles and map changes within a session.

`AmbientOcclusion.swift` uses eight hemisphere rays against world triangles.
Masked hits interpolate UVs and check the current animated texture's texel alpha;
holes let rays continue. Position/topology changes rebuild the structure, UV-only
changes replace attributes, and mask changes replace material mappings. All
submitted resources remain immutable. Sky and billboard sprites do not occlude.

Build 86 native controls/presentation were verified. GPU checks passed on
Ultimate Doom, Doom II and a generated MIDGRATE fixture, including analytic alpha
rays, settings effects, classic restoration, HUD stability, moving doors, map
replacement and shutdown. The app was left in E1M1 with AO on at default settings.

The user saw validate-ao crash dialogs from the old focus assertion. The harness
now drives the original door fixture independently of focus using a bridge added
only to its copied Renderer source. Checks and top-level/native load errors print
FAIL and exit nonzero; an intentional failure was verified as exit 1, not SIGTRAP.
Do not restore the old focus precondition or modal test error path.

M5 Pro capability probes report Metal 4, ray tracing in render shaders and
MetalFX spatial/temporal/denoised upscaling and frame interpolation support.
These optional MetalFX paths are not implemented. Other GPUs remain untested.
The prior build 83 benchmark is historical; see validation docs for timing limits.

The discussed next visible experiment is one shadow-casting light, before
projectile/torch lighting. It has not been implemented. Keep compatibility and
in-window picker work on separate branches. No push has been requested.

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
