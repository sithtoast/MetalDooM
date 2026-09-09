# Changelog

User-visible changes are recorded by successful app build. Build numbers can skip
when intermediate builds were used for validation. WADs and generated artifacts
are never included in the repository.

## Build 31 — Classic save, load and options

- Give all six save/load slots original Doom borders, bitmap names and the animated
  skull. Type a name in the slot; Enter saves and Escape cancels the edit.
- Extend the classic presentation to display and audio options, including original
  volume thermometers and keyboard/mouse adjustment.
- Play original menu opening, movement, selection, adjustment and back sounds through
  a separate mixer while gameplay is paused, respecting effects volume and focus loss.
- Honor artwork offsets so slot borders align with their text. Existing saves remain
  compatible.

## Build 28 — Original-style Doom menus

- Draw the main, episode and difficulty menus with original artwork, 320×200
  coordinates, crisp pixel scaling, and Doom's animated skull cursor.
- Restore original main-menu ordering and Read This artwork. Escape resumes or
  returns to the previous menu; arrows, Tab, Enter, Space, hotkeys and mouse work.
- Keep native display/audio options and named-save screens available.
- Cache decoded menu artwork during menu navigation.

## Build 23 — Pause menu, display options and save slots

- Escape opens a paused menu with Doom artwork; mouse and keyboard navigation
  support Resume, New Game, Options, Save/Load, Open WAD and Quit.
- New Game offers available episodes and all five original difficulty settings.
  Restart retains difficulty; loading restores the saved difficulty.
- Add six named save slots per WAD, separate from quick saves, preserving old saves.
- Add window-size presets, fullscreen, 50/75/100% render scale, actual pixel-size
  readout, and 35/60/120 FPS caps. Fullscreen uses the current desktop display mode.
- Add independent persistent music/effects volume controls, using Apple's native
  DLS synth on a separate mixer for music.

## Build 21 — Native WAD music

- Play and loop original level, intermission and completion music using Apple's
  MIDI player and built-in General MIDI sound bank; no instrument download needed.
- Convert MUS tracks in memory and preserve Ultimate Doom episode-four track
  assignments. Load/save and map changes select the corresponding level music.
- Pause/resume music on focus loss and file dialogs. Audio → Music (Cmd–Shift–M)
  toggles music independently of effects and remembers the setting.

## Build 19 — Intermission count-up and map markers

- Count kills, items, secrets, time and par with original Doom timing and sounds.
- Enter finishes the count; another press shows the destination. The next level
  starts after four seconds, or immediately with another Enter press.
- Show completed-level splats and the flashing next-level pointer on episode 1–3
  maps, including secret-level returns. Episode 4 and Doom II retain INTERPIC.
- Pause the sequence with the game when inactive; episode endings remain on stats.

## Build 18 — Weapon pickup grin

- Show Doomguy's original two-second grin when acquiring a new weapon, using the
  matching health-band artwork. Death and level loads clear the expression.
- Verify that E1M2's raised green armor at the end of the hall can be collected
  by walking up to the ledge; preserve the original map and pickup rules.

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
