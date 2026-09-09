# Changelog

User-visible changes are recorded by successful app build. Build numbers can skip
when intermediate builds were used for validation. WADs and generated artifacts
are never included in the repository.

## Build 17 — Map names and save/load

- Add canonical map names to window titles and status text, such as E1M1: Hangar.
- Add native Save Game and Load Game dialogs, plus one persistent quick-save slot
  per WAD. Saves use atomic file replacement, versioning, WAD identity and a payload
  integrity check.
- Restore player/view, inventory, world objects, moving sectors, random state and
  pending switch resets. Loading can return to a saved map from another map.
- Add this changelog and require an update with future user-requested changes.

## Build 15 — Game identification (`5805930`)

- Show the detected game name in the title alongside the WAD filename and map.
- Keep the full title when selecting or advancing maps.

## Build 14 — Ultimate Doom progression (`9f36143`)

- Add level completion, classic intermission stats and an Entering screen.
- Carry health, armor, weapons and ammo to the next level; clear keys and powers.
- Use original normal/secret-level routing and stop at episode completion.
- Synchronize live switch textures and timed resets.
- Validate all 36 Ultimate Doom maps, exit progression and the pillar switch.

## Build 12 — Exit panels and sky (`c215d7c`)

- Restore two-sided masked textures, including E1M1's exit-room panels.
- Correct texture pegging, directional wall faces and subsector plane bounds.
- Add sky depth boundaries and correct cylindrical sky projection.

## Build 11 — Combat and sound (`f9b6488`)

- Enable original weapons, monsters, attacks, ammo use, damage and death.
- Add Metal weapon/muzzle-flash overlays, weapon selection and damage tint.
- Play original sound effects through native AVAudioEngine voices.

## Build 9 — Sprite floor placement (`71ff098`)

- Keep below-origin sprite artwork above the live floor so it is not clipped.

## Build 8 — Sprites, pickups and HUD (`b317478`)

- Render original sprites, decorations and classic status-bar artwork in Metal.
- Enable pickups, keys, inventory and original pickup/locked-door messages.
- Preserve brief movement taps between simulation tics.

## Build 6 — Initial committed foundation (`828fe5d`)

- Native Apple Silicon AppKit/Metal app with WAD loading and BSP-based world rendering.
- Integrate the pinned Chocolate Doom engine for movement, collision, doors,
  moving sectors, fixed-rate gameplay and map restart.
- Add incrementing build numbers, licensing, validation scripts and project workflow.
