#!/bin/bash

# This script helps fix the sandbox permission issues with the openssl_grpc framework

echo "=== WpoopedFeb Build Fix Script ==="
echo "This script will help fix the sandbox permission issues with the openssl_grpc framework"

# Step 1: Verify the rsync wrapper script exists and is executable
if [ ! -f "rsync_wrapper.sh" ] || [ ! -x "rsync_wrapper.sh" ]; then
  echo "Error: rsync_wrapper.sh not found or not executable"
  exit 1
fi

# Step 2: Verify the custom.xcconfig file exists
if [ ! -f "custom.xcconfig" ]; then
  echo "Error: custom.xcconfig not found"
  exit 1
fi

# Step 3: Verify the Pods xcconfig files include our custom config
DEBUG_XCCONFIG="Pods/Target Support Files/Pods-WpoopedFeb/Pods-WpoopedFeb.debug.xcconfig"
RELEASE_XCCONFIG="Pods/Target Support Files/Pods-WpoopedFeb/Pods-WpoopedFeb.release.xcconfig"

if ! grep -q "custom.xcconfig" "$DEBUG_XCCONFIG" || ! grep -q "custom.xcconfig" "$RELEASE_XCCONFIG"; then
  echo "Error: custom.xcconfig not included in Pods xcconfig files"
  exit 1
fi

# Step 4: Verify the frameworks script uses our rsync wrapper
FRAMEWORKS_SCRIPT="Pods/Target Support Files/Pods-WpoopedFeb/Pods-WpoopedFeb-frameworks.sh"
if ! grep -q "RSYNC_CMD" "$FRAMEWORKS_SCRIPT"; then
  echo "Error: RSYNC_CMD not found in frameworks script"
  exit 1
fi

echo "All checks passed! Your project should now build without sandbox permission issues."
echo ""
echo "Instructions for building in Xcode:"
echo "1. Close Xcode if it's open"
echo "2. Open the WpoopedFeb.xcworkspace file"
echo "3. In Xcode, go to Product > Clean Build Folder (Shift+Command+K)"
echo "4. Build the project (Command+B)"
echo ""
echo "If you still encounter issues, try these additional steps:"
echo "1. In Xcode, go to File > Project Settings and click 'Discard Changes' to reset the project state"
echo "2. Try building for the simulator instead of a physical device"
echo "3. If you have CocoaPods installed, try running 'pod deintegrate' and then 'pod install'"
echo ""
echo "Good luck!" 