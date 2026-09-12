# Native lighting compatibility baseline — build 159

Ordinary native world lighting currently multiplies decoded RGB by a continuous
sector light and distance factor. Woof selects discrete COLORMAP rows and maps
original palette indices through those rows. Existing fixed-colormap/palette
flash and blend-table work does not make ordinary sector lighting equivalent.
No lighting shader change or software-renderer parity is claimed in build 159.

The read-only `scripts/audit-native-lighting.py /path/to/doom2.wad` produces JSON
statistics from the caller's private PLAYPAL/COLORMAP without exporting artwork.
It models canonical 320-wide opaque plane lighting from the pinned Woof
`acd1c7f84fdd0fae92d1c58643c14364a131c75a` sources:

- `src/r_main.c`, `R_InitLightTables`: 16 light levels, 128 distance buckets,
  `LIGHTSEGSHIFT=4`, `LIGHTZSHIFT=20`, `LIGHTSCALESHIFT=12`, row clamping 0–31.
- `src/r_plane.c`, `R_MapPlane`: distance bucket and sector light table selection.
- Native `Geometry.swift` / `Renderer.swift`: minimum light 0.12 and distance
  attenuation `max(0.3, 1-distance/3200)`.

For rerelease Doom II, 13,659 of 13,824 modeled palette/light/distance samples
have at least one different RGB channel. This is a deliberately broad set of
nine light levels and six distances, not a distribution of real scene pixels.
Native rounding is modeled; this is not GPU readback, a screenshot comparison,
a perceptual error score or whole-frame acceptance. The local JSON includes the
input WAD digest, each selected row and mean absolute RGB error.

## Implementation order

1. Carry original palette indices through opaque world and actor textures, with
   transparent coverage kept separate. Avoid reconstructing source indices from
   already shaded RGB when exact indexed shading is required.
2. Match plane depth tables and wall/sprite scale tables, directional fake
   contrast, sector transfers and player extra light. Use the pinned source's
   fixed-point selection, with explicit resolution/FOV assumptions.
3. Apply fullbright/brightmap, fixed-colormap, sector/thing tint and blend
   precedence against independent indexed pixel oracles. Preserve the existing
   classic renderer and optional native effects behavior.
4. Compare matched cameras/light levels on actual bundled maps, including
   power-ups and moving transferred-light sectors. Keep rasterization, sky,
   filtering, fuzz and interpolation differences separately identified.

Source details to carry into that work: `r_segs.c` combines sector light,
`extralight` and `fakecontrast` before `R_GetLightIndex`; `r_things.c` gives fuzz,
fixed maps, fullbright and sprite lighting distinct branches; `p_setup.c` sets
horizontal/vertical fake contrast. A single RGB gamma adjustment cannot replace
these rules. Multiplayer and demo recording are separate future work.
