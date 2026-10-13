#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-1.0.3}"
VERSION="${VERSION#v}"

echo "==> Bundling AulaDriverApp.app (Version: ${VERSION})..."

mkdir -p AulaDriverApp.app/Contents/MacOS
mkdir -p AulaDriverApp.app/Contents/Resources

cp Resources/AppIcon.icns AulaDriverApp.app/Contents/Resources/AppIcon.icns
cp .build/universal/release/AulaDriverApp AulaDriverApp.app/Contents/MacOS/AulaDriverApp

cat << EOF > AulaDriverApp.app/Contents/Info.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>AulaDriverApp</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.aulakit.driver</string>
    <key>CFBundleName</key>
    <string>Aula Driver</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

codesign --force --deep --sign - AulaDriverApp.app
echo "==> Successfully bundled and signed AulaDriverApp.app"
