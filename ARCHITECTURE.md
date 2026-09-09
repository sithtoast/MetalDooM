# Architecture

Chocolate Doom is authoritative for player movement, collision, and sector state.
Swift owns native input/windowing and direct Metal rendering.

| File | Responsibility |
| --- | --- |
| Engine/Bridge.h, Bridge.c | Initialize/restart, tic commands, player/sector snapshots, error boundary |
| Engine/Platform.c | Memory arena, argument lookup, silent audio/HUD host hooks |
| Engine/NativeHeaders.h | Native endian/input declarations replacing SDL platform headers |
| Engine/sources.txt | Explicit list of compiled upstream files |
| Sources/WAD.swift | Bounded binary reads, classic map records, BSP lookup |
| Sources/Geometry.swift | Palette/patch decoding and world triangle generation |
| Sources/Renderer.swift | Fixed tics, interpolation, sector synchronization, Metal resources |
| Sources/main.swift | AppKit lifecycle, WAD picker, map selector, cursor/focus handling |

## Engine boundary

The pinned upstream snapshot is unchanged. The host initializes its zone allocator,
WAD directory, renderer resource metadata, and play subsystem, then starts a map
with `G_InitNew`. Native input becomes `ticcmd_t`; original `P_Ticker` runs at 35 Hz.
Original player and sector code handles motion, blocking, use traces, doors, and
hazards. No software world frame is generated. Unused upstream code is dead-stripped.

The full `G_Ticker` state machine is not connected yet. An exit pauses the preview
and exposes a status message. Monsters are disabled; other non-player mobjs are
removed after level setup until sprites and interaction are ready. Upstream movement
and door code is not modified. Audio, status-bar startup, and automap hooks are silent.

Everything runs on the main thread. Swift never owns pointers into Doom's arena;
snapshots copy scalars through C. Fatal errors unwind to `setjmp` wholly within C,
poison the instance, and become native error messages. Restart after a fatal error.
One IWAD initializes per process; map restarts reuse those resources. Rejected WAD
changes and absent-map requests preserve the active engine.

## Rendering and input

WAD `(x,y)` becomes Metal `(x,height,-y)`. Vertices contain position and texel UV/light
float4s. Wall art is composited at load time; floors/ceilings are clipped through the
classic BSP. All side materials are cached, including those hidden by closed sectors.
Engine floor/ceiling height or light changes rebuild geometry using current values.
Textures persist and submitted buffers are immutable. Metal retains resources used
by in-flight commands; up to three command buffers may be outstanding.

Camera position, angle, and eye height interpolate between engine tics. Moving
sector geometry currently advances at tic rate. The accumulator is bounded after
stalls and cleared while inactive, so focus recovery does not fast-forward gameplay.
Use taps are queued until a tic consumes them. The earlier Swift approximation of
player collision has been removed.

## Validation boundaries

`Tests/EngineValidation.c` uses placement helpers excluded from normal builds to
put the player before an original E1M1 door. It checks blocking, engine use, ceiling
movement, traversal, resets, all nine shareware maps, and rejected load requests.
`Tests/make_door_fixture.py` changes only player-one's start in a local temporary
IWAD for visual validation using normal app controls. Original WADs are not modified.

Future actor rendering and the full game-state loop should extend this interface,
keeping engine pointers private and the simulation authoritative.
