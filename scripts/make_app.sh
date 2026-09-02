#!/bin/bash
# TTALGAK.app 번들 생성: ./scripts/make_app.sh [버전]
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-0.1.0}"
APP=dist/TTALGAK.app

swift build -c release --arch arm64 --arch x86_64

rm -rf dist
mkdir -p "$APP/Contents/MacOS"
cp .build/apple/Products/Release/ttalgak "$APP/Contents/MacOS/ttalgak"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>TTALGAK</string>
    <key>CFBundleDisplayName</key><string>TTALGAK</string>
    <key>CFBundleIdentifier</key><string>com.littleduck.ttalgak</string>
    <key>CFBundleExecutable</key><string>ttalgak</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

codesign --force --deep -s - "$APP"   # ad-hoc 서명 (Apple Silicon 실행 요건)
ditto -c -k --keepParent "$APP" "dist/TTALGAK-v${VERSION}.zip"
echo "made: dist/TTALGAK-v${VERSION}.zip"
