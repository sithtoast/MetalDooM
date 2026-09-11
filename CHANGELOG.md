# Changelog

User-visible changes are recorded by successful app build. Build numbers can skip
when intermediate builds were used for validation. WADs and generated artifacts
are never included in the repository.

## 0.8.0 · Build 108 — Ludicrous effects preset

- Add View → Effects Presets → Ludicrous: all effects, High ray quality, 50% AO
  at 48 units, Atmospheric haze, 200% added light, 30% bloom, 1.5× HDR fullbright
  world sprites and an HDR ceiling of 8× standard white. Keep the recent
  visibility optimizations, smooth textures, steady haze and correct HDR mapping.
- Add independent Added Light Strength, Bloom Strength and HDR Fullbright Sprite
  Boost controls. Preserve restrained Enhanced/Showcase settings and normal HUD,
  weapon and power-up colors. Retain every choice in saved custom presets;
  older custom saves remain compatible.
- Validate native build 108 on macOS 27, plus Ultimate Doom and Doom II GPU
  regressions for preset routing, intensity changes, HDR bounds, HUD isolation,
  resize, save/load and clean shutdown. Ludicrous intentionally costs more GPU
  time; no new controlled FPS comparison or cause for the reported macOS
  mediaanalysisd CPU spike is established.

## 0.8.0 · Build 106 — Lower frame intervals for lighting presets

- Resolve world visibility in a cheap alpha-tested depth pass before expensive
  ray shading. Reject hidden fragments early, and let finite shadow rays stop at
  the first valid blocker while AO retains nearest-hit distances.
- Add View → Ray Quality: Balanced (8 AO / 4 soft-shadow / 16 haze samples) and
  High (16 / 8 / 32). Presets select Balanced; High retains the prior sample
  quality. Preserve smooth textures, restrained HDR, steady haze and all switches.
- Stop rendering fully occluded/minimized windows so they do not compete for GPU
  time. Preserve game state and resume rendering when the window becomes visible.
- At 2200×1520 in an isolated fixed-scene GPU comparison, Enhanced improves from
  18.84 to 6.16 ms median and Showcase from 28.77 to 9.20 ms. In the user's restored
  viewpoint, the native HUD improves from roughly 50.5 ms / 20 FPS to 11.3 ms /
  88 FPS. These are focused measurements, not universal frame-rate guarantees.
- Pass Ultimate Doom/Doom II lighting, cutout, HUD, quality/custom-preset, resize,
  save/load, shutdown and ceiling regressions. Inspect native build 106 with the
  user's separate saved snapshot restored; previous quick saves are untouched.

## 0.8.0 · Build 104 — Calmer Enhanced and Showcase presets

- Reduce the grainy, over-contrasted appearance of the first HDR/effects presets.
  Add optional Smooth World Textures with mipmaps and anisotropic filtering for
  walls/floors/ceilings; retain exact nearest-sampled cutouts, sprites and HUD.
- Blend added illumination in linear color space with restrained energy. Reduce
  bloom from 30% to 12% and reserve it for brighter highlights. HDR peak is now a
  brightness ceiling, without an extra contrast multiplier at standard white;
  remove the blanket 1.5× HDR boost on fullbright world sprites.
- Use 16 AO rays and eight soft-shadow samples. Enhanced selects 25%/16-unit AO,
  soft shadows and world filtering. Atmospheric/Showcase select 25%/32-unit AO and
  Light Haze. Volumetrics use 32 fixed midpoints instead of 12 pixel-random samples.
- Preserve Classic, independent toggles, saved custom choices and normal HUD
  colors. Reselect built-in presets to apply their revised settings.
- Validate native Ultimate Doom/Doom II GPU regressions, filtered checker/alpha
  probes, HDR highlight contrast, preset restoration and final build 104 visuals.
  Smoother sampling costs additional GPU time; crowded-combat performance and
  the user's exact reported viewpoint remain unverified.

## 0.8.0 · Build 102 — HDR, volumetric lighting and presets

- Add optional HDR/EDR output with a floating-point scene, extended highlights,
  live display-headroom mapping and 2×/4×/8× peak controls. Preserve standard-white
  HUD/weapon art and exact Classic restoration when HDR/effects are disabled.
- Add independent volumetric lighting and four density choices. Existing lights
  scatter through haze bounded by raster depth; world geometry blocks shadowed
  sources. Use twelve samples at quarter resolution and four nearest lights.
