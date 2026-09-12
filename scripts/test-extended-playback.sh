#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [[ $# != 1 ]]; then echo "Usage: $0 rerelease-directory" >&2; exit 2; fi
OUT="$PROJECT_DIR/build/extended"
[[ -x "$OUT/MetalDooMWorker" ]]
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx14.0 -module-cache-path "$PROJECT_DIR/build/module-cache" \
 "$PROJECT_DIR/Sources/WAD.swift" "$PROJECT_DIR/Sources/Geometry.swift" "$PROJECT_DIR/Sources/ExtendedGeometry.swift" \
 "$PROJECT_DIR/Sources/ExtendedAudio.swift" "$PROJECT_DIR/Sources/ExtendedMaterials.swift" "$PROJECT_DIR/Sources/ExtendedPresentation.swift" \
 "$PROJECT_DIR/Sources/ExtendedWorker.swift" "$PROJECT_DIR/Sources/ExtendedScene.swift" "$PROJECT_DIR/Sources/ExtendedPlaybackClock.swift" \
 "$PROJECT_DIR/Tests/ExtendedPlaybackValidation.swift" -o "$OUT/validate-playback"
"$OUT/validate-playback" "$OUT/MetalDooMWorker" "$1"
