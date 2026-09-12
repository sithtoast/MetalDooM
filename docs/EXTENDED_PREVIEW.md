# Rust native preview — 0.10.0 build 132

An explicit development preview now starts the extended simulation in a separate
child process and draws its copied geometry with the existing native Metal world
and sky pipelines, with copied actor/weapon frames through the sprite renderer.
It uses the actual ordered id24res → Doom II → id1 resources,
checks their session fingerprint and reads the UMAPINFO sky selection.

This is a **manual simulation preview**, not playable Rust support. HUD, audio,
animation translations and full Boom/ID24 presentation are not connected.
The ordinary WAD picker still rejects Rust gameplay. Manual controls advance real
simulation; displayed health/ammo are simulation state. No speedrun/upload work.

## Build and launch

The helper is packaged only with the explicit development build option:

```sh
METALDOOM_EXTENDED_PREVIEW=1 METALDOOM_BUILD_DIR="$PWD/build/actor-preview" bash scripts/build.sh
open -n "$PWD/build/actor-preview/MetalDooM.app" --args \
  --rust-preview "/path/to/Ultimate Doom/rerelease" --map MAP01
```

MAP01–MAP16 are available. A normal build remains classic and does not package the
helper. A preview request without a packaged helper reports a launch error.
The separate candidate is ad-hoc signed/unnotarized; no release packaging occurs.
Both the helper and its dylib are signed before the outer app. The bundle includes
Woof and third-party license notices. WADs are never copied into the app.

Forward/Back submit eight movement tics; Turn left/right submit one 45-degree turn
tic; Use submits one use tic; Fire submits one attack tic; Fire 1 second submits
35 attack tics; Step 1 second submits 35 idle tics. At startup the weapon is still
raising: use Step 1 second to advance it. Each action requests current geometry
and sprite frames, prepares them off the main thread, then uploads on the main thread.
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
Sprites resolve in explicit S_START/SS_START namespaces, using the last matching
name across ordered resources. Missing materials/skies/frames stop the preview
instead of showing fallback artwork.
Classic material lookup is unchanged.

`ExtendedScene` supplies the shared `Geometry` mesh and decoded images to a fresh
`Renderer`, without calling classic engine initialization/ticking. Metal uses the
same world/sky/sprite shaders, depth handling and buffers as classic rendering.
The sprite renderer accepts copied records and caches uploaded patches; it never
queries the classic engine in preview mode. See [sprite details](EXTENDED_SPRITES.md).
Current
physical floors/ceilings, side offsets and switch texture identities are copied;
control-sector lighting, fake floors, sky transfers, translucency and animated
material translation still need their full presentation adapters. Every manual
step currently rebuilds/uploads the complete world: this is not a measured
real-time update strategy, especially for MAP13.

## Process and protocol

Worker ABI 2 has additive `ME_CopyView` and `ME_CopyPresentation`, bringing the
private export count to nine. No existing structure layout changes. `Engine/Worker/main.c` links only
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

Startup and geometry replies carry an `MVW2` body: magic, tic, fixed x/y/eye-z,
unsigned Doom angle, signed health, eight-byte sky name, geometry byte count,
sprite byte count (44 bytes total), then optional [MGE1](EXTENDED_GEOMETRY.md)
and required [MSP1](EXTENDED_SPRITES.md). Tick replies omit geometry but always
include sprite state. Old body versions reject. Swift checks envelope size/
sequence/status, view/geometry/sprite tic agreement, map identity and stable content identity. Maximum reply
is 160 MiB + 44 bytes; errors are at most 2048 bytes. Startup/requests have a
30-second deadline and run on one serial background queue; cancellation terminates
the owned child and interrupts reads. EOF/truncation and protocol errors stop the
session. No restart-in-process or save contract is implied.

## Validation

Run `scripts/test-extended-worker.sh original-doom2.wad /path/to/rerelease`.
It checks worker request boundaries, EOF/quit, Swift startup/movement/copy identity,
cancellation and bad-reply/timeout handling. All sixteen actual Rust maps resolve
materials/skies and actor/weapon frames at startup and tic 35. Tests cover eight
rotations/mirroring, actual Incinerator/Blade firing-frame decoding, complete-copy
canaries and nine malformed sprite packets. Wrong resource base identity rejects.
The previous MBF21/Rust suite and classic Doom II geometry/material/sprite suite
also pass. Logs: `build/presentation132-validation.log`,
`build/rust132-validation.log`, `build/classic132-validation.log`.

Native build 132 acceptance covers the signed bundle/helper, classic MAP01's
monsters/pistol/HUD, Rust MAP01's corpse and pistol/muzzle flash (tics 0→35→70,
ammo 50→47), and MAP16's starting switch opening its surrounding geometry after
Use and a 35-tic update. These are focused visual checks; new Rust guns have
automated frame-decoding evidence only. Build 131's MAP13 check and build 130's
child cleanup check remain historical evidence. Full gameplay, all moving-sector visuals and real-time
frame rates remain unverified. Next: animated materials, efficient state updates,
audio and remaining map/campaign/save acceptance.
