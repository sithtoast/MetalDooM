# Rust actor translucency — 0.10.0 build 149

The explicit Rust preview draws ordinary translucent actors and additive glowing
actors using the worker's actual palette-index blend tables. Opaque geometry and
actors draw first; translucent actors draw far to near with depth testing and no
depth writes. Sprite cutouts discard pixels. Shadow/fuzz takes precedence.

## Copied contract

ABI 2 gains `ME_CopyBlendTables` (18 exports total), with the existing whole-buffer
copy convention: size query, untouched short buffer, complete copy, no simulation
or random-number changes. MEQ1 operation 8 has an empty request and one fixed
131856-byte MBL1 response. Swift requests it once after startup/identity validation
and retains it for subsequent views. Restart/Continue use the same resources;
a fresh restore worker supplies its own tables.

| Offset | Bytes | Meaning |
| --- | --- | --- |
| 0 | 4 | MBL1 magic |
| 4 | 4 | Version 1, little-endian |
| 8 | 4 | Palette size 768 |
| 12 | 4 | Table count 2 |
| 16 | 768 | First PLAYPAL palette, RGB triples |
| 784 | 65536 | Normal table |
| 66320 | 65536 | Additive table |

Tables index `(background << 8) | foreground`. The engine loads a supplied
65536-byte TRANMAP or generates its normal default; it generates the additive
table using its existing color-distance implementation. Wrong TRANMAP length
fails before renderer initialization. MBL1 rejects wrong magic, version, palette
size, table count and total length.

MSP3/version 3 replaces MSP2 without changing header or record sizes. Actor flag
8 means translucent; flag 16 selects additive and requires flag 8. Fullbright
MF_TRANSLUCENT actors select additive; other MF_TRANSLUCENT and MIF_GHOST actors
select normal. Shadow still selects fuzz. Unknown bits reject. Weapon flags and
camera teleport marker are unchanged. Per-state/per-object custom table pointers
that do not identify a supported default table fail explicitly when presented.
No pointers cross into Swift.

## Metal composition and scope

Patch decoding retains original palette indices, including duplicate-color
entries. Fullbright foreground pixels use those indices directly. Shaded sprite
pixels and the current RGB framebuffer are quantized to the nearest PLAYPAL RGB
entry, using squared distance and first-entry tie breaking. Programmable blending
then reads the copied table, so overlapping sprites include earlier translucent
draws. Palette buffers and table/index textures are cached, not rebuilt per frame.

This adapts the engine's blend operations to the existing native RGB renderer.
It does not claim software-renderer pixel parity: native lighting is still RGB,
and palette/fixed-colormap powerups, custom per-state tables, translucent walls,
fake-floor clipping and ordering between fuzz and translucent actors remain
separate work. Weapons keep their existing opaque/fuzz paths. Classic engine
actor rendering is unchanged. This engine change also changes private-save
fingerprints; preserve earlier bundles for earlier saves.

## Validation

`scripts/test-extended-worker.sh` checks copied-buffer canaries, exact custom
TRANMAP bytes, distinct additive data, normal/additive/shadow actor selection,
malformed packets and unsupported tables, plus existing all-map/weapon/protocol
regressions. `scripts/test-extended-metal.sh` uses native Metal readback and a
synthetic grayscale palette/table oracle to check every affected pixel, both
actor enumeration orders, opaque actor and wall occlusion, cutouts and fuzz
precedence. It also retains real Rust mesh/HUD, scrolling/save and interpolation
pixel regressions. See VALIDATION.md for the final run and app evidence.
