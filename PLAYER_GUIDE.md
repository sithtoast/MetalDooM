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

## Window layout

The map picker sits beside the map name in the bottom status bar. Selecting a map
starts it with fresh inventory; save your progress first.

**View → Show Status Bar** shows or hides the bottom map picker, status text and
control hints. It is visible by default, and your choice is remembered across
launches and WAD switches. Hiding it gives that space to the game view. The classic
Doom HUD (face, health, ammo and armor) remains visible independently.

Open WAD remains available through **File → Open WAD…** or **Command-O**, and on
the empty startup screen.

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
the screen), fullscreen, 50/75/100% Metal render scale, and 35/60/120 FPS limits.
The pixel dimensions shown reflect the actual drawable, including Retina scaling.
Fullscreen uses the current desktop display mode; it does not switch the monitor's
resolution. Window preset, render scale, frame limit, music enablement, and separate
music/effects volume levels persist.

Launch the app by opening `~/Dev/MetalDooM/build/MetalDooM.app` in Finder. Save and
quit an older running build first. If no WAD is open, choose Open WAD and select
your IWAD; for example `~/Downloads/The_Ultimate_Doom/DOOM.WAD`.

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
support. Classic/enhanced mode selection, SIGIL II, Legacy of Rust/ID24 and Doom 64
remain future milestones.

