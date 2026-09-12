#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [[ $# != 2 ]]; then echo "Usage: $0 original-doom2.wad rerelease-directory" >&2; exit 2; fi
OUT="$PROJECT_DIR/build/extended"
python3 "$PROJECT_DIR/Tests/make_id24_fixture.py" "$OUT/fixtures"
xcrun clang -std=c11 -Wall -Wextra -Werror -arch arm64 -I"$PROJECT_DIR/Engine/Extended" \
 "$PROJECT_DIR/Tests/UICopyValidation.c" -L"$OUT" -lMetalDooMExtended -Wl,-rpath,@executable_path -o "$OUT/validate-ui-copy"
"$OUT/validate-ui-copy" "$OUT/cache" "$1" "$OUT/fixtures/ui-pickups.wad"
bash "$PROJECT_DIR/scripts/build-engine.sh" "$OUT/ui-classic-link"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx14.0 -module-cache-path "$PROJECT_DIR/build/module-cache" \
 -framework AVFoundation -import-objc-header "$PROJECT_DIR/Engine/Bridge.h" \
 "$PROJECT_DIR/Sources/WAD.swift" "$PROJECT_DIR/Sources/Geometry.swift" "$PROJECT_DIR/Sources/ExtendedGeometry.swift" \
 "$PROJECT_DIR/Sources/ExtendedAudio.swift" "$PROJECT_DIR/Sources/ExtendedMaterials.swift" "$PROJECT_DIR/Sources/ExtendedPresentation.swift" \
 "$PROJECT_DIR/Sources/ExtendedUI.swift" "$PROJECT_DIR/Sources/ExtendedWorker.swift" \
 "$PROJECT_DIR/Sources/MUS.swift" "$PROJECT_DIR/Sources/MusicPlayer.swift" "$PROJECT_DIR/Sources/OPLPlayer.swift" \
 "$PROJECT_DIR/Tests/ExtendedUIValidation.swift" "$OUT/ui-classic-link/libDoom.a" -Xlinker -dead_strip -o "$OUT/validate-ui"
"$OUT/validate-ui" "$OUT/MetalDooMWorker" "$1" "$2"
