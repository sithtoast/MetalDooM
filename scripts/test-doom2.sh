#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WAD_PATH="${1:?Provide a Doom II IWAD path}"
mkdir -p "$PROJECT_DIR/build"
TEST_DIR="$(mktemp -d "$PROJECT_DIR/build/doom2-check.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
MD_ENGINE_TEST_FLAGS=-DMD_TESTING bash "$PROJECT_DIR/scripts/build-engine.sh" "$TEST_DIR/objects"
xcrun clang -DMD_TESTING -I"$PROJECT_DIR/Engine" -I"$PROJECT_DIR/Vendor/ChocolateDoom/src/doom" -arch arm64 -mmacosx-version-min=14.0 \
  "$PROJECT_DIR/Tests/DoomIIValidation.c" "$TEST_DIR/objects/libDoom.a" \
  -Wl,-dead_strip -o "$TEST_DIR/validate-doom2"
"$TEST_DIR/validate-doom2" "$WAD_PATH"
