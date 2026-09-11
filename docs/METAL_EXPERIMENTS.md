# Metal rendering experiments

Branch: `codex/metal-experiments`. Classic rendering remains the launch default.

## Ray-traced ambient occlusion

Choose **View → Ray-Traced Ambient Occlusion (Experimental)** to compare the
current scene. The checkbox is per session and does not change game/save data.
It is disabled on GPUs without Metal ray tracing in render shaders. Allocation,
shader compilation and GPU failures report an error; the classic path remains
available. The ray-tracing pipeline and acceleration structure are allocated only while
AO or any world light category is enabled.

**View → AO Strength** offers 0–100% in 25% steps. **View → AO Radius** offers
16, 32, 48 and 96 Doom units. The defaults are 50% strength and 48 units; choices
last for the session, including toggles and map changes. Both settings appear
in diagnostics and benchmark identity. Changing settings does not rebuild the
ray mesh. Zero strength produces the same pixels as classic rendering.

The experiment shades nearby wall/floor/ceiling intersections using eight (Balanced) or sixteen (High) fixed,
cosine-weighted hemisphere rays per world fragment. Distance-weighted occlusion
reduces existing sector/distance lighting by up to the selected strength. It
adds no light sources and leaves power-up fullbright/inverse rendering, skies,
sprite shading, weapons and HUD on their existing paths. The fixed sample pattern
has no temporal noise or accumulation, but can show directional bias or bands.
This is a small-sample approximation, not full global illumination.

World materials with transparency now cast occlusion through their solid pixels.
A Metal intersection query accepts masked candidates only when interpolated,
wrapped texel alpha is at least 128/255, matching rasterization's nearest-sampled
alpha cutoff. Holes allow the ray to continue to another surface or escape.
The mask lookup follows the current translated animated texture. Fully opaque
batches can commit in hardware; animated walls conservatively use alpha testing
when any animated wall frame is masked. Sky boundaries and billboard sprites
still never cast occlusion.

The renderer reuses existing map triangles. A fresh acceleration structure is
encoded before world rendering when positions/topology/opacity classification
change, including moving sectors and map/save loads. In-flight commands retain
older resources. UV-only changes replace the immutable attribute buffer without
rebuilding the structure, and animation changes replace material mappings only.
Alpha masks are packed at map load. This version rebuilds the whole world mesh
for geometric changes; separating static/moving geometry remains future work.

## Moving test light and shadows — 0.5.0

**View → Moving Test Light (Experimental)** enables one amber light with radius
256 Doom units and intensity 2. It orbits a point 40 units ahead of the player
over eight seconds (16 units forward/back, 32 sideways), at eye height +12 clamped
inside the destination sector's floor/ceiling. Its clock is level game time, so
it freezes while paused/inactive and resumes from saved time. A wall may obscure
the source during its orbit. There is no visible source orb or physical light actor.

**Test Light Shadows** defaults on and is separately switchable. Direct lighting
uses the surface normal, squared radial falloff and the original texture color.
One finite ray toward the light tests visibility only for lit, in-range fragments;
geometry beyond the light does not block it. Grille masks use the same current
texture translation, wrapping and alpha threshold as AO. These are hard shadows.

AO and the light share one pipeline, acceleration structure and immutable mask
buffers but remain independently enabled. Moving the light or toggling shadows
does not rebuild geometry. Turning AO and all world light categories off releases ray resources and
restores the original pipeline. Failure disables ray effects with a warning. AO and the test light start
off; controls are per session, survive map/save loads, appear in diagnostics and
benchmark identity, and are locked during a benchmark.

Direct light is added after AO darkens ambient sector lighting. It affects world
surfaces only: sprites/weapon/HUD/sky and fixed-colormap power-ups retain their
existing paths unless Sprite Lighting is selected (0.7.0). Billboard sprites
do not cast shadows. The original 0.5.0 experiment had no other light sources or bloom; 0.6.0 adds
the independent options below. HDR is available in 0.8.0 below; multi-bounce indirect illumination remains unimplemented.

The existing GPU script now also checks analytic light attenuation, opaque and
masked blockers, geometry beyond the light, shadow bypass, independent toggles,
light motion, paused stability, shared resources and save/load. `AO_CEILING=1`
also compares shadows at twelve original E1M1 room/phase combinations. Outputs
include `light-shadowed.png`, `light-unshadowed.png`, `light-ao.png` and scene pairs.

