# Experimental extended simulation worker

The **0.10.0 build 137** development milestone includes copied geometry, sprite
frames, material animations and sound events, explicit session planning, three Rust-required ID24 fields, an explicit
[native preview](EXTENDED_PREVIEW.md), and headless tests with the actual Rust
patch/resources. The normal app still uses Chocolate Doom; its Rust rejection
remains in place. **Legacy of Rust is not playable in the GUI yet.**

## Reproduce

```sh
bash scripts/build-extended-engine.sh
bash scripts/test-extended-engine.sh /path/to/original/doom2.wad
bash scripts/test-rust-worker.sh /path/to/original/doom2.wad /path/to/rerelease
```

Apple Silicon, Xcode tools, macOS 14+; no SDL or Homebrew dependency. The second
command tests the MBF21 baseline. The third also tests session/error boundaries,
ID24 fields, all sixteen Rust map startups and actual Rust weapons/pickups. It
requires `id24res.wad`, `doom2.wad` and `id1.wad` in the supplied rerelease directory.
Generated fixtures, copied private data and logs stay under ignored `build/`.

## Session plan and ABI

`Engine/Extended/ExtendedCore.h` is **ABI version 2**. `ME_Init` takes exact resource
order, an independent base-WAD index, explicit profile, scratch directory, skill,
map and RNG seed. The tested Rust order is id24res → Doom II → id1, base index 1.
The native WAD code uses that base identity instead of assuming file zero is the
IWAD. No sibling pack is automatically added.

Before engine initialization, the planner checks WAD headers/directories/lump
bounds, rejects duplicate files, and checks that the selected base is a Doom
II-format IWAD. GAMECONF is read from the base first, then the remaining supplied
WADs in order. Non-null descriptive fields replace previous values; null retains
previous values; executable requirements use the specified ordering/max operation.
The explicit commercial base is already the maximum supported game mode.

This is a **restricted GAMECONF implementation**: envelope 1.0.0, descriptors,
IWAD filename matching and `comp_soul` options are supported. Options accumulate
in declaration order. Dependency expansion, external DEH files and translations
are rejected, along with unknown fields/features/modes, duplicate JSON keys,
invalid integer options and IWAD paths. It never searches for or installs files.
Files must remain unchanged during initialization; the worker reopens them after
planning. It is not a sandbox or a general hostile-WAD validator.

`ME_CopySession` returns copied metadata and a SHA-256 identity over ordered file
content hashes, base role and worker profile. Relocating the files preserves it;
changing order, base role or profile changes it. This is a content identity for
future persistence work, not a demo certification or a complete engine identity.

Profiles are explicit development choices:

- `ME_PROFILE_MBF21`: the baseline worker; rejects ID24 requirements/fields.
- `ME_PROFILE_RUST_PROBE`: opts into MBF21 simulation plus the tested Rust subset.
  The copied session still reports the declared ID24 requirement. This profile
  does **not** advertise full ID24 conformance or silently relabel it as MBF21.

The dylib exports exactly twelve `ME_` functions, keeping both engine and helper
symbols private. One `ME_Tick` consumes one 35 Hz command. Movement, attack/use
and validated weapon-change bits are accepted; special command bits and invalid
weapon indices fail. Player/actor snapshots copy values, messages and selected
UMAPINFO fields (name, routes, finale and boss-action count); no engine pointers
escape. Normal and secret exits still stop at the transition boundary.

## Process lifetime and presentation

Use a **dedicated single-thread process, one session per process**. Initialization
can be attempted once. Fatal engine errors stay inside the guarded C call and
invalidate the session; terminate the worker after completion/error to reclaim
its allocations. There is no teardown/restart API or extended save format yet.
The separate [preview worker protocol](EXTENDED_PREVIEW.md) now carries copied
views/geometry, named actor/weapon frames and material translations/sound events. Do not load the dylib into the Swift app process.

Simulation uses directly initialized defaults and an explicit seed, without
reading the user's Woof config. Upstream code owns physics, actors, weapons,
damage and map thinkers. Native services provide filesystem access/diagnostics.
The optional [audio adapter](EXTENDED_AUDIO.md) copies sound effects to the parent
for native playback; non-opted-in probes retain only the request count. Music
remains absent and ambient sound requests fail. UMAPINFO is parsed before map setup, including Rust's
boss-action overrides; episode hooks preserve the simulation flag without adding
a menu. Routes/finale metadata are copied, but their execution/presentation is
not implemented by this worker.

## ID24 fields and validation

