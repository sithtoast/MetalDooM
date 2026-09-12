# Rust native preview — 0.10.0 build 135

An explicit development preview now starts the extended simulation in a separate
child process and draws its copied geometry with the existing native Metal world
and sky pipelines, with copied actor/weapon frames through the sprite renderer.
It uses the actual ordered id24res → Doom II → id1 resources,
checks their session fingerprint and reads the UMAPINFO sky selection.

This is a **manual simulation preview**, not playable Rust support. HUD, music,
full Boom/ID24 presentation are not connected.
The ordinary WAD picker still rejects Rust gameplay. Manual controls advance real
simulation; displayed health/ammo are simulation state. No speedrun/upload work.

## Build and launch

The helper is packaged only with the explicit development build option:

```sh
METALDOOM_EXTENDED_PREVIEW=1 METALDOOM_BUILD_DIR="$PWD/build/audio-final" bash scripts/build.sh
open -n "$PWD/build/audio-final/MetalDooM.app" --args \
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
raising: use Step 1 second to advance it. Each action uses its tick reply, which carries sprite/material state and
geometry only when world values change. The background scene builder reuses
unchanged meshes and decoded resources; Metal uploads new textures only.
Sound events play at their copied 35 Hz offsets after each manual batch; controls
wait for its event timeline to finish. Sound toggles explicit voice mute. Sample
tails finish naturally while simulation is stopped. There is no automatic simulation clock. Closing the preview cancels its child,
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
control-sector lighting, fake floors, sky transfers, translucency still need their full presentation adapters. Wall/flat animation
uses the worker's current translation tables. See [materials and caching](EXTENDED_MATERIALS.md).
Unchanged scenes reuse meshes, but any geometry change rebuilds the whole mesh.
This is not a measured real-time update strategy, especially for MAP13.

## Process and protocol

Worker ABI 2 has additive `ME_CopyView`, `ME_CopyPresentation`, `ME_CopyMaterials`, `ME_EnableAudio` and
`ME_CopyAudio`, bringing the
private export count to twelve. No existing structure layout changes. `Engine/Worker/main.c` links only
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

Startup and geometry replies carry an `MVW4` body: magic, tic, fixed x/y/eye-z,
unsigned Doom angle, signed health, eight-byte sky name, geometry byte count,
sprite byte count, material byte count, audio byte count (52 bytes total), then optional [MGE1](EXTENDED_GEOMETRY.md),
required [MSP1](EXTENDED_SPRITES.md), [MMT1](EXTENDED_MATERIALS.md) and
[MSA1](EXTENDED_AUDIO.md). Tick replies
include geometry when changed and always include sprite/material state and drained sound events. Old body versions reject. Swift checks envelope size/
sequence/status, view/geometry/sprite/material/audio tic agreement, map identity and stable content identity. Maximum reply
is 160 MiB + 52 bytes; errors are at most 2048 bytes. Startup/requests have a
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
The previous MBF21/Rust suite passes with twelve private exports. Audio checks add
FIFO canaries/drain/overflow, left/right sources, thirteen malformed audio/order
packets and byte-identical simulation snapshots over 200 tics with capture off/on.
Worker logs: `build/audio134-worker-validation.log`, `build/rust134-validation.log`;
final build 135 only refines the parent's explicit voice mute. Native audio checks
are in `build/audio135-native-validation.log`, with classic PCM regression in
`build/classic135-audio-validation.log`. See [audio details](EXTENDED_AUDIO.md).

Native build 135 verifies its Sound toggle, MAP16 switch opening after Step → Use
→ Step (35→36→71), muted firing to tic 106/ammo 47, controls waiting for playback
and becoming available again. The final preview is left on MAP16 with Sound on.
Native mixer tests render both actual Rust weapons, pickups, switch/movement sounds,
stereo, mute and stop; a device-output tap measures nonzero PCM. Physical speaker
audibility is unverified. Prior animation/pistol checks remain in VALIDATION.md.
Music, full presentation, continuous gameplay and campaign/save acceptance remain
work ahead. Audio audition is deliberately separate from a real-time simulation clock.
