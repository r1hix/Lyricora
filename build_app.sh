#!/usr/bin/env bash
set -e

echo "🔨 Building Lyricora in Universal Release mode (arm64 + x86_64)..."
swift build -c release --arch arm64 --arch x86_64

# Locate output universal binary
BIN_PATH=""
if [ -f ".build/out/Products/Release/Lyricora" ]; then
    BIN_PATH=".build/out/Products/Release/Lyricora"
elif [ -f ".build/apple/Products/Release/Lyricora" ]; then
    BIN_PATH=".build/apple/Products/Release/Lyricora"
elif [ -f ".build/release/Lyricora" ]; then
    BIN_PATH=".build/release/Lyricora"
else
    BIN_PATH=$(find .build -name "Lyricora" -type f ! -path "*.dSYM*" ! -path "*Objects*" | head -n 1)
fi

if [ -z "$BIN_PATH" ] || [ ! -f "$BIN_PATH" ]; then
    echo "❌ Error: Could not locate compiled Lyricora binary in .build"
    exit 1
fi

APP_NAME="Lyricora.app"
BUNDLE_DIR="./build/$APP_NAME"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "📦 Assembling macOS application bundle: $APP_NAME..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp "$BIN_PATH" "$MACOS_DIR/Lyricora"
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
file "$MACOS_DIR/Lyricora"
echo "🚀 To launch: open $BUNDLE_DIR"
