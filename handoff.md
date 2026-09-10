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

Read [Metal experiments](docs/METAL_EXPERIMENTS.md). `AmbientOcclusion.swift`
adds eight short hemisphere rays per world fragment using a Metal acceleration
structure built from opaque world triangles. Moving geometry gets a fresh
structure; unchanged positions avoid rebuilds for light-only changes. Sky,
billboard sprites and masked materials do not cast occlusion. Original sprite,
weapon and HUD shading remain unchanged.

The View option is disabled when Metal ray tracing in render shaders is absent.
The M5 Pro used locally reports support. Other GPU families are untested.
Diagnostics and benchmark settings include AO state. The existing benchmark is
still a capped CPU-submission benchmark, not a GPU throughput measurement.

The focused Metal API-validation regression passed on Ultimate Doom E1M1:
paused AO pixels remain stable, HUD pixels are unchanged, disabling AO restores
identical classic pixels, a real door updates the ray mesh, map replacement
rebuilds it, and shutdown completes. A corrected single-frame 1280×800 paused
sample measured approximately 4.8 ms AO versus 0.18 ms classic GPU command time;
API validation/readback pacing limit performance conclusions. The original
geometry/art regression passed all 36 Ultimate Doom maps. See validation docs
for final native checks and Doom II coverage. Build 83's paired DEMO1 benchmark
at 2200×1400 returned 118.8 FPS AO / 118.0 FPS classic under the 120 FPS cap;
this does not establish uncapped throughput or an AO speedup. Build 84 hardens
the path where render-encoder creation fails after encoding a ray-mesh build.
Its final GPU regression passed, and the running build 84 View toggle/presentation
were verified. The app was left in E1M1 with AO enabled for this session.

Potential follow-ups are alpha-tested ray intersections, static/moving mesh
separation, sample-quality tuning and measurements on more maps/GPUs. Keep KEX
compatibility and the future in-window WAD picker on their own branches.

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
