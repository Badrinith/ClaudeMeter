#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="ClaudeMeter"
VOL_NAME="ClaudeMeter"
DMG_OUT="dist/${APP_NAME}.dmg"
STAGE="dist/stage"

./build.sh

rm -rf dist
mkdir -p "$STAGE"
cp -R "build/${APP_NAME}.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "Creating DMG..."
hdiutil create -volname "$VOL_NAME" \
    -srcfolder "$STAGE" \
    -ov -format UDZO \
    "$DMG_OUT"

rm -rf "$STAGE"
echo "Built $DMG_OUT"
