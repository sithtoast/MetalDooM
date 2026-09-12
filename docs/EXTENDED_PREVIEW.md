# Rust world preview — 0.10.0 build 131

An explicit development preview now starts the extended simulation in a separate
child process and draws its copied geometry with the existing native Metal world
and sky pipelines. It uses the actual ordered id24res → Doom II → id1 resources,
checks their session fingerprint and reads the UMAPINFO sky selection.

This is a **world-only simulation preview**, not playable Rust support. Actors,
weapons, HUD, audio, animation translations and full Boom/ID24 presentation are
not connected. The ordinary WAD picker still rejects Rust gameplay. Manual
controls advance real simulation, including unseen enemies; the displayed health
is simulation state, not a full gameplay interface. No speedrun/upload work.

## Build and launch

The helper is packaged only with the explicit development build option:

```sh
METALDOOM_EXTENDED_PREVIEW=1 METALDOOM_BUILD_DIR="$PWD/build/worker-preview" bash scripts/build.sh
open -n "$PWD/build/worker-preview/MetalDooM.app" --args \
  --rust-preview "/path/to/Ultimate Doom/rerelease" --map MAP01
```

MAP01–MAP16 are available. A normal build remains classic and does not package the
helper. A preview request without a packaged helper reports a launch error.
The separate candidate is ad-hoc signed/unnotarized; no release packaging occurs.
Both the helper and its dylib are signed before the outer app. The bundle includes
Woof and third-party license notices. WADs are never copied into the app.

Forward/Back submit eight movement tics; Turn left/right submit one 45-degree turn
tic; Use submits one use tic; Step 1 second submits 35 idle tics. Each action requests current geometry,
builds meshes/materials off the main thread, then uploads them on the main thread.
There is no automatic simulation clock. Closing the preview cancels its child,
drains the serial queue, reaps the process and removes its private scratch/log
folder before completing app termination. Existing app instances are unaffected.

The initial camera is derived from the engine's standing spawn viewheight and
ceiling clamp, because the per-tic viewz has not yet been computed at tic zero.
This does not tick the simulation or consume RNG. Later views copy actual viewz.

## Resources and rendering

The parent constructs a resource-only WAD view after matching the ordered session
fingerprint. It is labelled PWAD and cannot be passed to the normal IWAD gameplay
loader. Flat lookups use explicit F_START/FF_START namespaces: Rust's TCMFLRE/F
flats share names with wall patches and must not resolve to their patch bytes.
Missing materials/skies stop the preview instead of showing fallback artwork.
Classic material lookup is unchanged.

`ExtendedScene` supplies the shared `Geometry` mesh and decoded images to a fresh
`Renderer`, without calling classic engine initialization/ticking. Metal uses the
same world/sky shaders, depth handling and buffers as classic rendering. Current
physical floors/ceilings, side offsets and switch texture identities are copied;
control-sector lighting, fake floors, sky transfers, translucency and animated
material translation still need their full presentation adapters. Every manual
step currently rebuilds/uploads the complete world: this is not a measured
real-time update strategy, especially for MAP13.

## Process and protocol

Worker ABI 2 gains additive `ME_CopyView`, bringing the private export count to
eight. No existing structure layout changes. `Engine/Worker/main.c` links only
the isolated dylib; the Swift app never loads it. `scripts/build-extended-worker.sh`
produces both beside each other, using an executable-relative dylib path.

The child accepts cache directory, map, base index, profile, skill and ordered WAD
paths as separate arguments. Engine stdout is redirected to the diagnostic log;
a duplicated stdout descriptor carries only framed replies. No shell interprets
paths. Every request/reply header is 16 bytes, little-endian:

| Bytes | Request | Reply |
| --- | --- | --- |
| 0–3 | `MEQ1` | `MER1` |
| 4–7 | Sequence, starts at 1 | Matching sequence; startup is 0 |
| 8–11 | Operation | Status 0 success / 1 error |
| 12–15 | Body length | Body length |

Operations: 1 ticks (1–35 six-byte commands); 2 geometry (empty body); 3 graceful
quit (empty body/reply). Commands carry signed forward/side bytes, signed LE16
turn, button byte, reserved zero byte. Invalid sequence, length, operation, reserved
byte or command terminates the session with a bounded error reply.

Startup and geometry replies carry an `MVW1` body: magic, tic, fixed x/y/eye-z,
unsigned Doom angle, signed health, eight-byte sky name, geometry byte count,
reserved zero word (44 bytes total), then optional [MGE1](EXTENDED_GEOMETRY.md).
Tick replies omit geometry. Swift checks envelope size/sequence/status, view and
geometry tic agreement, map identity and stable content identity. Maximum reply
is 160 MiB + 44 bytes; errors are at most 2048 bytes. Startup/requests have a
30-second deadline and run on one serial background queue; cancellation terminates
the owned child and interrupts reads. EOF/truncation and protocol errors stop the
session. No restart-in-process or save contract is implied.

## Validation

Run `scripts/test-extended-worker.sh original-doom2.wad /path/to/rerelease`.
It checks worker request boundaries, EOF/quit, Swift startup/movement/copy identity,
cancellation and bad-reply/timeout handling. All sixteen actual Rust maps resolve
all materials/skies and build meshes through the process path. Wrong resource
base identity rejects. The full previous MBF21/Rust suite and classic Doom II
geometry/material/sprite suite also pass. Logs: `build/worker130-validation.log`,
`build/rust130-validation.log`, `build/classic130-validation.log`.

Native acceptance covers the bundled helper, classic MAP01 regression in the
intermediate build 130, Rust MAP01/MAP13 world rendering, manual commands, and
close cleanup. Final build 131 adds Use and verifies its command reaches MAP13
(tic 16→17), followed by a 35-tic update (52). The starting panel is solid scenery:
this does not establish door-opening behavior. This does not prove
full Rust gameplay, moving-sector visual parity or real-time frame rates. The next
work is actor/weapon presentation, animated materials and efficient state updates,
then audio and the remaining map/campaign/save acceptance.
