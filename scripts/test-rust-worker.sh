#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [[ $# != 2 ]]; then echo "Usage: $0 original-doom2.wad /path/to/rerelease" >&2; exit 2; fi
# Build once, and rerun the MBF21 baseline before testing explicit Rust opt-in.
bash "$PROJECT_DIR/scripts/test-extended-engine.sh" "$1"
OUT="$PROJECT_DIR/build/extended"
python3 "$PROJECT_DIR/Tests/make_id24_fixture.py" "$OUT/fixtures"
for unit in ID24FieldValidation RustWorkerValidation; do
  xcrun clang -std=c11 -Wall -Wextra -Werror -arch arm64 -mmacosx-version-min=14.0 \
    -I"$PROJECT_DIR/Engine/Extended" "$PROJECT_DIR/Tests/$unit.c" \
    -L"$OUT" -lMetalDooMExtended -Wl,-rpath,@executable_path -o "$OUT/$unit"
done
python3 "$PROJECT_DIR/Tests/run_rust_worker.py" "$OUT" "$1" "$2"
