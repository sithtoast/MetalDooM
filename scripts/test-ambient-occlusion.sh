#!/bin/bash
set -euo pipefail
if [[ $# -lt 1 || ! -f "$1" || ! -r "$1" ]]; then
  echo "Provide a readable IWAD path." >&2
  exit 2
fi
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "$PROJECT_DIR/build/ao-check.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
MD_ENGINE_TEST_FLAGS=-DMD_TESTING bash "$PROJECT_DIR/scripts/build-engine.sh" "$TEST_DIR/engine"
python3 - "$PROJECT_DIR" "$TEST_DIR" <<'PY'
from pathlib import Path
import sys, os
root, output = map(Path,sys.argv[1:])
source=(root/'Sources/main.swift').read_text().split('\nlet app = NSApplication.shared\n')[0]
# Report native load errors in stderr instead of waiting on an unattended dialog.
start=source.index('    func show(_ error: Error) {')
end=source.index('    @objc func toggleMusic',start)
source=source[:start]+'    func show(_ error: Error) { validationFail(String(describing:error)) }\n'+source[end:]
# Suppress only HUD drawing for identical-scene transparency/pixel comparisons.
renderer=(root/'Sources/Renderer.swift').read_text()
renderer=renderer.replace('final class Renderer: NSObject, MTKViewDelegate {',
    'final class Renderer: NSObject, MTKViewDelegate {\n    var validationHUDVisible=true')
renderer=renderer.replace('                sprites.drawHUD(', '                if validationHUDVisible { sprites.drawHUD(')
renderer=renderer.replace('percent:hudSizePercent,style:hudStyle,portrait:minimalHUDPortrait)', 'percent:hudSizePercent,style:hudStyle,portrait:minimalHUDPortrait) }')
(output/'Renderer.swift').write_text(renderer+"""
// Test-only bridge in this copied source file; not part of app builds.
extension Renderer {
    func validationHasTexture(_ name:String) -> Bool { textures[MaterialKey(name:name,flat:false)] != nil }
    func validationHUD(_ state:MD_HUD) { hud=state }
    func validationLightPhase(_ tics:Int32) { hud.levelTics=tics }
    var validationWorldShader: String { worldShader }
    var validationMapName: String? { map?.name }
    var validationSelectedLights: [DynamicLightUniforms] { sceneLights() }
    var validationSurfaceLights: [DynamicLightUniforms] { rebuildSurfaceLights();return surfaceLights }
    func validationCamera(_ x:Float,_ y:Float,_ z:Float,_ angle:Float,_ tilt:Float) {
        position=SIMD2(x,y);eyeZ=z;yaw=angle;pitch=tilt
    }
    func validationSynchronizeEngine() throws {
        currentPlayer=MD_GetPlayer();previousPlayer=currentPlayer;hud=MD_GetHUD()
        position=SIMD2(currentPlayer.x,currentPlayer.y);eyeZ=currentPlayer.eyeZ;yaw=currentPlayer.angle;pitch=0
        try syncGeometry()
    }
}
""")
(output/'main.swift').write_text(source+'\n'+(root/'Tests/AOAlphaValidation.swift').read_text()+'\n'+(root/'Tests/WorldSamplingValidation.swift').read_text()+'\n'+(root/'Tests/AmbientOcclusionValidation.swift').read_text().replace('// Exercise map replacement', (root/'Tests/SceneEffectsValidation.swift').read_text()+'\n'+(root/'Tests/AdvancedEffectsValidation.swift').read_text()+'\n'+(root/'Tests/HDRVolumeValidation.swift').read_text()+'\n// Exercise map replacement'))
if os.environ.get('AO_RESOLUTION') == '1':
    setup=(root/'Tests/AmbientOcclusionValidation.swift').read_text().split('func measure(')[0]
    (output/'main.swift').write_text(source+'\n'+setup+(root/'Tests/ResolutionValidation.swift').read_text())
if os.environ.get('AO_RESOURCES') == '1':
    setup=(root/'Tests/AmbientOcclusionValidation.swift').read_text().split('func measure(')[0]
    (output/'main.swift').write_text(source+'\n'+setup+(root/'Tests/ResourceMetalValidation.swift').read_text())
if os.environ.get('AO_PROFILE') == '1' or os.environ.get('AO_LIVE') == '1':
    setup=(root/'Tests/AmbientOcclusionValidation.swift').read_text().split('func frame()')[0]
    (output/'main.swift').write_text(source+'\n'+setup+(root/('Tests/EffectsLiveValidation.swift' if os.environ.get('AO_LIVE') == '1' else 'Tests/EffectsProfile.swift')).read_text())
PY
SOURCES=()
for source in "$PROJECT_DIR"/Sources/*.swift; do
  if [[ "$source" == "$PROJECT_DIR/Sources/Renderer.swift" ]]; then
    SOURCES+=("$TEST_DIR/Renderer.swift")
  elif [[ "$source" != "$PROJECT_DIR/Sources/main.swift" ]]; then SOURCES+=("$source"); fi
done
xcrun swiftc -swift-version 5 -Onone -g -target arm64-apple-macosx14.0 \
  -module-cache-path "$PROJECT_DIR/build/module-cache" \
  -framework AppKit -framework Metal -framework MetalKit -framework QuartzCore \
  -Xcc -DMD_TESTING -import-objc-header "$PROJECT_DIR/Engine/Bridge.h" \
  "${SOURCES[@]}" "$TEST_DIR/main.swift" "$TEST_DIR/engine/libDoom.a" \
  -Xlinker -dead_strip -o "$TEST_DIR/validate-ao"
export AO_OUTPUT="${AO_OUTPUT:-$PROJECT_DIR/build/ao-validation}"
mkdir -p "$AO_OUTPUT"
MTL_DEBUG_LAYER="${AO_VALIDATION_LAYER:-1}" "$TEST_DIR/validate-ao" -iwad "${1:?Provide IWAD path}" -warp "${2:-E1M1}" | tee "$AO_OUTPUT/results.txt"
