#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
xcrun swiftc -swift-version 5 -target arm64-apple-macosx14.0 \
  -module-cache-path "$PROJECT_DIR/build/module-cache" \
  "$PROJECT_DIR/Sources/ClassicMenuCanvas.swift" "$PROJECT_DIR/Tests/ClassicMenuValidation.swift" \
  -o "$PROJECT_DIR/build/validate-classic-menu"
"$PROJECT_DIR/build/validate-classic-menu"
