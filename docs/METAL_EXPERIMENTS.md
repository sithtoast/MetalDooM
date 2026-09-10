# Metal rendering experiments

Branch: `codex/metal-experiments`. Classic rendering remains the launch default.

## Ray-traced ambient occlusion

Choose **View → Ray-Traced Ambient Occlusion (Experimental)** to compare the
current scene. The checkbox is per session and does not change game/save data.
It is disabled on GPUs without Metal ray tracing in render shaders. Allocation,
shader compilation and GPU failures report an error; the classic path remains
available. No ray-tracing pipeline or acceleration structure is allocated while
the effect has never been enabled.

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
