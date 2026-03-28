#!/bin/bash
# MacMonitor — remove macOS quarantine flag so the app opens without a security warning

APP="/Applications/MacMonitor.app"

if [ ! -d "$APP" ]; then
  echo ""
  echo "MacMonitor.app not found in /Applications."
  echo "Please drag MacMonitor.app to your Applications folder first, then run this script again."
  echo ""
  read -n 1 -s -r -p "Press any key to close..."
  exit 1
fi

echo ""
echo "Removing macOS quarantine flag from MacMonitor..."
xattr -dr com.apple.quarantine "$APP"
echo "Done! MacMonitor is ready to open."
echo ""
open "$APP"
