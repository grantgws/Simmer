#!/bin/bash
# Builds a Release Simmer.app and zips it for distribution.
# Usage: scripts/release.sh
#
# Before running: bump the version in Xcode (target Simmer → General → Version),
# e.g. 0.1 → 0.2. That number is what the in-app update check compares against.
set -e
cd "$(dirname "$0")/.."

echo "▸ Building Release…"
xcodebuild -project Simmer.xcodeproj -scheme Simmer -configuration Release \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO clean build >/dev/null

APP="build/Build/Products/Release/Simmer.app"
VER=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")

mkdir -p dist
rm -f "dist/Simmer.zip"
ditto -c -k --keepParent "$APP" "dist/Simmer.zip"

echo "✓ Built Simmer $VER → dist/Simmer.zip"
echo
echo "Next steps to publish the update:"
echo "  1. Notarize dist/Simmer.zip (see SIGNING.md) — required so users can open it."
echo "  2. Create a GitHub release tagged v$VER and attach dist/Simmer.zip."
echo "     gh release create v$VER dist/Simmer.zip --title \"Simmer $VER\" --notes \"…\""
echo
echo "Once the release is live, every running copy of Simmer (older than $VER)"
echo "will show \"Update available — download\" in its dropdown."
