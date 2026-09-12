# Legacy of Rust development and ID24 evidence

Status: **0.10.0 build 151 native preview with translucent walls and palette effects, normal/additive/per-state actor translucency, camera/weapon interpolation, scrolling floors/ceilings, Save/Load, restart, normal/secret transitions, animated intermissions, stories, credits, custom cast, HUD, music and sound; full Rust campaign support remains pending.**
First campaign acceptance remains fully playable bundled single-player Rust.
Multiplayer and the online add-on catalog are outside scope. General ID24
conformance is a separate target and must never be inferred from this campaign.

## Reproduce the installed-data audit

Run `python3 scripts/audit-rust.py /path/to/rerelease > build/rust-audit.json`.
The script reads only, validates directory/record bounds, and reports hashes,
map records, resource tables, DeHackEd requirements and selected metadata. It is
an inventory, not a general UMAPINFO/GAMECONF parser or compatibility validator.
Never commit the generated WAD fixtures, extracted lumps or app bundles.

Audited on 2026-09-12. Installed campaign GAMECONF version: **1.2**.

| File | Lumps | SHA-256 |
| --- | ---: | --- |
| id1.wad | 2450 | e075f718eadb9aba2013eef07fc8cfce7463f5332517049c40d10db56046f9c0 |
| id24res.wad | 530 | b0268ac0d3b009b9cf4be8cea99e8b1557f85976e59ef6a151a3c171332da159 |
| id1-res.wad | 2206 | 6f1dd46da2ff351564303538bdec984161f68c5f1f3597a9a4df5fc14878f95b |
| id1-weap.wad | 6 | 5d61b1c620d3ef83aca7f213ad536bcea6c668be21b54d8101b910d33263ffb9 |
| id1-tex.wad | 1674 | 023227ba52a6ba2ac39e2417b9eb4559a4ddac2493fa66e3662f4a85825feedf |
| id1-mus.wad | 20 | bcd6604d9d951b347b01c9e40bdf242ed8d6891f5424578c5e533ee9e233e8d0 |
| extras.wad | 170 | 65e335714c23b9a57ac2ae0d7f8b5fb27ea11f25f2ed31e3e5670f3c08235bbb |

## Dependencies and precedence

