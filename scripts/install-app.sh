#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SOURCE="$ROOT/dist/Simple Screenshot.app"
USER_HOME=$(CDPATH= cd -- ~ && pwd)
APPLICATIONS_DIR=${APPLICATIONS_DIR:-"$USER_HOME/Applications"}
DESTINATION="$APPLICATIONS_DIR/Simple Screenshot.app"

if [ ! -d "$SOURCE" ]; then
  echo "App bundle not found: $SOURCE" >&2
  echo "Run 'make app' first." >&2
  exit 1
fi

mkdir -p "$APPLICATIONS_DIR"
ditto "$SOURCE" "$DESTINATION"

# Make the app immediately discoverable by Launchpad, Spotlight, Raycast, etc.
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [ -x "$LSREGISTER" ]; then
  "$LSREGISTER" -f "$DESTINATION"
fi

echo "Installed: $DESTINATION"
