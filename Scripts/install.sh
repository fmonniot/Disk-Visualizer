#!/bin/bash
# Builds Disk Visualizer in Release configuration and installs it into
# ~/Applications (or /Applications with -a).
#
# Usage: Scripts/install.sh [-a]
#   -a    install into /Applications instead of ~/Applications (uses sudo)

set -euo pipefail

cd "$(dirname "$0")/.."

SCHEME="Disk Visualizer"
DEST_DIR="$HOME/Applications"
USE_SUDO=0

while getopts "a" opt; do
  case "$opt" in
    a) DEST_DIR="/Applications"; USE_SUDO=1 ;;
    *) echo "Usage: $0 [-a]" >&2; exit 1 ;;
  esac
done

BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

echo "Building $SCHEME (Release)..."
xcodebuild -scheme "$SCHEME" -configuration Release \
  -destination "platform=macOS" \
  -derivedDataPath "$BUILD_DIR" \
  build

APP_PATH="$(find "$BUILD_DIR/Build/Products/Release" -maxdepth 1 -name "*.app" -print -quit)"
if [[ -z "$APP_PATH" ]]; then
  echo "error: could not find built .app in $BUILD_DIR/Build/Products/Release" >&2
  exit 1
fi

APP_NAME="$(basename "$APP_PATH")"
mkdir -p "$DEST_DIR"

echo "Installing $APP_NAME to $DEST_DIR..."
if [[ "$USE_SUDO" -eq 1 ]]; then
  sudo rm -rf "$DEST_DIR/$APP_NAME"
  sudo cp -R "$APP_PATH" "$DEST_DIR/"
else
  rm -rf "$DEST_DIR/$APP_NAME"
  cp -R "$APP_PATH" "$DEST_DIR/"
fi

echo "Installed: $DEST_DIR/$APP_NAME"
