#!/bin/bash
# Build Simmer from source and install it to /Applications.
# Requires Xcode (free from the Mac App Store).
#
#   Clone, then run:   ./install.sh
set -e
cd "$(dirname "$0")"

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "✗ Xcode is required. Install it from the Mac App Store, then run:"
  echo "    sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

echo "▸ Building Simmer (Release)…"
xcodebuild -project Simmer.xcodeproj -scheme Simmer -configuration Release \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO clean build >/dev/null

APP="build/Build/Products/Release/Simmer.app"
echo "▸ Installing to /Applications…"
rm -rf /Applications/Simmer.app
cp -R "$APP" /Applications/

echo "▸ Launching…"
open /Applications/Simmer.app

cat <<'DONE'

✓ Simmer is installed and running (look for the crab in your menu bar).

Next:
  1. Click the crab → "Connect to Claude Code"
  2. Restart your Claude Code session(s) so the hooks load
  3. Optional: toggle "Launch at login"

To remove: click the crab → "Disconnect from Claude Code", then drag
/Applications/Simmer.app to the Trash.
DONE
