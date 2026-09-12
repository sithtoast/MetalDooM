# Rust actor, weapon and wall translucency — 0.10.0 build 157

The explicit Rust preview draws ordinary translucent actors, additive glowing
actors and per-state custom blend tables. Opaque geometry and actors draw first;
translucent actors draw far to near with depth testing and no depth writes.
Sprite cutouts discard pixels. Shadow/fuzz takes precedence.

## Copied contract

ABI 2 still has 18 exports, including `ME_CopyBlendTables`, with the existing
whole-buffer convention: size query, untouched short buffer, complete copy, no
simulation or random-number changes. MEQ1 operation 8 has an empty request and a
bounded MBL3 response. Swift requests it after startup/identity validation and
refreshes it after Restart, Continue and restore before accepting the new view.
Palettes and colormaps stay resource-owned; the wall/object bank suffix is rebuilt
for each level so campaign traversal cannot accumulate obsolete tables.

| Offset | Bytes | Meaning |
| --- | --- | --- |
| 0 | 4 | MBL3 magic |
| 4 | 4 | Version 3, little-endian |
| 8 | 4 | PLAYPAL bytes, 768–196608, multiple of 768 |
| 12 | 4 | Table count, 2–64 |
| 16 | 4 | COLORMAP bytes, 256–65536, multiple of 256 |
| 20 | 4 | Reserved zero |
| 24 | PLAYPAL size | All RGB palettes |
| after palettes | COLORMAP size | All 256-entry colormaps |
| after colormaps | count × 65536 | Tables in ID order |

IDs 1 and 2 are the engine's normal and additive tables. IDs 3–64 are per-state
custom state, wall or object tables. Before level spawn, the worker scans patched states in index
order, checks each referenced table against its cached WAD lump allocation and
requires exactly 65536 bytes. Shared pointers receive one ID. All state tables,
including those first used later, are registered up front. Distinct lumps with
identical bytes may have separate IDs. No engine pointers cross into Swift.

Tables index `(background << 8) | foreground`. The engine loads a supplied
TRANMAP or generates its normal default; it generates the additive table using
its existing color-distance implementation. Wrong TRANMAP/custom table lengths
and more than 62 custom tables fail explicitly. MBL3 is at most 4,456,472
bytes; malformed headers, sizes, counts and total lengths reject. Previous
MBL versions reject. Every selected palette, colormap and wall ID must exist.

MSP5/version5 carries normal/additive/custom flags on actors and weapon layers.
It adds actor endpoints for interpolation; see EXTENDED_SPRITES.md. Every selected
actor/weapon/wall ID must exist in the copied bank. Fuzz combined with a blend ID
is invalid. The camera teleport flag remains at header28.

Per-state tables override object tables, which override default translucency.
This applies even to opaque/fullbright states. Without either table, fullbright
MF_TRANSLUCENT selects additive; other MF_TRANSLUCENT selects normal. MIF_GHOST
selects normal for world actors only. Fuzz wins and emits no blend ID.

After walls, the level bank registers object and respawn tables in thinker order.
Lump tables must contain exactly65536 bytes and are pinned for the level; generated
alpha tables must match one already created by the engine. Native keyframes store
resource/alpha references for both `mobj.tranmap` and `spawnpoint.tranmap`, never
pointers or table bytes. Zero means absent, 1/2 mean defaults, positive values3+
mean lump index+3, and -1 through -100 mean generated alpha0 through99. Restore
validates these references before replacing the thinker arena. This adapts object
blending; it does not declare broad UDMF map compatibility.

## Metal composition and scope

Patch decoding retains original palette indices, including duplicate-color
entries. Fullbright foreground pixels use those indices directly. Shaded sprite
pixels and the current RGB framebuffer are quantized to the nearest PLAYPAL RGB
entry, using squared distance and first-entry tie breaking. Programmable blending
then reads the selected table, so overlapping sprites include earlier translucent
draws. Palette buffers and table/index textures are cached, not rebuilt per frame.

This adapts the engine's blend operations to the existing native RGB renderer.
It does not claim software-renderer pixel parity: native lighting is still RGB,
and native fuzz uses its existing screen-row sampling effect.
Build152 adds fake-floor clipping; see EXTENDED_CONTROL_SECTORS.md. Palette/fixed-colormap support is described in
[EXTENDED_PALETTES.md](EXTENDED_PALETTES.md). Weapons use their selected table with original psprite slot order, so a
translucent muzzle flash composites over the weapon beneath it. Classic engine actor rendering is unchanged.
This engine change also changes private-save fingerprints; preserve earlier
bundles for earlier saves.

## Translucent walls

MGE3 adds a blend ID (0–64) at byte 20 of each 24-byte line record. The worker
registers engine-resolved `tranmap` pointers after level setup: this covers Boom
special 260, tag-based assignment and custom 65536-byte wall table lumps. Only
two-sided middle textures use the ID; upper, lower and one-sided walls stay
opaque. Existing clipping, pegging, masked holes and animated texture selection
are retained, and wall compositing preserves original palette indices.

Translucent walls form a bounded vertical-plane BSP. Crossing walls and dynamic
billboards split at those planes, giving them one back-to-front order with depth
testing and no depth writes. This handles a wall crossing an actor rather than
sorting both by their centers. Excessive subdivision fails explicitly. The
same ordering now includes fuzz polygons. Before each fuzz polygon, Metal copies
the color attachment and resumes drawing with preserved depth; nearer translucent
surfaces then see that fuzz result. Invisible weapons receive a fresh completed
world snapshot. Classic rendering retains its existing path.

## Validation

`scripts/test-extended-worker.sh` checks copied-buffer canaries with a custom bank,
exact table bytes, shared IDs and precedence, delayed states, save/restore and
continuation, restart, the maximum bank/ID, malformed sizes/counts/references,
and existing all-map/weapon/protocol regressions. `scripts/test-extended-metal.sh`
uses native readback and an independent grayscale palette/table oracle for
normal/additive/custom pixels, both actor enumeration orders, shaded foregrounds,
opaque actor and wall occlusion, cutouts and fuzz precedence. Real Rust mesh/HUD,
scrolling/save and interpolation pixel regressions remain. See VALIDATION.md for
the final run and app evidence.

`scripts/test-blend-motion-core.sh` privately links the core for object/respawn
and weapon table precedence, generated alpha, fuzz precedence, spawn endpoints,
fresh-worker restore and exact future snapshots. Native readbacks additionally
check both fuzz/actor depth orders, crossing fuzz/wall fragments and all weapon
blend modes, including mixed weapon/flash slot order.
