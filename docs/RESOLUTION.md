# World resolution and native presentation

Version 0.9.0 keeps the Metal drawable at the window's display pixel size.
Esc → Options → Display offers 50/75/100/150/200% World scale and an Upscaling
choice. View → Graphics Presets also adds Sharp (150%, 120 FPS) and Supersampled
(200%, 60 FPS). Resolution is independent of effects presets.

- 100% uses direct native rendering.
- 50/75% renders the world at lower resolution. MetalFX Spatial is optional and
  device-gated; Nearest preserves pixel sampling without reconstruction.
- 150/200% renders more world pixels and downsamples with four filtered taps.
  This costs GPU time and memory, and can soften pixel artwork in the world.

The world, sprites, depth, AO, lighting, particles, haze and bloom render first.
Scaling completes before the weapon, palette tint and original HUD; menus,
intermissions and native stats remain at output resolution. Camera projection uses
the output world aspect so HUD integer-size steps do not change the field of view
when world scale changes. Invisibility retains world and native weapon snapshots.

SDR MetalFX uses perceptual color. HDR converts the extended palette scene to
linear float input, uses MetalFX HDR processing, then returns to palette encoding
before native weapon/HUD composition and the existing EDR display mapping.
Supersampling retains the extended float scene. Resolution resources rebuild on
size, format or mode changes and release on returning to native rendering. Failed
allocation restores native scale and reports the error. No temporal history,
motion vectors, temporal upscaling or frame generation is implemented.

This follows Apple's [spatial scaler API](https://developer.apple.com/documentation/metalfx/mtlfxspatialscaler)
and [color processing modes](https://developer.apple.com/documentation/metalfx/mtlfxspatialscalercolorprocessingmode).

## HUD style

Esc → Options → HUD → HUD style, or View → HUD Style, selects Classic or Minimal.
The choice is remembered. Classic remains the default, with the complete original
bar. Minimal draws health and armor at bottom left, current ammo at bottom right,
and owned key cards/skulls above ammo. WAD numbers and labels have black pixel
shadows for readability, with no opaque background. Melee weapons omit ammo.

Minimal renders the world through the bottom edge and composes its artwork after
world scaling and palette tints, at native output resolution and standard white
in HDR. Its weapon is bottom-anchored on a 200-line canvas; changing HUD size does
not change weapon scale or world projection. Changing style adjusts the world
viewport. Both styles share the size setting below; stats and menus are independent.

### Optional Doomguy portrait

Options → HUD → Doomguy portrait and View → Doomguy Portrait in Minimal HUD toggle
an animated face beside the health readout. This preference starts off and is
remembered. The face uses the engine's original expressions, including pain, glances,
god mode and death. It scales with the Minimal HUD and has a pixel shadow with no
background panel. Turning it off restores the existing Minimal layout exactly.
Classic always retains its original face, regardless of this preference.

## Status bar size

Esc → Options → HUD → Status bar size, or View → HUD Status Bar Size, offers
25%, 50%, 75% and 100% of the original width-based size. Start with 50% or 75% if
the health/ammo/armor bar feels too large in fullscreen. The choice persists;
100% is the original/default layout. Artwork never drops below one output pixel
per source pixel, so the smallest choices can coincide in small windows.

The entire original status bar stays centered along the bottom, including KEX's
wide background and aligned foreground widgets. Shrinking it returns the unused
height to the world viewport. It remains composed at output resolution, independent
of MetalFX/supersampling; level counters, native window chrome and menus have their
own existing sizing. The same preference applies in windowed and fullscreen play.

## Measurements and checks

M5 Pro, fixed E1M1 camera, 2200×1520 output, Medium HDR, 32 GPU command samples per
mode, Metal API validation disabled:

| World scale | Median GPU duration | p95 |
| --- | --- | --- |
| 100% native | 5.672 ms | 7.076 ms |
| 75% MetalFX | 4.571 ms | 6.094 ms |
| 50% MetalFX | 3.119 ms | 5.451 ms |

These are one local paused-scene sample, not sustained gameplay FPS or universal
speedups. With a simpler 1280×800 Medium scene and API validation enabled, MetalFX
was slower than native (2.54–2.84 ms vs 1.78 ms); its overhead can dominate.

`AO_RESOLUTION=1 bash scripts/test-ambient-occlusion.sh IWAD` verifies exact native
HUD equality at every scale, stable paused results, exact Classic restoration,
HDR/SDR transitions, bounded finite HDR, resize, effects and weapon invisibility.
`AO_PROFILE=1 AO_RESOLUTION_PROFILE=1 AO_VALIDATION_LAYER=0` runs the larger profile.
Other GPUs, physical HDR brightness, and moving between displays with different
backing scales/headroom still need live testing.
