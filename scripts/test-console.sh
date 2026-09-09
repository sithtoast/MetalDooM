#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$PROJECT_DIR/build/module-cache"
xcrun swiftc -swift-version 5 -module-cache-path "$PROJECT_DIR/build/module-cache" -framework AppKit "$PROJECT_DIR/Sources/DeveloperConsole.swift" "$PROJECT_DIR/Tests/ConsoleValidation.swift" -o "$PROJECT_DIR/build/console-validation"
"$PROJECT_DIR/build/console-validation"
