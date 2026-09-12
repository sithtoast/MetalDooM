# Rust actor translucency — 0.10.0 build 150

The explicit Rust preview draws ordinary translucent actors, additive glowing
actors and per-state custom blend tables. Opaque geometry and actors draw first;
translucent actors draw far to near with depth testing and no depth writes.
Sprite cutouts discard pixels. Shadow/fuzz takes precedence.

## Copied contract

ABI 2 still has 18 exports, including `ME_CopyBlendTables`, with the existing
whole-buffer convention: size query, untouched short buffer, complete copy, no
simulation or random-number changes. MEQ1 operation 8 has an empty request and a
bounded MBL2 response. Swift requests it once after startup/identity validation
and retains it for subsequent views. Restart/Continue use the same resources;
a fresh restore worker supplies its own tables.

| Offset | Bytes | Meaning |
| --- | --- | --- |
| 0 | 4 | MBL2 magic |
| 4 | 4 | Version 2, little-endian |
| 8 | 4 | Palette size 768 |
| 12 | 4 | Table count, 2–64 |
| 16 | 768 | First PLAYPAL palette, RGB triples |
| 784 | count × 65536 | Tables in stable ID order |

IDs 1 and 2 are the engine's normal and additive tables. IDs 3–64 are per-state
custom tables. Before level spawn, the worker scans patched states in index
order, checks each referenced table against its cached WAD lump allocation and
requires exactly 65536 bytes. Shared pointers receive one ID. All state tables,
including those first used later, are registered up front. Distinct lumps with
identical bytes may have separate IDs. No engine pointers cross into Swift.

Tables index `(background << 8) | foreground`. The engine loads a supplied
TRANMAP or generates its normal default; it generates the additive table using
its existing color-distance implementation. Wrong TRANMAP/custom table lengths
and more than 62 custom tables fail at initialization. MBL2 is at most 4,195,088
bytes; malformed magic, version, palette size, count and total length reject.
MBL1 replies are no longer accepted.

MSP4/version 4 replaces MSP3 without changing the 32-byte header, 40-byte actor
records or 24-byte weapon records. Low actor flags remain mirrored 1, fullbright
2, shadow 4, translucent 8 and additive 16 (requires 8). Bits 8–15 hold a custom
table ID, either zero or 3–64; a custom ID requires translucent 8 and forbids
additive 16. Other bits reject. The client also verifies that every referenced
ID exists in the session's bank, both at startup and on subsequent replies.
Weapon flags and the camera teleport marker are unchanged.

Per-state tables override object/default translucency, including on opaque or
fullbright actors. Without a state table, fullbright MF_TRANSLUCENT selects
additive; other MF_TRANSLUCENT and MIF_GHOST actors select normal. Fuzz wins and
emits no effective blend ID. Custom per-object tables remain explicitly
unsupported: that pointer is not serialized by the private keyframe path.
Per-state tables restore through their patched state indices, preserving IDs and
copied bytes across fresh workers, state changes and restart.

## Metal composition and scope

Patch decoding retains original palette indices, including duplicate-color
entries. Fullbright foreground pixels use those indices directly. Shaded sprite
pixels and the current RGB framebuffer are quantized to the nearest PLAYPAL RGB
entry, using squared distance and first-entry tie breaking. Programmable blending
then reads the selected table, so overlapping sprites include earlier translucent
draws. Palette buffers and table/index textures are cached, not rebuilt per frame.

This adapts the engine's blend operations to the existing native RGB renderer.
It does not claim software-renderer pixel parity: native lighting is still RGB,
and palette/fixed-colormap powerups, translucent walls, fake-floor clipping and
ordering between fuzz and translucent actors remain separate work. Weapons keep
their existing opaque/fuzz paths. Classic engine actor rendering is unchanged.
This engine change also changes private-save fingerprints; preserve earlier
bundles for earlier saves.

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
