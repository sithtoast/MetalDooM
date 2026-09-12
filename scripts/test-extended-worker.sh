#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [[ $# != 2 ]]; then echo "Usage: $0 original-doom2.wad rerelease-directory" >&2; exit 2; fi
OUT="$PROJECT_DIR/build/extended"
bash "$PROJECT_DIR/scripts/build-extended-worker.sh" "$OUT"
python3 "$PROJECT_DIR/Tests/check_worker_protocol.py" "$OUT/MetalDooMWorker" "$1"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx14.0 -module-cache-path "$PROJECT_DIR/build/module-cache" \
 "$PROJECT_DIR/Sources/WAD.swift" "$PROJECT_DIR/Sources/Geometry.swift" "$PROJECT_DIR/Sources/ExtendedGeometry.swift" \
 "$PROJECT_DIR/Sources/ExtendedWorker.swift" "$PROJECT_DIR/Sources/ExtendedScene.swift" \
 "$PROJECT_DIR/Tests/ExtendedWorkerValidation.swift" -o "$OUT/validate-worker"
"$OUT/validate-worker" "$OUT/MetalDooMWorker" "$1" "$2"
