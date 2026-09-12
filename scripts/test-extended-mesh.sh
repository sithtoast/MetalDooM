#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [[ $# != 1 ]]; then echo "Usage: $0 rerelease-directory" >&2; exit 2; fi
OUT="$PROJECT_DIR/build/extended"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx14.0 -module-cache-path "$PROJECT_DIR/build/module-cache" \
 "$PROJECT_DIR/Sources/WAD.swift" "$PROJECT_DIR/Sources/Geometry.swift" "$PROJECT_DIR/Sources/ExtendedGeometry.swift" \
 "$PROJECT_DIR/Sources/ExtendedAudio.swift" "$PROJECT_DIR/Sources/ExtendedMaterials.swift" "$PROJECT_DIR/Sources/ExtendedPresentation.swift" \
 "$PROJECT_DIR/Sources/ExtendedWorker.swift" "$PROJECT_DIR/Sources/ExtendedMesh.swift" "$PROJECT_DIR/Sources/ExtendedScene.swift" \
 "$PROJECT_DIR/Tests/ReferenceGeometry.swift" "$PROJECT_DIR/Tests/ExtendedMeshValidation.swift" -o "$OUT/validate-mesh"
"$OUT/validate-mesh" "$1" "$OUT/MetalDooMWorker"
