# Installing MetalDooM 0.10.0

Requires an Apple Silicon Mac and macOS 14 or later.

Extract the release ZIP, drag MetalDooM.app to Applications, then open it.
The current 0.10.0 build 127 is a local, ad-hoc-signed development preview and has
not been notarized. No new distribution ZIP was produced for this milestone.
The previous 0.9.0 build 124 distribution was separately Developer ID signed,
accepted by Apple and stapled; its notarization does not apply to newer builds.
GitHub workflow assets remain unnotarized.
If macOS blocks the first launch, go to System Settings → Privacy & Security,
choose Open Anyway for MetalDooM and confirm. Managed Macs may restrict exceptions.
Apple's instructions: https://support.apple.com/102445

Choose Open WAD… and supply your own Doom/Ultimate Doom, Doom II, TNT or Plutonia
IWAD. Standard SIGIL can be added as a PWAD with Ultimate Doom. No game data is
included. The validated rerelease nerve.wad and masterlevels.wad use Doom II;
sigil2.wad uses Ultimate Doom. Load one campaign add-on at a time. Use Open WAD
to change games. See docs/KEX_SUPPORT.md for exact edition boundaries.

Legacy of Rust remains unsupported. Version 0.10.0 includes resource tables and
a separately built experimental simulation worker; see docs/LEGACY_OF_RUST.md
for the remaining engine work.

See PLAYER_GUIDE.md for controls and BUG_REPORT.md for reports. When reporting a bug,
include Diagnostics → Copy Diagnostic Report; never attach commercial WADs.

The matching source archive is provided alongside the app release. License and
upstream notices are included in this package and inside the app bundle.
