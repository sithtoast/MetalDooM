# Copied extended geometry — MGE4, build 152

The experimental worker now supplies its decoded map to the same `DoomMap` and
`Geometry` types used by the native renderer. `Sources/ExtendedGeometry.swift`
decodes copied bytes without linking or loading Woof into the app process.
Build 146 adds independent floor/ceiling offsets to the live preview. Full
Boom/ID24 presentation remains incomplete; see EXTENDED_SCROLLING.md.

## Contract

`ME_CopyGeometry(out, capacity)` is the seventh exported function in additive
worker ABI 2. Existing config/snapshot layouts are unchanged. Call on the owning
session thread between ticks. NULL queries the required size. An undersized
buffer is untouched and returns the required size. A successful full copy returns
that size; zero means not ready or a guarded engine error. Discard output on error.
No engine pointers, compiler padding, native `size_t`, or resource paths enter the
snapshot. This is an experimental value format, used by the private worker IPC; it is not a save.

All words are little-endian 32-bit. Coordinates/heights/offsets are signed 16.16;
angles use unsigned Doom binary angles. Indices are unsigned except missing line
sides, represented as signed -1. Names occupy eight ASCII bytes, NUL padded unless
all eight bytes are used. Material names are current base identities, **not**
per-tic animation translations. The session must still own the matching ordered
resources; its fingerprint accompanies the map.

| Offset | Header field |
| --- | --- |
| 0 | Four bytes `MGE4` |
| 4 | Format version 4 |
| 8 | Simulation tic |
| 12 | Map number, 1–32 |
| 16, 20, 24 | Current player x, y, angle |
| 28–52 | Seven counts in the array order below |
| 56–119 | 64 lowercase hex characters: session content SHA-256 |

Arrays immediately follow the 120-byte header:

| Array | Bytes/record | Fields |
| --- | --- | --- |
| Vertices | 8 | x, y (engine simulation coordinates) |
| Lines | 24 | vertex a, vertex b, flags, front side, back side, blend table ID (0–64) |
| Sides | 36 | sector, x offset, y offset; upper/lower/middle names |
| Sectors | 76 | resolved floor/ceiling/light/names/offsets; plane lights; back-view heights/ceiling name; actor clip limits (see EXTENDED_CONTROL_SECTORS.md) |
| Segs | 16 | vertex a, vertex b, line, side (0/1) |
| Subsectors | 12 | seg count, first seg, engine sector |
| Nodes | 24 | x, y, dx, dy, right child, left child |

Node child bit 31 marks a subsector; remaining bits hold its index. The classic
WAD decoder normalizes its bit-15 tags into this common representation. Missing
side -1 similarly avoids collision with valid extended side index 65535.

The decoder bounds each array at one million records, requires exact total size,
and rejects unsupported versions, invalid identity/names, references, negative
ranges, missing seg sides, degenerate partitions and non-postordered/cyclic node
links before meshing. Engine export rejects minisegs needing a future GL adapter.
The map uses the engine's explicit subsector sector rather than guessing it.

MBF21 level setup projects split vertices onto parent linedefs. Those coordinates
can differ from the original lump, including XNOD's added vertices; the snapshot
preserves the engine result. Mesh clipping continues to use original directed
linedefs to avoid seams. Build152 adds camera-resolved transfer heights and
independent plane lighting; see EXTENDED_CONTROL_SECTORS.md. Static topology and
unchanged material buffers remain cached. Sky transfers and further rendering
features remain separately tracked in the handoff.

## Evidence

Run `scripts/test-extended-geometry.sh original-doom2.wad /path/to/rerelease`.
Private snapshots/logs live in `build/extended/geometry/`, outside Git.

- All 32 original Doom II maps: worker/classic linedef endpoints, BSP nodes,
  subsector sectors and native triangle counts agree. The existing classic
  geometry/material/sprite suite also passes.
- All sixteen Rust maps: copied engine geometry decodes and produces nonempty,
  finite native mesh batches. MAP13 has 37,547 vertices, 76,284 segs, 32,993 leaves,
  32,992 nodes and 508,713 triangles (default texture heights, CPU generation).
- Independent MAP13 byte check confirms all wall endpoints, seg/leaf ranges and
  node partitions/children against the actual XNOD lump: 29,143 original + 8,404
  added vertices; 3,558 split vertices retain engine projection adjustments.
- Fourteen malformed snapshot cases reject before meshing, including truncated/
  trailing bytes, version/count limits, invalid ranges and cyclic/out-of-range
  BSP children. Per-map worker checks cover no-session queries, undersized-buffer
  nonmutation, repeated-copy equality and buffer-end canaries.
- Full existing Rust session/ID24/gameplay tests pass with seven private exports.

Native build 129 remains the classic app. Its separate preview, signature and
visible version are checked in the host context. No live Rust graphics, audio,
frame-time, moving-sector visual parity or full campaign acceptance is claimed.

Build 131 connects these values to an explicit [native world preview](EXTENDED_PREVIEW.md)
through a separate process. The format above is unchanged; live actor/audio and
full presentation acceptance remain pending.

## Build 139 cache refinement

Wire MGE1 remains unchanged. The Swift decoder can reuse already validated static
arrays after exact byte matches, decoding differing side/sector records and still
checking names/references. Static mutation falls back to full validation. The
scene builder reuses BSP clipping/stitching and updates affected surfaces and
Metal materials. See [cache invariants and parity tests](EXTENDED_MESH.md).
