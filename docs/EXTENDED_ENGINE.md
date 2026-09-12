# Experimental extended simulation worker

The 0.10.0 build 127 development milestone adds a **separate native headless
simulation target** based on pinned Woof code. The app still uses Chocolate Doom.
Legacy of Rust remains rejected and is not playable. This is the beginning of
milestone 2 in [the Rust roadmap](LEGACY_OF_RUST.md), not its completion.

## Build and exercise

```sh
bash scripts/build-extended-engine.sh
bash scripts/test-extended-engine.sh /path/to/original/doom2.wad
```

Requires Apple Silicon and Xcode command-line tools; targets macOS 14+. No SDL or
Homebrew dependency. Output stays under ignored `build/extended/`. Supply an
original Doom II IWAD: this worker rejects GAMECONF, including the rerelease
Doom II's configuration, until the session planner can interpret it correctly.
The fixture generator creates original geometry/patches and resolves art from the
user's IWAD. It contains no copied WAD data.

## Boundary and lifetime

`Engine/Extended/ExtendedCore.h` defines ABI version 1. `ME_Init` takes ordered
paths, a scratch directory, skill, map and an explicit RNG seed. `ME_Tick` accepts
one 35 Hz command. Player and actor snapshots are copied scalars; no upstream
pointers escape. `ME_CopyError` copies diagnostic text. The dylib exports exactly
these five functions, with engine and helper-library symbols hidden.

This target must run in a **dedicated, single-thread process, one session per
process**. Initialization can be attempted only once. Engine failures are caught
inside C, invalidate the session and return an error; terminate the worker after
failure or completion to reclaim all engine allocations. Do not load it into the
Swift app yet. There is no unload/reset/teardown, IPC protocol or production
backend selection in this milestone. There is also no extended save format.

The worker initializes simulation defaults directly without loading a Woof user
configuration. It explicitly selects MBF21 and replaces the clock-derived RNG
seed before level setup. Upstream code owns actors, state transitions, weapons,
collision, damage, thinker updates and Boom specials. Native hooks provide
filesystem access and diagnostics. Presentation hooks are inert; sound calls
are only counted. This does not validate audio, MIDI, rendering, rumble or UI.
Ambient sound requests and level transitions fail with explicit errors.

The entry point is intentionally limited to original Doom II, MAP01–MAP32,
attack/use/movement commands and caller-owned trusted fixtures. GAMECONF/ID24
configuration is rejected. Patch warnings/errors and unknown/unsupported mapped
fields fail closed. These checks are not a general validator for malicious or
arbitrary WADs. Custom ANIMATED/SWITCHES tables require complete terminator records
in this worker; the normal app's resource loader supports compact terminators.

## Verified behavior

- Native arm64 library links only system dependencies and exports the five ABI
  functions. Both `P_Ticker` and `states` are invisible to a client symbol lookup.
- An original Doom II MAP01 runs real MBF21 simulation for 35 tics. Two fresh
  workers with the same seed/commands produce matching actor snapshot digests.
- Synthetic Thing 500 and Frames 1100/1101/1200/1201 extend the sparse data tables
  to 146 actor types and 1080 states. `A_AddFlags` changes the actor's flags to
  518 while preserving MBF21 LOGRAV.
- A patched pistol executes `A_ConsumeAmmo` and `A_WeaponBulletAttack`: ammo
  changes from 50 to 48 and the target's health changes from 200 to 193.
- A Boom linedef 252 conveyor moves the player north without input, preserving x.
- Weapon callbacks in actor states, and actor callbacks in weapon states, fail
  before incorrect invocation and leave snapshots unavailable after the error.
- Unsupported ID24 pickup fields, unknown fields/sections, GAMECONF and a
  truncated animation table produce their expected diagnostics. The installed
  `id1.wad` also stops at the GAMECONF/ID24 guard before gameplay initialization.

Evidence logs: `build/extended-validation.log`, `build/extended/` and
`build/extended-rust-rejection.log`. Native app build 127 was separately launched
on Doom II MAP01 and inspected in CUA; title/footer and bundle report 0.10.0/127.
The existing classic presentation/animation/save-phase regression passes. That
GUI observation verifies the classic app, **not extended Rust rendering**.

## Next implementation work

Build the session plan that separates base-game identity from resource order,
then implement the required ID24 data fields/actions, Rust actors and weapons,
XNOD/shared geometry, and copied render/audio data. Extend coverage to actual
Rust combat and map mechanics before connecting the native renderer. Campaign
routes, interlevels/finale and versioned extended saves remain separate gates.
Do not switch the default backend or relax the Rust picker guard on this evidence.

To preserve a running app preview while building another candidate:

```sh
METALDOOM_BUILD_DIR="$PWD/build/extended-milestone" bash scripts/build.sh
```

The app builder uses one project-wide lock so alternate output directories still
share the monotonic BUILD_NUMBER workflow. Build 126's paused resource preview
and the primary checkout's notarized 0.9.0 build 124 release remain preserved.
