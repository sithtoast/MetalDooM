#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$PROJECT_DIR/build/module-cache"
python3 "$PROJECT_DIR/Tests/make_fixture.py" "$PROJECT_DIR/build/test-room.wad"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx14.0 \
  -module-cache-path "$PROJECT_DIR/build/module-cache" \
  "$PROJECT_DIR/Sources/WAD.swift" "$PROJECT_DIR/Sources/Geometry.swift" \
  "$PROJECT_DIR/Tests/Validation.swift" -o "$PROJECT_DIR/build/validate"
"$PROJECT_DIR/build/validate" "$PROJECT_DIR/build/test-room.wad" "$@"
