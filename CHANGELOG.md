# Changelog

User-visible changes are recorded by successful app build. Build numbers can skip
when intermediate builds were used for validation. WADs and generated artifacts
are never included in the repository.

## Build 75 — Player-focused release archive

- Move contributor setup, release, development, architecture, testing and validation
  documents into docs/, retaining them in the public repository and source archive.
- Trim the app ZIP to the app, installation/player guides, short bug-report guide,
  license notices and signing status. Update documentation and CI release-note links.
- Verify documentation links, the packaged file list and extracted app signature.

## Build 74 — GitHub Actions builds and tagged releases

- Add macOS builds and WAD-free checks on main pushes/pull requests, with downloadable
  development artifacts. Version tags sign with Developer ID and publish a prerelease
  containing the app, matching source archive and checksums; notarization stays off.
- Isolate signing secrets to tag builds and remove the temporary runner keychain.
- Separate CI build numbering from the local counter and validate tags against the
  app version. Add a beginner guide for certificate export and GitHub secret setup.
- Validate local build and WAD-free checks. Hosted execution and secret import await
  the first GitHub run after setup and push.

## Build 73 — GitHub preview packaging and documentation

- Shorten the README and move controls, development details and historical
  validation into dedicated guides; add installation and release notes.
- Replace the verbose, outdated About text with a short description and credits
  for Chocolate Doom, id Software and Nuked OPL3.
- Add explicit signed-but-unnotarized ZIP packaging with instructions, license
  notices and SHA-256 checksums. Keep Apple submission separate.
- Build and verify the signed app, About dialog and extracted release archive.

## Build 72 — Selected Metal M app icon

- Replace the placeholder with the selected standalone Apple Metal M in Doom gold-to-blue-steel colors.
- Remove the draft's checkerboard background while preserving the original opaque artwork and providing transparent rounded corners.
- Verify all ten bundled icon sizes, app signature, Finder rendering and launch of build 72.

## Build 71 — Placeholder app icon

- Add a metallic M placeholder icon with warm orange lighting and transparent corners.
- Generate standard and Retina macOS icon sizes from the source artwork during each build.
- Verify the signed app bundle, Finder icon preview and launch of build 71.

## Build 70 — Developer ID release packaging

- Add separate local signing and Apple notarization steps, using a Developer ID
  Application identity, Hardened Runtime, secure timestamps and Keychain credentials.
- Prepare release copies without modifying local builds; retain notarization receipts,
  staple accepted tickets, verify Gatekeeper and generate ZIP/SHA-256 artifacts.
- Document release setup and source/archive publication. Verify the local signature
  and native Doom II launch; Apple submission is pending upload approval.

## Version 0.2.1 — Build 69 — Patch version update

- Bump the app version to 0.2.1 for the invisible-teleport-destination rendering
  fix delivered in build 68; update the documented version.
- Rebuild and verify the installed app displays 0.2.1 with build 69.

## Build 68 — Invisible teleport destinations

- Stop drawing non-sector objects as world sprites. Invisible teleport
  destinations were appearing as frozen imps, notably in SIGIL's demo openings.
- Preserve teleport/gameplay behavior; filter only the renderer's object list.
- Validate both SIGIL DEMO1/DEMO2 openings, real imp visibility and death frames;
  verify the installed E5M5 spawn scene against the supplied Crispy Doom recording.

## Build 67 — WAD hashes in diagnostics

- Include SHA-256 hashes for every loaded IWAD/PWAD, in load order, in copied
  diagnostics and session exports, using the exact file contents loaded in memory.
- Share the same report with benchmarks without duplicating their hash listing.
- Verify the installed build's copied report against independent file hashes.

## Build 66 — KEX edition identification

- Identify Doom, Doom II, TNT and Plutonia rerelease IWADs from their campaign
  resources and GAMECONF metadata, including renamed copies.
- Show KEX Edition in the window title, console status, title accessibility label,
  benchmark summary and diagnostics/session reports.
- Preserve the base IWAD edition when adding PWADs; identification does not enable
  KEX gameplay extensions or change campaign/save identity.
- Validate all four IWADs, renamed copies, malformed metadata, original IWADs and
  mixed-edition stacks; verify the installed build's native window labels.

## Version 0.2.0 — Build 65 — Classic OPL music

