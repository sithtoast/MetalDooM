# Bundled single-player preview — 0.10.0 build 159

The explicit development preview can now run the rerelease's resource packs on
Doom II, independently of the Legacy of Rust campaign. The ordinary picker and
standard build retain their existing acceptance rules. No multiplayer mode is
included; `iddm1.wad` remains outside this milestone.

Build with `METALDOOM_EXTENDED_PREVIEW=1 METALDOOM_BUILD_DIR="$PWD/build/bundled-preview-final" bash scripts/build.sh`.
Supply a directory containing your own rerelease WADs:

```sh
build/bundled-preview-final/MetalDooM.app/Contents/MacOS/MetalDooM \
  --bundled-preview /path/to/rerelease --content weapons --extras --map MAP32
```

| Content | Additional resources after Doom II | Maps | Worker profile |
| --- | --- | --- | --- |
| `rust` (default) | `id1.wad` | MAP01–16 | 1, Rust campaign |
| `doom2` | none | MAP01–32 | 0, strict |
| `resources` | `id1-res.wad` | MAP01–32 | 2, bundled components |
| `weapons` | `id1-res.wad`, then `id1-weap.wad` | MAP01–32 | 2, bundled components |
| `textures` | `id1-tex.wad` | MAP01–32 | 0, strict |
| `music` | `id1-mus.wad` | MAP01–32 | 0, strict |

Every plan starts with `id24res.wad`, then `doom2.wad`. `--extras` prepends
`extras.wad` before both. The explicit base index identifies Doom II independently
of its position. Ordered bytes, base index and worker profile are all hashed for
resource/save identity. Existing `--rust-preview /path/to/rerelease --map MAP01`
keeps its original three-file order and profile. Sibling packs are not implicit
Rust campaign dependencies and are not all stacked together.

The resources pack patches actors and supplies artwork; it does not install the
new weapon/ammo definitions. The weapons plan adds the full weapon patch after
those resources. HUD weapon/ammo names follow the chosen plan: Doom II names for
ordinary/component-resource play, Rust names for the Rust/weapon plans. Profile 2
permits the same audited ID24 patch fields as profile 1 while retaining Doom II's
32-map campaign bound. This is not a general ID24/PWAD compatibility promise.

The music pack contains 17 named MIDI tracks but no automatic Doom II map-to-track
remapping. Its preview explicitly auditions `D_IBEGIN`, including after Save/Load
and map changes. Use `--content music --track D_BILGE` (or another existing pack
lump) to choose another track. Sound/Music toggles and Pause still apply. Engine-supplied music names are
resolved case-insensitively, including Doom II's lowercase default track names.

Private `.mdrust` saves accept MAP01–32 and must match the engine, resource order
and profile. The Rust UI still bounds saves/maps to 16. Restore uses the current
plan's base/profile and creates a fresh paused worker. No migration of old saves
or automatic loading from other profiles is implied.

## Named sky flats

Rerelease Doom II SKYDEFS maps `F_RSKY1/2/3` to `SKY1/2/3` without transfer
linedefs. The copied geometry now accepts normal sky mappings without a side,
uses zero side offsets, and canonicalizes their render-only plane names to
`F_SKY1`. Sky records retain the actual texture/mapping. This fixes the previous
"Unsupported layered or procedural transferred sky" rejection. World simulation
flats are unchanged. MGE5 layout and ABI2/18 exports remain unchanged.

## Evidence and boundaries

`test-bundled-preview.sh` exercises all six plans with/without extras: 352 map
starts and tic35 world/actor preparations; first/last map saves and eight future
movement tics per plan; all 1,831 merged texture definitions in resources,
weapons and textures plans; all 17 music tracks; transparent extras `TNT1A0`;
and both replacement weapons' pickup/firing frames and ammo use in fixtures.
`test-extended-metal.sh` compares first/last maps of each plan with extras against
independent full geometry and checks a named-flat sky with a projected pixel
oracle. See VALIDATION.md for actual results and the running candidate.

Loading extras makes its resources available. Its custom SBARDEF, carousel/menu
presentation, alternate `H_` music selection and all presentation-specific cues
are not implemented. Texture/resource loading does not exercise every authored
map effect. Full campaign/boss playthroughs, sustained performance, layered/fire
skies and software sky-stretch parity remain open. Native lighting still differs
from software; EXTENDED_LIGHTING.md records the first measured baseline.