The new fields are `Pickup message`, `Min respawn tics` and `Respawn dice`, guarded
by the explicit Rust profile. Built-in and sparse actors default to 420 tics and
4. Messages resolve BEX mnemonics after patch loading and override the message of
a successful vanilla pickup while retaining its ammo/weapon behavior. Unknown
mnemonics and invalid numeric values fail before map setup; message formatting
is bounded. Four ID24 pickup mnemonic defaults come from the pinned specification.
Other ID24 fields and reserved signed data IDs remain unsupported.

Respawn comparison follows the pinned Rum and Raisin implementation: it returns
without respawning when the random roll is greater than the threshold, therefore
allowing rolls **≤ threshold**. The 0.99.2 prose table says “greater than,” which
contradicts that implementation and the legacy default. We preserve the executable
reference/default behavior and record this discrepancy rather than claiming full
conformance. See [ID24HACKED](https://github.com/doom-cross-port-collab/id24/blob/e96a9e1c9ee34621b03a4894f4053c2a3426496e/version_0_99_2_md/ID24HACKED.md)
and [reference thinker](https://github.com/GooberMan/rum-and-raisin-doom/blob/eaf5381814e1b1993047b5e752d9e003951768aa/src/doom/p_mobj.cpp).

With seed 1993, the synthetic corpse dies on tic 4 and respawns on tic 97 for
64/255, tic 2145 for Rust's 2100/64, and tic 1601 for the default 420/4. Tests verify
no respawn before the requested minimum. Pickup tests preserve cell quantities
and exercise both default and BEX-replaced messages.

The actual installed Rust 1.2 patch loads into 203 actor types and 1543 states.
All sixteen campaign maps run 35 idle tics. MAP13 uses the upstream XNOD loader;
its 1437 actor snapshots do not establish Swift geometry/rendering parity.
Copied metadata verifies MAP02/MAP10 secret routes, MAP15/MAP16 returns, MAP13/14
boss-action counts and MAP14's XFINALE1 declaration. Boss kills/exits are not yet
exercised by these startup checks.

Original test rooms using the actual unmodified Rust resource/weapon patch pass:

| Probe | Verified result |
| --- | --- |
| Fuel can / tank | Adds 10 / 50 fuel and the correct ID24 message |
| Incinerator, 12 tics held | 20→16 fuel; up to 4 concurrent projectiles |
| Calamity Blade tap | 20→10 fuel; up to 6 concurrent projectiles |
| Blade held 25 tics | 20→0 fuel; up to 12 concurrent projectiles |
| Blade held 85 tics (full charge) | 70→20 fuel; up to 30 concurrent projectiles |

These are bounded simulation probes. They do not establish every monster's combat
behavior, projectile damage parity, all map specials, complete charging/dry-fire
semantics, saves, audio or native visuals. Custom resource tables still require
complete terminator records in this worker; the app loader also accepts compact
terminators. See [the remaining roadmap](LEGACY_OF_RUST.md).

## Build evidence and next work

The build 128 simulation evidence is in `build/rust128-validation.log`, rerun for
129 in `build/rust129-validation.log`. Build 129 adds the seventh API export,
`ME_CopyGeometry`, without changing ABI 2 structures. See the [copied geometry
contract and evidence](EXTENDED_GEOMETRY.md): every Rust map builds CPU native
mesh batches, and MAP13 XNOD references match independently decoded lump records.

Build 131 adds `ME_CopyView` and the [isolated worker/world preview](EXTENDED_PREVIEW.md).
The development build option packages an independently signed helper/dylib. The
native app renders Rust world geometry and skies through copied process data.
Build 132 adds `ME_CopyPresentation`, the ninth private export, and native actor/
weapon rendering with manual firing. See the [sprite contract](EXTENDED_SPRITES.md).
Music and complete presentation remain ahead. The classic app and
normal picker remain unchanged. All older previews and the primary release are
preserved. No package or upload.

Build 133 adds `ME_CopyMaterials`, engine-timed native material animation and
[scene/resource reuse](EXTENDED_MATERIALS.md). Tick replies include geometry only
when world values change; explicit geometry requests remain complete.

Build 135 adds opt-in sound capture and native manual-batch effects playback.
See [audio limits](EXTENDED_AUDIO.md).

Build 137 adds continuous one-tic scene/audio playback in the parent with keyboard
controls and pause handling; worker/protocol remain unchanged.
Next: partial moving-world updates (especially MAP13), music and targeted real-monster/map-special parity.
Campaign transitions, boss/secret exits, JSON presentation and versioned saves
remain acceptance gates. Keep the ordinary GUI Rust guard until native campaign
play is validated.
