# Rust presentation interpolation — 0.10.0 build 157

Continuous Run blends the camera, compatible weapon positions, actors and moving
sector heights between consecutive 35 Hz snapshots. This smooths walking, turning,
existing view/weapon bob, projectiles, doors and lifts on faster displays.

## Timing and boundaries

The renderer blends over 1/35 second from receipt, then holds the exact endpoint.
It never extrapolates or advances the worker. This adds up to one visual tic of
delay. Input cadence, sound events, HUD, lights, animation/rotation frames and
scrolling texture phases retain their per-tic timing. Slow worker replies still
slow the simulation; this is not a sustained frame-rate claim for every map.

Only Run opts in. Manual steps show exact snapshots. Pause, Escape and focus loss
snap to the latest state and clear history. Resume starts fresh. Restart, Continue
and Load construct fresh paused renderers. Saves record engine state, never an
intermediate rendered pose. A pending reply after Pause remains an exact snapshot.

Blending requires consecutive tics in the same live map, no camera teleport flag,
and receipt gaps no longer than two tic periods. Unmarked camera corrections of
64 horizontal or 32 vertical units snap. Yaw takes the shortest wrapped path.
Weapon/flash slots blend together only with compatible weapon identity, layer
names, flags and bounded coordinates. Artwork and weapon changes remain discrete.

## Actors

MSP5 keeps the header32 and weapon24 layouts and extends actor40 to actor56.
Actor offsets40/44/48/52 contain previous x/y/z/floor-z. Flag32 enables those
endpoints. They are captured on each object before the entire world tic, including
sector thinkers. This keeps an actor's feet aligned with the lift supporting it.
The engine's own interpolation marker disables blending on teleports; a capture
tic check also excludes objects spawned during the current tic.

No matching by list position, address or state is needed: each current actor
carries its own endpoints. Removed actors disappear, new actors snap, and sprite
artwork changes immediately. The worker never exports a pointer or object ID.
The native keyframe stores the endpoints and capture tic for deterministic copied
state after restore. Rendering still begins paused at the restored endpoint.

## Moving surfaces

`ExtendedSurfaceInterpolation` retains consecutive resolved maps with stable
sector indices. It blends front/back floor and ceiling heights and finite sprite
clip limits using the same fraction as the camera and actors. The existing
`ExtendedMesh` rebuilds affected sector and neighboring wall chunks before upload;
unchanged material buffers and all textures remain cached. Each new snapshot
first restores materials that differ from the last displayed pose, including
a mover that stops while another sector changes. Re-tessellating heights
preserves door openings, lower/upper walls, pegging and clipping when triangle
counts change. Interpolating arbitrary vertex-array positions would not.

Material/sky changes, finite/unbounded clip transitions and plane jumps of 64
units or more snap. These guards keep discrete fake-flat region changes from
sweeping the room or generating infinity arithmetic. Rotation and texture/sky
scroll phases remain discrete. This is a conservative native interpolation policy,
not software-renderer pixel parity or interpolation of every ID24 sky variant.

Camera-only and actor-only movement does not rebuild world buffers. Moving
surfaces do CPU meshing and GPU uploads per displayed intermediate pose; large
maps with many simultaneous movers still need gameplay performance testing.
Classic interpolation remains unchanged. MGE5/MBL3/MUI3/MVW5 and the eighteen
private ABI2 exports remain unchanged; the engine fingerprint changes, so retain
older bundles for older private saves.

## Validation

```sh
bash scripts/test-extended-interpolation.sh /path/to/rerelease
bash scripts/test-blend-motion-core.sh /path/to/original-doom2.wad
bash scripts/test-extended-metal.sh /path/to/rerelease
```

Focused tests cover camera/weapon midpoint and discontinuities, actor feet,
front/back planes, clip bounds and instant changes. Native GPU tests compare
actual manual-door and lift midpoints to independently built full meshes, including
a pickup riding the lift, and check paused endpoints and unchanged physics.
The core probe checks spawn capture suppression and exact future presentation
through a fresh worker. See VALIDATION.md for final build and runtime evidence.
