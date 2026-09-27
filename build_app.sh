#!/usr/bin/env bash
set -e

echo "🔨 Building Lyricora in Release mode..."
swift build -c release

APP_NAME="Lyricora.app"
BUNDLE_DIR="./build/$APP_NAME"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "📦 Assembling macOS application bundle: $APP_NAME..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp .build/release/Lyricora "$MACOS_DIR/Lyricora"
chmod +x "$MACOS_DIR/Lyricora"

cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Lyricora</string>
    <key>CFBundleIdentifier</key>
    <string>com.r1hix.lyricora</string>
    <key>CFBundleName</key>
    <string>Lyricora</string>
    <key>CFBundleDisplayName</key>
    <string>Lyricora</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>Lyricora requires permission to sync playback state and control Spotify.</string>
</dict>
</plist>
EOF

echo "✅ Successfully built $APP_NAME in ./build/"
echo "🚀 To launch: open $BUNDLE_DIR"
