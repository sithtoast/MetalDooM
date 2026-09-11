# MetalDooM player guide

See [INSTALL.md](INSTALL.md) for installation and [BUG_REPORT.md](BUG_REPORT.md) for bug reports.

## Music playback

**Audio → Classic OPL** (default) uses Chocolate Doom's Doom 1.9 OPL2/Sound
Blaster instrument mapping, the loaded WAD's GENMIDI bank and the pinned Nuked
OPL chip emulator. **Audio → Apple MIDI** uses Apple's General MIDI instruments.
The selection persists and switching restarts the current track. Neither is
labelled as a recreation of the original Macintosh QuickTime instrument bank.

OPL scores are rendered into temporary 44.1 kHz stereo PCM before native Core
Audio playback. Loading/switching may briefly pause while a score renders. Files
are removed when their player is released; title and level playback remain
independent. Tracks over ten minutes or missing/invalid GENMIDI are rejected;
choose Apple MIDI for those scores. Volume, mute, pause/resume and looping work
with both backends. No instrument banks or game music are bundled.

## Controls

| Input | Action |
| --- | --- |
| W / S or up / down | Forward / backward |
| A / D | Strafe |
| Left / right | Turn |
| Shift | Run |
| E / Space | Use a door or switch; restart after death; advance intermission/story |
| Click the viewport | Capture mouse; subsequent clicks/hold fire |
| F | Fire (also works without mouse capture) |
| 1–7 | Classic weapon slots; 1 fist/chainsaw, 2 pistol, 3 shotgun, etc. |
| Escape | Pause/open menu; back from submenus; resume from main menu |
| R | Restart map with fresh starting inventory |
| Return / Enter | Intermission: skip counting, show destination, then skip the four-second map display |
| Command-Shift-E | Toggle Classic / Medium effects |
| Command-O | Open or switch IWAD and optional add-ons |
| Command-S / Command-L | Save Game… / Load Game… |
| Command-Shift-S / Command-Shift-L | Quick Save / Quick Load for this WAD |

Mouse capture releases and simulation/audio pause on focus loss. Aim uses classic
Doom horizontal targeting and vertical autoaim; looking up/down is cosmetic.
Weapon selection requires ownership. After death, a fresh E, Space or Enter press
restarts with starting inventory after a short delay. Escape selects Load Game in
the pause menu. R remains an immediate fresh-inventory restart.

Use **File → Open WAD…** during a game to choose another base WAD and add-ons.
Save first if you want to keep your progress. Selecting Play opens the new game
in a fresh app instance automatically; the previous instance closes after the
new WAD loads successfully. Cancel leaves your current game available.

## Choosing WADs

**Open WAD…** opens a two-column picker:

- **Main game:** choose a folder to list its main IWADs, select one, or use
  Choose IWAD. You can also drop a main WAD or folder into the left drop area.
  Recognized games show their game title and edition above the filename.
  SIGIL and add-ons with a declared GAMECONF title also show their names; unknown
  add-ons keep their filenames. The last folder is remembered. Folder browsing
  scans that folder only.
- **Extra WADs:** add optional PWADs using Add PWAD or the right drop area.
  Dropping a folder adds its PWADs in filename order. Move Up, Move Down and
  Remove let you adjust the stack; later files take priority. Duplicate files
  are ignored, and main IWADs cannot be added as extras.

For SIGIL, select your Ultimate Doom IWAD on the left and add `sigil.wad` on the
right. Review compatibility and load order before Play; listing a WAD is not a
full compatibility check. Reopening the picker during play shows the current
stack. Choosing a different main game keeps the extras visible for your review.
The original WAD files are never moved or modified.

## Window layout

The map picker sits beside the map name in the bottom status bar. Selecting a map
starts it with fresh inventory; save your progress first.

**View → Show Status Bar** shows or hides the bottom map picker, status text and
control hints. It is visible by default, and your choice is remembered across
launches and WAD switches. Hiding it gives that space to the game view. The classic
Doom HUD (face, health, ammo and armor) remains visible independently.

Open WAD remains available through **File → Open WAD…** or **Command-O**, and on
the empty startup screen.

## Level stats and secrets

