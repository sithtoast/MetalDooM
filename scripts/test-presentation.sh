#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WAD_PATH="${1:?Provide a Doom shareware IWAD path}"
mkdir -p "$PROJECT_DIR/build"
TEST_DIR="$(mktemp -d "$PROJECT_DIR/build/engine-check.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
MD_ENGINE_TEST_FLAGS=-DMD_TESTING bash "$PROJECT_DIR/scripts/build-engine.sh" "$TEST_DIR/objects"
xcrun clang -DMD_TESTING -I"$PROJECT_DIR/Engine" -arch arm64 -mmacosx-version-min=14.0 \
  "$PROJECT_DIR/Tests/PresentationValidation.c" "$TEST_DIR/objects/libDoom.a" \
  -Wl,-dead_strip -o "$TEST_DIR/validate-engine"
"$TEST_DIR/validate-engine" "$WAD_PATH"