A separate native room fixture can be generated without changing source game data:

```sh
python3 Tests/make_surface_fixture.py /path/to/DOOM.WAD build/light.wad light
```

Open the resulting WAD and enable the test light. It relocates the player near
the E1M1 pillar/stairs and disables monsters; geometry/art remain original.

## Gameplay lights, emission and bloom — 0.6.0

**View → More Metal Effects** includes these original six session-local switches, all off
at launch. A shadow switch can be selected before enabling a light category.

| Switch | Visible behavior |
| --- | --- |
| Torch & Lamp Lights | Blue/green/red torches, candles, burning barrels and tech lamps illuminate nearby world surfaces. |
| Projectile Lights | Plasma, BFG, rockets and selected monster fireballs carry colored lights, including their surviving explosion frames. |
| Muzzle Flash Light | Brief warm, blue or green illumination while the engine weapon flash sprite is active. |
| Gameplay Light Shadows | Finite, alpha-tested hard world shadows for the three categories above; the test light retains its own shadow switch. |
| Emissive Surfaces | Bright texels on LITE/TLITE/GATE, NUKAGE/LAVA/FIRE families and saturated COMP panel pixels self-illuminate. |
| Bloom | Soft halo around bright world highlights, independent of emissive surfaces. |

Lighting follows authoritative actor snapshots and weapon flash state. It makes
no simulation changes and needs no save-format change. Flicker freezes with game
time. Emitters stay inside sector heights. At most 16 lights are submitted, with
the test light and muzzle flash reserved first, then nearest eligible actors
within 1024 units (engine order breaks equal-distance ties). Decorations have a
224-unit radius, projectiles 176, muzzle flashes 192. Distant/budgeted-out sources
can pop in; no screen-tiled light culling is implemented yet.

Dynamic lights illuminate world triangles, with optional sprite reception in 0.7.0;
billboard sprites do not cast shadows. The three new light categories require ray tracing
in render shaders, even with their shadows off. Emission and bloom work without
ray tracing. Emission uses material names and color thresholds, not authored masks;
custom replacement textures can be misclassified, and unknown families stay classic.
Self-emission alone does not illuminate neighboring surfaces; 0.7.0 adds a
separate Emissive Surface Lighting switch. Animated materials retain their
family while sampling the current engine texture frame.

Bloom copies only the world viewport, extracts highlights at quarter resolution,
runs a separable nine-tap blur and adds a restrained 12% glow before the weapon,
damage tint and HUD. In SDR this is LDR bloom; in HDR the same pass preserves extended highlights before display mapping. Skies and fullbright
world sprites can bloom too. Invisibility uses the existing world snapshot and
the weapon is drawn afterward. Fixed-colormap power-ups bypass bloom and added
lighting/emission. There is no temporal history. Disabling bloom releases its
textures; resize replaces them safely, and disabling all effects restores classic
pixels. Session choices are logged, included in diagnostics/benchmark identity,
locked during benchmarks, and retained through map/save loads.

The GPU regression also exercises engine-spawned lights, real pistol flash/expiry,
individual image changes, combined effects, HUD isolation, classic restoration,
odd-sized resize, source budget, save/load, map replacement and shutdown. Additional
captures use `effect-*.png`, `effect-muzzle.png` and `effects-combined.png`.
For a native comparison with three colored torches in original E1M1 geometry:

```sh
python3 Tests/make_surface_fixture.py /path/to/DOOM.WAD build/effects-preview.wad effects
```

Open that local fixture and enable the switches. Keep the generated WAD private.

## Connected lighting and particles — 0.7.0

Four more independent View → More Metal Effects switches start off each launch:

- **Sprite Lighting** uses the same bounded sources and world shadow rays on
  monsters/pickups. Isotropic reception avoids shading tied to billboard rotation.
  Alpha-cutout edges remain exact; original fullbright frames and power-up colormaps
  bypass additional lighting. Fuzz/invisibility, weapon and HUD use their original
  paths. Sprites still do not cast shadows or receive AO.
