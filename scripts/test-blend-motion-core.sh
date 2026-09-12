#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/extended"
if [[ $# != 1 ]]; then echo "Usage: $0 original-doom2.wad" >&2;exit 2;fi
python3 "$ROOT/Tests/make_translucency_fixture.py" "$OUT/fixtures"
xcrun clang -std=gnu11 -O2 -fwrapv -arch arm64 -mmacosx-version-min=14.0 \
 -I"$ROOT/Engine/Extended" -I"$ROOT/Vendor/Woof/src" -I"$ROOT/Vendor/Woof/third-party/yyjson" \
 -include "$ROOT/Engine/Extended/NativeHeaders.h" \
 "$ROOT/Tests/BlendMotionCoreValidation.c" "$OUT"/objects/*.o -Wl,-dead_strip -lz -o "$OUT/validate-blend-motion-core"
CACHE="$(mktemp -d)";trap 'rm -rf "$CACHE"' EXIT
for mode in write read;do "$OUT/validate-blend-motion-core" "$mode" "$CACHE" "$1" "$OUT/fixtures/blend-object.wad" "$CACHE/save.json";done

python3 - "$OUT/validate-blend-motion-core" "$CACHE" "$1" "$OUT/fixtures/blend-object.wad" <<'PYTEST'
import json,pathlib,subprocess,sys
exe,cache,base,fixture=sys.argv[1:]
original=(pathlib.Path(cache)/'save.json').read_text()
for mode in ['object','respawn','endpoint']:
 data=json.loads(original)
 def mutate(value):
  if isinstance(value,dict):
   if 'native_previous' in value:
    if mode=='object':value['native_blend']=2147483647
    elif mode=='respawn':value['spawnpoint']['native_blend']=-101
    else:value['native_previous']=[0]
    return True
   return any(mutate(v) for v in value.values())
  if isinstance(value,list):return any(mutate(v) for v in value)
  return False
 assert mutate(data)
 target=pathlib.Path(cache)/f'bad-{mode}.json';target.write_text(json.dumps(data))
 subprocess.run([exe,'reject',cache,base,fixture,str(target)],check=True)
PYTEST
