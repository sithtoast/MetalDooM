# Installing MetalDooM 0.10.0 β1

Requires an Apple Silicon Mac and macOS 14 or later.

Extract the release ZIP, drag MetalDooM.app to Applications, then open it.
The **0.10.0 β1 (build 165)** GitHub prerelease is Developer ID signed,
notarized by Apple and includes a stapled ticket. Keep the app bundle intact when
copying it. The release ZIP also includes installation/player guides and licenses.
Local source builds use ad-hoc signing; their signing status is separate.

Choose Open WAD… and supply your own Doom/Ultimate Doom, Doom II, TNT or Plutonia
IWAD. Standard SIGIL can be added as a PWAD with Ultimate Doom. No game data is
included. The validated rerelease nerve.wad and masterlevels.wad use Doom II;
sigil2.wad uses Ultimate Doom. Load one campaign add-on at a time. Use Open WAD
to change games. See docs/KEX_SUPPORT.md for exact edition boundaries.

This beta includes labelled Rust and bundled plans in the WAD picker.
Choose rerelease Doom II and a Play mode; required companions must be in the same
folder. Standard builds without the worker retain classic modes. Version 0.10.0 includes
an explicitly built Run/Pause preview of worlds, actors, weapons, HUD, level music, sound effects and native intermissions/finales through a separate
simulation worker, with Restart, native completion/Continue and private Save/Load controls. See
docs/EXTENDED_SAVES.md for save compatibility. See docs/EXTENDED_PREVIEW.md for launch instructions and
docs/LEGACY_OF_RUST.md for the remaining work. The optional bundled single-player
resource/weapon/texture/music plans and extras load order are documented in
docs/EXTENDED_BUNDLED.md. Indexed preview lighting is implemented; full software
parity and complete campaign playthrough acceptance remain open. See
docs/BRANCH_ACCEPTANCE.md.

See PLAYER_GUIDE.md for controls and BUG_REPORT.md for reports. When reporting a bug,
include Diagnostics → Copy Diagnostic Report; never attach commercial WADs.

The matching source archive is provided alongside the app release. License and
upstream notices are included in this package and inside the app bundle.