- **Emissive Surface Lighting** averages eligible bright texels of known material
  families and builds one-sided light patches from actual world triangles.
  Large triangles are subdivided toward 128-unit edges (at most eight recursive
  splits), then grouped into 128-unit cells on each material/plane. Representatives
  stay on actual triangles and are offset four units into the emitting side.
  The nearest four patches reserve slots in the existing 16-light budget; the
  test light and muzzle flash retain priority among remaining actor sources.
  These 256-unit-radius sources always test world occlusion, independently of
  Gameplay Light Shadows. Moving sectors/material changes invalidate the source
  cache; sector-light flicker alone does not. Map/save loads rebuild it.
- **Soft Shadows** uses four (Balanced) or eight (High) fixed disk samples instead of the hard-shadow ray
  when a source has shadows enabled. Test/gameplay source radius is six units;
  emissive patches use twelve. Samples on emissive sources stay parallel to the
  emitting plane. Hard shadows return exactly when switched off. This small
  sample count can show steps in penumbrae; no temporal filtering is used.
- **Embers & Projectile Trails** draws at most 128 small additive, depth-tested
  particles from nearby torch/projectile snapshots, independently of their light
  switches. Embers rise; projectile sparks trail along copied engine velocity.
  Trails approximate the previous four tics using current velocity and disappear
  with their source. There is no simulation history, collision or lingering impact
  smoke; saves need no extra particle state. The level clock controls animation,
  with no animation while paused. Fixed-colormap power-ups bypass particles.

The world shadow mesh and source buffers are shared. Enabling sprite reception
alone creates no lights; soft shadows alone create no sources. Sprite/surface
lighting requires ray tracing in render shaders. Particles need ordinary Metal.
Particles are drawn before bloom and the weapon/HUD. All new switches appear in
reports and benchmark identity, lock during a benchmark, and survive map/save
loads within the session. Bounded source selection can pop as the camera moves;
this is approximate direct surface emission, not multi-bounce GI.

GPU checks include analytical partial shadow visibility and one-sided emission,
real monster reception, original nukage/LITE5 rooms, independent source switches,
real rocket velocity/trails, budgets, exact restoration, power-ups, resize and
save/load. Additional images are `advanced-*.png`. For native inspection:

```sh
python3 Tests/make_surface_fixture.py /path/to/DOOM.WAD build/advanced-preview.wad advanced
python3 Tests/make_surface_fixture.py /path/to/DOOM.WAD build/emission-preview.wad emission
```

The first adds torches, a medikit and barrel to original pillar-room geometry;
the second relocates the player to the original zigzag/nukage room. Keep generated
WADs private.

## Comparing and measuring

Pause at the same viewpoint and toggle the View option. Keep window dimensions,
render scale and display settings identical. **Copy Diagnostic Report** includes
the AO state, ray settings, occluder count and the latest GPU command duration.
That duration includes the complete frame and any acceleration-structure build;
it excludes presentation latency and is not an FPS estimate.

The existing **Diagnostics → Run Benchmark…** records AO state in its report and
settings identity, so switching it invalidates a run. It still measures capped
CPU submission intervals rather than isolated GPU time. Compare a classic and
an AO run with the same IWAD, build, dimensions, frame cap and display.

Run the focused native GPU regression with your own WAD:

```sh
bash scripts/test-ambient-occlusion.sh /path/to/DOOM.WAD
AO_OUTPUT="$PWD/build/ao-doom2" bash scripts/test-ambient-occlusion.sh /path/to/doom2.wad MAP01
AO_CEILING=1 AO_OUTPUT="$PWD/build/ao-ceiling" bash scripts/test-ambient-occlusion.sh /path/to/DOOM.WAD
```

The regression needs a logged-in Mac desktop and GPU access. Its gameplay
fixture advances engine ticks directly, so the test need not keep keyboard focus.
Validation failures print `FAIL` and exit nonzero; native load errors also print
to stderr instead of opening a modal dialog. It opens a test
window with Metal API validation, compares a paused 1280×800 scene, checks
unchanged HUD and exact classic restoration, exercises a moving Ultimate Doom
door, replaces the map and closes the window. PNG comparisons and sampled GPU
command times go under `build/ao-validation` (or `AO_OUTPUT`); these local outputs
and WAD data must not be committed. Timings include API validation overhead and
synchronous readback affects workload pacing; use normal-app benchmarks for
sustained gameplay performance.

