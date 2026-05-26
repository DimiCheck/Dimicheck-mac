#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/app/DimiCheck Mac.app"
EXECUTABLE="$ROOT_DIR/.build/release/DimiCheckMac"

cd "$ROOT_DIR"
"$ROOT_DIR/scripts/generate-assets.sh"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/DimiCheckMac"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
cp "$ROOT_DIR/Resources/DMGBackground.png" "$APP_DIR/Contents/Resources/DMGBackground.png"

chmod +x "$APP_DIR/Contents/MacOS/DimiCheckMac"
codesign --force --deep --sign - "$APP_DIR" >/dev/null
codesign --verify --deep --strict "$APP_DIR"

echo "$APP_DIR"
