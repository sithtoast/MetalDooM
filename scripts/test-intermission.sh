#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$PROJECT_DIR/build/module-cache"
xcrun swiftc -swift-version 5 -target arm64-apple-macosx14.0 \
  -module-cache-path "$PROJECT_DIR/build/module-cache" \
  -import-objc-header "$PROJECT_DIR/Engine/Bridge.h" \
  "$PROJECT_DIR/Sources/IntermissionSequence.swift" "$PROJECT_DIR/Tests/IntermissionValidation.swift" \
  -o "$PROJECT_DIR/build/validate-intermission"
"$PROJECT_DIR/build/validate-intermission"
