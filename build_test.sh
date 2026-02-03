#!/bin/bash

# Test build script for SunHat app
# This script builds the app with proper iOS 18.5 configuration

echo "Starting SunHat build test..."
echo "Targeting iOS 18.5 with Swift 6.0..."

# Clean previous builds
echo "Cleaning previous builds..."
xcodebuild clean -project SunHat.xcodeproj -scheme SunHat

# Build for iOS Simulator with proper configuration
echo "Building for iOS Simulator (iPhone 16, iOS 18.5)..."
xcodebuild \
  -project SunHat.xcodeproj \
  -scheme SunHat \
  -sdk iphonesimulator \
  -destination "platform=iOS Simulator,name=iPhone 16,OS=18.5" \
  -configuration Debug \
  ONLY_ACTIVE_ARCH=YES \
  ENABLE_PREVIEWS_BUILD=NO

# Check build result
if [ $? -eq 0 ]; then
  echo "✅ Build succeeded!"
  echo "The app should now be compatible with iOS 18.5 and ready for iOS 26 updates."
else
  echo "❌ Build failed!"
  echo "Please check the error messages above for details."
  exit 1
fi