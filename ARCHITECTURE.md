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
| Sources/IntermissionRenderer.swift | Original intermission patches, stats and destination screen |
| Sources/SaveStore.swift | Versioned save container, WAD hash, integrity, atomic persistence |
| Sources/MapNames.swift | Canonical English map titles from the pinned engine |
| Sources/SoundPlayer.swift | DMX decoding, native AVAudioEngine voices, focus pause |
| Sources/main.swift | AppKit lifecycle, WAD picker, map selector, cursor/focus handling |

## Engine boundary

The pinned upstream snapshot is unchanged. The host initializes its zone allocator,
WAD directory, renderer resource metadata, and play subsystem, then starts a map
with `G_InitNew`. Native input becomes `ticcmd_t`; original `P_Ticker` runs at 35 Hz.
Original player and sector code handles motion, blocking, use traces, doors, and
hazards. No software world frame is generated. Unused upstream code is dead-stripped.

The full `G_Ticker` state machine is not connected. A completed exit invokes
`G_DoCompleted`, snapshots final stats and the engine-selected next map, and pauses
simulation for the native intermission. `MD_Continue` calls `G_DoWorldDone` to retain
inventory, then ticks once to initialize the new view height. It does not call
`G_InitNew`. Normal/secret routing and removal of keys/powers remain upstream rules.
Episode endings produce a terminal stats summary; original finales are deferred. Monsters, projectiles, pickups, and decorations keep
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
classic BSP and each leaf's directed seg boundaries. All side materials are cached, including those hidden by closed sectors.
Engine floor/ceiling height, light, sidedef texture or offset changes rebuild geometry
using current values, once per changed tic. The native bridge caches texture names
from the WAD using the engine's texture indices, without exposing internal texture
structs. SW1/SW2 counterparts are cached up front so pressing a switch needs no upload.
Textures persist and submitted buffers are immutable. Metal retains resources used
by in-flight commands; up to three command buffers may be outstanding.

Two-sided middle textures cover one texture-height interval clipped to the shared
sector opening. Pegging flags and row offsets determine its anchor, as well as
upper/lower/one-sided wall alignment. Directional wall fragments reject back faces,
so opposing sidedefs can use different art without depth fighting. Transparent
fragments discard before depth writes, preserving views and sprites behind grilles.

Sky flats are separate GPU geometry, not simply omitted ceilings. Sky planes and
boundary curtains write depth while sampling an unlit cylindrical sky using the
world ray, 1024 columns per revolution, and a 100-texel horizon. A matching background
fills uncovered pixels. Sky-to-sky height changes produce sky curtains rather than
ordinary upper walls. Dynamic geometry updates rebuild sky surfaces too.

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
ProgressionValidation tests the Ultimate Doom pillar switch and timed reset,
actual exit use, frozen stats, inventory carryover, key clearing, secret routes,
episode endings, and loading all 36 maps. Native rendering uses WIMAP/INTERPIC,
WILV, and WI stats patches. Return is queued independently of use/fire, and entry
input is cleared to prevent the exit press from skipping the intermission. A short
entry delay rejects accidental immediate continuation; a second fresh Return
loads the next map and updates the AppKit title and selector.

Surface regression tests assert E1M1 BRNBIG panels and their UV bounds, sky planes
and curtains, and floor/ceiling containment with an unused far-away fixture vertex.
`make_surface_fixture.py` creates local exit/sky viewing positions without monsters;
it changes only THINGS records, retaining original geometry and art.

## Native persistence

MD_WriteSave calls the original player/world/thinker/special archives inside the
C error boundary. A fixed-width extension adds gametic, full level time, both RNG
indices and active button timers with line indices. MD_ReadSave validates the
header, loads the base map and unarchives state without a simulation tic, then
restores the extension. Engine pointers never enter the Swift save container.
Enemy target/tracer pointers retain vanilla load behavior (cleared/reacquired).

SaveStore wraps the payload in a version-1 binary property list with the exact WAD
SHA-256, map id, view pitch, timestamp and payload checksum. It validates identity,
size, digest and map before preparing renderer resources and invoking the native
loader. File replacement is atomic; quick saves use an Application Support path
per WAD digest. Native fatal archive errors still poison the engine instance.
This wrapper detects accidental damage; it does not make the upstream decoder a
hardened parser for malicious, checksum-recomputed files.

SaveValidation exercises cross-map world/player round trips, enemy health, pickups,
switch timers, bad containers, wrong WADs, save-write failure, death/intermission
loading and rejection of bad native headers before live state changes.
