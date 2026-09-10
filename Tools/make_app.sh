#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP=build/anicap.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/anicap-gui "$APP/Contents/MacOS/anicap-gui"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>anicap</string>
  <key>CFBundleDisplayName</key><string>anicap</string>
  <key>CFBundleIdentifier</key><string>local.anicap.gui</string>
  <key>CFBundleExecutable</key><string>anicap-gui</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

plutil -lint "$APP/Contents/Info.plist"
echo "✅ $APP"
