#!/bin/bash

# Build and Run iOS App Script
# Usage: ./build_and_run.sh [simulator_name]

# Default simulator
SIMULATOR_NAME="${1:-iPhone 16 Pro}"
PROJECT_NAME="Ruuvi"
SCHEME="station"
BUNDLE_ID="com.ruuvi.station"

echo "🔄 Starting build and run process..."
echo "📱 Target Simulator: $SIMULATOR_NAME"
echo ""

# Step 1: Regenerate project
echo "🔧 Regenerating Xcode project..."
xcodegen generate
if [ $? -ne 0 ]; then
    echo "❌ Failed to regenerate project"
    exit 1
fi
echo "✅ Project regenerated successfully"
echo ""

# Step 2: Clean build (optional)
echo "🧹 Cleaning previous builds..."
xcodebuild -project "$PROJECT_NAME.xcodeproj" -scheme "$SCHEME" clean > /dev/null 2>&1
echo "✅ Clean completed"
echo ""

# Step 3: Build the app
echo "🔨 Building iOS app..."
BUILD_OUTPUT=$(xcodebuild \
    -project "$PROJECT_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -sdk iphonesimulator \
    -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" \
    build 2>&1)

BUILD_STATUS=$?
if [ $BUILD_STATUS -ne 0 ]; then
    echo "❌ Build failed!"
    echo "$BUILD_OUTPUT" | grep -i error | head -5
    exit 1
fi
echo "✅ Build completed successfully"
echo ""

# Step 4: Boot simulator
echo "📱 Starting simulator..."
xcrun simctl boot "$SIMULATOR_NAME" 2>/dev/null || true
sleep 2
echo "✅ Simulator started"
echo ""

# Step 5: Install app
echo "📦 Installing app..."
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "$SCHEME.app" -type d | head -1)
if [ -z "$APP_PATH" ]; then
    echo "❌ Could not find built app"
    exit 1
fi

xcrun simctl install booted "$APP_PATH"
if [ $? -ne 0 ]; then
    echo "❌ Failed to install app"
    exit 1
fi
echo "✅ App installed successfully"
echo ""

# Step 6: Launch app
echo "🚀 Launching app..."
xcrun simctl launch booted "$BUNDLE_ID"
if [ $? -ne 0 ]; then
    echo "❌ Failed to launch app"
    exit 1
fi
echo "✅ App launched successfully"
echo ""

# Step 7: Open Simulator app (if not already open)
echo "📱 Opening Simulator app..."
open -a Simulator

echo ""
echo "🎉 Build and run completed successfully!"
echo "💡 The app is now running in $SIMULATOR_NAME"