- Add separate graphics presets (resolution/frame cap) and effects presets:
  Classic, Enhanced, Atmospheric and HDR Showcase. Keep individual switches and
  save/apply one custom effects setup. Effects launch Classic; graphics settings
  and explicitly saved custom setups persist.
- Remove the unused macOS Show Tab Bar / Show All Tabs commands by disabling
  automatic window tabbing. Include new effects in diagnostics and benchmark locks.
- Validate Ultimate Doom and Doom II GPU suites, opaque-partition scattering,
  linear EDR output and headroom limits, HUD colors, toggles, custom/graphics
  presets, resize, save/load, map replacement, shutdown and the 48 ceiling captures.
  Inspect version 0.8.0 build 102 with HDR Showcase in a separate native preview.
- Haze is a bounded additive approximation; fullbright world sprites can gain HDR
  highlights. Other displays/GPUs, physical peak luminance and sustained crowded
  combat remain unmeasured. System brightness is unchanged.

## 0.7.0 · Build 100 — Connected lighting and particles

- Add separate Sprite Lighting, Emissive Surface Lighting, Soft Shadows and
  Embers & Projectile Trails switches under View → More Metal Effects. All
  start off and remain independent of existing AO, light and bloom controls.
- Let monsters and pickups receive colored lights and world occlusion while
  preserving fullbright frames, invisibility, weapons and the HUD. Sprites
  remain billboards and do not cast shadows.
- Light neighboring geometry from one-sided lamp, computer and liquid surface
  patches. Subdivide large surfaces for local coverage, update moving geometry,
  and reserve up to four patches within the shared 16-light budget.
- Soften enabled shadows with four fixed samples. Draw up to 128 torch embers
  and projectile sparks from authoritative game time and velocity; pause cleanly
  and restore without extra save data. Embers rise from torch flames.
- Pass native Ultimate Doom/Doom II GPU comparisons, analytic penumbra/emission
  tests, real monster reception and rocket trails, independent toggles, budgets,
  power-ups, resize, save/load, map transitions and shutdown. Preserve the 48
  ceiling captures, level-stat tests and diagnostics; inspect native build 100.
- Surface illumination uses bounded point approximations, soft shadows can show
  sampling steps, and trails approximate recent motion without particle collision
  or lingering impact smoke. Other GPUs and sustained crowded combat remain untested.

## 0.6.0 · Build 96 — Independent scene effects

- Add View → More Metal Effects with separate torch/lamp lighting, projectile
  lighting, muzzle-flash lighting, gameplay light shadows, emissive surfaces and
  bloom switches. All start off; existing AO/test-light controls stay independent.
- Follow real actors and weapon flash timing. Colored lights illuminate world
  surfaces with a shared 16-light budget; optional hard shadows respect walls,
  moving doors and grille alpha. Flicker pauses with game time.
- Make bright lamp/liquid/fire texels and colored computer-panel pixels glow.
  Add restrained world-only LDR bloom before drawing the weapon, damage tint and
  HUD. Preserve power-up colormaps, invisibility, stats and secret notifications.
- Keep session choices through map/save loads, include every switch in diagnostics
  and benchmark identity, and lock them during benchmarks. Turning effects off
  restores classic pixels; resizing safely replaces bloom textures.
- Pass Ultimate Doom and Doom II native GPU checks, real pistol flash/expiry,
  individual/combined toggles, HUD isolation, resize, power-ups, save/load, map
  changes and shutdown. Pass the existing 48 ceiling captures and level-stat
  tests; inspect 0.6.0 build 96's native controls and combined effects on M5 Pro.
- Lights/shadows affect world geometry; billboard sprites do not receive or cast
  them. Material emission is selective by name/color, not indirect illumination.
  Bloom is LDR. Other GPUs and sustained crowded-scene performance remain untested.

## 0.5.0 · Build 94 — Moving light and ray-traced shadows

- Add an optional amber light orbiting just ahead of the player, with a separate
  Test Light Shadows comparison toggle. Its eight-second motion follows game
  time and pauses with gameplay. Both lighting effects remain off at launch.
- Cast hard shadows from world geometry and masked grille bars using finite rays
  toward the light. Share AO's ray mesh while keeping effects independently
  switchable; light motion and shadow toggles do not rebuild geometry.
