#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$PROJECT_DIR/build/extended}"
bash "$PROJECT_DIR/scripts/build-extended-engine.sh" "$OUT"
xcrun clang -std=c11 -O2 -Wall -Wextra -Werror -arch arm64 -mmacosx-version-min=14.0 \
  -I"$PROJECT_DIR/Engine/Extended" "$PROJECT_DIR/Engine/Worker/main.c" \
  -L"$OUT" -lMetalDooMExtended -Wl,-rpath,@executable_path -o "$OUT/MetalDooMWorker"
