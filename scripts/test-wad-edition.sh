#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "$PROJECT_DIR/build/edition-test.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
xcrun swiftc -swift-version 5 -O -module-cache-path "$PROJECT_DIR/build/module-cache" \
 "$PROJECT_DIR/Sources/WAD.swift" "$PROJECT_DIR/Tests/WADEditionValidation.swift" -o "$TEST_DIR/test"
"$TEST_DIR/test" "${1:?Provide KEX rerelease folder}" "${2:?Provide original Ultimate Doom IWAD}"