For a local visual fixture using the original Ultimate Doom MIDGRATE texture:

```sh
python3 Tests/make_ao_grille_fixture.py /path/to/DOOM.WAD build/ao-grille.wad
AO_OUTPUT="$PWD/build/ao-grille" bash scripts/test-ambient-occlusion.sh "$PWD/build/ao-grille.wad"
```

The generator changes one E1M1 portal's middle textures and player start while
preserving geometry, and disables monsters in that map. Never distribute the
output IWAD. The GPU regression also checks analytic grille rays against known
hit distances, alpha cutoff, negative UV wrapping, texture-mask changes and
UV-only updates; these do not depend on a particular WAD's scene contents.

`AO_CEILING=1` requires original Ultimate Doom E1M1 geometry/art. It captures 24
upward viewpoints in the zigzag room with AO off and at strength 100%/radius 96,
rejects bright sky pixels above the HUD, and writes a `ceiling.mdsave` camera
fixture. To start a native window near the affected ceiling, generate a local WAD
with `python3 Tests/make_surface_fixture.py /path/to/DOOM.WAD build/ceiling.wad ceiling`,
open that WAD and look up. The long ceiling slit reported in build
86 also occurred with AO off: rounded BSP seg endpoints trimmed gaps out of the
flat mesh. Build 87 uses original linedef clipping and shared flat/wall edge
vertices to close the slit and smaller T-junction gaps. This adds triangles; the
older performance figures above should not be treated as build 87 measurements.


## Volumetric lighting, HDR and presets — 0.8.0

**View → More Metal Effects → Volumetric Lighting** adds light scattering from
existing test/gameplay/surface sources. It does not create a sun or extra light
sources. **View → Volumetric Density** offers Light Haze, Atmospheric, Dense and
Thick (0.001, 0.003, 0.006 and 0.01 inverse Doom units). Default: Atmospheric.

The compute pass marches 16 (Balanced) or 32 (High) fixed midpoint samples at quarter width/height,
selecting four nearest lights from the existing bounded source list. Marches stop
at raster depth or 768 units. Each source retains finite falloff and one-sided
surface emission; enabled shadows trace the same alpha-tested world. Volumetric
shadows use one ray per step even when surface Soft Shadows is selected. The
resolve weights four neighbors by depth to avoid bleeding over foreground edges.
Compositing is additive, before bloom and the weapons/HUD. Power-up fixed colormaps
bypass it, and paused frames have no temporal noise. Sprites bound the viewing
ray through raster depth but still do not cast light shadows. Four-source selection
can pop, finite steps can show bands, and this is lit haze rather than a full
participating-media simulation with multiple scattering or dense fog extinction.

**View → HDR Display Output** swaps the complete render pipeline set to RGBA16Float
and enables CAMetalLayer EDR with extended linear sRGB. The intermediate scene
preserves Doom's existing palette/distance lighting in an extended range rather
than replacing its look with physically based materials. The final pass decodes
the sRGB transfer function, preserves SDR midtones, and maps over-range highlights
through a hue-preserving shoulder. Peak limits no longer multiply near-white contrast. Fullbright sprites, power-ups,
weapons and HUD remain at standard white; only actual light/emission energy adds
extended highlights.
Bloom can consume over-range light/emission values before this mapping.

Peak controls request up to 2×, 4× (default) or 8× standard white, constrained by
`NSScreen.maximumExtendedDynamicRangeColorComponentValue` every frame. This is
relative brightness, not a promise of a specific nit level. Potential headroom
controls whether HDR can be enabled from the menu; moving an enabled window to an
SDR display maps back to 1× automatically. System brightness is never changed.
The app uses Apple's [custom EDR tone-mapping setup](https://developer.apple.com/documentation/metal/performing-your-own-tone-mapping).

