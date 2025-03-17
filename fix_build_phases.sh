#!/bin/bash

# This script modifies the Xcode project to uncheck "Based on dependency analysis" 
# for the "Create Symlinks to Header Folders" build phases

# Path to the project.pbxproj file
PBXPROJ_PATH="Pods/Pods.xcodeproj/project.pbxproj"

if [ ! -f "$PBXPROJ_PATH" ]; then
  echo "Error: $PBXPROJ_PATH not found"
  exit 1
fi

# Backup the original file
cp "$PBXPROJ_PATH" "${PBXPROJ_PATH}.bak"

# Find all script build phases with "Create Symlinks to Header Folders" and modify them
# to set runOnlyForDeploymentPostprocessing = 1 (which means "Based on dependency analysis" is unchecked)
sed -i '' 's/\(name = "Create Symlinks to Header Folders".*runOnlyForDeploymentPostprocessing = \)0;/\11;/g' "$PBXPROJ_PATH"

echo "Modified $PBXPROJ_PATH to uncheck 'Based on dependency analysis' for header symlink build phases"
echo "Original file backed up to ${PBXPROJ_PATH}.bak" 