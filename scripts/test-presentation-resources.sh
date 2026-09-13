#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ $# != 2 ]];then echo "Usage: $0 rerelease-directory original-doom2.wad" >&2;exit 2;fi
OUT="$ROOT/build/extended"
python3 "$ROOT/Tests/make_presentation_fixture.py" "$OUT/fixtures"
xcrun clang -std=gnu11 -O2 -arch arm64 -fwrapv -I"$ROOT/Engine/Extended" -I"$ROOT/Vendor/Woof/src" \
 -include "$ROOT/Engine/Extended/NativeHeaders.h" "$ROOT/Tests/PresentationResourcesValidation.c" "$OUT"/objects/*.o -lz -Wl,-dead_strip -o "$OUT/validate-presentation"
for kind in 0 1 2;do "$OUT/validate-presentation" "$OUT/cache" "$2" "$OUT/fixtures/presentation-$kind.wad";done
python3 "$ROOT/Tests/check_sky_save.py" "$OUT/MetalDooMWorker" "$1" "$ROOT/build/presentation-test"
xcrun clang -O2 -arch arm64 -dynamiclib "$ROOT/Engine/VorbisMusic.c" -o "$ROOT/build/validate-vorbis.dylib"
python3 "$ROOT/Tests/check_recorded_music.py" "$ROOT/build/validate-vorbis.dylib" "$1/extras.wad"
