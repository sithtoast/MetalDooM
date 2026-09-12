# Rust native preview — 0.10.0 build 144

An explicit development preview now starts the extended simulation in a separate
child process and draws its copied geometry with the existing native Metal world
and sky pipelines, with copied actor/weapon frames through the sprite renderer.
It uses the actual ordered id24res → Doom II → id1 resources,
checks their session fingerprint and reads the UMAPINFO sky selection.

This is a **continuous development preview**, not full Rust campaign support.
Native HUD, MIDI, intermissions, episode stories/credits and custom cast are
connected; full Boom/ID24 world presentation, saves and gameplay acceptance remain
ahead. Death, Restart and Continue are connected; see
[lifecycle behavior](EXTENDED_LIFECYCLE.md) and [campaign presentation](EXTENDED_CAMPAIGN.md).
The ordinary WAD picker still rejects Rust gameplay. Run and manual controls advance real
simulation; displayed health/ammo are simulation state. No speedrun/upload work.

## Build and launch

The helper is packaged only with the explicit development build option:

```sh
METALDOOM_EXTENDED_PREVIEW=1 METALDOOM_BUILD_DIR="$PWD/build/campaign-preview" bash scripts/build.sh
open -n "$PWD/build/campaign-preview/MetalDooM.app" --args \
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
Run starts a 35-tics/s target clock. WASD moves/strafe, arrows turn/move, Shift
runs, E/Space uses, F fires, 1–7 selects a weapon, and clicking captures horizontal
mouse aim (subsequent clicks fire). Escape or Pause releases input and stops all
sounds. Losing app/window focus or minimizing also pauses; resuming is explicit.
There is no vertical look or interpolation yet.

Both continuous and finite manual actions submit **one tic at a time**. Each
prepared scene and that tic's sound events are applied on the main queue together,
with audio starting before the next display refresh. This aligns scene updates
and event delivery, not sample-accurate hardware presentation. Manual buttons
remain disabled until their finite command count completes; Pause can interrupt
it, and Sound/Music stay usable. Finite actions may leave natural sample tails;
explicit Pause stops them. Music pauses at the end of finite actions, on explicit
Pause and on focus loss; it resumes with playback. Its checkbox is independent of
sound effects. See [HUD and music](EXTENDED_UI.md).

Only one worker request is in flight. A delayed reply slows simulation; there
is no catch-up command queue, tic dropping or input sampled far in advance. Pause
cancels the next wakeup. A pending reply can still present its already-computed
tic, silently, before Run becomes available; it never starts another request.
Resuming clears held/queued input and resets the pacing deadline. Closing cancels
the child, drains the serial queue, reaps the process and removes private scratch
before app termination. Existing app instances are unaffected.

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
Build 139 caches static clipping/stitching, updates affected wall/sector chunks,
and retains unchanged Metal material buffers. MAP13's 140-tic worker/CPU mean
falls from 210.57 to 20.56 ms; native load averages 3.39 ms in a separate check.
See [incremental geometry](EXTENDED_MESH.md) for invalidation, exact pixel parity,
measurement boundaries and remaining costs. This is not full campaign acceptance.

Build 144 presents [native intermissions and finales](EXTENDED_CAMPAIGN.md) using
worker-selected metadata and original artwork. A separate 35 Hz presentation
clock supports counting stats, entering markers, stories, credits and the custom
cast without ticking the simulation. Pause/Restart also work during presentation.

## Process and protocol

Worker ABI 2 has additive `ME_CopyView`, `ME_CopyPresentation`, `ME_CopyMaterials`, `ME_EnableAudio` and
`ME_CopyAudio`, plus `ME_CopyUI`, bringing the
private export count to fifteen with `ME_Advance` and `ME_CopyCampaign`. No existing structure layout changes. `Engine/Worker/main.c` links only
the isolated dylib; the Swift app never loads it. `scripts/build-extended-worker.sh`
produces both beside each other, using an executable-relative dylib path.

MEQ1 op5 (empty body) returns bounded campaign JSON at completion; see
[the campaign contract](EXTENDED_CAMPAIGN.md). View packet layouts stay unchanged.

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
quit (empty body/reply); 4 lifecycle action (u32: 0 restart, 1 continue).
Lifecycle replies force complete geometry at tic zero. Tick batches stop early
at death/completion. Commands carry signed forward/side bytes, signed LE16
turn, button byte, reserved zero byte. Invalid sequence, length, operation, reserved
byte or command terminates the session with a bounded error reply.

Startup and geometry replies carry an `MVW5` body: magic, tic, fixed x/y/eye-z,
unsigned Doom angle, signed health, eight-byte sky name, geometry byte count,
sprite byte count, material byte count, audio byte count, UI byte count (56 bytes total), then optional [MGE1](EXTENDED_GEOMETRY.md),
required [MSP1](EXTENDED_SPRITES.md), [MMT1](EXTENDED_MATERIALS.md) and
[MSA1](EXTENDED_AUDIO.md) and [MUI2](EXTENDED_LIFECYCLE.md). Tick replies
include geometry when changed and always include sprite/material/UI state and drained sound events. Old body versions reject. Swift checks envelope size/
sequence/status, view/geometry/sprite/material/audio/UI tic agreement, map identity and stable content identity. Maximum reply
is 160 MiB + 56 bytes; errors are at most 2048 bytes. Startup/requests have a
30-second deadline and run on one serial background queue; cancellation terminates
the owned child and interrupts reads. EOF/truncation and protocol errors stop the
session. Level restart/continue use the existing process and resource session;
there is no reinitialization or save contract.

## Validation

Run `scripts/test-extended-worker.sh original-doom2.wad /path/to/rerelease`.
It checks worker request boundaries, EOF/quit, Swift startup/movement/copy identity,
cancellation and bad-reply/timeout handling. All sixteen actual Rust maps resolve
materials/skies and actor/weapon frames at startup and tic 35. Tests cover eight
rotations/mirroring, actual Incinerator/Blade firing-frame decoding, complete-copy
canaries and nine malformed sprite packets. Wrong resource base identity rejects.
The MBF21/Rust suite passes with fourteen private exports. Audio checks add
FIFO canaries/drain/overflow, left/right sources, thirteen malformed audio/order
packets and byte-identical simulation snapshots over 200 tics with capture off/on.
Build 140 worker/core logs: `build/ui140-worker.log`, `build/ui140-core.log`.
The new UI suite covers all map music selections, copied inventory, malformed UI
packets and native music lifecycle; see EXTENDED_UI.md.

New `scripts/test-extended-playback.sh /path/to/rerelease` checks clock deadlines,
slow work, one in-flight request, exact finite command lengths, pause/resume,
and 140 consecutive prepared scene/audio tics on MAP01, MAP13 and MAP16. Native
`scripts/test-extended-audio.sh` additionally checks immediate synchronized PCM,
pause with a pending reply, duplicate rejection and mute/resume. Logs:
`build/continuous136-validation.log`, `build/continuous136-audio-validation.log`.

Intermediate build 136 verifies manual frames (tic 14 then exactly 35),
continuous MAP16 keyboard use/fire (opening geometry and ammo 50→49), Escape pause
and minimizing pause. A closed test's app/worker processes exit and scratch is
removed. Final build 137 verifies Escape interrupting a manual step at tic 4, another
35-tic step ending at 39, muted firing to 74/ammo 47, then Run/Escape ending at 91.
That candidate was left paused on MAP01 with Sound on. Native audio regressions
still cover both Rust weapons, pickups, switches and a device-output tap; physical
speaker audibility remains unverified. Full presentation and campaign/save
acceptance and large-map performance remain work ahead.

Build 139 adds cached geometry decoding, static topology and partial material
updates. All 21 reference GPU comparisons pass; all-map/worker regressions pass.
The build-139 candidate remains at `build/mesh-final/MetalDooM.app`. See
EXTENDED_MESH.md. Build 140 is `build/ui-preview/MetalDooM.app`; its native HUD,
Music control and pause/fire/weapon behavior are recorded in VALIDATION.md.
