#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$PROJECT_DIR/build/module-cache"
TEST_DIR="$(mktemp -d "$PROJECT_DIR/build/input-check.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
# Exercise the production input view without pulling in the renderer or engine.
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx14.0 \
  -module-cache-path "$PROJECT_DIR/build/module-cache" \
  -framework AppKit -framework MetalKit \
  "$PROJECT_DIR/Sources/GameView.swift" "$PROJECT_DIR/Tests/InputValidation.swift" \
  -o "$TEST_DIR/validate-input"
"$TEST_DIR/validate-input"
