# Rust palette effects — 0.10.0 build 151

Current build164 adds the adapters and updated packets documented in
[EXTENDED_PRESENTATION.md](EXTENDED_PRESENTATION.md). The milestone layout and
validation details below are retained as implementation history.

The explicit Rust preview now shows damage and pickup flashes, berserk red,
radiation-suit green, invulnerability and light amplification. The headless engine
uses its normal enabled palette option. MUI3/version 3 retains the 144-byte HUD
layout, replacing reserved words at offsets 136 and 140 with the selected PLAYPAL
palette and fixed COLORMAP index. Both are 0–255 and must exist in MBL3 resources.
Earlier UI versions reject. Completed/ending presentation selects zero for both.

Palette selection copies normal gameplay state without advancing timers or RNG:
damage takes precedence over bonus, then radiation protection. Berserk contributes
to damage redness. The engine selects the fixed colormap and its blinking phase.
Save/Load preserves these timers and the selected effects.

World, sky, actors and weapons apply a fixed colormap before translucent lookup.
Fixed maps enable full brightness. Native RGB shading still quantizes to the first
nearest base-palette entry by squared RGB distance; this does not claim software
lighting parity. Damage/bonus/suit palettes are applied after the HUD, covering the
whole game image using the original PLAYPAL colors. Palette zero bypasses the
final pass, restoring the exact unmodified frame. Classic rendering retains its
existing powerup path. Palette/colormap buffers are cached between frames.

Validation combines real engine pickup/damage fixtures (including saved future
tics), malformed resource and UI boundaries, exact native Metal palette/removal
and fixed-map oracles, fixed-map/translucency interaction, and actual Rust HUD
pixel probes. See VALIDATION.md for the final build and logs.
