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
| Sources/AmbientOcclusion.swift | Shared ray mesh/pipeline, masked intersections, AO and direct-light shadow shading |
| Sources/DynamicLight.swift | Deterministic camera-relative light orbit and GPU uniforms |
| Sources/SpriteRenderer.swift | Sprite texture cache, billboard quads, original HUD patch composition |
| Sources/IntermissionRenderer.swift | Original intermission patches, stats and destination screen |
| Sources/SaveStore.swift | Versioned save container, WAD hash, integrity, atomic persistence |
| Sources/MapNames.swift | Canonical English map titles from the pinned engine |
| Sources/SoundPlayer.swift | DMX decoding, native AVAudioEngine voices, focus pause |
| Sources/main.swift | AppKit lifecycle, WAD picker, map selector, cursor/focus handling |

## Engine boundary

The pinned engine has narrow native integration changes; the 0.9.0 A_BossDeath hook delegates only recognized campaign overrides to Bridge.c. The host initializes its zone allocator,
WAD directory, renderer resource metadata, and play subsystem, then starts a map
with `G_InitNew`. Native input becomes `ticcmd_t`; original `P_Ticker` runs at 35 Hz.
Original player and sector code handles motion, blocking, use traces, doors, and
hazards. No software world frame is generated. Unused upstream code is dead-stripped.

The full `G_Ticker` state machine is not connected. A completed exit invokes
`G_DoCompleted`, snapshots final stats and the engine-selected next map, and pauses
simulation for the native intermission. `MD_Continue` calls `G_DoWorldDone` to retain
inventory, then ticks once to initialize the new view height. It does not call
`G_InitNew`. Normal/secret routing and removal of keys/powers remain upstream rules.
Doom episode endings and Doom II story/cast phases use native Metal presentation.
Monsters, projectiles, pickups, and decorations keep
their original thinker lifecycles. Native attack/change buttons drive unchanged
weapon code. A fresh Use/Enter restarts after the death delay; R reloads immediately. Native
input stays outside the upstream rebirth path. Software HUD and automap hooks are silent.
The bridge copies inventory values and captures/clears engine player messages after
each tic, with a serial so repeated pickups of the same type still renew the notice.

Everything runs on the main thread. Swift never owns pointers into Doom's arena;
snapshots copy scalars through C. Fatal errors unwind to `setjmp` wholly within C,
poison the instance, and become native error messages. Restart after a fatal error.
One fixed IWAD/PWAD stack initializes per process; map restarts reuse those resources. Open WAD hands off to a fresh app instance, closing the old instance only after
a successful-load acknowledgement. Canceled or failed switches and absent-map
requests preserve the active engine.

## Rendering and input

WAD `(x,y)` becomes Metal `(x,height,-y)`. Vertices contain position and texel UV/light
float4s. Wall art is composited at load time; floors/ceilings are clipped through the
classic BSP and each leaf's original directed linedefs. Seg endpoints can be rounded
off those lines by node builders, so they must not define clipping planes. Clipping
uses Double precision, then inserts shared edge vertices into adjacent flats and
horizontal wall edges before converting to GPU floats. Subdivided boundaries use
center fans to preserve collinear vertices and avoid raster T-junction cracks.
Wall UV/light attributes interpolate along the original triangle. All side materials
are cached, including those hidden by closed sectors.
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
frame/rotation/flip, and returns copied positions, light/fullbright, and combined-directory lump
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
engine messages and accessible inventory values. The bridge updates a copied face
index once per gameplay tic with classic priorities/durations and a separate
presentation random stream. It covers health bands, idle, weapon grin, directional
hurt, sustained fire, invulnerability and death. The reversed vanilla heavy-damage
subtraction is corrected; ouch persists for its reaction interval. Face state resets
on map/save load and is not part of the save payload.

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
approximations, not bit-exact DMX behavior. Route-change recovery remains.

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

## Music

`MUS.swift` translates bounded MUS scores into type-0 MIDI at 70 ticks per beat
(140 ticks per second), following the pinned upstream converter's event mapping.
Conversion state is local; MIDI lumps pass through to the selected backend's parser.
Classic OPL is the default. `Engine/OPLMusic.c` adapts the unchanged pinned
Chocolate Doom `i_oplmusic.c` sequencer and Nuked OPL chip emulator to offline
44.1 kHz stereo PCM, using the loaded stack's GENMIDI bank and Doom 1.9 OPL2
voice rules. The main-thread renderer caps each score at ten minutes and bounds
callback/event counts. `OPLPlayer.swift` owns the temporary MIDI/WAV directory
and an AVAudioPlayer with native looping; release and orderly shutdown delete
its files. No global gameplay WAD/zone state or SDL audio is used by rendering.
Switching the persistent Audio menu choice restarts the current track. A failed
switch reports an error and restores the previous backend preference.

In Apple MIDI mode, `MusicPlayer.swift` owns an AVAudioSequencer and Apple DLS synth on an independent
AVAudioEngine mixer, with the built-in macOS General MIDI sound bank. The renderer selects level/intermission/completion tracks
and pauses music alongside gameplay. Duration-based polling loops the score because
the sequencer can continue advancing after the last MIDI event. No completion
callback retains the player or races a subsequent track selection.

