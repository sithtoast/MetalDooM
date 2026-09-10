#!/bin/bash
# Sign and notarize the most recent successful build. Credentials stay in Keychain.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-prepare}"
[[ "$MODE" == prepare || "$MODE" == notarize ]] || { echo "Usage: $0 [prepare|notarize]" >&2; exit 1; }
PROFILE="${METALDOOM_NOTARY_PROFILE:-MetalDooM-notary}"
SOURCE_APP="$PROJECT_DIR/build/MetalDooM.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$SOURCE_APP/Contents/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$SOURCE_APP/Contents/Info.plist")"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$BUILD" =~ ^[0-9]+$ ]] || exit 1
RELEASE_DIR="$PROJECT_DIR/build/releases/MetalDooM-$VERSION-build$BUILD"
APP="$RELEASE_DIR/MetalDooM.app"
if [[ "$MODE" == prepare ]]; then
IDENTITY="${METALDOOM_SIGN_IDENTITY:?Set METALDOOM_SIGN_IDENTITY to your Developer ID Application identity}"
mkdir -p "$(dirname "$RELEASE_DIR")"
# Refuse to overwrite a previous release or an in-progress notarization.
mkdir "$RELEASE_DIR"
ditto "$SOURCE_APP" "$APP"
codesign --force --sign "$IDENTITY" --options runtime --timestamp "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$RELEASE_DIR/notary-upload.zip"
echo "Signed locally: $APP"
echo "Run $0 notarize to upload this app to Apple for notarization."
exit 0
fi
[[ -f "$RELEASE_DIR/notary-upload.zip" ]] || { echo "Run prepare first." >&2; exit 1; }
xcrun notarytool submit "$RELEASE_DIR/notary-upload.zip" --keychain-profile "$PROFILE" \
  --wait --output-format json > "$RELEASE_DIR/notarization.json"
python3 - "$RELEASE_DIR/notarization.json" <<'PY'
import json,sys
result=json.load(open(sys.argv[1]))
print('Notarization:',result.get('status'),'submission:',result.get('id'))
if result.get('status') != 'Accepted':
    raise SystemExit('Notarization failed; inspect the submission with notarytool log before distributing.')
PY
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
spctl --assess --type execute --verbose=2 "$APP"
ARCHIVE="MetalDooM-$VERSION-build$BUILD-macOS-arm64.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$RELEASE_DIR/$ARCHIVE"
(cd "$RELEASE_DIR" && shasum -a 256 "$ARCHIVE" > "$ARCHIVE.sha256")
echo "Release ready: $RELEASE_DIR/$ARCHIVE"
