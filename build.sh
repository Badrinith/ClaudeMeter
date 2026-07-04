#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP="ClaudeMeter.app"
BUILD="build"
CONTENTS="$BUILD/$APP/Contents"

rm -rf "$BUILD/$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

echo "Compiling..."
# Pin the deployment target so LaunchServices doesn't reject the app with
# kLSIncompatibleSystemVersionErr (-10825) when the toolchain defaults minos
# to a version newer than the running OS.
swiftc -O \
    -target arm64-apple-macos13.0 \
    -o "$CONTENTS/MacOS/ClaudeMeter" \
    Sources/*.swift \
    -framework Cocoa -framework SwiftUI

cp Info.plist "$CONTENTS/Info.plist"

# Ad-hoc sign so macOS is happy launching a locally built app.
codesign --force --deep --sign - "$BUILD/$APP" 2>/dev/null || true

echo "Built $BUILD/$APP"