- Preserve sector lighting, fixed-colormap power-ups, sprites, weapon/HUD and
  stats/secret notifications. Remember choices within a session across map/save
  loads; include them in diagnostics and benchmark identity.
- Validate analytic blocker/mask/falloff cases, native Doom/Doom II GPU rendering,
  motion/pause, exact classic restoration, visible original-room shadows, moving
  doors, save/load, map replacement and shutdown; verify native build 94 controls.
- This is one test light. Sprite lighting/shadows, torch/projectile lights,
  emissive surfaces and bloom are not included. GPU samples use validation and
  readback; sustained gameplay performance and other GPUs remain untested.

## 0.4.0 · Build 93 — Integrate main into Metal experiments

- Rebase the AO, masked-grille and ceiling-seam work onto main commit `771625e`,
  retaining compact time/kills/items/secrets counters, optional par time, secret
  notifications and all existing HUD/AO controls.
- Keep the current 0.4.0 feature release and continue above main's build 92.
  No additional lighting effect is introduced by this integration.
- Validate level stats/secret timing and saves, the AO/48-view ceiling GPU
  regression, and the combined HUD/View menu in native build 93.

## 0.4.0 · Build 92 — Level stats feature release

- Bump the minor version for the new compact level stats, whole-second clock,
  optional par time and secret notifications introduced in build 91.
- Synchronize current version/install/release documentation and record the
  versioning rule in AGENTS.md: minor for features, patch for fixes, independent
  of the build counter; intermediate release refinements keep the same version.
- Verify the bundled and running app report 0.4.0, build 92. Gameplay code is
  unchanged from the validated build 91; no publishing or notarization performed.

## 0.3.0 · Build 91 — Level stats and secret notifications

- Add compact, color-coded live kills/items/secrets counters and a whole-second
  level clock using the original WAD font. Reduce the overlay size after visual
  review and remove distracting subsecond updates.
- Announce newly discovered secrets for three seconds of game time, independently
  of pickup messages. Restore saved counts without replaying notifications.
- Add remembered Level Stats, Par Time and Secret Notifications controls in
  View and Options → HUD. Stats/notifications default on; par defaults off.
- Show built-in campaign par times, turn par gold when reached, and show N/A for
  maps without defined pars. Hide the overlay during title demos and endings.
- Validate engine counts, time, saves, transitions, secret notice timing and
  Doom II par coverage; verify the HUD and controls in the running app.

## 0.3.0 · Build 87 — Close ceiling seams

- Fix the bright slit in E1M1's zigzag-room ceiling, visible with classic rendering
  as well as maximum AO. Clip flats to original linedefs instead of rounded BSP
  seg endpoints, keep precise intersections and match shared flat/wall edge vertices.
- Add a rounded-segment geometry fixture and 24 ceiling viewpoints rendered with
  AO disabled and at 100% strength/96-unit radius. Preserve texture alignment,
  sector lighting, moving-door updates and existing AO controls.
- Validate all 68 Ultimate Doom/Doom II geometry/art maps, focused GPU suites
  and the native build 87 ceiling view. Shared edges add triangles; a sustained
  gameplay performance comparison has not been run.

## 0.3.0 · Build 86 — AO controls and transparent grilles

- Add per-session View controls for AO strength (0–100%) and radius (16–96 Doom
  units), preserving the previous 50%/48-unit defaults and classic launch mode.
- Let grille bars and other masked world textures cast occlusion while rays
  pass through transparent pixels. Match texture wrapping, alpha cutoff and
  animation; avoid geometry rebuilds for control, UV-only and mask-only changes.
- Record both controls in diagnostics and benchmark comparisons. Validate native
  menus plus GPU alpha rays, control effects, unchanged HUD/classic restoration,
  moving doors, map replacement and shutdown on Doom/Doom II and a grille fixture.
- Fix validate-ao crashes from its window-focus assertion. Drive the door test
  without keyboard focus and report test/load failures as terminal errors with
  nonzero exits, instead of assertion crash reports or unattended modal alerts.

## 0.3.0 · Build 84 — Experimental ray-traced ambient occlusion

- Add View → Ray-Traced Ambient Occlusion (Experimental), off at launch, with
  Metal capability checks and classic-rendering fallback on failure.
