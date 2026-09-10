#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ICONSET="${1:?Usage: build-icon.sh temporary.iconset output.icns}"
OUTPUT="${2:?Usage: build-icon.sh temporary.iconset output.icns}"
mkdir -p "$ICONSET" "$(dirname "$OUTPUT")"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$PROJECT_DIR/Assets/AppIcon.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  retina=$((size * 2))
  sips -z "$retina" "$retina" "$PROJECT_DIR/Assets/AppIcon.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil --convert icns "$ICONSET" --output "$OUTPUT"
