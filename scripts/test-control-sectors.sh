#!/bin/bash
set -euo pipefail
if [[ $# != 1 ]]; then echo "Usage: $0 original-doom2.wad" >&2; exit 2; fi
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/control-test"
mkdir -p "$OUT"
xcrun clang -std=gnu11 -O2 -fwrapv -arch arm64 -mmacosx-version-min=14.0 \
 -I"$ROOT/Engine/Extended" -I"$ROOT/Vendor/Woof/src" -I"$ROOT/Vendor/Woof/third-party/yyjson" \
 -include "$ROOT/Engine/Extended/NativeHeaders.h" \
 "$ROOT/Engine/Extended/RenderSector.c" "$ROOT/Tests/ReferenceFakeFlat.c" -o "$OUT/reference"
"$OUT/reference"
python3 "$ROOT/Tests/make_control_fixture.py" "$ROOT/build/extended/fixtures"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx14.0 -module-cache-path "$ROOT/build/module-cache" \
 "$ROOT/Sources/WAD.swift" "$ROOT/Sources/Geometry.swift" "$ROOT/Sources/ExtendedGeometry.swift" \
 "$ROOT/Sources/ExtendedAudio.swift" "$ROOT/Sources/ExtendedMaterials.swift" "$ROOT/Sources/ExtendedPresentation.swift" \
 "$ROOT/Sources/ExtendedUI.swift" "$ROOT/Sources/ExtendedWorker.swift" "$ROOT/Sources/ExtendedMesh.swift" "$ROOT/Sources/ExtendedScene.swift" \
 "$ROOT/Tests/ControlSectorValidation.swift" -o "$OUT/worker"
"$OUT/worker" "$ROOT/build/extended/MetalDooMWorker" "$1"
