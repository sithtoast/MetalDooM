#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [[ $# != 2 ]]; then echo "Usage: $0 /path/to/original/doom2.wad /path/to/rerelease" >&2; exit 2; fi
OUT="$PROJECT_DIR/build/extended"
GEOMETRY="$OUT/geometry"
bash "$PROJECT_DIR/scripts/build-extended-engine.sh" "$OUT"
mkdir -p "$GEOMETRY" "$OUT/cache" "$PROJECT_DIR/build/module-cache"
xcrun clang -std=c11 -Wall -Wextra -Werror -arch arm64 -mmacosx-version-min=14.0 \
  -I"$PROJECT_DIR/Engine/Extended" "$PROJECT_DIR/Tests/ExtendedGeometryExport.c" \
  -L"$OUT" -lMetalDooMExtended -Wl,-rpath,@executable_path -o "$OUT/export-geometry"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx14.0 \
  -module-cache-path "$PROJECT_DIR/build/module-cache" \
  "$PROJECT_DIR/Sources/WAD.swift" "$PROJECT_DIR/Sources/Geometry.swift" "$PROJECT_DIR/Sources/ExtendedGeometry.swift" \
  "$PROJECT_DIR/Tests/ExtendedGeometryValidation.swift" -o "$OUT/validate-geometry"
for ((map=1;map<=32;map++)); do
  name="$(printf 'MAP%02d' "$map")"
  "$OUT/export-geometry" "$OUT/cache" "$map" 0 0 "$GEOMETRY/classic-$name.mge" "$1" > "$GEOMETRY/classic-$name.log" 2>&1
done
for ((map=1;map<=16;map++)); do
  name="$(printf 'MAP%02d' "$map")"
  "$OUT/export-geometry" "$OUT/cache" "$map" 1 1 "$GEOMETRY/rust-$name.mge" "$2/id24res.wad" "$2/doom2.wad" "$2/id1.wad" > "$GEOMETRY/rust-$name.log" 2>&1
done
python3 "$PROJECT_DIR/Tests/check_xnod_geometry.py" "$2/id1.wad" "$GEOMETRY/rust-MAP13.mge"
"$OUT/validate-geometry" "$1" "$GEOMETRY"
