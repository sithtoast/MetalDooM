# Metal rendering experiments

Branch: `codex/metal-experiments`. Classic rendering remains the launch default.

## Ray-traced ambient occlusion

Choose **View → Ray-Traced Ambient Occlusion (Experimental)** to compare the
current scene. The checkbox is per session and does not change game/save data.
It is disabled on GPUs without Metal ray tracing in render shaders. Allocation,
shader compilation and GPU failures report an error; the classic path remains
available. The ray-tracing pipeline and acceleration structure are allocated only while
AO or the moving test light is enabled.

**View → AO Strength** offers 0–100% in 25% steps. **View → AO Radius** offers
16, 32, 48 and 96 Doom units. The defaults are 50% strength and 48 units; choices
last for the session, including toggles and map changes. Both settings appear
in diagnostics and benchmark identity. Changing settings does not rebuild the
ray mesh. Zero strength produces the same pixels as classic rendering.

The experiment shades nearby wall/floor/ceiling intersections using eight fixed,
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
does not rebuild geometry. Turning both effects off releases ray resources and
restores the original pipeline. Failure disables both with a warning. Both start
off; controls are per session, survive map/save loads, appear in diagnostics and
benchmark identity, and are locked during a benchmark.

Direct light is added after AO darkens ambient sector lighting. It affects world
surfaces only: sprites/weapon/HUD/sky and fixed-colormap power-ups retain their
existing paths. Billboard sprites neither receive nor cast light/shadows. No HDR,
bloom, emissive textures, torch/projectile light collection, indirect illumination
or soft-shadow sampling is included in this first experiment.

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
