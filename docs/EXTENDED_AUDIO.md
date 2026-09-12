# Rust sound effects preview — build 135

The manual Rust preview plays sound effects from the worker's actual gameplay
calls, including pistol fire, Rust weapon charge/fire/impact, pickups, switches
and moving sectors. The Sound checkbox starts enabled; turning it off stops
current voices and suppresses new starts. Music remains pending.

## Engine adapter and capture

`ME_EnableAudio()` opts into capture before `ME_Init`. Initialization has the same
one-attempt lifetime; enabling after it fails. Headless callers that do not opt
in retain the prior request counter without buffering events. Capture does not
consume RNG or advance additional simulation tics.

`AudioEvents.c` replaces count-only S_* effects hooks. It resolves the initialized
extended sound table and linked descriptors to actual WAD names, including BEX
remaps and explicit no-prefix names. It validates DMX PCM headers/durations and
fails on missing resources, unsupported formats, random/ambient definitions or
loops. Ambient hooks and music are not implemented. No game sounds are bundled.

There are 32 channels. A new sound replaces the same origin/singularity class;
otherwise it uses an available channel, or a lower-priority one when full. The
adapter estimates natural expiry from DMX length in simulation tics. Nearby
sounds play at full scale, attenuating from 200 to 1200 units; the MBF stereo
swing supplies pan. The distance calculation uses Euclidean distance, not the
upstream lookup-table approximation. Position changes produce channel updates;
inaudible channels stop. Removed actors detach their positions before their
memory can be freed. Only value records leave the worker.

This is a bounded native adapter, not full upstream mixer parity. Pitch stays
normal (no randomization), and upstream per-sample concurrency/volume limiters,
rumble, ambient loops, alternate sound formats and reverb are not reproduced.
The existing `sound_events` snapshot value still counts gameplay requests, not
the number of audible voices or PCM samples.

## MSA1 FIFO and MVW4

`ME_CopyAudio` is a whole-buffer draining copy: NULL/undersized calls return the
required size and preserve the FIFO; a successful complete copy consumes it.
Zero means capture is unavailable/session failed. Overflow beyond 4096 records
stops the session with an explicit error rather than dropping sounds.

MSA1 has a 16-byte header: magic, version u32=1, current tic u32, count u32.
Each 28-byte event contains tic u32, channel u32 (0–31), operation u32,
eight-byte zero-padded resource name, volume i32 (0–127), pan i32 (-128–128).
All integers are little-endian. Operations are 0 stop, 1 start, 2 parameter update.
Only starts carry a name; stop parameters are zero. Events retain FIFO order,
including ties, and their tics cannot exceed the packet tic. Updates may occur
at the end of a tick batch. Swift validates these constraints and exact lengths.

ABI 2 now has twelve private exports; existing struct/MGE1/MSP1/MMT1 layouts are
unchanged. The MEQ1/MER1 envelope is unchanged. The MVW4 view header has 52 bytes,
adding audio byte count at offset 48 after the previous fields. Payload order is
optional MGE1, required MSP1, required MMT1, required MSA1. Aggregate payload stays
within 160 MiB. All snapshot tics must agree. Geometry queries do not replay audio
already consumed by a tick reply; protocol versions are intentionally strict.

## Native playback and manual timing

The parent resolves names against its verified ordered resource view and lazily
uses the existing DMX-to-44.1-kHz PCM decoder. Classic playback still defaults to
16 voices; only the explicit preview requests 32. Stop and parameter-update
records act on the corresponding native AVAudioPlayerNode.

The scene displays the completed batch, then main-queue callbacks play its events
at their copied offsets, spaced by 1/35 second. Command buttons wait for that
batch's event timeline to finish, preventing a queue of overlapping simulations.
The Sound checkbox stays usable. PCM tails finish naturally while simulation is
stopped; this is manual sound audition, not synchronized continuous gameplay.
Empty-event batches finish immediately. Closing/error increments a cancellation
generation, stops voices and pauses the mixer; deferred callbacks cannot restart
playback. No audio callback ticks the engine.

Mute explicitly stops/skips voices. An early gain-only offline test returned
nonzero samples even when AVAudioMixer reported outputVolume=0; the final preview
mute does not depend on that gain observation. Unmuting permits subsequent starts,
without replaying sound starts suppressed while muted.

## Validation

The worker suite checks copied FIFO capacity/canaries, complete-copy drain,
overflow, no replay on geometry queries, two independent left/right pistol
origins, thirteen malformed audio/order packets, and byte-identical player/actor
snapshots over 200 tics with capture disabled/enabled. Existing all-map, sprite,
material, weapon and protocol checks pass.

`bash scripts/test-extended-audio.sh original-doom2.wad /path/to/rerelease`
requires the matching worker/fixtures from `test-extended-worker.sh` and native
Core Audio access. It checks exact pistol event tics 39/53/67 after firing begins
at tic 35 (including wind-up), real AVAudioEngine PCM, stereo separation, explicit
mute and channel stop. Actual Rust fixture events decode/render Incinerator
DSINCBRN/DSINCFI1–2/DSINCHT1–3, Blade DSHETCHG/DSHETSHT/DSHETXPL, pickups, and MAP16
DSSTNMOV/DSSWTCHN. A brief live pistol test measures the device-output tap; this
proves output data, not physical speaker audibility. See VALIDATION.md for logs,
final native controls and remaining limits.