The campaign GAMECONF specifies `doom2.wad`, `id24`, `commercial`, and null
`pwadfiles`, `dehfiles`, and `options`. It does not request sibling WADs.
The ID24 specification recommends placing its supporting resources before the
IWAD. The intended baseline is therefore **id24res → Doom II → id1**. The reference
GAMECONF setup additionally places `extras` before `id24res`. These are the
specified orders, not a captured trace of KEX's proprietary launcher. The current
MetalDooM stack API assumes the base IWAD is first; a future session planner must
separate game identity from pre-IWAD resource placement and hash the whole order.
[ID24 supporting data](https://github.com/doom-cross-port-collab/id24/blob/e96a9e1c9ee34621b03a4894f4053c2a3426496e/version_0_99_2_md/ID24_formal_specification_0.99.2.md),
[GAMECONF setup](https://github.com/doom-cross-port-collab/id24/blob/e96a9e1c9ee34621b03a4894f4053c2a3426496e/version_0_99_2_md/GAMECONF.md).

Byte comparisons establish why sibling names must not imply dependencies:

- `id1-res`: 2,199 identical lumps, no new names; seven differ, including the actor
  patch and two texture patches (`TCMFLRE`, `TCMFLRF`).
- `id1-tex`: 1,669 identical lumps, no new names; five differ, including those same
  two texture patches. Its ANIMATED/SWITCHES match id1 exactly.
- `id1-weap`: three identical lumps including the complete DEHACKED/DECOHACK;
  only version/info/credits differ. Loading it after id1 repeats the patch.
- `id1-mus`: sixteen identical lumps, three metadata differences, one new music
  name `D_IBEGIN`. It is not an extra required campaign music layer.
- `id24res`: 492 identical lumps, 31 differing lumps, seven names absent in id1:
  `STAMMO24`, `STARMS24`, `DSFLAME`, `INCNA0`, `CBLDA0`, `FCPUA0`, `FTNKA0`.
  Supporting resources do not themselves install the required engine data tables.
- `extras`: primarily menu/carousel, alternate `H_` music and status-bar resources;
  no maps. Its SBARDEF differs. It is a reference-loader presentation layer, not
  evidence for loading the id1 sibling family.

Comparison counts are directory entries against id1's last same-name lump, not a
claim that blindly concatenating directories produces a valid resource namespace.
No dependency or sibling resource is automatically loaded by this milestone.

## Seventeen map blocks, sixteen campaign maps

UMAPINFO declares two episode starts: MAP01 (The Vulcan Abyss) and MAP08
(Counterfeit Eden). Episode one runs MAP01–07; MAP02 secret-exits to MAP15,
which returns to MAP03. Episode two runs MAP08–14; MAP10 secret-exits to MAP16,
which returns to MAP11. That is fourteen main maps plus two secret maps.
MAP07 and MAP14 end their episodes; neither should fall into Doom II's defaults.

The seventeenth block is **MAP99**, titled “Test Map Please Ignore,” marked
`kex_nolevelselect = true`, and routed back to MAP99. It must be excluded from
normal new-game/level-selection routes. It is not a seventeenth advertised level.

## Actual campaign requirements

| Area | Installed evidence | Required implementation/acceptance |
| --- | --- | --- |
| Actors/states | 66 Thing sections (indices 1–209); 467 Frame sections (1100–1566); sprite/sound remapping; eight action arguments | Extensible tables and typed actor/weapon action dispatch; defaults and reference validation, not bigger arrays alone |
| Combat | MonsterProjectile, SpawnObject, RadiusDamage, RemoveFlags, RandomJump; MBF21 flags, projectile/splash groups, fast speed and respawn fields | Correct movement/collision, damage immunity, targeting, state entry, RNG and action defaults; combat fixtures for all six new monsters and boss variants |
| Weapons/ammo | Weapon 5/6 replace plasma/BFG; Ammo 2 becomes fuel; CheckAmmo, ConsumeAmmo, WeaponProjectile/Jump/Sound, RefireTo, GunFlashTo | Incinerator and charge/release Calamity Blade, pickups/messages, consumption, dry fire, switching and save restoration; do not assume this patch uses the reserved negative ID24 weapon IDs |
| Nodes | MAP13 NODES begins XNOD, 2,094,096 bytes; remaining map nodes use classic records | Bounded extended-node decoding in both simulation and Swift geometry with identical vertex/subsector/seg interpretation |
| Map semantics | Boom generalized actions, scrollers, transfers, friction; special 272; sector 368/512; ID24 1023/1024/1080/2048/2083 | Explicit feature selection and source-matched generalized/MBF21/ID24 dispatch, sky/floor lighting, scrolling and physics. MAP13 has 160 lines of special 2083 |
| Materials | 49 ANIMATED records, 85 SWITCHES pairs; animation rates 4/8/32; replacements extend NUKAGE/BLOOD to four frames | Data-driven replacement tables, namespace lookup, engine clock, all Metal frames and switch pairs; completed foundation below |
| Skies/HUD | SKYDEFS and SBARDEF JSON 1.0.0 | Audit and implement required sky motion/composition and weapon/ammo display semantics; custom native HUD needs explicit parity checks |
| Progression | Two episode starts and endings; secret routes above; cleared default boss actions; MAP13 Cyberdemon tag 666, MAP14 Deh_Actor_156/157 tags 666/667 | Episode-aware routing, inventory transitions, boss triggers and map filters; ordinary exit tests and actual boss-death tests |
| Music/intermission | 18 D_ MIDI lumps; XWINTER0/1 interlevel JSON selects D_DM2INT and episode animation | Parse and render conditions/frames/durations with pause/resume; map/intermission music mapping and playback |
| Finale | MAP14 endfinale XFINALE1; JSON cast roll call, custom sprite frames/sounds, nonlooping D_DEJAVU; CREDIT endings | Native custom cast and episode story/ending state machine, correct input/timing/music transitions |
| Saves | Existing archives encode vanilla players, thinkers and specials | Version extended payload and engine identity; serialize new inventory/state IDs, action/RNG state, new sector thinkers and pointers safely; reject incompatible saves before mutation |

The reserved signed ID24 indices and action invocation contracts are documented in
[ID24HACKED](https://github.com/doom-cross-port-collab/id24/blob/e96a9e1c9ee34621b03a4894f4053c2a3426496e/version_0_99_2_md/ID24HACKED.md)
and the GPL-2.0-or-later [reference data/thinker code](https://github.com/doom-cross-port-collab/id24/tree/e96a9e1c9ee34621b03a4894f4053c2a3426496e/source_code_reference).
The latter labels itself 0.99.1 and uses C++17 layouts; it is not a drop-in C file
for the pinned Chocolate core. The campaign's positive replacement IDs are not
proof that the reserved namespace can be omitted from broader ID24 conformance.
The [mapping additions](https://github.com/doom-cross-port-collab/id24/blob/e96a9e1c9ee34621b03a4894f4053c2a3426496e/version_0_99_2_md/Mapping_Additions.md)
define the observed ID24 map specials.

## Engine approach

Source snapshots inspected, rather than inferred from product labels:

| Approach | Benefit | Cost/risk | Decision |
| --- | --- | --- | --- |
| Extend Chocolate in place | Existing native bridge and classic behavior already validated | Almost all Boom generalized actions/physics, MBF21 combat and extensible data/save machinery would have to be ported together; isolated patches risk silent semantic gaps | Keep as the classic reference path; only bounded shared work such as resource tables lands before the simulation integration |
| Adapt Woof simulation modules | Established Boom/MBF lineage, extended tables/actions, nodes and UMAPINFO; C sources relatively close to existing core | Save/layout/platform dependencies; its current source does not by itself establish complete ID24HACKED conformance | Preferred starting point for the extended simulation boundary, with explicit ID24 additions and tests |
| Adapt Rum and Raisin | Chocolate ancestry plus feature-gated extended simulation and ID24-related table/presentation machinery | Substantial C++ container/type/thinker changes, renderer/platform coupling; `rnr24` naming and published spec require reconciliation | Reference for ID24 semantics and defaults; evaluate individual modules, not a wholesale native frontend replacement |

Pinned references: [Woof acd1c7f](https://github.com/fabiangreffrath/woof/tree/acd1c7f84fdd0fae92d1c58643c14364a131c75a),
[Rum and Raisin eaf5381](https://github.com/GooberMan/rum-and-raisin-doom/tree/eaf5381814e1b1993047b5e752d9e003951768aa),
[ID24 e96a9e1](https://github.com/doom-cross-port-collab/id24/tree/e96a9e1c9ee34621b03a4894f4053c2a3426496e).
The resource-only build 126 preceded engine import. Build 127 added the pinned
Woof subset after a native bootstrap; build 128 adds session planning, three
required ID24 fields and actual Rust probes. Review the per-file changes and
licenses in `Vendor/Woof/UPSTREAM.md`. These tests do not establish full ID24
compatibility or Rust playability.

Keep Swift/AppKit/Metal ownership and the copied C snapshot boundary. Preserve
classic save decoding and do not reinterpret old payloads as an extended layout.
The fixed weapon/ammo fields in MD_HUD and the save format need explicit versioned
extensions before new IDs are exposed. Session feature levels must be chosen
before resource/game initialization, not guessed separately by Swift and C.

## Implementation milestones

1. **Resource foundation (implemented in 0.10.0):** bounded packed ANIMATED/SWITCHES
   tables, dynamic storage, last-lump replacement, shared animation layout,
   native switch-pair preload, original tick/save phase and button reset.
   SIGIL II now uses its actual ANIMATED lump instead of a hardcoded flame entry.
   Existing add-on guards remain intact. Limits: 65,536 records per table;
   positive rates below 65,536; no SMMU swirl or single-frame extension.
2. **Extended engine seam and data (builds 127–128):** an isolated native worker
   now has copied snapshots, typed actions, ordered session planning and a guarded
   Rust profile. Tests cover required pickup/respawn fields, actual Rust weapons
   and all sixteen map startups ([limits](EXTENDED_ENGINE.md)). Complete broader
   data/action validation and remaining GAMECONF/ID24 semantics. Compare classic deterministic movement,
   combat, RNG, saves and all KEX profiles before switching any default backend.
3. **Rust simulation:** complete Boom/MBF21/required ID24 actions and physics;
   both new weapons and all actors, required skies and
   materials. Headless map startup (including MAP13 XNOD) and bounded real-weapon
   probes pass in build 128. Build 129 adds [copied shared geometry](EXTENDED_GEOMETRY.md)
   and all-map CPU mesh validation. Build 131 adds an explicit [native world preview](EXTENDED_PREVIEW.md)
   through a child process. Build 132 adds [actor/weapon frames](EXTENDED_SPRITES.md)
   and manual firing. Build 133 adds engine-timed material animation and
   [cached scene updates](EXTENDED_MATERIALS.md). Build 137 adds continuous one-tic
   scene/audio playback and Run/Pause. Build 139 adds [incremental geometry](EXTENDED_MESH.md)
   with measured MAP13 CPU improvement and exact GPU parity. Build 135 adds native
   [sound effects](EXTENDED_AUDIO.md). Build 140 adds [native HUD and level MIDI](EXTENDED_UI.md).
   Full presentation and campaign gameplay remain required. Validate targeted combat/map behavior, not just startup.
4. **Campaign and persistence:** build 143 adds death/restart and all normal/secret
   route probes and inventory carryover ([details](EXTENDED_LIFECYCLE.md)). Build 144
   adds native interlevel animations, stories, credits and the custom finale
   ([details](EXTENDED_CAMPAIGN.md)). Build 145 adds private extended saves ([details](EXTENDED_SAVES.md)).
   Complete actual boss exits.
   Test each route and restore
   during projectiles, charge attacks, moving sectors, switches and transitions.
5. **Playable Rust acceptance:** native play from both episode starts, combat,
   pickups, hazards, secrets, boss exits, endings and mid-campaign saves; record
   exact version/build and limits. All 16 maps must work, not just MAP01 loading.
6. **Broader ID24 conformance (separate):** spec feature matrix and independent
   fixtures for GAMECONF merging/translation, reserved data IDs and hashes,
   complete mapping/HUD/sky/finale/interlevel/DEMOLOOP features, MUSINFO, Ogg and
   tracker formats. Campaign MIDI success cannot establish those audio formats.
