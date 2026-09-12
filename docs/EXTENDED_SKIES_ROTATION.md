# Sky transfers and flat rotation — 0.10.0 build 155

The explicit Rust preview now draws sector-local Boom sky transfers (271/272)
and rotated floors/ceilings, including combined offsets (2051–2056). The worker
owns special activation, sky identities, orientation and live offsets. Rendering
copies that state without changing simulation or save timers.

## Flat coordinates

MGE5 supplies each resolved front sector's floor/ceiling rotation as an unsigned
Doom binary angle. Geometry rotates world coordinates about the map origin, then
adds the existing plane offsets:

    u = x cos(angle) - y sin(angle) + xoffs
    v = -x sin(angle) - y cos(angle) + yoffs

Offsets retain 64-texel wrapping. Each plane rotates independently. The fake-flat
adapter also copies the control-sector rotations selected by Woof's underwater
and above-ceiling rules, including its special sky branches. Rotation affects
flat meshes only; wall geometry and collision remain unchanged. Native floating
point UVs are not a claim of fixed-point software rasterization parity.

## Sector-local skies

A stable positive ID selects an engine-resolved transferred sky. Only a sector
plane using F_SKY1 draws that transfer; ordinary flats and untagged sky surfaces
keep their own materials. Sky-border walls inherit their sector's ceiling sky.
Separate sky batches retain depth testing, directional clipping and opaque
occlusion. Unmodified surfaces use the existing default-sky shader path.

The worker copies the background texture, angular offset, vertical midpoint and
scales from the engine's sky object and controlling sidedef. In the pinned engine,
271 has negative horizontal scale and272 positive scale. The transfer midpoint
is rowoffset minus28, plus any engine sky offset. Sidedef horizontal offsets are
binary-angle additions, not ordinary wall texel offsets. The shader floors the
1024-column angle before applying horizontal scale, wraps transferred textures,
and applies vertical offset and scale to the native sky projection. Scrolling
updates mapping uniforms; stable IDs avoid creating a new texture cache entry
for every offset. Animated sky textures use the current material translation.

## MGE5 contract

The header stays120 bytes and all non-sector strides stay unchanged. Sectors grow
from76 to140 bytes; offsets0–72 retain MGE4 fields. New fields:

| Offset | Bytes | Value |
| --- | --- | --- |
| 76, 80 | 4 each | Unsigned floor/ceiling binary rotation |
| 84, 112 | 28 each | Floor/ceiling sky transfer record |

Each sky record contains ID at0, eight-byte texture name at4, unsigned binary-angle
offset at12, signed16.16 midpoint at16, and signed16.16 X/Y scales at20/24.
An absent record is28 zero bytes. Nonzero IDs are1–1000000; X scale is nonzero
within±256 and Y scale is positive through256. Names, sizes, empty records,
scales and conflicting definitions of one ID reject in both full/cached decodes.
Prior MGE versions reject. MBL3/MUI3/MSP4/MVW5 and the eighteen-export ABI2 remain.

## Validation and remaining scope

`scripts/test-sky-rotation.sh /path/to/doom2.wad` checks real map specials,
quarter-turn UV orientation, combined offsets, tagged versus untagged surfaces,
scrolling, immutable copies, saved continuation, stable topology and malformed
sky records. The control-sector oracle now also compares inherited rotations.
Native Metal checks independently project rays to sky columns or rotated flat
texels at spawn and tic35, covering both transfer orientations and scrolling.
Existing control-sector, palette, wall, actor, real-map, HUD and save regressions
remain; final evidence is in VALIDATION.md.

Native sky projection retains its existing perspective and does not reproduce
Woof's optional sky stretching exactly. Layered/procedural transferred skies fail
explicitly pending their adapters. Other outstanding work includes per-object
and weapon blending, fuzz/translucent ordering, actor/moving-surface interpolation
and full campaign/boss-playthrough acceptance. Old private saves still require
the matching earlier bundle because engine fingerprints change.

The final build also restores the classic lighting shaders' two-argument
power-color helper, which the optional AO/lighting renderer still requires.
