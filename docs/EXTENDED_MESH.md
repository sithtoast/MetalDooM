# Incremental Rust geometry — 0.10.0 build 139

The preview retains a fixed map's BSP layout and updates the surfaces affected by
current sector/side values. This build-139 optimization left simulation, ABI and
wire layouts unchanged. Build 140 adds MUI1/MVW5; build 146 adds MGE2 floor/ceiling offsets. Every triangle is retained; the native comparison uses the old complete
mesh as its reference.

## Copied data and invalidation

`ExtendedGeometry` first validates header/length/count bounds. Against the previous
valid snapshot it compares identity/counts and every vertex, line, seg, leaf and
node byte. Exact matches reuse those already validated arrays. Only differing
36-byte side and 44-byte sector records decode again; names and side-sector
references still validate. Player/start metadata updates normally. A changed
immutable record falls back to complete decoding/validation. Invalid cached data
fails rather than inheriting the previous value. `reusedTopology` describes this
wire-array reuse; changed side-sector membership can still invalidate the mesh.

`ExtendedMesh` checks actual static arrays and side-sector membership, caches one
`GeometryTopology`, and builds one chunk per linedef plus one flat chunk per
sector. An offset-only sector change invalidates its flats; other changed sector fields
also invalidate both sides of bordering lines;
a changed side invalidates every line that references it. This includes adjacent
height-dependent upper/lower/middle walls, pegging, sky boundaries, light clamps
and offsets. Static changes rebuild the topology cache. Missing resource behavior
is unchanged.

The topology retains BSP-clipped polygons, split flat triangles and wall-edge
T-junction points. Geometric calculations use the original double-precision
clipping/stitching equations. Lexicographic tie breaks make nearly coincident
edge choices independent of Swift Set iteration. Dynamic heights, UVs, lighting
and material names are evaluated again for changed chunks.

Only materials belonging to replaced chunks are assembled again; other vertex
arrays stay shared. `ExtendedScene.changedMaterials` controls Metal replacement.
Unchanged material buffers keep their identity. Changed buffers are freshly
allocated, so a GPU command still reading the old buffer remains valid. Empty
materials disappear; sky buffers clear/rebuild when the sky material changes.
Textures, sprites and engine material animation keep their existing caches.
An explicit repeat geometry query produces no material-buffer changes.

Classic callers still build a full `Geometry`; the extended cache is opt-in at
the scene-builder boundary. The common topology algorithm is checked against a
frozen build-137 implementation for classic and Rust geometry.

## Measurements and validation

140 tics per map, after startup; worker IPC/decode plus CPU scene preparation:

| Map | Build 137 mean | Build 139 mean | Build 139 p95 | Build 139 max |
| --- | ---: | ---: | ---: | ---: |
| MAP01 | 12.52 ms | 2.12 ms | 2.69 ms | 4.52 ms |
| MAP13 | 210.57 ms | 20.56 ms | 24.03 ms | 28.16 ms |
| MAP16 | 4.27 ms | 0.87 ms | 1.06 ms | 2.33 ms |

Each map changes geometry on all 140 tics but builds static topology once.
MAP13 is about 10.2 times faster in this comparison. The earlier prototype sample
was 17.64 ms; the final sample was taken with the native preview open, illustrating
normal host-load variability. These timings exclude native Metal upload/drawing.

A separate native Metal API validation check at 640×400 measures scene loading
at 0.40 ms mean on MAP01, 3.39 ms MAP13, 0.18 ms MAP16 (MAP13 max 4.15 ms).
It retains 6,130 of 7,776 observed material buffers on MAP13 and renders seven
sampled tics on each map against the frozen old full mesh: **all 21 images match
pixel-for-pixel**. These samples are not sustained whole-campaign frame rates.
The worker still copies/compares full MGE2 and sends it when anything changes;
changed materials still assemble/upload all of that material's vertices.

Commands (private WAD inputs, generated outputs stay ignored):

```sh
bash scripts/test-extended-worker.sh original-doom2.wad /path/to/rerelease
bash scripts/test-extended-geometry.sh original-doom2.wad /path/to/rerelease
bash scripts/test-extended-mesh.sh /path/to/rerelease
bash scripts/test-extended-playback.sh /path/to/rerelease
bash scripts/test-extended-metal.sh /path/to/rerelease
```

The mesh and Metal scripts require the worker from the worker suite. Metal requires
native host AppKit/Metal access. CPU tests compare reference triangle/UV/light/sky
multisets at six snapshots on MAP01/13/16, plus synthetic height/light/offset/
material/sky changes and restoration. Classic/full-mesh parity covers all 32
Doom II and 16 Rust maps. Only sub-micro-unit zero values are normalized in CPU
comparisons: the frozen reference's unordered Set can produce ~1e-15 variation
near zero between identical runs. GPU comparisons use unmodified actual vertices
and demand exact pixel equality. Malformed snapshots are tested both with and
without a previous cache; valid static mutation requires full validation/rebuild.

Logs: `build/mesh139-performance.log`, `build/mesh139-parity.log`,
`build/mesh139-geometry.log`, `build/mesh139-worker.log`,
`build/mesh139-metal.log`, `build/mesh139-classic.log`.
Final app: `build/mesh-final/MetalDooM.app` (139), `build/build139.log`.
Native MAP13 Step shows tic 12 then exactly 35, Run/E/F reaches tic 46/ammo 49,
and Escape pauses at 280 with all 508,713 triangles and health 100.

Full ID24 palette/sky/control-sector presentation,
interpolation, campaign routes/restarts and saves remain separate acceptance work.
The normal picker still rejects Rust; no speedrun or upload work is included.

Build 146 scrolling and native buffer/phase validation: EXTENDED_SCROLLING.md.
