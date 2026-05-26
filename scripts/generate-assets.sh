#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_LOGO="${DIMICHECK_ICON_SOURCE:-/Users/hjun1052/Documents/Codes/NormalProjects/dimicheck4/logo.png}"
RESOURCES_DIR="$ROOT_DIR/Resources"
ICONSET_DIR="$RESOURCES_DIR/AppIcon.iconset"

if [[ ! -f "$SOURCE_LOGO" ]]; then
  echo "Icon source not found: $SOURCE_LOGO" >&2
  exit 1
fi

rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR" "$RESOURCES_DIR"

for spec in \
  "16 icon_16x16.png" \
  "32 icon_16x16@2x.png" \
  "32 icon_32x32.png" \
  "64 icon_32x32@2x.png" \
  "128 icon_128x128.png" \
  "256 icon_128x128@2x.png" \
  "256 icon_256x256.png" \
  "512 icon_256x256@2x.png" \
  "512 icon_512x512.png" \
  "1024 icon_512x512@2x.png"; do
  size="${spec%% *}"
  name="${spec#* }"
  sips -z "$size" "$size" "$SOURCE_LOGO" --out "$ICONSET_DIR/$name" >/dev/null
done

iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"
rm -rf "$ICONSET_DIR"

swift - "$RESOURCES_DIR/DMGBackground.png" <<'SWIFT'
import AppKit
import Foundation

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let size = NSSize(width: 640, height: 400)
let image = NSImage(size: size)

image.lockFocus()

let rect = NSRect(origin: .zero, size: size)
let gradient = NSGradient(colors: [
    NSColor(red: 0.965, green: 0.975, blue: 0.992, alpha: 1.0),
    NSColor(red: 0.996, green: 0.955, blue: 0.970, alpha: 1.0)
])!
gradient.draw(in: rect, angle: 18)

NSColor.white.withAlphaComponent(0.72).setFill()
NSBezierPath(roundedRect: NSRect(x: 38, y: 40, width: 564, height: 310), xRadius: 34, yRadius: 34).fill()

NSColor(red: 0.12, green: 0.16, blue: 0.22, alpha: 1.0).setFill()
let title = "DimiCheck Mac" as NSString
title.draw(
    in: NSRect(x: 52, y: 310, width: 536, height: 36),
    withAttributes: [
        .font: NSFont.systemFont(ofSize: 26, weight: .bold),
        .foregroundColor: NSColor(red: 0.12, green: 0.16, blue: 0.22, alpha: 1.0)
    ]
)

let subtitle = "Drag to Applications" as NSString
subtitle.draw(
    in: NSRect(x: 52, y: 286, width: 536, height: 24),
    withAttributes: [
        .font: NSFont.systemFont(ofSize: 14, weight: .medium),
        .foregroundColor: NSColor(red: 0.38, green: 0.44, blue: 0.52, alpha: 1.0)
    ]
)

let arrowPath = NSBezierPath()
arrowPath.move(to: NSPoint(x: 246, y: 198))
arrowPath.line(to: NSPoint(x: 386, y: 198))
arrowPath.move(to: NSPoint(x: 366, y: 218))
arrowPath.line(to: NSPoint(x: 388, y: 198))
arrowPath.line(to: NSPoint(x: 366, y: 178))
NSColor(red: 0.28, green: 0.34, blue: 0.44, alpha: 0.42).setStroke()
arrowPath.lineWidth = 4
arrowPath.lineCapStyle = .round
arrowPath.lineJoinStyle = .round
arrowPath.stroke()

let footer = "If macOS blocks the beta, open System Settings > Privacy & Security and allow it." as NSString
footer.draw(
    in: NSRect(x: 52, y: 54, width: 536, height: 36),
    withAttributes: [
        .font: NSFont.systemFont(ofSize: 11, weight: .regular),
        .foregroundColor: NSColor(red: 0.45, green: 0.50, blue: 0.58, alpha: 1.0)
    ]
)

image.unlockFocus()

guard
    let tiffData = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiffData),
    let pngData = bitmap.representation(using: .png, properties: [:])
else {
    fatalError("Failed to render DMG background")
}

try pngData.write(to: outputURL)
SWIFT
