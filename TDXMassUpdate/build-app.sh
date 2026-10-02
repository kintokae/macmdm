#!/bin/bash
# Builds "TDX Mass Update.app" from the Swift package (ad-hoc signed).
set -euo pipefail
cd "$(dirname "$0")"

APP="TDX Mass Update.app"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/TDXMassUpdate"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/TDXMassUpdate"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>TDXMassUpdate</string>
  <key>CFBundleIdentifier</key><string>edu.example.TDXMassUpdate</string>
  <key>CFBundleName</key><string>TDX Mass Update</string>
  <key>CFBundleDisplayName</key><string>TDX Mass Update</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>CFBundleIconFile</key><string>AppIcon</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP"
echo "Built $APP"
