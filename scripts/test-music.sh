#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$PROJECT_DIR/build/module-cache"
bash "$PROJECT_DIR/scripts/build-engine.sh" "$PROJECT_DIR/build/music-engine"
xcrun swiftc -swift-version 5 -target arm64-apple-macosx14.0 \
  -module-cache-path "$PROJECT_DIR/build/module-cache" \
  "$PROJECT_DIR/Sources/WAD.swift" "$PROJECT_DIR/Sources/MUS.swift" "$PROJECT_DIR/Sources/MusicPlayer.swift" "$PROJECT_DIR/Sources/OPLPlayer.swift" \
  -import-objc-header "$PROJECT_DIR/Engine/Bridge.h" \
  "$PROJECT_DIR/Tests/MusicValidation.swift" "$PROJECT_DIR/build/music-engine/libDoom.a" -Xlinker -dead_strip -o "$PROJECT_DIR/build/validate-music"
"$PROJECT_DIR/build/validate-music" "${@:?Provide IWAD path and optional PWADs}"