The upper-left overlay shows **TIME** as minutes:seconds and **K / I / S**
as kills, items and secrets found out of each level's totals. Completed nonempty
counters turn green. Items follow Doom's intermission rules: health/armor bonuses
and other counted items count; ordinary ammo and weapon pickups do not all count.
The clock follows the 35 Hz game simulation, pauses with the game, resets on a new
level or restart, and restores from saves.

A gold **SECRET FOUND!** notice appears for three seconds of game time when you
enter a new secret. Pickup messages have their own space below the stats. Loading
a save does not announce secrets already discovered.

Use **Options → HUD** or the **View** menu to toggle Level Stats, Par Time and
Secret Notifications. Stats and notifications default to on; par time defaults to
off. All three choices are remembered. Par time appears beside TIME when stats
are enabled and turns gold when reached. It uses the built-in campaign reference
(Doom episodes I–III, Doom II/Final Doom, or SIGIL); custom maps retain that slot's
reference, and maps without a defined par, including Doom episode IV, show N/A.
The overlay is hidden during title demos, intermissions and finales.

## Saving and loading

Use **File → Save Game…** to choose a `.mdsave` file, or **Quick Save** for one
persistent slot per WAD. Quick saves live under
`~/Library/Application Support/MetalDooM/Saves/`, keyed by the WAD's SHA-256 digest.
Open the same WAD before loading; renaming an unchanged WAD does not invalidate saves.
Quick Save replaces that WAD's previous quick save. Named saves let you keep several.

Save while alive during a level. You can load from another map, after death, or at
intermission. Loading restores player/view, inventory, pickups and enemies, world
and moving-sector state, random state, and pending switch resets. The original
archive clears enemy target/tracer pointers; enemies reacquire targets as in
classic Doom saves. Some world coordinates use the original archive's integer
precision. This is not a frame-exact replay format.

Versioned containers check WAD identity and payload integrity before entering the
native loader. Atomic replacement preserves the previous file if saving fails.
Only MetalDooM `.mdsave` files are supported; arbitrary `.dsg` imports and guarantees
of compatibility with future format versions are outside this first implementation.
The original engine decoder has not been hardened for deliberately crafted payloads.

## Pause menu and options

Escape pauses simulation, intermission timing, and audio. The menu supports mouse
buttons and arrows/Enter/Space/Tab. Left/right adjusts options; original Doom sound
cues accompany navigation even while gameplay audio is paused. New Game
offers the episodes present in the WAD and all five original difficulty settings.
Restart retains difficulty, and loading restores the difficulty saved in the slot.

Save Game and Load Game expose six named slots per WAD, separate from Quick Save.
Choose a save slot, type its bitmap name (up to 24 characters within the border),
then press Enter to save or Escape to cancel. Backspace edits the name. Saving to
an occupied slot replaces it. Earlier saves without names remain compatible. File menu import/export and
quick-save shortcuts are still available.

Options offers window sizes from 960×720 to 1920×1080 macOS points (clamped to
the screen), fullscreen, 50/75/100/150/200% world render scale, and 35/60/120 FPS limits.
The pixel dimensions shown reflect the actual drawable, including Retina scaling.
Fullscreen uses the current desktop display mode; it does not switch the monitor's
resolution. Window preset, render scale, frame limit, music enablement, and separate
music/effects volume levels persist.

Launch the app by opening `~/Dev/MetalDooM/build/MetalDooM.app` in Finder. Save and
quit an older running build first. If no WAD is open, choose Open WAD and select
your IWAD; for example `~/Downloads/The_Ultimate_Doom/DOOM.WAD`.

## Experimental lighting

In View, enable **Moving Test Light (Experimental)** for one amber light that
orbits a point just ahead of you. **Test Light Shadows** compares lighting with
and without world shadows; it defaults on. The light's eight-second motion follows
game time, so Escape pauses it. It can be used with or without ray-traced AO.
Both effects start off at launch and require Metal ray tracing in render shaders.

Walls, floors, ceilings and grille bars block the light; transparent grille pixels
let it through. Sprite light reception has its own switch; the weapon and HUD
keep their original lighting. This
test light has no visible orb; the additional effects below are independent.
It follows your position and can become occluded when its orbit crosses a wall.
Light/shadow choices last for the session and survive map/save loads.

**View → More Metal Effects** offers independent switches:

