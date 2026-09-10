# Testing MetalDooM on another Mac

## Get running

Use an Apple Silicon Mac running macOS 14 or later. Intel Macs are not supported.
Supply your own legally obtained Doom IWAD; this repository contains no game WADs.

For a source checkout, install Xcode command-line tools, then from the repository:

```sh
bash scripts/build.sh
open build/MetalDooM.app
```

The currently verified compiler is Xcode 27 beta's Swift 6.4 in Swift 5 mode;
older toolchains and macOS versions still need tester coverage. The local build is
ad-hoc signed, not a Developer ID signed/notarized release. No downloadable release
is published by these instructions.

Choose **Open WAD…**, select the base IWAD and any supported add-ons in load order,
then start a game. Supported campaign targets are Doom/Ultimate Doom, Doom II,
TNT: Evilution, The Plutonia Experiment and standard SIGIL Episode 5.
General MAPINFO/UMAPINFO/DeHackEd mods, SIGIL II, Legacy of Rust and Doom 64 are
not supported. See README.md for controls and compatibility details.

## Collect a useful bug report

1. Use **Diagnostics → Metal Performance HUD** to show Apple's graphics overlay.
   Toggle it again to hide it. It starts hidden on every launch and affects only
   MetalDooM when opened through Finder or `open`. No Xcode session or Terminal command is needed for the overlay.
2. Reproduce the issue, then choose **Diagnostics → Copy Diagnostic Report**.
3. Paste the report into a GitHub issue, along with reproduction steps, what you
   expected, what happened, and a screenshot/video if useful. Review before posting.
   The report includes WAD filenames and their order, not full paths or WAD data.
4. For a crash, include the corresponding MetalDooM crash report from macOS Console.
   Review it for personal paths before attaching it. Never attach commercial WADs.

The report includes version/build, macOS, Mac model/chip/GPU, RAM, drawable size,
render scale, display refresh, frame cap, recent renderer FPS and campaign/map.
Recent FPS is a short sample, not a repeatable benchmark. The HUD provides GPU and
frame timing; leave it off for ordinary play.

## Compare performance consistently

Use the same IWAD version, map, viewpoint, window/fullscreen size, render scale and
frame cap. Record whether the Mac is plugged in, Low Power Mode is enabled, and
which display is used. Allow loading to settle before taking screenshots.

A 60 FPS cap can hide differences between faster Macs. Frame cap and render scale
are adjustable in the game options (or console `fps 120`, `render_scale 100`).
There is currently no automated benchmark or session-log export.

## Gameplay checks

- Start a game, move/fire/use doors, switch weapons and collect items/keys.
- Verify HUD counters, face, keys and labels at normal and resized window sizes.
- Save/load, die/restart, switch maps and test secret exits and story transitions.
- Check music/sound, pause/resume, focus loss and mouse capture/release.
- Quit with a WAD loaded and separately close the window; report any crash.

Automated diagnostics checks (from the source checkout):

```sh
bash scripts/test-diagnostics.sh
bash scripts/test-diagnostics.sh -iwad /path/to/DOOM.WAD
bash scripts/test-diagnostics.sh -iwad /path/to/DOOM.WAD -file /path/to/sigil.wad
```

These tests create native windows and require a logged-in macOS GUI session.
Full campaign playthroughs and broad hardware testing remain outstanding.

### Direct executable launches

Finder and `open build/MetalDooM.app` apply the app-local HUD launch environment.
If you launch `Contents/MacOS/MetalDooM` directly from a debugger or shell, provide
`MTL_HUD_ENABLED=1` at process startup to make the toggle available. Changing this
after launch is too late on the tested macOS version. No global settings are used.
