# Fake floors and transferred lighting — 0.10.0 build 152

The explicit Rust preview now presents Boom transfer heights (special 242),
independent floor lighting (213) and ceiling lighting (261). Control-sector
relationships remain engine-owned. Rendering copies resolved values without
changing collision heights, player movement, sector thinkers, RNG or save state.

## Camera-dependent presentation

`RenderSector.c` adapts the pinned Woof `R_FakeFlat` rules at simulation-tic
precision. Normal views borrow the control sector's floor/ceiling heights.
Underwater and above-ceiling views resolve the corresponding textures, offsets
and lighting, including the special sky-flat branches. The one-fixed-point-unit
surface separation is retained. Front and neighboring back sectors resolve
separately: the underwater back-sector path deliberately keeps different texture
and light behavior. The camera uses the same tic-zero spawn-height calculation
as the copied view, avoiding a false underwater frame before the first tick.

Floor and ceiling light each honor their transfer sector, relative offset and
absolute-light flag; exported plane levels clamp to 0–255. Actors use the average
of the resolved floor/ceiling lights. Native RGB distance/directional lighting
continues to apply, so this does not claim software-renderer pixel parity.

Actor quads clip against camera-selected fake floor/ceiling limits, preserving
texture coordinates and masked holes. Fully clipped quads are omitted. Opaque,
normal/additive/custom translucent and fuzz passes share this clipping. Real
actor positions, physics floor heights and gameplay records remain unchanged.

## Copied geometry

MGE4/version4 retains the 120-byte header and all other array strides. Each sector
is now 76 bytes. Offsets0–40 retain the earlier sector fields but contain the
resolved front view; appended fields are:

| Offset | Type | Meaning |
| --- | --- | --- |
| 44, 48 | u32 | Floor and ceiling light, 0–255 |
| 52, 56 | i32 fixed | Neighbor/back-view floor and ceiling height |
| 60 | 8 bytes | Back-view ceiling texture name |
| 68, 72 | i32 fixed | Actor lower/upper clipping limits |

INT32_MIN/MAX express unbounded clipping. Inverted limits/heights can deliberately
hide geometry in sky-control cases and are valid. Names, lengths and plane lights
are checked on full and cached decoding. Previous MGE versions reject. MBL3,
MUI3, MSP4, MVW5 and the eighteen-export ABI2 remain unchanged.

The engine resolves every sector at each copied view. Crossing a control plane
or changing its controller therefore updates affected sector/wall chunks. Pure
plane-light changes rebuild the affected flat chunk while retaining wall buffers
and static topology. Copies and Save/Load retain the same resolved presentation.
This engine change updates private-save fingerprints; retain older bundles for
older private saves.

## Validation and limits

`scripts/test-control-sectors.sh /path/to/doom2.wad` runs 374,400 cases against a
frozen copy of the pinned Woof fake-flat function, including front/back, camera
boundaries, sky branches, offsets, transferred/absolute lights and unchanged
source sectors. Real map-special fixtures cover normal, underwater, above-ceiling,
sky variants, independent lights, actor lighting, physical step blocking,
Save/Load/future tics, malformed cached plane lights and selective mesh updates.

The native Metal suite compares seven fixture images against independently
specified plane/light meshes and actor clipping against projected pixel oracles
in all five rendering modes. Existing real-map, HUD, palette, translucent-wall,
scroll/save and interpolation checks remain. See VALIDATION.md for final logs.

This covers Boom fake-sector presentation, not arbitrary stacked 3D floors.
Flat rotation, sky transfers, per-object/weapon blending, fuzz/translucent ordering,
actor/moving-surface interpolation and full campaign playtesting remain. Camera
interpolation still uses discrete sector presentation at each simulation tick.
