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
DMG_RW_PATH="$TMP_DIR/$ARCHIVE_NAME-rw.dmg"
VOLUME_NAME="DimiCheck Mac $VERSION"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

detach_conflicting_volumes() {
  local volume_path
  for volume_path in "/Volumes/$VOLUME_NAME" "/Volumes/$VOLUME_NAME "*; do
    [[ -e "$volume_path" ]] || continue
    hdiutil detach "$volume_path" >/dev/null 2>&1 || true
  done
}

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

mkdir -p "$TMP_DIR/dmg"
ditto "$APP_PATH" "$TMP_DIR/dmg/DimiCheck Mac.app"
ln -s /Applications "$TMP_DIR/dmg/Applications"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$TMP_DIR/dmg" \
  -ov \
  -format UDRW \
  "$DMG_RW_PATH" >/dev/null

detach_conflicting_volumes
MOUNT_DIR="$(hdiutil attach "$DMG_RW_PATH" -nobrowse -readwrite -noverify | awk 'index($0, "/Volumes/") {print substr($0, index($0, "/Volumes/")); exit}')"
if [[ -z "$MOUNT_DIR" || ! -d "$MOUNT_DIR" ]]; then
  echo "Failed to mount staging dmg" >&2
  exit 1
fi

if command -v SetFile >/dev/null 2>&1; then
  SetFile -a C "$MOUNT_DIR" || true
fi

osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$VOLUME_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {100, 100, 740, 500}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 96
    set background picture of viewOptions to (POSIX file "$MOUNT_DIR/DimiCheck Mac.app/Contents/Resources/DMGBackground.png" as alias)
    set position of item "DimiCheck Mac.app" of container window to {160, 205}
    set position of item "Applications" of container window to {480, 205}
    update without registering applications
  end tell
  delay 1
  close container window of disk "$VOLUME_NAME"
end tell
APPLESCRIPT

sync
sync
hdiutil detach "$MOUNT_DIR" >/dev/null
hdiutil convert "$DMG_RW_PATH" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" >/dev/null

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
