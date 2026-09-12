# Rust material animation and scene reuse — build 133

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

## MVW3 and geometry reuse

The framed MEQ1/MER1 envelope is unchanged. The view body is MVW3 with a 48-byte
header: prior fields through byte 43, then MMT1 byte count u32 at byte 44. Payloads
are optional MGE1, required MSP1, required MMT1, in that order. Their counts must
sum exactly to the body length. Maximum payload is 160 MiB plus the header.

Startup and explicit geometry requests return full geometry. Tick requests also
copy current geometry in the worker, but send it only if geometry values changed.
A worker owns one fixed map; comparison excludes the tic/player fields and checks
counts, content identity and every geometry record byte exactly. There is no hash
collision risk. Camera-only or animation-only changes therefore omit MGE1;
sector heights, light levels, offsets and switch textures still invalidate it.

The queue-confined `ExtendedSceneBuilder` retains the last valid geometry and
CPU mesh. An update without geometry requires an existing scene. An update with
geometry rebuilds it, rejecting a different content identity/map. Decoded images
and sprite patches are cached across updates; only missing resources decode.
The renderer uploads each material texture once per session, rebuilds vertex/sky
buffers only for geometry updates and resolves the current material mapping at
draw time. The ordinary classic renderer keeps its existing engine translation
path. The UI now prepares the tick reply directly, eliminating its second request.

## Validation and limits

A synthetic room using supplied Doom II art cycles NUKAGE1–3 and FIREBLU1–2.
Tests check all 65 consecutive tics against expected engine phase, resolve each
frame, assert no geometry retransmission, assert one CPU mesh build and check
stable decode counters on a repeated snapshot. MAP16's starting switch verifies
that moving geometry is sent and rebuilt. All sixteen real Rust maps pass initial
and tic-35 scene/actor/weapon preparation through the cache.

This removes redundant work on unchanged scenes, but is not a continuous-play
performance claim. Worker geometry comparison is still linear in map size, and
any geometry change rebuilds the whole mesh. Partial sector updates, scrolling
flat offsets, control-sector effects, sky definitions, palette/translucency, music,
campaign transitions and saves remain work ahead. Build 137 adds continuous playback; build 135 added native
[sound effects](EXTENDED_AUDIO.md) via MVW4. See VALIDATION.md for final
native checks and logs.
