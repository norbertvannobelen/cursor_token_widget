#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/DerivedData/Build/Products/Debug/Cursor Tokens.app"
DEST="/Applications/Cursor Tokens.app"

if [[ ! -d "$APP" ]]; then
  echo "Build the app first: make build" >&2
  exit 1
fi

rm -rf "$DEST"
ditto "$APP" "$DEST"
xattr -dr com.apple.quarantine "$DEST" || true
open "$DEST"
echo "Installed to $DEST"
echo "Add the widget: Control-click the desktop, choose Edit Widgets, and drag Cursor Usage onto the desktop."
