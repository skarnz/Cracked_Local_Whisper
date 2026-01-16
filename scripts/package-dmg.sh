#!/bin/bash
# DMG packaging script for Cracked Local Whisper

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$SCRIPT_DIR/.."
BUILD_DIR="$PROJECT_DIR/build"
DMG_DIR="$BUILD_DIR/dmg"
APP_NAME="Cracked Local Whisper"
DMG_NAME="CrackedLocalWhisper"
VERSION="1.0.0"

echo "📦 Packaging DMG..."

# Check if app exists
APP_PATH="$BUILD_DIR/$APP_NAME.app"
if [ ! -d "$APP_PATH" ]; then
    echo "❌ App not found at $APP_PATH"
    echo "   Run build.sh first."
    exit 1
fi

# Clean DMG directory
rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR"

# Copy app to DMG staging directory
cp -R "$APP_PATH" "$DMG_DIR/"

# Create symbolic link to Applications folder
ln -s /Applications "$DMG_DIR/Applications"

# Create DMG background and configuration
mkdir -p "$DMG_DIR/.background"

# Create README
cat > "$DMG_DIR/README.txt" << 'EOF'
Cracked Local Whisper
=====================

100% local speech-to-text powered by WhisperKit.

Installation:
1. Drag "Cracked Local Whisper" to your Applications folder
2. Open the app from Applications
3. Grant microphone permission when prompted
4. Grant accessibility permission for auto-paste feature

Usage:
- Press Cmd+` (hold) to record
- Release to transcribe and paste

The first time you use a model, it will be downloaded automatically.

For more information: https://github.com/skarnz/Cracked_Local_Whisper
EOF

# Create the DMG
DMG_PATH="$BUILD_DIR/${DMG_NAME}-${VERSION}.dmg"
TEMP_DMG="$BUILD_DIR/temp.dmg"

echo "📀 Creating DMG..."

# Create temporary DMG
hdiutil create -srcfolder "$DMG_DIR" \
    -volname "$APP_NAME" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    "$TEMP_DMG"

# Mount the DMG
MOUNT_DIR=$(hdiutil attach -readwrite -noverify "$TEMP_DMG" | grep "Volumes" | awk '{print $3}')

echo "   Mounted at: $MOUNT_DIR"

# Set DMG window appearance (AppleScript)
echo "🎨 Setting DMG appearance..."
osascript << EOF
tell application "Finder"
    tell disk "$APP_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 100, 900, 500}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 80

        -- Position items
        set position of item "$APP_NAME.app" of container window to {150, 200}
        set position of item "Applications" of container window to {350, 200}
        set position of item "README.txt" of container window to {250, 350}

        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

# Unmount
sync
hdiutil detach "$MOUNT_DIR"

# Convert to compressed DMG
hdiutil convert "$TEMP_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH"

# Clean up
rm -f "$TEMP_DMG"
rm -rf "$DMG_DIR"

echo "✅ DMG created: $DMG_PATH"
echo ""
echo "📝 To sign for distribution:"
echo "   codesign --sign \"Developer ID Application: YOUR_NAME\" \"$DMG_PATH\""
echo ""
echo "📝 To notarize:"
echo "   xcrun notarytool submit \"$DMG_PATH\" --apple-id YOUR_APPLE_ID --team-id YOUR_TEAM_ID --password YOUR_APP_PASSWORD"
