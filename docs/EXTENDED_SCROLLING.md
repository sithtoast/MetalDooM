# Rust floor and ceiling scrolling — 0.10.0 build 146

The Rust preview renders the simulation's independent floor and ceiling texture
offsets. Constant, displacement-controlled and accelerated scrollers feed the
same engine sector fields; the renderer does not simulate their speed or time.
The focused fixtures exercise constant scrolling and floor carry. Other scroller
variants retain upstream simulation and still need targeted gameplay coverage.

## Data and rendering

MGE2/version 2 replaces MGE1. Its header remains 120 bytes and all other array
strides remain unchanged. Sector records grow from 28 to 44 bytes: signed 16.16
floor X/Y offsets at 28/32, ceiling X/Y offsets at 36/40. Old geometry versions
reject. MVW5, other packets, and the 17 private ABI2 exports are unchanged.

ExtendedGeometry decodes those offsets in both its full and cached paths. Shared
Sector values default both offsets to zero, preserving classic callers. Texture
coordinates follow the pinned Woof r_plane.c equations: U = world X + X offset,
V = -world Y + Y offset. CPU meshing reduces offsets modulo 64 before adding them
to world coordinates; this is the period of the supported Doom flat textures and
avoids losing fractional phase to a large accumulated offset. Walls retain their
own sidedef offsets; sky rendering retains its existing direction-based mapping.

An offset-only change invalidates its sector's flat chunk. It does not rebuild
bordering walls, recalculate BSP polygons, upload new texture pixels or change
actor movement. Materials shared by several sectors are reassembled together,
so a scrolling surface can still replace a buffer containing static flats of the
same material. That existing material grouping is unchanged.

Pause stops simulation and therefore texture motion. Restart resets offsets;
Save/Load preserves the engine scroller thinker and accumulated offsets, so the
restored image and following tics retain their phase. Build 146 changes the engine
fingerprint: private saves from build 145 require its preserved matching bundle.

## Validation and remaining work

```sh
bash scripts/test-extended-scroll.sh /path/to/rerelease
bash scripts/test-extended-mesh.sh /path/to/rerelease
bash scripts/test-extended-metal.sh /path/to/rerelease
bash scripts/test-extended-geometry.sh /path/to/doom2.wad /path/to/rerelease
```

The scroll script generates original floor-only, ceiling-only, combined,
reverse-direction and carry rooms. It checks engine direction/speed, signed and
fractional wrapping, unchanged texture-only player position, actual conveyor
movement, one rebuilt flat chunk per tick, pause copies, save continuation,
restart, and old-format rejection. Native Metal readbacks compare scrolling
against identical state with stationary flats, full reference meshes and restored
saves, while checking unchanged wall buffer identity. Existing mesh and all-map
geometry tests retain the classic baseline and extended-node coverage.

This delivers floor/ceiling translation. Flat rotation, bob/interpolation,
palette/TRANMAP translucency, control-sector/fake-floor/sky effects and complete
campaign/boss playthrough acceptance remain separate work. It does not enable
extras.wad, sibling id1 packs or ordinary Rust picker support.