Track selection and loop restart send all-sounds-off, reset controllers, and center
pitch bend on all 16 synth channels before playback. Pause/resume preserves state.
A direct native synth regression measures A4 before bending it, after bending it,
and after selecting another track, proving that the bend does not leak.

MusicValidation loads every music lump in the supplied WAD into AVMIDIPlayer, then
checks native position advance, pause/resume, mute, selection, and a short synthetic
score's loop. It also checks malformed MUS data and percussion/controller mapping.

## Pause menu, settings and slots

GameMenu uses ClassicMenuCanvas for original menu patches, bitmap text, slot borders
and thermometers, with accessible AppKit button hit targets. Patch offsets are
preserved; keyboard input supports navigation, adjustment and save-name editing. Renderer.paused
gates the same update path as focus loss, freezing gameplay and intermission while
rendering the paused scene. Escape releases pending gameplay input before opening.
Classic controls select display and mixer settings; GameView sizes its Metal
drawable using display backing scale; Renderer scales the world separately. The app owns a separate
SoundPlayer decoding only five menu cues, so navigation remains audible while
gameplay is paused. It follows effects volume and pauses on focus loss.

MD_LoadSkill validates and passes difficulty to original G_InitNew. MD_GetSkill
synchronizes the host after save restoration. Six per-WAD slot paths are separate
from quick saves, and optional container titles preserve backward compatibility.

## Developer console

DeveloperConsole is an AppKit overlay with selectable scrollback, a text-field
command editor, session history and command-name completion. ConsoleCommand parses
and validates a bounded command set before App dispatches to existing renderer,
map and settings APIs. Output is capped at 400 lines and history at 100 entries.
Opening releases pending gameplay input, blocks GameView input and pauses the
renderer. Closing restores the prior menu/pause state. Original engine code is
unchanged; commands do not execute shell code.

## Animated world materials

The bridge enumerates source frames from the pinned engine's p_spec animation table
and copies translated texture/flat IDs. Metal preloads those frames at map load and
selects the current translated texture when drawing each batch, preserving geometry
and UVs. P_UpdateSpecials owns the 8-tic animation clock; pause freezes it. Save
restoration rebuilds translation tables from the saved level time without ticking
thinkers or advancing gameplay. The animation layout is shared through Engine/ResourceTables.h; no engine
pointers escape to Swift.

## Attract mode and cheats

AttractScreen renders the WAD title/credit patch with 4:3 pixel scaling. App owns the
foreground-only attract timer and title music, retaining the page or paused demo
behind GameMenu. Demo map resources load through Renderer before copied snapshots
are consumed. Title/menu/console input is isolated from playback; normal New Game,
load or map selection clears attract state. Saving an attract state is blocked.

The bridge validates a complete, bounded single-player 1.8/1.9 demo header and
four-byte command stream before starting playback. G_InitNew resets the original
engine with the recorded skill/options and appropriate executable version; each
35 Hz tic uses recorded movement/turn/buttons through P_Ticker. Live commands are
ignored. End markers and level completion return to the attract sequence. Demo
buffers are freed on completion, restart and load. Full G_Ticker/network/demo
recording compatibility is outside this implementation.

Typed cheat prefixes are consumed only in gameplay. Console aliases dispatch to
the same bridge implementation; cheats modify original player flags, inventory
and powers, emitting HUD feedback. Nightmare/dead players and demos reject cheats.
Weapon grants filter shareware and Doom II-only weapons. No vendored engine files
are changed.

## Menu branding

MenuLogo derives the Ultimate Doom caption from the loaded standard-size TITLEPIC
and combines it with the transparent M_DOOM patch at runtime. Gold caption pixels
are isolated in the known title regions, outlined and resampled with nearest-neighbor
sampling. The lower title logo is not copied because the character obscures it.
Missing or differently sized artwork falls back to M_DOOM. No generated game artwork
is shipped. GameMenu reserves extra header space for the composite and ClassicMenuCanvas
renders a small version/build footer separately from bitmap menu labels.

## Power-up shaders and fuzz

MD_HUD copies fixedcolormap, suit/berserk state, invisibility duration and map power.
World/sky/sprite fragments share inverse-grayscale and full-bright power uniforms;
HUD fragments receive neutral uniforms. Existing scene tints include suit and berserk.
These are RGB approximations, not exact PLAYPAL/COLORMAP remapping.

Shadow flags are copied for world sprites and weapon frames. Opaque geometry and
sprites render first; a Metal blit copies their color buffer into a private texture.
A second render pass loads color/depth and draws shadow masks using displaced,
darkened scene samples with depth testing but no depth writes. Weapons/HUD finish
the frame. The fuzz phase follows gameplay tics, so pause freezes its pattern.
MTKView framebufferOnly is disabled for the snapshot blit. Spectres use original
MF_SHADOW; the weapon follows the original invisibility expiry blink condition.

## Native automap