- Add persistent Audio menu choices for Classic OPL (default) and Apple MIDI;
  switching restarts the current track while preserving volume/mute settings.
- Use pinned Chocolate Doom Doom 1.9 OPL2/Sound Blaster sequencing, the loaded
  GENMIDI bank and Nuked OPL chip emulation, with native Core Audio playback.
- Keep Apple General MIDI available without labelling it original Mac QuickTime.
- Render OPL scores into temporary PCM (up to ten minutes); clean up players on
  release/quit and report failed switches while restoring the previous backend.
- Validate deterministic PCM, native playback, loops, pause/resume, mute,
  backend switching and loaded-WAD shutdown. All 35 Doom II tracks render as
  OPL PCM; Apple MIDI pitch/reset tests pass.
- Bump the marketing version for the accumulated classic-campaign, WAD-stack,
  diagnostics and selectable music milestone; update tester documentation.

## Build 62 — Benchmarks and session logs

- Add a base-IWAD DEMO1 benchmark from the title screen: 5-second warm-up,
  15-second measurement, average/slowest-1% FPS and mean/p99/max intervals.
- Record current capped rendering settings, hardware/build and WAD SHA-256;
  label CPU submission timing explicitly and export completed results as text.
- Preserve normal settings, return to title, and discard interrupted runs when
  cancelled, unfocused, resized or affected by playback/Metal errors.
- Export bounded, path-redacted session logs with map/WAD loads, missing textures,
  errors, settings and benchmark events; update the testing guide/issue template.
- Validate statistics, log bounds/redaction, cancellation/settings preservation,
  shutdown, native Doom II/TNT runs and exported reports in installed builds.

## Build 60 — Tester diagnostics

- Add Diagnostics menu controls for Apple's Metal Performance HUD and a copyable
  report with app/build, Mac/macOS/GPU/RAM, rendering settings and campaign/map.
- Include ordered WAD filenames without full filesystem paths or game data.
- Enable HUD support for normal app launches with a process-local launch
  environment; start the overlay hidden and allow live on/off toggling.
- Add a testing guide and GitHub bug-report template. Verify installed build 60
  HUD visibility, empty/ordered-stack reports, clipboard output and shutdown.

## Build 55 — Rerelease HUD alignment

- Center extended rerelease status-bar backgrounds around the classic HUD so
  ammo, health and armor labels align with their counters in Final Doom and
  other rerelease IWADs, without stretching the artwork or moving widgets.
- Preserve original 320-pixel backgrounds and integer HUD scaling; use the
  extended artwork for side padding and clip it at the viewport edges.
- Verify installed build 55 with TNT and Plutonia, normal/expanded windows,
  original Doom II and Ultimate Doom artwork, and clean loaded-WAD exits.

## Build 54 — Final Doom

- Recognize TNT: Evilution and The Plutonia Experiment from the base IWAD,
  preserving campaign identity for renamed files and ordered add-on stacks.
- Display all 64 campaign map names and select Final Doom's original gameplay
  profile, story screens and cast ending, using each IWAD's artwork/music/skies.
- Validate all 64 rerelease maps, assets, music, secret routes, inventory,
  save restoration/isolation, cast cycle and original teleport-height behavior.
- Preserve Doom II, Ultimate Doom and rerelease SIGIL regression coverage.
  Verify both native MAP01 scenes and clean loaded-WAD Quit/window-close exits.

## Build 51 — Doom II finales, WAD stacks and SIGIL

- Add Doom II story breaks and the original interactive, animated 17-member cast
  with attack/death sounds and final music; retain inventory through story breaks.
- Validate MAP07 boss triggers, Icon of Sin spawning/death, secret routes and cast.
- Add a base-IWAD/add-on load-order dialog and ordered `-file` PWAD arguments.
  Keep files separate; later resources override earlier ones in shared namespaces.
- Support standard SIGIL v1.23 as Episode 5 with maps, names, sky, MIDI music,
  secret routing, intermission art, story ending and native saves.
- Key saves/slots by the entire ordered stack while preserving single-IWAD saves.
- Preserve Ultimate Doom and clean-exit regression coverage. General metadata,
  DeHackEd mods, SIGIL COMPAT, SIGIL II and MP3 music remain unsupported.

## Build 48 — Clean exit with a loaded WAD

- Stop the title/demo timer, input monitor, rendering and audio before window
  teardown, both when closing the window and when quitting the app.
