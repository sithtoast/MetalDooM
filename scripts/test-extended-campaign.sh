#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [[ $# != 1 ]]; then echo "Usage: $0 rerelease-directory" >&2; exit 2; fi
OUT="$PROJECT_DIR/build/campaign-test"
mkdir -p "$OUT"
python3 "$PROJECT_DIR/Tests/make_lifecycle_fixture.py" "$PROJECT_DIR/build/extended/fixtures"
xcrun clang -std=c11 -Wall -Wextra -Werror -arch arm64 -mmacosx-version-min=14.0 \
 -I"$PROJECT_DIR/Engine/Extended" "$PROJECT_DIR/Tests/CampaignCopyValidation.c" \
 -L"$PROJECT_DIR/build/extended" -lMetalDooMExtended -Wl,-rpath,"$PROJECT_DIR/build/extended" -o "$OUT/copy"
"$OUT/copy" "$PROJECT_DIR/build/extended/cache" "$1/id24res.wad" "$1/doom2.wad" "$1/id1.wad" "$PROJECT_DIR/build/extended/fixtures/lifecycle-normal.wad"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx14.0 -module-cache-path "$PROJECT_DIR/build/module-cache" \
 -framework AppKit -import-objc-header "$PROJECT_DIR/Engine/Bridge.h" \
 "$PROJECT_DIR/Sources/WAD.swift" "$PROJECT_DIR/Sources/Geometry.swift" "$PROJECT_DIR/Sources/ExtendedGeometry.swift" \
 "$PROJECT_DIR/Sources/ExtendedAudio.swift" "$PROJECT_DIR/Sources/ExtendedMaterials.swift" "$PROJECT_DIR/Sources/ExtendedPresentation.swift" \
 "$PROJECT_DIR/Sources/ExtendedUI.swift" "$PROJECT_DIR/Sources/ExtendedWorker.swift" "$PROJECT_DIR/Sources/IntermissionSequence.swift" \
 "$PROJECT_DIR/Sources/ExtendedCampaign.swift" "$PROJECT_DIR/Sources/ExtendedCampaignView.swift" \
 "$PROJECT_DIR/Tests/ExtendedCampaignValidation.swift" -o "$OUT/validate"
"$OUT/validate" "$PROJECT_DIR/build/extended/MetalDooMWorker" "$1" "$OUT"
