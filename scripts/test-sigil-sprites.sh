#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$PROJECT_DIR/build"
TEST_DIR="$(mktemp -d "$PROJECT_DIR/build/sigil-sprites.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
bash "$PROJECT_DIR/scripts/build-engine.sh" "$TEST_DIR/engine"
xcrun swiftc -swift-version 5 -O -module-cache-path "$PROJECT_DIR/build/module-cache" \
  -import-objc-header "$PROJECT_DIR/Engine/Bridge.h" "$PROJECT_DIR/Sources/WAD.swift" \
  "$PROJECT_DIR/Tests/SigilSpriteValidation.swift" "$TEST_DIR/engine/libDoom.a" \
  -Xlinker -dead_strip -o "$TEST_DIR/test"
"$TEST_DIR/test" "${1:?Provide Ultimate Doom IWAD}" "${2:?Provide SIGIL PWAD}"