- Disable AppKit's automatic window release so Swift retains valid window ownership.
- Add loaded-WAD shutdown checks covering title/gameplay closure, Quit cleanup,
  repeated shutdown and late timer callbacks.

## Build 47 — Doom II core validation and MIDI pitch reset

- Reset MIDI pitch bend and controllers between songs and on loop restart to
  prevent stale synth state carrying into subsequent music.
- Validate all 32 Doom II maps and the super shotgun's firing, reload sounds,
  weapon switching and inventory carryover; smoke-test eight added monster types.
- Keep Ultimate Doom geometry, progression and music regression checks passing.
- Verify native Doom II title/demo, MAP01 and super shotgun presentation. Story
  breaks, MAP07/Icon of Sin encounter validation and cast ending remain future work.
- Pitch-reset audio measurements pass; the reported startup title timbre has not
  been matched against a reference recording.

## Build 45 — Episode endings and animated intermissions

- Add original Doom episode story text, tiled backgrounds, ending artwork and
  victory music, including Episode 3's scrolling bunny finale and ending shots.
  Use/Enter reveals the story, then advances to the artwork; automatic timing works.
- Animate episode intermission backgrounds and the Episode 2 secret-map overlay
  using WAD patches, without affecting gameplay randomness.
- Restart after death with a fresh E, Space or Enter press after a short delay.
  Clear held input at death and select Load Game when opening the pause menu.
- Enlarge Sound Volume, Display and Back consistently on the initial Options page.
- Expand checks to all four episode progression chains, representative lifts,
  crushers and secret counting, finale timing, plus existing save/load regressions.

## Build 44 — Power-up effects, fuzz and automap

- Add invulnerability inverse grayscale, night vision, suit and berserk scene tints,
  with power-up expiry blinking driven by the original engine.
- Render spectres and invisible weapons with depth-tested background fuzz sampling.
- Add the Tab automap with live gameplay, explored lines, player follow, pan, zoom,
  fit and map-power reveal. Save/load retains exploration; the HUD stays visible.
- Make Sound Volume match the other Options row text and tighten Ultimate logo
  letter masks to remove background pixels. Keep map titles clear of pickup messages.

## Build 40 — Ultimate Doom menu header

- Build a transparent Ultimate Doom menu logo from the loaded WAD's gold title
  caption and M_DOOM artwork, keeping game art out of the repository.
- Remove the separate game-name label beneath the menu and add a small gray
  MetalDooM version/build footer. Adjust Ultimate Doom menu spacing for the header.
- Retain the standard M_DOOM logo when the expected Ultimate artwork is unavailable.

## Build 39 — Cheats, title screens and attract demos

- Show the WAD's original title artwork and music before the menu, and identify the
  loaded game on the menu. File → Return to Title Screen revisits the attract loop.
- Play embedded single-player Doom 1.8/1.9 demos between title/credit pages, including
  Ultimate Doom's fourth demo. Key/click opens the menu; menus/console/focus loss pause.
- Connect typed god, ammo/keys, noclip, power-up, chainsaw and level-warp cheats,
  with console aliases and HUD feedback. Reject gameplay cheats on Nightmare and
  during demos; restrict weapon grants to the loaded game's weapons.
- Validate demo headers/streams, ignore live gameplay input during playback, and
  clean up demo state when starting or loading a game. Attract states cannot be saved.

## Build 35 — Animated surfaces and Doomguy expressions

- Animate original wall textures and floor/ceiling flats using the engine's frame
  translations; preload Metal frames and switch textures without rebuilding geometry.
- Freeze animation with gameplay pause and restore its phase on save loading.
- Add directional hurt, heavy-damage ouch, sustained-fire and invulnerability faces,
  retaining idle, pickup grin, health bands and death with tic-based priorities.
- Correct the original reversed heavy-damage check so ouch appears on large hits.
  Face state resets on map/save load without consuming gameplay randomness.

## Build 33 — Developer console

- Open an optional Quake-style console with backtick/tilde; Escape closes it.
  Gameplay pauses, mouse capture is released, and an existing menu is restored on close.
- Add command history, Tab completion, bounded scrollback, help and clear commands.
- Support map listing/loading, restart, renderer/game diagnostics, effects/music
  volumes, music enablement, render scale, frame limit and fullscreen.
- Validate command arguments before applying settings; console errors remain inline.

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
