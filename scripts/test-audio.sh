#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$PROJECT_DIR/build/module-cache"
TEST_DIR="$(mktemp -d "$PROJECT_DIR/build/audio-check.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
bash "$PROJECT_DIR/scripts/build-engine.sh" "$TEST_DIR/engine"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx14.0 \
  -module-cache-path "$PROJECT_DIR/build/module-cache" \
  -framework AppKit -framework Metal -framework MetalKit -framework QuartzCore \
  -import-objc-header "$PROJECT_DIR/Engine/Bridge.h" \
  "$PROJECT_DIR/Sources/WAD.swift" "$PROJECT_DIR/Sources/Geometry.swift" \
  "$PROJECT_DIR/Sources/SoundPlayer.swift" "$PROJECT_DIR/Sources/Renderer.swift" "$PROJECT_DIR/Sources/SpriteRenderer.swift" \
  "$PROJECT_DIR/Tests/AudioValidation.swift" "$TEST_DIR/engine/libDoom.a" -Xlinker -dead_strip \
  -o "$TEST_DIR/validate-audio"
"$TEST_DIR/validate-audio" "${1:?Provide IWAD path}"
