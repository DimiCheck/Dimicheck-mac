#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFO_PLIST="$ROOT_DIR/Resources/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$("$ROOT_DIR/scripts/build-app.sh" | tail -n 1)"
ARCHIVE_NAME="DimiCheck-Mac-$VERSION"
ZIP_PATH="$DIST_DIR/$ARCHIVE_NAME.zip"
DMG_PATH="$DIST_DIR/$ARCHIVE_NAME.dmg"
CHECKSUM_PATH="$DIST_DIR/SHA256SUMS"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

mkdir -p "$TMP_DIR/dmg"
ditto "$APP_PATH" "$TMP_DIR/dmg/DimiCheck Mac.app"
ln -s /Applications "$TMP_DIR/dmg/Applications"
hdiutil create \
  -volname "DimiCheck Mac $VERSION" \
  -srcfolder "$TMP_DIR/dmg" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

(
  cd "$DIST_DIR"
  shasum -a 256 "$(basename "$ZIP_PATH")" "$(basename "$DMG_PATH")" > "$CHECKSUM_PATH"
)

cat <<EOF
Version: $VERSION
Build: $BUILD
App: $APP_PATH
ZIP: $ZIP_PATH
DMG: $DMG_PATH
Checksums: $CHECKSUM_PATH
EOF
