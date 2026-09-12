#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [[ $# != 2 ]]; then echo "Usage: $0 original-doom2.wad rerelease-directory" >&2; exit 2; fi
OUT="$PROJECT_DIR/build/extended"
bash "$PROJECT_DIR/scripts/build-extended-worker.sh" "$OUT"
mkdir -p "$OUT/cache"
xcrun clang -std=c11 -Wall -Wextra -Werror -arch arm64 -mmacosx-version-min=14.0 \
 -I"$PROJECT_DIR/Engine/Extended" "$PROJECT_DIR/Tests/PresentationCopyValidation.c" \
 -L"$OUT" -lMetalDooMExtended -Wl,-rpath,@executable_path -o "$OUT/validate-presentation-copy"
"$OUT/validate-presentation-copy" "$OUT/cache" "$1"
python3 "$PROJECT_DIR/Tests/make_id24_fixture.py" "$OUT/fixtures"
python3 "$PROJECT_DIR/Tests/make_translucency_fixture.py" "$OUT/fixtures"
xcrun clang -std=c11 -Wall -Wextra -Werror -arch arm64 -mmacosx-version-min=14.0 \
 -I"$PROJECT_DIR/Engine/Extended" "$PROJECT_DIR/Tests/AudioCopyValidation.c" \
 -L"$OUT" -lMetalDooMExtended -Wl,-rpath,@executable_path -o "$OUT/validate-audio-copy"
for mode in copy overflow; do "$OUT/validate-audio-copy" "$OUT/cache" "$1" "$OUT/fixtures/audio-loop.wad" "$mode"; done
xcrun clang -std=c11 -Wall -Wextra -Werror -arch arm64 -mmacosx-version-min=14.0 \
 -I"$PROJECT_DIR/Engine/Extended" "$PROJECT_DIR/Tests/AudioSimulationValidation.c" \
 -L"$OUT" -lMetalDooMExtended -Wl,-rpath,@executable_path -o "$OUT/validate-audio-simulation"
for enabled in 0 1; do "$OUT/validate-audio-simulation" "$OUT/cache" "$1" "$OUT/fixtures/render-rotations.wad" "$enabled" "$OUT/audio-state-$enabled.bin"; done
cmp "$OUT/audio-state-0.bin" "$OUT/audio-state-1.bin"
python3 "$PROJECT_DIR/Tests/check_worker_protocol.py" "$OUT/MetalDooMWorker" "$1"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx14.0 -module-cache-path "$PROJECT_DIR/build/module-cache" \
 "$PROJECT_DIR/Sources/WAD.swift" "$PROJECT_DIR/Sources/Geometry.swift" "$PROJECT_DIR/Sources/ExtendedGeometry.swift" \
 "$PROJECT_DIR/Sources/ExtendedAudio.swift" "$PROJECT_DIR/Sources/ExtendedMaterials.swift" "$PROJECT_DIR/Sources/ExtendedPresentation.swift" "$PROJECT_DIR/Sources/ExtendedUI.swift" "$PROJECT_DIR/Sources/ExtendedWorker.swift" "$PROJECT_DIR/Sources/ExtendedMesh.swift" "$PROJECT_DIR/Sources/ExtendedScene.swift" \
 "$PROJECT_DIR/Tests/ExtendedWorkerValidation.swift" -o "$OUT/validate-worker"
"$OUT/validate-worker" "$OUT/MetalDooMWorker" "$1" "$2"
