#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
mkdir -p "$BUILD_DIR/module-cache"
if ! mkdir "$BUILD_DIR/.build-lock" 2>/dev/null; then
  echo "Another build is running (lock: $BUILD_DIR/.build-lock)." >&2
  exit 1
fi
TEMP_BUILD=""
cleanup() {
  if [[ -n "$TEMP_BUILD" ]]; then rm -rf "$TEMP_BUILD"; fi
  rmdir "$BUILD_DIR/.build-lock"
}
trap cleanup EXIT
CURRENT_BUILD="$(cat "$PROJECT_DIR/BUILD_NUMBER")"
if [[ ! "$CURRENT_BUILD" =~ ^[0-9]{1,9}$ ]]; then
  echo "BUILD_NUMBER must contain a nonnegative integer of at most nine digits." >&2
  exit 1
fi
NEXT_BUILD="$((10#$CURRENT_BUILD + 1))"
TEMP_BUILD="$(mktemp -d "$BUILD_DIR/.compile.XXXXXX")"
APP_DIR="$TEMP_BUILD/MetalDooM.app"
mkdir -p "$APP_DIR/Contents/MacOS"
bash "$PROJECT_DIR/scripts/build-engine.sh" "$TEMP_BUILD/engine"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx14.0 \
  -module-cache-path "$BUILD_DIR/module-cache" \
  -framework AppKit -framework Metal -framework MetalKit -framework QuartzCore \
  -import-objc-header "$PROJECT_DIR/Engine/Bridge.h" \
  "$PROJECT_DIR"/Sources/*.swift "$TEMP_BUILD/engine/libDoom.a" -Xlinker -dead_strip \
  -o "$APP_DIR/Contents/MacOS/MetalDooM"
mkdir -p "$APP_DIR/Contents/Resources"
cp "$PROJECT_DIR/LICENSE" "$APP_DIR/Contents/Resources/LICENSE"
cp "$PROJECT_DIR/Vendor/ChocolateDoom/UPSTREAM.md" "$APP_DIR/Contents/Resources/ChocolateDoom.txt"
cp "$PROJECT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEXT_BUILD" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :MetalDooMBuildDate string $(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$APP_DIR/Contents/Info.plist"
codesign --force --sign - "$APP_DIR"
if [[ -d "$BUILD_DIR/MetalDooM.app" ]]; then
  mv "$BUILD_DIR/MetalDooM.app" "$TEMP_BUILD/previous.app"
fi
if ! mv "$APP_DIR" "$BUILD_DIR/MetalDooM.app"; then
  if [[ -d "$TEMP_BUILD/previous.app" ]]; then mv "$TEMP_BUILD/previous.app" "$BUILD_DIR/MetalDooM.app"; fi
  exit 1
fi
printf '%s\n' "$NEXT_BUILD" > "$PROJECT_DIR/BUILD_NUMBER"
echo "Built $BUILD_DIR/MetalDooM.app (build $NEXT_BUILD)"
