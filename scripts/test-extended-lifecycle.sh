#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [[ $# != 2 ]]; then echo "Usage: $0 original-doom2.wad rerelease-directory" >&2; exit 2; fi
OUT="$PROJECT_DIR/build/extended"
python3 "$PROJECT_DIR/Tests/make_lifecycle_fixture.py" "$OUT/fixtures"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx14.0 -module-cache-path "$PROJECT_DIR/build/module-cache" \
 "$PROJECT_DIR/Sources/WAD.swift" "$PROJECT_DIR/Sources/Geometry.swift" "$PROJECT_DIR/Sources/ExtendedGeometry.swift" \
 "$PROJECT_DIR/Sources/ExtendedAudio.swift" "$PROJECT_DIR/Sources/ExtendedMaterials.swift" "$PROJECT_DIR/Sources/ExtendedPresentation.swift" \
 "$PROJECT_DIR/Sources/ExtendedUI.swift" "$PROJECT_DIR/Sources/ExtendedWorker.swift" "$PROJECT_DIR/Sources/ExtendedMesh.swift" "$PROJECT_DIR/Sources/ExtendedScene.swift" \
 "$PROJECT_DIR/Tests/ExtendedLifecycleValidation.swift" -o "$OUT/validate-lifecycle"
"$OUT/validate-lifecycle" "$OUT/MetalDooMWorker" "$1" "$2"
