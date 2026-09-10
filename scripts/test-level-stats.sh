#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WAD_PATH="${1:?Provide a Doom shareware IWAD path}"
mkdir -p "$PROJECT_DIR/build"
TEST_DIR="$(mktemp -d "$PROJECT_DIR/build/progression-check.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
MD_ENGINE_TEST_FLAGS=-DMD_TESTING bash "$PROJECT_DIR/scripts/build-engine.sh" "$TEST_DIR/objects"
xcrun clang -DMD_TESTING -I"$PROJECT_DIR/Engine" -arch arm64 -mmacosx-version-min=14.0 \
  "$PROJECT_DIR/Tests/LevelStatsValidation.c" "$TEST_DIR/objects/libDoom.a" \
  -Wl,-dead_strip -o "$TEST_DIR/validate-level-stats"
"$TEST_DIR/validate-level-stats" "$WAD_PATH" "$TEST_DIR/save.dsg"
xcrun swiftc -swift-version 5 -module-cache-path "$PROJECT_DIR/build/module-cache" \
  -import-objc-header "$PROJECT_DIR/Engine/Bridge.h" \
  "$PROJECT_DIR/Sources/LevelStatsState.swift" "$PROJECT_DIR/Tests/LevelStatsStateValidation.swift" \
  -o "$TEST_DIR/validate-state"
"$TEST_DIR/validate-state"
