#!/bin/sh
# Builds PurgeBar.app next to this script. Copy it to /Applications if you like.
set -e
cd "$(dirname "$0")"
APP=PurgeBar.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
swiftc -O main.swift -o "$APP/Contents/MacOS/PurgeBar"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>PurgeBar</string>
  <key>CFBundleIdentifier</key><string>local.purgebar</string>
  <key>CFBundleExecutable</key><string>PurgeBar</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "Built $(pwd)/$APP"
