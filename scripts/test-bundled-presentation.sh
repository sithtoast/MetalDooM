#!/bin/bash
set -euo pipefail
if [[ $# != 1 ]];then echo "Usage: $0 rerelease-directory" >&2;exit 2;fi
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/presentation-test"
mkdir -p "$OUT"
bash "$ROOT/scripts/build-engine.sh" "$OUT/engine"
python3 - "$ROOT" "$OUT" <<'PY'
from pathlib import Path
import sys
root,out=map(Path,sys.argv[1:])
(out/'MusicPlayer.swift').write_text((root/'Sources/MusicPlayer.swift').read_text()+'\nextension MusicPlayer {func validationNearEnd(){recorded!.currentTime=recorded!.duration-0.03};func validationStaleCompletion()throws->Bool {let old=recorded!;try select(trackName);recordedCompletion.audioPlayerDidFinishPlaying(old,successfully:true);return !recordedCompletion.finished}}\n')
(out/'Renderer.swift').write_text((root/'Sources/Renderer.swift').read_text()+'\n'+(root/'Tests/BundledPresentationValidation.swift').read_text())
(out/'main.swift').write_text((root/'Sources/main.swift').read_text().split('\nlet app = NSApplication.shared\n')[0]+'''
setbuf(stdout,nil)
do {
 let app=NSApplication.shared;app.setActivationPolicy(.regular)
 let view=GameView(frame:NSRect(x:0,y:0,width:640,height:400),device:MTLCreateSystemDefaultDevice())
 view.colorPixelFormat = .bgra8Unorm;view.depthStencilPixelFormat = .depth32Float
 let renderer=try Renderer(view:view)
 try renderer.validateSkyPixels(WAD(url:URL(fileURLWithPath:CommandLine.arguments[1]+"/doom2.wad")))
 try renderer.validateBundledPresentation(root:URL(fileURLWithPath:CommandLine.arguments[1]),executable:URL(fileURLWithPath:CommandLine.arguments[2]))
} catch {fputs("FAIL: \\(error)\\n",stderr);exit(1)}
''')
PY
SOURCES=()
for source in "$ROOT"/Sources/*.swift;do
 case "$(basename "$source")" in
 main.swift|Renderer.swift|MusicPlayer.swift) SOURCES+=("$OUT/$(basename "$source")");;
 *) SOURCES+=("$source");;
 esac
done
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx14.0 -module-cache-path "$ROOT/build/module-cache" \
 -framework AppKit -framework Metal -framework MetalKit -framework QuartzCore -import-objc-header "$ROOT/Engine/Bridge.h" \
 "${SOURCES[@]}" "$OUT/engine/libDoom.a" -Xlinker -dead_strip -o "$OUT/validate"
MTL_DEBUG_LAYER=1 "$OUT/validate" "$1" "$ROOT/build/extended/MetalDooMWorker"
