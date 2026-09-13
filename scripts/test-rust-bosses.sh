#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/extended"
xcrun clang -std=gnu11 -O2 -arch arm64 -mmacosx-version-min=14.0 -fwrapv \
 -I"$ROOT/Engine/Extended" -I"$ROOT/Vendor/Woof/src" -include "$ROOT/Engine/Extended/NativeHeaders.h" \
 "$ROOT/Tests/RustBossValidation.c" "$OUT"/objects/*.o -lz -Wl,-dead_strip -o "$OUT/validate-bosses"
for scenario in 13:0 14:0 14:1;do
 "$OUT/validate-bosses" "$OUT/cache" "${scenario%:*}" "${scenario#*:}" "$1/id24res.wad" "$1/doom2.wad" "$1/id1.wad"
done
