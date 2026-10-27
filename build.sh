#!/bin/zsh
# Builds Frost.app next to this script.
set -euo pipefail
cd "${0:A:h}"

APP=Frost.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

swiftc -O -target arm64-apple-macos13 Sources/*.swift -o "$APP/Contents/MacOS/Frost"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Frost</string>
  <key>CFBundleIdentifier</key><string>local.frost.lidglass</string>
  <key>CFBundleExecutable</key><string>Frost</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST

# A stable signing identity keeps the Screen Recording permission across rebuilds;
# ad-hoc signing (-) would make macOS treat every build as a new app.
IDENTITY=$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ {print $2; exit}')
codesign --force --sign "${IDENTITY:--}" "$APP"
echo "Built $PWD/$APP"

# Install where Finder and System Settings can find it, replacing a running copy.
pkill -f /Applications/Frost.app/Contents/MacOS/Frost || true
rm -rf /Applications/Frost.app
ditto "$APP" /Applications/Frost.app
echo "Installed /Applications/Frost.app"