- **Torch & Lamp Lights**: colored illumination from torches, candles, lamps and burning barrels.
- **Projectile Lights**: moving illumination from rockets, plasma, BFG shots and monster fireballs.
- **Muzzle Flash Light**: brief illumination when your weapon flashes.
- **Gameplay Light Shadows**: world shadows for those three light categories.
- **Emissive Surfaces**: glowing lamp, liquid, fire and colored computer-panel pixels.
- **Bloom**: a subtle halo around bright world highlights.
- **Sprite Lighting**: monsters and pickups receive existing colored lights.
- **Emissive Surface Lighting**: lamp, liquid and computer surfaces illuminate nearby geometry.
- **Soft Shadows**: soften the edges of enabled world shadows.
- **Smooth World Textures**: reduce distant texture shimmer and soften wall/floor texels; sprites and HUD stay crisp.
- **Embers & Projectile Trails**: drifting torch embers and sparks behind moving projectiles.

All start off and can be combined with AO and the test light. The new lights
require ray tracing; self-emission, bloom and particles do not. Up to 16 nearby lights illuminate
world surfaces and optionally sprites. Sprites do not cast shadows. Bloom is
applied before the weapon/HUD, keeping them crisp. Emissive Surfaces controls the
visible glow; Emissive Surface Lighting separately controls illumination of
neighboring surfaces.
Soft Shadows needs an enabled shadow-casting source. Particles work independently
of lighting and follow game time. Choices last until you quit.

## Developer console

Press backtick/tilde (`~`) to open the console; Escape or the same key closes it.
Gameplay pauses while it is open. Up/Down recalls command history; Tab completes
command names. Output and history remain available until the app exits.

Type `help` for commands. Examples:

```text
maps
map E1M2
status
volume 0.7
musicvolume 0.5
music on
render_scale 75
fps 60
fullscreen on
```

`map` and `restart` start a fresh level, so save progress first. Map names must
exist in the loaded WAD. `status` reports the game, map, player state, GPU, render
resolution and audio settings. `clear` clears output; `close` returns to the game
or the paused menu. The console runs only these game commands, never shell code.
Settings use the same persistence as the Options menu. Window fullscreen remains
a macOS window state. Parser validation: `bash scripts/test-console.sh`.

## Title screen, demos and cheats

Opening a WAD shows its original `TITLEPIC` with title music before the menu.
Leave it unattended for about 11 seconds to start an embedded demo. Title/credit
pages alternate with DEMO1–3 (also DEMO4 in Ultimate Doom). Press a key or click to
open the menu; Escape resumes the attract sequence. New Game or loading a save
starts normal play. File → Return to Title Screen returns to the sequence; save
current progress first. `-warp` launches directly into gameplay.

Playback supports bounded, single-player Doom 1.8/1.9 recordings from the loaded WAD,
using their recorded commands with the original gameplay thinkers. Multiplayer,
longtics, external demo files and demo recording are not supported. Unsupported or
missing demos are skipped. This does not establish compatibility with every vanilla
recording or its original executable. Playback pauses for menus, console and focus loss.

During gameplay, type these codes without opening the console:

| Code | Effect |
|---|---|
| `iddqd` | Toggle god mode |
| `idclip` / `idspispopd` | Toggle noclip |
| `idfa` / `idkfa` | Weapons, ammo and armor; `idkfa` also gives keys |
| `idclev12` | Warp to E1M2 (MAP12 for Doom II) |
| `idbeholdv/s/i/r/a/l` | Use one suffix: invulnerability, berserk, invisibility, suit, map, light |
| `idchoppers` | Give chainsaw |

Console aliases are `god`, `noclip`, `give all`, and `give ammo`; the classic codes
except `idclev` also work there (use `map` to warp). Cheats are disabled in attract
mode and on Nightmare. Weapon grants respect the loaded game's available weapons.
`idbeholda` reveals otherwise unexplored automap walls in gray. `idmus` and `iddt`
are not connected. Validate with `bash scripts/test-cheats-demos.sh /path/to/DOOM.WAD`.

## Automap and power-up presentation

Tab opens/closes the north-up automap. Gameplay continues: WASD moves, arrows pan,
+/- (or the mouse wheel) zoom, F toggles player follow, and 0 fits the level. Escape
closes the map before opening the menu. The HUD remains visible. Red walls, brown
floor changes, yellow ceiling changes and green teleport lines distinguish features;
unexplored map-power lines appear gray. Hidden lines stay hidden and secret doors
look like walls. Explored flags are retained by saves. Visibility uses original
sector sight tests around forward-facing line midpoints, an approximation of Doom's
software-renderer discovery behavior.

