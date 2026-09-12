#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$PROJECT_DIR/build"
TEST_DIR="$(mktemp -d "$PROJECT_DIR/build/resources-check.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
MD_ENGINE_TEST_FLAGS=-DMD_TESTING bash "$PROJECT_DIR/scripts/build-engine.sh" "$TEST_DIR/engine"
xcrun clang -DMD_TESTING -include "$PROJECT_DIR/Engine/NativeHeaders.h" \
  -I"$PROJECT_DIR/Engine" -I"$PROJECT_DIR/Vendor/ChocolateDoom/src" -I"$PROJECT_DIR/Vendor/ChocolateDoom/src/doom" \
  -arch arm64 -mmacosx-version-min=14.0 "$PROJECT_DIR/Tests/ResourceTableValidation.c" \
  "$TEST_DIR/engine/libDoom.a" -Wl,-dead_strip -o "$TEST_DIR/validate"
if [[ $# == 0 ]]; then echo "Provide at least one IWAD" >&2; exit 2; fi
if [[ -n "${RUST_TEXTURES:-}" ]]; then
  python3 "$PROJECT_DIR/Tests/make_resource_pack_fixture.py" "${RUST_BASE:?Set RUST_BASE with RUST_TEXTURES}" "$RUST_TEXTURES" "$TEST_DIR/rust-materials.wad"
  "$TEST_DIR/validate" "$TEST_DIR/rust-materials.wad" rust-materials
fi
for WAD_PATH in "$@"; do
  "$TEST_DIR/validate" "$WAD_PATH" classic
  python3 "$PROJECT_DIR/Tests/make_resource_fixture.py" "$WAD_PATH" "$TEST_DIR/fixtures"
  for mode in valid empty absent-start; do "$TEST_DIR/validate" "$TEST_DIR/fixtures/$mode.wad" "$mode"; done
  for mode in short-end padded-end; do "$TEST_DIR/validate" "$TEST_DIR/fixtures/$mode.wad" absent-start; done
  for mode in zero-speed negative-speed swirl-speed bad-kind backward missing-end truncated unterminated bad-name switch-truncated switch-unterminated switch-scope switch-name; do
    "$TEST_DIR/validate" "$TEST_DIR/fixtures/$mode.wad" reject
  done
done
