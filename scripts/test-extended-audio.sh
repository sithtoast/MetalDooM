#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [[ $# != 2 ]]; then echo "Usage: $0 original-doom2.wad rerelease-directory" >&2; exit 2; fi
OUT="$PROJECT_DIR/build/extended"
# Run test-extended-worker.sh first to prepare the matching worker and fixtures.
[[ -x "$OUT/MetalDooMWorker" && -f "$OUT/fixtures/audio-spatial.wad" ]]
bash "$PROJECT_DIR/scripts/build-engine.sh" "$OUT/audio-classic-link"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx14.0 -framework AVFoundation \
 -module-cache-path "$PROJECT_DIR/build/module-cache" -import-objc-header "$PROJECT_DIR/Engine/Bridge.h" \
 "$PROJECT_DIR/Sources/WAD.swift" "$PROJECT_DIR/Sources/Geometry.swift" "$PROJECT_DIR/Sources/ExtendedGeometry.swift" \
 "$PROJECT_DIR/Sources/ExtendedPresentation.swift" "$PROJECT_DIR/Sources/ExtendedMaterials.swift" \
 "$PROJECT_DIR/Sources/ExtendedAudio.swift" "$PROJECT_DIR/Sources/ExtendedUI.swift" "$PROJECT_DIR/Sources/ExtendedWorker.swift" \
 "$PROJECT_DIR/Sources/SoundPlayer.swift" "$PROJECT_DIR/Sources/ExtendedSoundPlayer.swift" \
 "$PROJECT_DIR/Tests/ExtendedAudioValidation.swift" "$OUT/audio-classic-link/libDoom.a" \
 -Xlinker -dead_strip -o "$OUT/validate-audio"
"$OUT/validate-audio" "$OUT/MetalDooMWorker" "$1" "$2"
