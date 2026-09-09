#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "$PROJECT_DIR/build/shutdown-check.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
bash "$PROJECT_DIR/scripts/build-engine.sh" "$TEST_DIR/engine"
python3 - "$PROJECT_DIR" "$TEST_DIR" <<'PY'
from pathlib import Path
import sys
root, output = map(Path,sys.argv[1:])
source=(root/'Sources/main.swift').read_text().split('\nlet app = NSApplication.shared\n')[0]
(output/'main.swift').write_text(source+'\n'+(root/'Tests/ShutdownValidation.swift').read_text())
PY
SOURCES=()
for source in "$PROJECT_DIR"/Sources/*.swift; do
  if [[ "$source" != "$PROJECT_DIR/Sources/main.swift" ]]; then SOURCES+=("$source"); fi
done
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx14.0 \
  -module-cache-path "$PROJECT_DIR/build/module-cache" \
  -framework AppKit -framework Metal -framework MetalKit -framework QuartzCore \
  -import-objc-header "$PROJECT_DIR/Engine/Bridge.h" \
  "${SOURCES[@]}" "$TEST_DIR/main.swift" "$TEST_DIR/engine/libDoom.a" \
  -Xlinker -dead_strip -o "$TEST_DIR/validate-shutdown"
for mode in --close --quit --gameplay; do
  "$TEST_DIR/validate-shutdown" -iwad "${1:?Provide IWAD path}" "$mode"
done