Invulnerability uses inverse grayscale, night vision removes scene dimming, the
radiation suit adds green, and berserk adds a fading red tint. Expiry blinking follows
the engine's timers. Spectres and the invisible weapon sample a displaced, darkened
scene through their sprite masks; they retain depth occlusion. These are Metal
approximations; exact COLORMAP/palette output and software fuzz patterns differ.

## SIGIL and WAD load order

Open WAD… selects the base IWAD, then shows a load-order dialog. Add PWAD… adds
files; Move Up / Move Down changes priority. Play starts the chosen stack. The
files remain separate and are never modified. Sprites and flats use merged
namespaces with exact-name overrides; maps must supply complete classic map blocks.
This does not promise compatibility with every mod or sprite-rotation replacement.

For the supplied standard SIGIL v1.23, select Ultimate Doom's DOOM.WAD as the base
and SIGIL_V1_23.wad as the add-on. New Game lists SIGIL as Episode 5 alongside the
original four episodes. Its nine map names, MIDI music, SKY5, SIGIL intermission
art, E5M6 secret exit/E5M9 return and story/credit ending are supported.

```sh
open build/MetalDooM.app --args \
  -iwad "$HOME/Downloads/The_Ultimate_Doom/DOOM.WAD" \
  -file "$HOME/Downloads/SIGIL_V1_23/SIGIL_V1_23.wad"
bash scripts/test-stack.sh "$HOME/Downloads/The_Ultimate_Doom/DOOM.WAD" \
  "$HOME/Downloads/SIGIL_V1_23/SIGIL_V1_23.wad"
```

Saves and quick slots identify every file's contents and the load order. A save
from a different stack is rejected. Existing single-IWAD saves retain their
identity and format. Save destinations cannot overwrite any file in the stack.

Doom II now shows stats before story breaks after MAP06, MAP11, MAP20, MAP30 and
the secret exits from MAP15/MAP31. Enter/Use reveals the text, then continues.
MAP30 proceeds to the original 17-member cast: Fire/Enter plays each death;
Escape opens the menu. Cast attacks, deaths and sounds use the upstream state machine.

## Final Doom

Open `tnt.wad` or `plutonia.wad` as the base IWAD, with no add-on required.
MetalDooM identifies the campaign from its base resource set, including when the
file is renamed, and selects the original Final Doom engine behavior. Add-on
resources do not change the base campaign. The rerelease IWADs supplied for this
milestone are the validated versions; other releases still need regression runs.

Both campaigns have their own 32 map names, menu/title artwork, music and skies,
six story breaks, secret exits and cast ending. Music uses each IWAD's original
Doom II-style track slots; skies change at MAP12 and MAP21. Gameplay uses the
original Final Doom executable profile, including its teleporter-height quirk
(the rerelease also requests this through `comp_finaldoomteleport`).

```sh
open build/MetalDooM.app --args -iwad /path/to/tnt.wad
open build/MetalDooM.app --args -iwad /path/to/plutonia.wad
bash scripts/test-final-doom.sh /path/to/tnt.wad /path/to/plutonia.wad
```

Quit before switching base games. Saves identify IWAD contents, so TNT and
Plutonia saves cannot be mixed, and renaming an identical IWAD preserves saves.

This is dedicated Final Doom support, not general GAMECONF/UMAPINFO or DeHackEd
support. Legacy of Rust/ID24 and Doom 64
remain future milestones.


## Graphics presets, HDR and volumetric lighting

Open **Esc → Options → Effects** to browse presets in-game. Arrow keys or mouse
hover change the description; Enter or a click applies the highlighted preset.
The page names the current setup, including Custom, and explains unavailable
choices. Esc returns to Options. Resolution, frame cap and saved custom setups
are preserved. Presets are also available under **View → Effects Presets**.

| Preset | Appearance |
| --- | --- |
| Classic | Original lighting and textures; all added effects and HDR off. |
| Medium | Subtle AO, dynamic lights, soft shadows, emissive glow, bloom, sprite lighting and smooth world textures. |
| High | Medium plus surface lighting, particles, light volumetric haze and a wider AO radius. |
| Medium HDR | High's effects with restrained HDR highlights, capped at up to 4× standard white. |
| Ludicrous | All effects, High ray quality, stronger AO/lights/bloom, denser haze and up to 8× HDR highlights. Highest GPU cost. |

