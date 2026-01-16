#!/bin/bash
# Build script for Cracked Local Whisper

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$SCRIPT_DIR/.."
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="Cracked Local Whisper"

echo "🔨 Building Cracked Local Whisper..."

# Clean build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Check if xcodegen is installed
if command -v xcodegen &> /dev/null; then
    echo "📦 Generating Xcode project with XcodeGen..."
    cd "$PROJECT_DIR/CrackedLocalWhisper"
    xcodegen generate
    cd "$PROJECT_DIR"
else
    echo "⚠️  XcodeGen not found. Install with: brew install xcodegen"
    echo "   Or use the pre-generated Xcode project."
fi

# Build the app
echo "🏗️  Building app..."
xcodebuild -project "$PROJECT_DIR/CrackedLocalWhisper/CrackedLocalWhisper.xcodeproj" \
    -scheme "CrackedLocalWhisper" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
    archive \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

# Export app
echo "📤 Exporting app..."
xcodebuild -exportArchive \
    -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
    -exportPath "$BUILD_DIR/export" \
    -exportOptionsPlist "$PROJECT_DIR/scripts/ExportOptions.plist" \
    || true

# Copy app to build directory (fallback if export fails)
if [ -d "$BUILD_DIR/$APP_NAME.xcarchive/Products/Applications/$APP_NAME.app" ]; then
    cp -R "$BUILD_DIR/$APP_NAME.xcarchive/Products/Applications/$APP_NAME.app" "$BUILD_DIR/"
fi

echo "✅ Build complete!"
echo "   App location: $BUILD_DIR/$APP_NAME.app"
