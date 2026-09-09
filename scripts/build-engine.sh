#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OBJECT_DIR="${1:?Provide an object directory}"
mkdir -p "$OBJECT_DIR"
ENGINE_DIR="$PROJECT_DIR/Vendor/ChocolateDoom/src"
while IFS= read -r SOURCE || [[ -n "$SOURCE" ]]; do
  [[ -n "$SOURCE" ]] || continue
  xcrun clang -std=gnu11 -O2 -fwrapv -fno-strict-aliasing -arch arm64 -mmacosx-version-min=14.0 \
    -include "$PROJECT_DIR/Engine/NativeHeaders.h" -I"$PROJECT_DIR/Engine" -I"$ENGINE_DIR" -I"$ENGINE_DIR/doom" \
    -c "$ENGINE_DIR/$SOURCE" -o "$OBJECT_DIR/${SOURCE//\//_}.o"
done < "$PROJECT_DIR/Engine/sources.txt"
for SOURCE in Bridge Platform; do
  xcrun clang -std=gnu11 -O2 -fwrapv -fno-strict-aliasing -arch arm64 -mmacosx-version-min=14.0 \
    ${MD_ENGINE_TEST_FLAGS:-} -include "$PROJECT_DIR/Engine/NativeHeaders.h" -I"$PROJECT_DIR/Engine" -I"$ENGINE_DIR" -I"$ENGINE_DIR/doom" \
    -c "$PROJECT_DIR/Engine/$SOURCE.c" -o "$OBJECT_DIR/$SOURCE.o"
done
ar rcs "$OBJECT_DIR/libDoom.a" "$OBJECT_DIR"/*.o