AutomapView overlays the world portion of GameView while preserving the status bar
and live simulation. It redraws at 30 Hz, reads copied line/player snapshots, and
supports follow, fit, zoom, pan and close controls through the local key monitor.
Movement keys still reach gameplay; map controls and mouse clicks do not fire.
Map titles sit at the upper right to avoid pickup messages.

Because the hardware renderer never calls R_StoreWallRange, the bridge approximates
exploration every five gameplay tics with original P_CheckSight tests to nearby,
forward-facing line midpoints. Only ML_MAPPED changes; it is already included in
native save archives. Map snapshots classify hidden/secret walls, floor/ceiling
changes and teleport lines. The map power reveals unmapped non-hidden lines in gray.
Full software automap discovery, thing markers, rotation and IDDT remain separate work.

## Application shutdown

The Swift-owned main window disables AppKit release-on-close. Window closure and
application termination share idempotent cleanup: cancel attract mode and its
timer, release input, detach/pause the Metal view, pause audio, and remove the key
monitor. Attract callbacks check shutdown state before accessing window state.
Ending attract mode also invalidates its timer during normal gameplay transitions.
`test-shutdown.sh` drains the run loop after loaded-WAD closure and checks that
late callbacks and repeated cleanup are harmless.

## Ordered WAD stacks and SIGIL

WAD retains the source file URLs and byte snapshots. Add-on loading builds a
single directory plan: general lumps retain file order, sprite/flat namespaces
combine exact-name replacements, and later files win. MD_ConfigureWADStack opens
the separate files and applies that same index plan before R_InitData/P_Init.
Swift texture/audio/sprite lookups and native engine indices therefore agree;
no stitched WAD or bundled game assets are created. The active renderer and bridge
reject changes to an initialized stack. Malformed replacement maps cannot borrow
lumps from a following map. Save identity hashes ordered, fixed-length per-file
digests with a domain prefix, preserving single-IWAD identity unchanged.

Standard SIGIL v1.23 is a deliberate compatibility profile, not a general metadata
parser. E5 keeps its native map identifiers and disables the original E3 boss-exit
semantics. Completion borrows E3's secret return with E5 par times, then restores
the episode number; native save headers accept E5 only with SIGIL loaded. Swift
selects its map titles, SKY5, intermission artwork and E5TEXT/credit ending. Other
metadata/DeHackEd-dependent add-ons are rejected rather than silently ignored.

## Doom II story and cast phases

After stats, MD_BeginStory calls the original G_WorldDone/F_StartFinale to choose
story text and background. Non-story exits proceed directly. Phases 3 and 4 denote
commercial story and cast; Doom's existing episode finale remains phase 2. Story
input reveals text and then continues, preserving inventory through G_DoWorldDone.
MAP30 enters upstream F_StartCast/F_CastTicker/F_CastResponder. The bridge copies
cast name, sprite patch, flip and death state; Metal presents BOSSBACK, text and
sprite quads without calling software drawers. Fire taps are retained until a cast
tic. Swift selects D_READ_M/D_EVIL; native finale music hooks are presentation stubs.

## Experimental ray-traced lighting

`AmbientOcclusion.swift` owns the optional shader and primitive acceleration
structure shared by independently enabled AO and the moving test light. View
selects AO strength/radius and light/shadow toggles for the session; classic
rendering is the launch default. World positions build the structure before
rendering on the same command buffer. Masked hits use interpolated texel UVs and
the current animated alpha mask; opaque batches commit directly. Replacement
buffers/structures keep queued frames immutable. Position equality avoids builds
for sector-light/UV-only changes. AO traces eight short hemisphere rays. Direct
light adds a normal-weighted, radially attenuated color contribution and, when
shadows are enabled, a finite alpha-tested visibility ray toward the light.
`DynamicLight.swift` derives the orbit from level tics and camera orientation;
moving it changes uniforms rather than the acceleration structure. Sky, sprite,
weapon and HUD shading remain independent. Both effects bypass fixed-colormap
power-ups; ray failure clears both enable flags and restores classic rendering. See
[Metal experiments](METAL_EXPERIMENTS.md) for controls and measurement boundaries.

## Resolution and campaign profiles (0.9.0)

See [world composition and scaling](RESOLUTION.md) and [campaign profiles](KEX_SUPPORT.md).
SIGIL II uses its ANIMATED resource table; normal engine ticks and save restoration
drive it. Profile routing and boss overrides
are per-process and keep the base engine behavior when no profile is configured.

## Resource tables and extended-engine direction (0.10.0)

Engine/ResourceTables.c decodes packed little-endian ANIMATED/SWITCHES, replacing
built-in tables only when a corresponding lump exists. Tables allocate within the
zone with a 65,536-record input budget and required termination. Unknown animation
starts and missing switch pairs are skipped; invalid cycles, names, rates and
records fail through the C error boundary. No arbitrary mod acceptance is enabled.
The bridge enumerates all switch materials, allowing Metal to preload pairs whose
names do not follow SW1/SW2. Animation timing and button archives use the existing
engine paths. See [Rust/ID24 evidence and milestones](LEGACY_OF_RUST.md) for the
extended simulation boundary, XNOD requirement and remaining save/ABI work.
