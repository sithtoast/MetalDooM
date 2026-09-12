#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [[ $# != 1 ]]; then echo "Usage: $0 rerelease-directory" >&2; exit 2; fi
OUT="$PROJECT_DIR/build/save-test"
mkdir -p "$OUT" "$PROJECT_DIR/build/extended/cache"
python3 "$PROJECT_DIR/Tests/check_extended_save.py" "$PROJECT_DIR/build/extended/MetalDooMWorker" "$1" "$OUT"
xcrun clang -std=c11 -Wall -Wextra -Werror -arch arm64 -I"$PROJECT_DIR/Engine/Extended" \
 "$PROJECT_DIR/Tests/SaveCopyValidation.c" -L"$PROJECT_DIR/build/extended" -lMetalDooMExtended -Wl,-rpath,"$PROJECT_DIR/build/extended" -o "$OUT/copy"
"$OUT/copy" "$PROJECT_DIR/build/extended/cache" "$1/id24res.wad" "$1/doom2.wad" "$1/id1.wad"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx14.0 -module-cache-path "$PROJECT_DIR/build/module-cache" \
 "$PROJECT_DIR/Sources/WAD.swift" "$PROJECT_DIR/Sources/ExtendedSave.swift" "$PROJECT_DIR/Tests/ExtendedSaveValidation.swift" -o "$OUT/envelope"
"$OUT/envelope" "$OUT/sample.json"
