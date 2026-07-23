#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUILD="$ROOT/.build/release"
APP="$ROOT/dist/Simple Screenshot.app"

# Prefer the full Xcode toolchain when xcode-select currently points at the
# standalone Command Line Tools, whose compiler and SDK can get out of sync.
if [ -z "${DEVELOPER_DIR:-}" ] && [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
  DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
  export DEVELOPER_DIR
fi

cd "$ROOT"
swift build --disable-sandbox -c release
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BUILD/SimpleScreenshot" "$APP/Contents/MacOS/SimpleScreenshot"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
# Keep the designated requirement stable across local ad-hoc builds. macOS
# stores this requirement with privacy grants such as Screen Recording.
codesign --force --sign - \
  --requirements '=designated => identifier "jp.shoirhi.simple-screenshot"' \
  "$APP"
echo "$APP"
