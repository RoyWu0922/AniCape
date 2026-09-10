#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP=build/AniCape.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/AniCapeGUI "$APP/Contents/MacOS/AniCapeGUI"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>AniCape</string>
  <key>CFBundleDisplayName</key><string>AniCape</string>
  <key>CFBundleIdentifier</key><string>local.anicap.gui</string>
  <key>CFBundleExecutable</key><string>AniCapeGUI</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
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