**Graphics Presets** change and remember render scale/frame cap only: Performance
50%/120, Balanced 75%/120, Native 100%/120 and Quiet 75%/60. **Effects Presets** do
not change resolution, frame rate or gameplay. Classic disables all effects;
Enhanced uses AO at 25%/16 units plus torch/projectile/muzzle lights, gameplay
shadows, emissive surfaces, bloom, sprite reception, soft shadows and world filtering.
Atmospheric enables all twelve scene switches with AO at 25%/32 units and Light
Haze density. HDR Showcase adds HDR output to Atmospheric. Built-ins leave the moving test light off. Manual overrides remove
the built-in checkmark; Save Current as Custom stores one full effects setup,
including test lighting, AO, density and HDR controls. Apply Saved Custom restores
it after relaunch. Launch effects remain Classic; graphics preferences persist.

Preset and HDR changes allocate a full compatible set before switching state.
Failure leaves the prior setup intact. New settings are reflected in diagnostics,
benchmark identity and benchmark locking. Tests in HDRVolumeValidation.swift use
real half-float GPU readback, including an opaque-partition scattering probe,
SDR HUD color equivalence, synthetic 1×/2×/4×/8× headroom, live display output,
resize, save/load and repeated format switching.


### Preset polish — build 104

The initial Enhanced preset already used SDR. Its harsh texture contrast and
aliasing were therefore not purely HDR artifacts. Showcase also combined noisy
12-step fog and an extra HDR peak-dependent contrast multiplier. Build 104 removes
that multiplier and the blanket fullbright-sprite gain, reduces bloom, and blends
added direct light in linear space at half the former source energy scale while
preserving the original sector/distance base exactly when no light is present.
The overall renderer remains palette-based rather than a full PBR material system.

**Smooth World Textures** is enabled by the enhanced presets and can be toggled
independently. Static and animated world textures have GPU-generated mipmaps;
the filtered sampler uses trilinear filtering and up to 4× anisotropy. Mask alpha
always comes from the original nearest texel, matching shadow rays. Filtered
colors are unpremultiplied to avoid black cutout fringes. Sprites, skies, weapons
and HUD retain their existing sampling, and fixed-colormap power-ups bypass
filtering. Turning filtering off restores original world texels exactly.

AO now uses sixteen fixed hemisphere rays, soft shadows eight disk rays, and
volumetrics 32 fixed midpoint samples. There is no per-pixel fog jitter pattern.
Built-in AO strength is reduced to 25%; Enhanced uses a 16-unit radius,
Atmospheric/Showcase 32 units and 0.001 haze density. These are visual-quality
choices with additional GPU cost, not a performance improvement. Existing saved
custom sets are preserved; reselect a built-in or resave custom to adopt changes.


### Performance and ray quality — build 106

Ray shading previously ran during ordinary world drawing, potentially tracing
rays for surfaces later hidden by nearer batches. A color-write-disabled world
pass now resolves nearest depth with the original binary alpha masks. The ray
color pass uses equal-depth, no depth writes and `early_fragment_tests`; sprites
then return to normal depth writes. Sky and masked geometry retain their original
coverage. Only the ray path needs the extra visibility pass; Classic is unchanged.

Shadow queries use Metal's accept-any-intersection option so the first accepted
opaque or alpha-tested hit is sufficient. AO continues finding nearest distances.
This preserves finite light ranges, grille holes and one-sided surface emitters.

**View → Ray Quality** selects Balanced (8 AO rays, 4 soft-shadow rays, 16 haze
midpoints) or High (16/8/32). Presets choose Balanced; High retains build 104's
sample counts. Neither setting changes resolution, texture filtering, HDR peak,
light budget or haze density. Changes do not rebuild the world structure, are
included in diagnostics/benchmark identity, and round-trip through custom saves.
Older saved presets without the new field load as Balanced.

Occluded/minimized live windows skip GPU submissions and pause audio. Explicit
manual draws in the GPU harness remain available without a focus prerequisite.

For comparable per-preset GPU timings without pixel readback:

```sh
AO_PROFILE=1 AO_VALIDATION_LAYER=0 AO_OUTPUT="$PWD/build/effects-profile" \
  bash scripts/test-ambient-occlusion.sh /path/to/DOOM.WAD
```

This fixes the viewport at 2200×1520, pauses simulation, warms eight frames and
records 32 GPU durations per case. It fences each frame, so these timings exclude
display pacing and are not native FPS. Avoid competing renderers. See VALIDATION.md
for baseline provenance and a live frame-interval comparison at the user's save.
