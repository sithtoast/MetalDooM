# Bundled KEX campaign support

Version 0.9.0 adds dedicated profiles for the installed rerelease editions of
No Rest for the Living, Master Levels for Doom II and SIGIL II. Choose the base
IWAD on the left of Open WAD and one campaign PWAD on the right. Files can be
renamed: recognition uses file contents. No game data is bundled or copied.

| Campaign | Base | Add-on | Implemented behavior |
| --- | --- | --- | --- |
| No Rest for the Living | Doom II | nerve.wad | Nine maps; MAP04 secret exit → MAP09 → MAP05; MAP08 story/cast; music, skies, pars; disabled MAP07 boss actions |
| Master Levels | Doom II | masterlevels.wad | 21 maps; MAP18 secret exit → MAP21 → MAP19; MAP20 story/cast; custom skies/music; MAP19/20 boss actions; no inherited Doom II pars |
| SIGIL II | Ultimate Doom | sigil2.wad | Nine E6 maps; E6M3 secret exit → E6M9 → E6M4; E6M8 story/CREDIT; music, SKY6, SIGILIN2, pars; 9,000-health spider, disabled boss exit, FLMWAL01–03 animation |

Only campaign maps appear in selectors. Saves include the exact ordered WAD
identity and restore campaign state. The campaign profiles exclude inherited base
demos and cycle title/credit pages. Load one dedicated campaign at a time; arbitrary
additional PWAD combinations are rejected. Use Open WAD to switch campaigns.

These are bounded profiles, not a general UMAPINFO, MAPINFO or DeHackEd interpreter.
The three recognized PWADs are identified by full SHA-256 in `Sources/WAD.swift`.
Different or edited editions remain rejected until assessed. Runtime text, names,
skies and music are read from each identified file's UMAPINFO; the engine implements
its routes, boss rules and other gameplay changes explicitly. SIGIL II's SWITCHES
matches vanilla; ANIMATED adds one flame-wall sequence. None of these three WADs
contains linedef specials above vanilla's 141. The engine still runs classic Doom
simulation; multiplayer and the online add-on catalog are outside the requested scope.

## Remaining bundled content

Inventory read from the user's installed rerelease directory on 2026-09-11:

| File/group | Observed contents | Remaining work |
| --- | --- | --- |
| doom.wad, doom2.wad, tnt.wad, plutonia.wad | 36/32/32/32 maps, MUS music | Existing classic campaign coverage; GAMECONF options are not generally interpreted |
| sigil.wad | Nine E5 maps, MIDI music | Existing dedicated SIGIL profile |
| extras.wad | 170 resource lumps, no maps or D_ music | Classify optional replacement/menu resources and precedence; not a new campaign |
| id1.wad | GAMECONF declares id24, 17 map blocks, DeHackEd/UMAPINFO/ANIMATED/SWITCHES, 18 MIDI lumps | Legacy of Rust: extended actors/states/actions, weapons/ammo, MBF21/ID24 rules, progression and intermission animation; unsupported |
| id1-res.wad | 2,206 lumps, actor DeHackEd plus animation/switch tables | Establish exact dependency/precedence rules; implement extended actor engine support |
| id1-weap.wad | Six lumps including DeHackEd | Implement weapon patch semantics and pickup/ammo behavior |
| id1-tex.wad | 1,674 lumps, animation/switch tables | Implement resource tables and validate animated/masked materials |
| id1-mus.wad | 20 lumps, 17 MIDI tracks | Confirm intended replacement/load precedence and track assignments |
| id24res.wad | 530 resource lumps, no maps | Audit ID24 base resources against the engine implementation |
| iddm1.wad | 26 map blocks, id24 executable, extended patches | Deathmatch pack: excluded from the requested single-player scope |

`id1.wad` GAMECONF has null pwadfiles/dehfiles, so its filename family must not be
assumed to be one additive load list. Its advertised 16 playable levels and the
17 directory map blocks also need reconciliation. Do not relax rejection guards
or claim complete KEX/ID24 support based on opening a map. Legacy of Rust is the
next substantial engine compatibility project.

## Validation boundary

`bash scripts/test-kex-campaign.sh BASE.wad CAMPAIGN.wad` checks all campaign maps,
geometry/materials/sprites, metadata/music decoding, normal and secret routing,
inventory continuation, endings, save round trips, campaign boundaries, modified
edition rejection, and boss/animation requirements. Master Levels MAP20 declares
an arachnotron/tag-667 action but contains no tag-667 sectors; it is a no-op there.
Its tag-666 floors and MAP19's tag-666 floors were verified through boss deaths.

Native launch and artwork checks complement these tests. Automated routes and
resource checks do not establish full manual campaign playthroughs, sound mixing
accuracy, parity with every KEX option, or compatibility with other file editions.
