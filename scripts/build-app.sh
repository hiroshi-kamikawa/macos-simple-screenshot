#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUILD="$ROOT/.build/release"
APP="$ROOT/dist/Simple Screenshot.app"

cd "$ROOT"
swift build -c release
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BUILD/SimpleScreenshot" "$APP/Contents/MacOS/SimpleScreenshot"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "$APP"
