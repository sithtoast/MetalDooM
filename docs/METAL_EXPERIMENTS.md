# Metal rendering experiments

Branch: `codex/metal-experiments`. Classic rendering remains the launch default.

## Ray-traced ambient occlusion

Choose **View → Ray-Traced Ambient Occlusion (Experimental)** to compare the
current scene. The checkbox is per session and does not change game/save data.
It is disabled on GPUs without Metal ray tracing in render shaders. Allocation,
shader compilation and GPU failures report an error; the classic path remains
available. No ray-tracing pipeline or acceleration structure is allocated while
the effect has never been enabled.

The experiment shades nearby wall/floor/ceiling intersections using eight fixed,
cosine-weighted hemisphere rays per world fragment. Rays extend 48 Doom units;
distance-weighted occlusion reduces existing sector/distance lighting by at most
50%. It adds no light sources and leaves power-up fullbright/inverse rendering,
skies, sprite shading, weapons and HUD on their existing paths. The fixed sample
pattern has no temporal noise or accumulation, but can show directional bias or
bands. This is a small-sample approximation, not full global illumination.

Only fully opaque world materials cast occlusion. Materials with transparent
pixels are omitted entirely, including their opaque portions, so grilles do not
block rays as solid rectangles. Animated walls are conservatively excluded if
any wall animation frame is masked. Sky boundaries and billboard sprites never
cast occlusion. Masked world surfaces can still receive occlusion from nearby
opaque geometry. Alpha-tested ray intersections and sprite occlusion are future
work.

The renderer reuses its existing map triangles. A fresh Metal primitive
acceleration structure is encoded before world rendering when opaque positions
change (including moving doors/lifts and map/save loads). In-flight commands
retain the older resources. Sector light/UV changes do not rebuild it when the
positions are identical. This first version rebuilds the whole opaque mesh;
large animated maps may benefit from separating static and moving geometry.

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

The regression needs a logged-in Mac desktop and GPU access. It opens a test
window with Metal API validation, compares a paused 1280×800 scene, checks
unchanged HUD and exact classic restoration, exercises a moving Ultimate Doom
door, replaces the map and closes the window. PNG comparisons and sampled GPU
command times go under `build/ao-validation` (or `AO_OUTPUT`); these local outputs
and WAD data must not be committed. Timings include API validation overhead and
synchronous readback affects workload pacing; use normal-app benchmarks for
sustained gameplay performance.
