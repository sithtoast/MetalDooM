#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$PROJECT_DIR/build/module-cache"
TEST_DIR="$(mktemp -d "$PROJECT_DIR/build/kex-check.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
MD_ENGINE_TEST_FLAGS=-DMD_TESTING bash "$PROJECT_DIR/scripts/build-engine.sh" "$TEST_DIR/engine"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx14.0 \
  -module-cache-path "$PROJECT_DIR/build/module-cache" -Xcc -DMD_TESTING \
  -import-objc-header "$PROJECT_DIR/Engine/Bridge.h" \
  "$PROJECT_DIR/Sources/WAD.swift" "$PROJECT_DIR/Sources/MapNames.swift" "$PROJECT_DIR/Sources/Geometry.swift" "$PROJECT_DIR/Sources/SaveStore.swift" "$PROJECT_DIR/Sources/MUS.swift" \
  "$PROJECT_DIR/Tests/KEXCampaignValidation.swift" "$TEST_DIR/engine/libDoom.a" -Xlinker -dead_strip \
  -o "$TEST_DIR/validate-kex"
"$TEST_DIR/validate-kex" "${1:?Provide base IWAD}" "${2:?Provide campaign PWAD}"
