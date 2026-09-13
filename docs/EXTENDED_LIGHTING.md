# Indexed preview lighting — 0.10.0 build 164

The extended preview now shades opaque world surfaces, actors, weapons and
translucent foregrounds through the original palette indices and COLORMAP rows.
The classic renderer and its optional native effects retain their prior RGB path.
This replaces the preview's continuous RGB darkening for ordinary lighting.

The implementation follows pinned Woof
`acd1c7f84fdd0fae92d1c58643c14364a131c75a`: `r_main.c` light tables,
`r_plane.c` plane distance buckets, `r_segs.c` directional/scale lighting and
`r_things.c` actor/weapon and fixed/fullbright precedence. It uses canonical
320-wide depth/scale normalization while retaining Metal's camera projection.

## Data and ordering

WorldVertex now has a third float4 (48-byte stride): discrete light level and
primitive kind (plane, wall, actor or weapon). Geometry and independent reference
meshes preserve metadata through stitched triangles; the translucent BSP preserves
it through splits. Draws using inline Metal buffers stay below the 4 KiB limit.
Classic shaders ignore the metadata. CPU topology caches, moving-surface meshes
and GPU upload sizes use the shared stride.

Planes use their transferred light and one of 128 distance buckets. Walls add
horizontal -1 / vertical +1 fake contrast before final clamping; walls and actors
use one of 48 scale buckets. Weapons use the final scale bucket. The worker copies
player extra light in 16-unit increments, and weapon light uses the resolved
floor/ceiling average. Wall light retains headroom to 511 so extra light is not
clamped before directional contrast. MGE6 adds tint references; copied wall-light
validation accepts 0–511, plane/actor light remains 0–255. Engine/resource save
fingerprints still require a matching build.

The GPU reads source indices from textures separately from transparent coverage.
Fixed maps override fullbright; otherwise fullbright uses row zero. Custom blend
tables receive the already mapped foreground index and the background palette
index. Animation selects matching color and index textures. HUD rendering is
unshaded; palette flashes still apply after the HUD. Fuzz remains its separate
background effect.

## Evidence

`scripts/test-indexed-lighting.sh /path/to/doom2.wad` renders 1,548,288 native GPU
samples against an independent integer table oracle: four primitive kinds, six
light levels, seven distances, fixed rows 0/1/32, fullbright variants and opaque/
custom-blended output, both with/without selective brightmaps and a custom tint. It uses the production shader pipelines with Metal API
validation. Original source indices are checked across all 256 palette entries.

The bundled native-map suite compares all six plans' first/last maps with extras
against independent full geometry under indexed lighting. Existing RGB-based
projection/blending regression oracles explicitly retain the legacy shading mode;
indexed color correctness has its separate independent GPU oracle. Classic
AO/lighting/HDR tests verify the shared vertex/binding changes do not alter Classic
restoration or optional effects behavior. See VALIDATION.md for results.

`scripts/audit-native-lighting.py` retains the **build159 RGB baseline**: 13,659 of
13,824 modeled samples differed from Woof. It is historical, not a measurement of
the current shader. Current acceptance uses actual GPU readback above.

## Remaining parity work

Software rasterization, projection edge cases, optional software sky stretching
and fuzz pattern matching remain separate. Brightmaps and custom tints now use the
engine's authored masks and colormap bank; see EXTENDED_PRESENTATION.md for their
wire layout and precedence. The table-sample evidence does not establish
whole-frame software parity. Campaign/performance acceptance remains in
BRANCH_ACCEPTANCE.md.
