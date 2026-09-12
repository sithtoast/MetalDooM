# Rust camera and weapon interpolation — 0.10.0 build 148

Continuous Run now blends camera position, view height, yaw and compatible weapon
positions between consecutive 35 Hz snapshots. This smooths walking, turning and
existing engine view/weapon bob on faster displays. Basic bob was already present
in the copied simulation coordinates; earlier handoff notes incorrectly listed
it as absent. No new bob physics or client-side sine wave is introduced.

## Timing and boundaries

The renderer blends the previous snapshot toward the current one over 1/35 second
from receipt, then holds the endpoint. It never extrapolates. This adds up to one
visual tic of camera/weapon delay; the simulation, input cadence, sound events,
HUD, sprite animation frames, actors and moving surfaces retain their existing
per-tic timing. It is not whole-world interpolation or a claim of sustained 35 Hz
simulation on every map. Slow worker replies still slow the simulation.

Only continuous Run opts in. Manual step buttons show exact snapshots. Pause,
Escape and focus loss snap to the latest received state and clear blend history.
Resume does not replay old history. Restarts, Continue and save loads construct
fresh renderers and begin paused. Saving records engine state, not an intermediate
rendered pose. A pending reply received after pause remains an exact snapshot.

Blending requires consecutive tics in the same live map, no engine teleport flag,
and receipt gaps no longer than two tic periods. Large unmarked position changes
also snap (64 horizontal units or 32 vertical). Yaw takes the shortest wrapped
path. Weapon/flash slots blend together only when weapon identity, layer names,
flags and bounded coordinates are compatible. Frame changes, appearing/disappearing
flashes, weapon changes and patched coordinate jumps snap to the new artwork.

## Wire and resource behavior

MSP2/version 2 replaces MSP1 without changing the 32-byte header or record strides.
Header word 28 becomes flags: bit 0 means snap camera, set when the player's engine
interpolation marker is nonpositive. Unknown bits reject. The marker also covers
short teleports that distance heuristics would miss. It is copied read-only from
Woof's player/mobj state; the existing teleport routine clears it and player
thinking sets it for ordinary motion. Existing native structures, MVW5, MGE2,
MMT1/MSA1/MUI2 and 17 private exports remain unchanged.

The renderer changes camera uniforms and weapon quad positions on each draw.
It does not rebuild geometry, upload textures or issue worker commands. Actor
interpolation will need stable identities and additional copied state; moving
surfaces likewise remain separate work. Classic renderer interpolation is unchanged.
The engine fingerprint changes with MSP2, so older private saves still require
the preserved matching engine bundle.

## Validation

```sh
bash scripts/test-extended-interpolation.sh /path/to/rerelease
bash scripts/test-extended-metal.sh /path/to/rerelease
bash scripts/test-extended-save-app.sh /path/to/rerelease
```

The focused suite checks midpoint coordinates, 359°→1° yaw wrapping, aligned
weapon/flash motion, endpoint clamping, pause/resume and nine discontinuity cases.
An original walk-over-teleporter room exercises an actual short teleport and the
MSP2 flag. Real MAP01 walking verifies existing view/weapon bob, saved phase and
35 future tics after restore.

The native Metal harness uses a test-only deterministic presentation clock to
check distinct start/middle/end images, exact paused endpoints, retained world
buffers and unchanged worker tic. Its existing Rust reference, scrolling and save
pixel tests remain. The native save harness exercises Run/Pause after repeated
loads and checks failure/close cleanup. Final bundle evidence is in VALIDATION.md.

Remaining rendering work includes actor/moving-surface interpolation, flat
rotation, palette/TRANMAP translucency and control-sector/fake-floor/sky effects.
Full campaign/boss playthrough acceptance and ordinary picker support remain pending.
