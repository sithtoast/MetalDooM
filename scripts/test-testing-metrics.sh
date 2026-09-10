#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "$PROJECT_DIR/build/testing-metrics.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
xcrun swiftc -swift-version 5 -module-cache-path "$PROJECT_DIR/build/module-cache" \
  "$PROJECT_DIR/Sources/TestingMetrics.swift" "$PROJECT_DIR/Tests/TestingMetricsValidation.swift" \
  -o "$TEST_DIR/test"
"$TEST_DIR/test"
