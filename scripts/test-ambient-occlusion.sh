#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "$PROJECT_DIR/build/ao-check.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
MD_ENGINE_TEST_FLAGS=-DMD_TESTING bash "$PROJECT_DIR/scripts/build-engine.sh" "$TEST_DIR/engine"
python3 - "$PROJECT_DIR" "$TEST_DIR" <<'PY'
from pathlib import Path
import sys
root, output = map(Path,sys.argv[1:])
source=(root/'Sources/main.swift').read_text().split('\nlet app = NSApplication.shared\n')[0]
(output/'main.swift').write_text(source+'\n'+(root/'Tests/AmbientOcclusionValidation.swift').read_text())
PY
SOURCES=()
for source in "$PROJECT_DIR"/Sources/*.swift; do
  if [[ "$source" != "$PROJECT_DIR/Sources/main.swift" ]]; then SOURCES+=("$source"); fi
done
xcrun swiftc -swift-version 5 -Onone -g -target arm64-apple-macosx14.0 \
  -module-cache-path "$PROJECT_DIR/build/module-cache" \
  -framework AppKit -framework Metal -framework MetalKit -framework QuartzCore \
  -Xcc -DMD_TESTING -import-objc-header "$PROJECT_DIR/Engine/Bridge.h" \
  "${SOURCES[@]}" "$TEST_DIR/main.swift" "$TEST_DIR/engine/libDoom.a" \
  -Xlinker -dead_strip -o "$TEST_DIR/validate-ao"
export AO_OUTPUT="${AO_OUTPUT:-$PROJECT_DIR/build/ao-validation}"
mkdir -p "$AO_OUTPUT"
MTL_DEBUG_LAYER=1 "$TEST_DIR/validate-ao" -iwad "${1:?Provide IWAD path}" -warp "${2:-E1M1}" | tee "$AO_OUTPUT/results.txt"
