#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TNT="${1:?Provide TNT IWAD}"; PLUTONIA="${2:?Provide Plutonia IWAD}"
mkdir -p "$PROJECT_DIR/build/module-cache"
TEST_DIR="$(mktemp -d "$PROJECT_DIR/build/final-check.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
MD_ENGINE_TEST_FLAGS=-DMD_TESTING bash "$PROJECT_DIR/scripts/build-engine.sh" "$TEST_DIR/engine"
xcrun clang -DMD_TESTING -include "$PROJECT_DIR/Engine/NativeHeaders.h" -I"$PROJECT_DIR/Engine" -I"$PROJECT_DIR/Vendor/ChocolateDoom/src" -I"$PROJECT_DIR/Vendor/ChocolateDoom/src/doom" -arch arm64 -mmacosx-version-min=14.0 \
 "$PROJECT_DIR/Tests/FinalDoomValidation.c" "$TEST_DIR/engine/libDoom.a" -Wl,-dead_strip -o "$TEST_DIR/routes"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx14.0 -module-cache-path "$PROJECT_DIR/build/module-cache" -Xcc -DMD_TESTING \
 -import-objc-header "$PROJECT_DIR/Engine/Bridge.h" \
 "$PROJECT_DIR/Sources/WAD.swift" "$PROJECT_DIR/Sources/MapNames.swift" "$PROJECT_DIR/Sources/Geometry.swift" "$PROJECT_DIR/Sources/SaveStore.swift" "$PROJECT_DIR/Sources/MusicPlayer.swift" "$PROJECT_DIR/Sources/OPLPlayer.swift" "$PROJECT_DIR/Sources/MUS.swift" \
 "$PROJECT_DIR/Tests/FinalDoomValidation.swift" "$TEST_DIR/engine/libDoom.a" -Xlinker -dead_strip -o "$TEST_DIR/assets"
"$TEST_DIR/routes" "$TNT" 1
"$TEST_DIR/routes" "$PLUTONIA" 2
"$TEST_DIR/assets" "$TNT" "$PLUTONIA" 1
"$TEST_DIR/assets" "$PLUTONIA" "$TNT" 2
