# Copied Rust actor and weapon frames — MSP5, build 157

Current build164 adds the adapters and updated packets documented in
[EXTENDED_PRESENTATION.md](EXTENDED_PRESENTATION.md). The milestone layout and
validation details below are retained as implementation history.

`ME_CopyPresentation` returns an MSP5 snapshot on the session thread between
ticks. NULL queries required bytes; insufficient capacity returns that size and
leaves the buffer untouched. Zero means no ready session/error. It is an additive
ABI 2 export, with no change to existing structures or MGE5 geometry. No pointers
or engine lump indices cross the process boundary.

The engine resolves frames from its initialized sprite tables, including extended
states, camera-relative rotations, paired mirrored lumps, fullbright and shadow
flags. It excludes players and MF_NOSECTOR helpers. An absent TNT1 blank sprite
also stays invisible: upstream normally supplies that blank in its own resource
WAD. An explicit TNT1 replacement remains drawable. Other missing frames fail.
No game artwork is bundled.

## MSP5 layout

All integers are little-endian. Fixed coordinates use signed 16.16 units.

| Header offset | Value |
| --- | --- |
| 0 | `MSP5` magic, four bytes |
| 4 | Version u32, 5 |
| 8 | Simulation tic u32 |
| 12 | Actor count u32, at most 1,000,000 |
| 16 | Weapon layer count u32, at most 2 |
| 20 | Ready weapon i32, 0–8 |
| 24 | Ready ammo i32; -1 for no ammo type |
| 28 | Flags u32: snap camera 1; other bits reject |

The 32-byte header is followed by actor records (56 bytes each), then weapon
records (24 bytes each). Names occupy eight bytes, zero-padded when shorter;
all eight may be used. They identify sprite namespace resources in the verified
ordered WAD stack. Sprite replacements use the last matching name.

| Actor offset | Value |
| --- | --- |
| 0 | Sprite resource name |
| 8, 12, 16, 20 | x, y, z, floor z (fixed) |
| 24 | Sector light i32, clamped 0–255 |
| 28 | Flags u32: mirrored 1, fullbright 2, shadow 4, translucent 8, additive 16 (requires 8), valid previous pose 32; bits 8–15 custom table ID 3–64 or zero |
| 32, 36 | Editor number, state index (i32) |
| 40, 44, 48, 52 | Previous x, y, z, floor z (fixed), enabled by flag32 |

| Weapon offset | Value |
| --- | --- |
| 0 | Sprite resource name |
| 8, 12 | psprite sx, sy (fixed) |
| 16 | Sector light plus weapon extra light, clamped 0–255 |
| 20 | Flags u32: mirrored 1, fullbright 2, shadow 4, translucent 8, additive 16; custom ID bits8–15 as for actors |

Weapon and flash layers preserve psprite order. Swift rejects incorrect lengths,
versions, counts, names, light ranges and unknown flags; the enclosing view tic
must agree. Custom IDs require flag 8, forbid 16 and must exist in the
session bank; see the translucency contract. `ExtendedScene` decodes each selected sprite name once per update.
`SpriteRenderer` caches its uploaded patch across updates and reuses the native
world billboard, weapon overlay and fuzz paths. Classic engine calls are gated
off when external weapon records are supplied, including an empty array.

## Limits and evidence

Simulation psprite offsets include movement bob. Run interpolates camera,
compatible weapon positions, actors and moving surfaces; see
[interpolation](EXTENDED_INTERPOLATION.md). Normal/additive/state/object tables,
weapon blending and shared fuzz/transparent ordering use copied engine data;
see [translucency](EXTENDED_TRANSLUCENCY.md). Palette effects, control-sector
lighting and fake-floor clipping are adapted. Animation frames remain discrete;
large-map performance and actual campaign playtesting remain ongoing work.

`scripts/test-extended-worker.sh` checks complete-copy canaries, nine malformed
packets, all sixteen actual Rust maps at startup/tic 35, and eight directional
rotations/mirrored pairs. Original test rooms use the actual Rust patch/resources:
Incinerator firing decodes 16 unique frames with up to four visible projectile
actors and ammo 20→16; full-charge Blade decodes 31 frames, up to 15 visible actors,
a separate flash and ammo 70→20. Invisible TNT1 projectiles are excluded from
presentation counts; these differ from simulation actor counts.

Native build 132 verifies MAP01 corpse placement and raised/firing pistol artwork,
plus MAP16's world/sprite view after its starting switch opens. Rust-specific guns
and all monster animations still require targeted native visual checks. See
[validation](VALIDATION.md) for evidence and the remaining acceptance boundaries.
