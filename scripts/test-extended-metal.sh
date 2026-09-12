#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [[ $# != 1 ]]; then echo "Usage: $0 rerelease-directory" >&2; exit 2; fi
OUT="$PROJECT_DIR/build/extended-metal"
mkdir -p "$OUT"
python3 "$PROJECT_DIR/Tests/make_scroll_fixture.py" "$PROJECT_DIR/build/extended/fixtures"
bash "$PROJECT_DIR/scripts/build-engine.sh" "$OUT/engine"
python3 - "$PROJECT_DIR" "$OUT" <<'PY'
from pathlib import Path
import sys
root,out=map(Path,sys.argv[1:])
source=(root/'Sources/main.swift').read_text().split('\nlet app = NSApplication.shared\n')[0]
(out/'main.swift').write_text(source+'\n'+(root/'Tests/ExtendedMetalValidation.swift').read_text())
renderer=(root/'Sources/Renderer.swift').read_text().replace('final class Renderer: NSObject, MTKViewDelegate {','final class Renderer: NSObject, MTKViewDelegate {\n    var validationHUDVisible=true;var validationTime:Double?')
renderer=renderer.replace('now:ProcessInfo.processInfo.systemUptime','now:validationTime ?? ProcessInfo.processInfo.systemUptime')
renderer='\n'.join('                if validationHUDVisible { '+line.strip()+' }' if line.strip().startswith('sprites.drawHUD(') else line for line in renderer.split('\n'))
(out/'Renderer.swift').write_text(renderer+'''
extension Renderer {
    var validationPreviewBuffers:[MaterialKey:ObjectIdentifier] { Dictionary(uniqueKeysWithValues:batches.map{($0.material,ObjectIdentifier($0.vertices))}) }
}
''')
(out/'ExtendedScene.swift').write_text((root/'Sources/ExtendedScene.swift').read_text()+'''
extension ExtendedScene {
    func validationReference(stationaryFlats:Bool=false) throws -> ExtendedScene {
        var map=copiedGeometry.map
        if stationaryFlats {for i in map.sectors.indices {map.sectors[i].floorOffset = .zero;map.sectors[i].ceilingOffset = .zero}}
        let reference=try ReferenceGeometry(map:map,textureHeights:Art(wad:resources).textureHeights())
        let full=Geometry(batches:reference.batches,skyVertices:reference.skyVertices)
        return ExtendedScene(view:view,resources:resources,copied:copiedGeometry,geometry:full,images:images,sky:sky,indices:spriteIndices,patches:spritePatches,changed:true,changedMaterials:Set(full.batches.map(\\.material)).union([MaterialKey(name:"F_SKY1",flat:true)]))
    }
}
''')
PY
SOURCES=()
for source in "$PROJECT_DIR"/Sources/*.swift; do
 case "$(basename "$source")" in
 main.swift|Renderer.swift|ExtendedScene.swift) SOURCES+=("$OUT/$(basename "$source")");;
 *) SOURCES+=("$source");;
 esac
done
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx14.0 -module-cache-path "$PROJECT_DIR/build/module-cache" \
 -framework AppKit -framework Metal -framework MetalKit -framework QuartzCore -import-objc-header "$PROJECT_DIR/Engine/Bridge.h" \
 "${SOURCES[@]}" "$PROJECT_DIR/Tests/ReferenceGeometry.swift" "$OUT/engine/libDoom.a" -Xlinker -dead_strip -o "$OUT/validate-metal"
MTL_DEBUG_LAYER=1 "$OUT/validate-metal" "$1" "$PROJECT_DIR/build/extended/MetalDooMWorker"
