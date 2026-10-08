#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
swift build --configuration release --disable-sandbox
BIN_DIR="$(swift build --configuration release --show-bin-path --disable-sandbox)"
APP="$PWD/.build/ClipboardStack.app"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN_DIR/ClipboardStack" "$APP/Contents/MacOS/ClipboardStack"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>ClipboardStack</string>
<key>CFBundleDisplayName</key><string>Clipboard Stack</string>
<key>CFBundleIdentifier</key><string>local.clipboardstack.app</string>
<key>CFBundleExecutable</key><string>ClipboardStack</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
printf 'Built %s\n' "$APP"
