# Rust material animation and scene reuse — build 139

The preview now draws the engine's current wall/flat animation translations.
It retains decoded images, sprite patches, GPU textures and unchanged meshes
within one fixed worker session. Build 137 adds continuous one-tic playback and paced manual actions.

## MMT1 copied state

`ME_CopyMaterials` is the tenth private ABI 2 export. It uses the same required-
size/whole-buffer copy semantics as geometry and sprite snapshots. Its bounded
packet has a 16-byte header: `MMT1`, version u32=1, tic u32, record count u32
(at most 65,536). Each 20-byte record contains an eight-byte source name, an
eight-byte target name and namespace u32 (0 wall texture, 1 flat). Integers are
little-endian; shorter names are zero-padded. No engine indices or pointers escape.

The packet is the complete set of nonidentity mappings for that tic. An absent
key means the source draws itself; replacing the entire mapping each update
restores the first animation frame correctly. Names come from canonical engine
lookups so duplicate directory names cannot override the effective lookup.
Sources and targets stay in their original namespace. Negative/swirl translations
fail explicitly; SMMU swirl and general ANIMDEFS support are not implemented.

The engine's initialized `texturetranslation` / `flattranslation` arrays remain
authoritative. The preview does not infer timing from wall-clock time or reparse
ANIMATED into a second animation clock. This preserves initial identity mappings,
frame offsets and the phase calculated by `P_UpdateSpecials` before the simulation
tic increments. Swift checks lengths, versions, count, names, namespaces, duplicate
keys, nonidentity records and agreement with the view's tic.

## MVW5 and geometry reuse

The framed MEQ1/MER1 envelope is unchanged. The current view body is MVW5 with a
56-byte header: MMT1 count at byte 44, MSA1 audio count at byte 48, MUI2 at byte 52. Payloads are
optional MGE1, required MSP1/MMT1/MSA1/MUI2, in that order, with exact length/tic checks.
Build 133 originally introduced MMT1 through MVW3; build 135 added audio/MVW4; build 140 adds HUD/music through MUI1/MVW5.

Startup, explicit geometry requests and lifecycle actions return full geometry.
Build 143 replaces the scene builder and native caches on restart/continue. Tick requests also
copy current geometry in the worker, but send it only if geometry values changed.
Within a level, comparison excludes the tic/player fields and checks
counts, content identity and every geometry record byte exactly. There is no hash
collision risk. Camera-only or animation-only changes therefore omit MGE1;
sector heights, light levels, offsets and switch textures still invalidate it.

The queue-confined `ExtendedSceneBuilder` retains the last valid geometry and
cached topology/chunks. A geometry update rejects a different map/content identity;
build 139 reuses static clipping/stitching and replaces affected line/sector chunks.
Only changed materials replace Metal vertex buffers; textures and sprite patches
remain cached, and current animation translations resolve at draw time. See the
[invalidation contract and performance evidence](EXTENDED_MESH.md).

## Validation and limits

A synthetic room using supplied Doom II art cycles NUKAGE1–3 and FIREBLU1–2.
Tests check all 65 consecutive tics against expected engine phase, resolve each
frame, assert no geometry retransmission, assert one CPU mesh build and check
stable decode counters on a repeated snapshot. MAP16's starting switch verifies
that moving geometry is sent and rebuilt. All sixteen real Rust maps pass initial
and tic-35 scene/actor/weapon preparation through the cache.

Build 139 validates partial updates against the old full meshes, including 21 exact
GPU pixel comparisons. MAP13 worker/CPU mean improves from 210.57 to 20.56 ms per
tic in the final local sample. Full MGE1 copy/comparison remains linear; changed
materials still assemble/upload complete material buffers. Scrolling flat offsets,
control-sector effects, sky definitions, palette/translucency, music, campaign
transitions and saves remain ahead. See EXTENDED_MESH.md and VALIDATION.md.
