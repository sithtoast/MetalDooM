#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "$PROJECT_DIR/build/opl-test.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
bash "$PROJECT_DIR/scripts/build-engine.sh" "$TEST_DIR/engine"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx14.0 -module-cache-path "$PROJECT_DIR/build/module-cache" \
  -import-objc-header "$PROJECT_DIR/Engine/Bridge.h" "$PROJECT_DIR/Sources/WAD.swift" "$PROJECT_DIR/Sources/MUS.swift" \
  "$PROJECT_DIR/Sources/MusicPlayer.swift" "$PROJECT_DIR/Sources/OPLPlayer.swift" "$PROJECT_DIR/Tests/OPLValidation.swift" \
  "$TEST_DIR/engine/libDoom.a" -Xlinker -dead_strip -o "$TEST_DIR/test"
"$TEST_DIR/test" "${@:?Provide IWAD and optional --all}"