- Add subtle nearby shading to world surfaces using eight rays per fragment;
  update ray geometry for moving sectors and map/save loads. Preserve classic
  sector lighting, power-up fullbright effects, sprite/weapon shading and HUD.
- Omit sky, billboard sprites and transparent materials as occluders in this
  first version; masked materials do not become solid ray blockers.
- Include AO state in diagnostics and benchmark comparisons. Document the
  experiment, its visual limits and GPU measurement workflow.
- Validate actual GPU pixels, exact restoration when disabled, unchanged HUD,
  paused stability in Doom/Doom II, a moving Ultimate Doom door, map replacement
  and shutdown;
  retain all 36 Ultimate Doom geometry/art regression passes. Paired build 83
  DEMO1 runs stay near the 120 FPS cap; final build 84 hardens encoder failure.

## 0.3.0 — Next-chat handoff (app build 81 unchanged)

- Add handoff.md with the current implementation/release state, validation limits,
  workflow and proposed compatibility, rendering and in-window picker branches.
- No experimental branch has been selected or created; no app rebuild required.

## 0.3.0 — Publishing helper (app build 81 unchanged)

- Add scripts/publish.sh with a read-only dry run, a clean-main requirement and
  version lookup from Info.plist. Push main alone for an existing version, or
  atomically push main with a new annotated version tag to trigger GitHub Actions.
- Reject older versions and conflicting tags; never force-push or auto-commit.
- Document the routine publishing command and validate against disposable local
  remotes, including first release, unchanged/bumped versions, dirty checkouts,
  conflicting tags, detached/other branches and atomic push rejection.
- No GitHub push or hosted release was performed as part of this change.

## 0.3.0 · Build 81 — WAD picker feature preview

- Bump the minor version for the new folder/drop WAD picker, game switching and
  optional bottom status bar introduced since the 0.2.1 patch.
- Align both picker button rows and drop areas, with matching summary rows for
  the selected main game and extra-WAD count.
- Refresh current version references and release notes. Verify the balanced
  layout and 0.3.0 version in the running build 81 app.

## 0.2.1 · Build 80 — Game titles in the WAD picker

- Show recognized game names and KEX edition labels above filenames in both
  picker columns. Recognize SIGIL and declared GAMECONF add-on titles; retain
  filenames for unknown add-ons and full paths in tooltips.
- Cache names during picker use and update the player guide.
- Verify all four rerelease IWAD names and SIGIL in the native build 80 picker;
  the WAD picker drop/load-order regression passes with the new rows.

## 0.2.1 · Build 79 — Folder and drag-and-drop WAD picker

- Replace the two-step file/load-order flow with a single two-column picker:
  main IWAD folder list on the left, ordered extra PWADs on the right.
- Remember the last folder and accept files or folders in separate drop areas.
  Filter by WAD signature, reject files on the wrong side, and normalize paths
  to prevent duplicate add-ons. Keep move/remove controls and current-stack review.
- Validate build 79 with the rerelease folder, Doom + SIGIL launch, persisted
  folder selection, current-stack review and cancellation. Add a WAD-free native
  regression covering file-URL drop callbacks, filtering, rejection, duplicates,
  ordering and Play handoff. Finder mouse-drag interaction was not manually tested.

## 0.2.1 · Build 77 — Optional bottom status bar

- Remove the top toolbar and place the map picker beside the map name in the
  bottom status bar. Keep Open WAD in the File menu and empty startup screen.
- Add View → Show Status Bar, visible by default and remembered across launches.
  Hiding the bar expands the game view without hiding the classic Doom HUD.
- Update the player guide. Validate the native layout, E1M1 to E1M2 map selection,
  hide/show behavior, classic HUD visibility, preference persistence after relaunch,
  and the empty startup screen in build 77.

## 0.2.1 · Build 76 — Switch WADs during play

- Allow Open WAD during a running game, including selection of an ordered add-on stack.
- Start the chosen stack in a fresh app instance and close the old instance only
  after a successful load acknowledgement. Preserve the current game on cancellation
  or failure, and explain that players should save before switching.
- Update the player guide and engine architecture notes.
- Validate the native build, chooser cancellation, an Ultimate Doom E1M1 to Doom II
  switch, one remaining app process, and malformed-WAD rejection preserving Doom II.
  The launch-failure and timeout paths have not been induced in native testing.

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
