#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/extended"
if [[ $# != 1 ]];then echo "Usage: $0 rerelease-directory" >&2;exit 2;fi
python3 "$ROOT/Tests/make_id24_fixture.py" "$OUT/fixtures"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx14.0 -module-cache-path "$ROOT/build/module-cache" \
 "$ROOT/Sources/WAD.swift" "$ROOT/Sources/Geometry.swift" "$ROOT/Sources/ExtendedGeometry.swift" \
 "$ROOT/Sources/ExtendedAudio.swift" "$ROOT/Sources/ExtendedMaterials.swift" "$ROOT/Sources/ExtendedPresentation.swift" \
 "$ROOT/Sources/ExtendedUI.swift" "$ROOT/Sources/ExtendedWorker.swift" "$ROOT/Sources/ExtendedMesh.swift" "$ROOT/Sources/ExtendedScene.swift" \
 "$ROOT/Sources/ExtendedSave.swift" "$ROOT/Sources/BundledPreviewPlan.swift" "$ROOT/Sources/MUS.swift" \
 "$ROOT/Tests/BundledPreviewValidation.swift" -o "$OUT/validate-bundled"
"$OUT/validate-bundled" "$1" "$OUT/MetalDooMWorker"
