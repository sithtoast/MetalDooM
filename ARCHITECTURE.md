# Architecture

Chocolate Doom is authoritative for movement, combat, inventory, and sector state.
Swift owns native input/windowing and direct Metal rendering.

| File | Responsibility |
| --- | --- |
| Engine/Bridge.h, Bridge.c | Initialize/restart, tic commands, player/sector/thing/HUD snapshots, error boundary |
| Engine/Platform.c | Memory arena, argument lookup, copied sound-event queue, HUD host hooks |
| Engine/NativeHeaders.h | Native endian/input declarations replacing SDL platform headers |
| Engine/sources.txt | Explicit list of compiled upstream files |
| Sources/WAD.swift | Bounded binary reads, classic map records, BSP lookup |
| Sources/Geometry.swift | Palette/patch decoding and world triangle generation |
| Sources/Renderer.swift | Fixed tics, interpolation, sector synchronization, Metal resources |
| Sources/SpriteRenderer.swift | Sprite texture cache, billboard quads, original HUD patch composition |
| Sources/SoundPlayer.swift | DMX decoding, native AVAudioEngine voices, focus pause |
| Sources/main.swift | AppKit lifecycle, WAD picker, map selector, cursor/focus handling |

## Engine boundary

The pinned upstream snapshot is unchanged. The host initializes its zone allocator,
WAD directory, renderer resource metadata, and play subsystem, then starts a map
with `G_InitNew`. Native input becomes `ticcmd_t`; original `P_Ticker` runs at 35 Hz.
Original player and sector code handles motion, blocking, use traces, doors, and
hazards. No software world frame is generated. Unused upstream code is dead-stripped.

The full `G_Ticker` state machine is not connected yet. An exit pauses the preview
and exposes a status message. Monsters, projectiles, pickups, and decorations keep
their original thinker lifecycles. Native attack/change buttons drive unchanged
weapon code. A dead player stays dead until R reloads; use is masked after death
to avoid entering rebirth without G_Ticker. Software HUD and automap hooks are silent.
The bridge copies inventory values and captures/clears engine player messages after
each tic, with a serial so repeated pickups of the same type still renew the notice.

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
Use, movement, fire taps, and weapon selections queue until a tic consumes them.
Held fire remains active until release; focus loss clears every pending input.
The first viewport click captures the mouse without shooting.

## Sprites and HUD

The bridge walks live mobj thinkers, omits the player, resolves the original sprite
frame/rotation/flip, and returns copied positions, light/fullbright, and IWAD lump
indices. No object pointers cross into Swift. All sprite patches are decoded and
uploaded at WAD load, so animations do not upload textures during a frame. Removed
pickups disappear from the next snapshot. Transparent fragments are discarded before
depth writes; opaque portions test against world geometry and other sprites.

Sprites remain upright and face the camera horizontally. Patch origins determine
their placement, with the visual bottom clamped to the object's live floor height
so below-origin artwork is not clipped by the floor. This does not move the engine
object or change its collision/pickup position. Metal draws the original STBAR, digits, keys, ammo reserves, arms,
and face patches as a final depth-independent pass. The HUD uses integer scaling
in a centered 320x32 region below the world viewport. Native text displays temporary
engine messages and accessible inventory values. Face expressions are an initial
health-band/idle implementation; the complete original face logic remains pending.

## Weapons and sound

Copied psprite snapshots contain the engine weapon and muzzle-flash frames, their
320x200 coordinates, lighting and flip. Metal draws them over the world with depth
disabled, scaled to a centered 320x168 view above the HUD. Damage/pickup tints draw
between the weapon and HUD. Weapon bobbing, raise/lower and firing timing stay in C.

Sound host hooks resolve original S_sfx/DS lump names and emit bounded commands to
16 native voice slots. Only C stores origin pointers; Swift receives scalar slot,
lump, gain and pan values. Restart emits stops for all voices. SoundPlayer strips
DMX padding, converts unsigned PCM to 44.1 kHz float buffers, and caches samples.
AVAudioPlayerNode instances feed a native mixer; focus loss pauses the engine.
This follows Apple's [player-node buffer scheduling](https://developer.apple.com/documentation/avfaudio/avaudioplayernode).
Pan/attenuation are sampled on emission; voice allocation and resampling are native
approximations, not bit-exact DMX behavior. Music and route-change recovery remain.

## Validation boundaries

`Tests/EngineValidation.c` uses placement helpers excluded from normal builds to
put the player before an original E1M1 door. It checks blocking, engine use, ceiling
movement, traversal, resets, all nine shareware maps, and rejected load requests.
`Tests/make_door_fixture.py` changes only player-one's start in a local temporary
IWAD for visual validation using normal app controls. The pickup fixture similarly
relocates items and the player while preserving map geometry and specials. Tests
verify item removal, inventory changes, animated frame changes, key-gated doors,
and restoration on restart. Original WADs are not modified.

CombatValidation uses test-only isolated targets to check pistol/fist damage,
ammo, animation/flash, monster attacks, death, reset and empty-ammo fallback.
AudioValidation renders the original pistol sound offline through AVAudioEngine.
The full game-state loop should extend the same copied-snapshot boundary.
