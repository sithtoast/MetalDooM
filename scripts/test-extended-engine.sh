#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [[ $# != 1 ]]; then echo "Usage: $0 /path/to/original/doom2.wad" >&2; exit 2; fi
OUT="$PROJECT_DIR/build/extended"
bash "$PROJECT_DIR/scripts/build-extended-engine.sh" "$OUT"
mkdir -p "$OUT/cache"
python3 "$PROJECT_DIR/Tests/make_extended_fixture.py" "$OUT/fixtures"
xcrun clang -std=c11 -Wall -Wextra -Werror -arch arm64 -mmacosx-version-min=14.0 \
  -I"$PROJECT_DIR/Engine/Extended" "$PROJECT_DIR/Tests/ExtendedCoreValidation.c" \
  -L"$OUT" -lMetalDooMExtended -Wl,-rpath,@executable_path -o "$OUT/validate"
# Verify the two engines cannot resolve each other's globals via this dylib.
nm -gUj "$OUT/libMetalDooMExtended.dylib" > "$OUT/exports.txt"
python3 - "$OUT" <<'PY'
import pathlib, subprocess, sys
out = pathlib.Path(sys.argv[1])
exports = set((out/'exports.txt').read_text().splitlines())
assert exports == {'_ME_Init','_ME_Tick','_ME_CopySnapshot','_ME_CopyThings','_ME_CopyError','_ME_CopySession','_ME_CopyGeometry','_ME_CopyView','_ME_CopyPresentation','_ME_CopyMaterials'}, exports
links = subprocess.check_output(['otool','-L',str(out/'libMetalDooMExtended.dylib')],text=True)
assert 'SDL' not in links and '/opt/homebrew' not in links, links
print('PASS native dependencies and private engine symbols')
PY
"$OUT/validate" movement "$OUT/cache" "$1" > "$OUT/movement-1.log" 2>&1
"$OUT/validate" movement "$OUT/cache" "$1" > "$OUT/movement-2.log" 2>&1
cmp "$OUT/movement-1.log" "$OUT/movement-2.log"
cat "$OUT/movement-1.log"
for mode in combat conveyor bad-actor bad-weapon; do
  "$OUT/validate" "$mode" "$OUT/cache" "$1" "$OUT/fixtures/$mode.wad"
done
for mode in id24-field unknown-field unknown-section id24-config bad-table; do
  "$OUT/validate" reject "$OUT/cache" "$1" "$OUT/fixtures/$mode.wad" > "$OUT/$mode.log" 2>&1
  cat "$OUT/$mode.log"
done
python3 - "$OUT" <<'PY'
import pathlib, sys
out = pathlib.Path(sys.argv[1])
for mode, expected in {'id24-field':'unsupported','unknown-field':'not found',
                       'unknown-section':'Unsupported DeHackEd section',
                       'id24-config':'GAMECONF/ID24','bad-table':'no complete terminator'}.items():
    assert expected in (out/f'{mode}.log').read_text(), mode
print('PASS deterministic ticks, copied snapshots, patched combat, Boom conveyor and rejection boundaries')
PY