Build 114 renames Enhanced to Medium, Atmospheric to High and HDR Showcase to
Medium HDR without changing their settings. Medium HDR describes the restrained
HDR presentation; it includes High's effects. HDR presets require a compatible
display. All presets except Ludicrous use Balanced ray quality.

Start with **View → Effects Presets → Medium HDR** on a compatible HDR display.
It enables the lighting effects, bloom, ambient occlusion and illuminated haze.
**HDR Highlight Peak** requests up to 2×, 4× or 8× standard white; actual brightness
adapts to the display's available headroom. The HUD and weapon stay at normal
brightness. HDR output can be toggled separately, and Classic returns to the
original presentation. Screenshots may not reproduce the screen's HDR brightness.

**Volumetric Lighting** is a separate switch under **More Metal Effects**. It
needs light sources such as torch, projectile, surface or test lights; select
**Volumetric Density** to adjust the haze. Try High for all effects in SDR,
or Medium for fewer effects. Every individual switch remains available.

**Save Current as Custom** remembers one effects setup; **Apply Saved Custom**
restores it. Effects start in Classic on each launch. Graphics presets separately
set resolution and frame cap: Performance (50%/120 FPS), Balanced (75%/120),
Native (100%/120), or Quiet (75%/60). These graphics settings persist. Frame caps
are targets, not guaranteed performance with every effect enabled.

The previous Show Tab Bar and Show All Tabs items were automatic macOS window
commands. MetalDooM doesn't use window tabs, so those commands are now disabled.


Build 104 refines Enhanced and HDR Showcase with gentler AO, softer shadows,
reduced bloom and smoother world textures. Showcase uses lighter, steadier haze.
HDR peak now limits brightness without exaggerating near-white texture contrast.
Reselect the preset after updating; previously saved custom choices are preserved.
Turn off **Smooth World Textures** if you prefer the original blocky world texels.


For lower frame intervals, use **View → Ray Quality → Balanced** (the launch default and the choice in
all presets except Ludicrous). **High** doubles AO, soft-shadow and haze sampling for
additional refinement at a higher GPU cost. Both retain smooth world textures
and steady haze. This setting is included when saving a custom effects preset;
older custom presets load with Balanced quality. Minimized or fully covered
windows stop rendering until visible again.


**View → Effects Presets → Ludicrous** restores an intentionally exaggerated
setup: all twelve effects, High ray quality (16 AO / 8 soft-shadow / 32 haze
samples), 50% AO at 48 units, Atmospheric haze, 200% added-light strength, 30% bloom,
1.5× fullbright world-sprite boost and an HDR ceiling of 8× standard white.
Expect a higher GPU cost than Medium HDR; it keeps your resolution and frame cap.
The actual highlight brightness still follows the display's live HDR headroom.

**Added Light Strength**, **Bloom Strength** and **HDR Fullbright Sprite Boost**
are separate View controls. The sprite boost only operates in HDR and leaves
weapon/HUD artwork and fixed-colormap power-ups at their normal brightness.
The existing effect switches still work independently. Select Medium HDR to return
to restrained settings, or Save Current as Custom to keep your own combination.
Ludicrous keeps smooth textures, steady sampling and the visibility optimizations.


Press **⌘⇧E (Command-Shift-E)**, or choose **View → Toggle Classic / Medium**,
to compare the original rendering with Medium in place. Any active effects
setup (including Medium HDR or Ludicrous) switches to Classic first; the next
press selects Medium. A brief message names the selected preset. Use Save
Current as Custom before comparing if you want to restore a manually tuned setup.
The shortcut leaves resolution, frame cap, saved custom presets and game progress
unchanged. It is disabled while benchmarking and does not activate the E/Use key.

## Resolution and additional rerelease campaigns

World scale changes world rendering while the HUD, weapon and menus stay at native
display resolution. Below 100%, choose optional MetalFX Spatial or Nearest; above
100%, supersampling can smooth edges at greater GPU cost. See [resolution](docs/RESOLUTION.md).

The validated KEX editions of No Rest for the Living and Master Levels use Doom II;
SIGIL II uses Ultimate Doom. Add one campaign PWAD in Open WAD. See
[campaign support](docs/KEX_SUPPORT.md) for file editions and remaining ID24 work.
