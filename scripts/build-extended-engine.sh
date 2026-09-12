#!/bin/bash
# Experimental standalone native worker core. Never linked into the classic core.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$PROJECT_DIR/build/extended}"
SRC="$PROJECT_DIR/Vendor/Woof"
NATIVE="$PROJECT_DIR/Engine/Extended"
mkdir -p "$OUT/objects"
FLAGS=(-std=gnu11 -O2 -g -fwrapv -fno-strict-aliasing -fvisibility=hidden
  -arch arm64 -mmacosx-version-min=14.0 -I"$NATIVE" -I"$SRC/src"
  -include "$NATIVE/NativeHeaders.h")
for lib in miniz yyjson sha1 md5 spng; do FLAGS+=(-I"$SRC/third-party/$lib"); done
objects=()
while read -r file; do
  [[ -z "$file" ]] && continue
  obj="$OUT/objects/${file%.c}.o"
  xcrun clang "${FLAGS[@]}" -c "$SRC/src/$file" -o "$obj"
  objects+=("$obj")
done < "$NATIVE/sources.txt"
for lib in miniz yyjson sha1 md5 spng; do
  obj="$OUT/objects/$lib.o"
  xcrun clang "${FLAGS[@]}" -c "$SRC/third-party/$lib/$lib.c" -o "$obj"
  objects+=("$obj")
done
for file in "$NATIVE"/*.c; do
  obj="$OUT/objects/native-$(basename "${file%.c}").o"
  xcrun clang "${FLAGS[@]}" -c "$file" -o "$obj"
  objects+=("$obj")
done
xcrun clang -arch arm64 -mmacosx-version-min=14.0 -dynamiclib \
  "${objects[@]}" -Wl,-dead_strip -Wl,-exported_symbols_list,"$NATIVE/exports.txt" -lz \
  -install_name @rpath/libMetalDooMExtended.dylib -o "$OUT/libMetalDooMExtended.dylib"
echo "Built experimental native core: $OUT/libMetalDooMExtended.dylib"
