#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/indexed-lighting-test"
mkdir -p "$OUT"
bash "$ROOT/scripts/build-engine.sh" "$OUT/engine"
python3 - "$ROOT" "$OUT" <<'PY'
from pathlib import Path
import sys
root,out=map(Path,sys.argv[1:])
(out/'Renderer.swift').write_text((root/'Sources/Renderer.swift').read_text()+'\n'+(root/'Tests/IndexedLightingValidation.swift').read_text())
(out/'main.swift').write_text((root/'Sources/main.swift').read_text().split('\nlet app = NSApplication.shared\n')[0]+'''\nsetbuf(stdout,nil)
do {
 let app=NSApplication.shared;app.setActivationPolicy(.regular)
 let view=GameView(frame:NSRect(x:0,y:0,width:256,height:1),device:MTLCreateSystemDefaultDevice())
 view.colorPixelFormat = .bgra8Unorm;view.depthStencilPixelFormat = .depth32Float
 let renderer=try Renderer(view:view)
 try renderer.validateIndexedLighting(WAD(url:URL(fileURLWithPath:CommandLine.arguments[1])))
} catch {fputs("FAIL: \\(error)\\n",stderr);exit(1)}
''')
PY
SOURCES=()
for source in "$ROOT"/Sources/*.swift;do
 case "$(basename "$source")" in
 main.swift|Renderer.swift) SOURCES+=("$OUT/$(basename "$source")");;
 *) SOURCES+=("$source");;
 esac
done
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx14.0 -module-cache-path "$ROOT/build/module-cache" \
 -framework AppKit -framework Metal -framework MetalKit -framework QuartzCore -import-objc-header "$ROOT/Engine/Bridge.h" \
 "${SOURCES[@]}" "$OUT/engine/libDoom.a" -Xlinker -dead_strip -o "$OUT/validate"
MTL_DEBUG_LAYER=1 "$OUT/validate" "$1"
