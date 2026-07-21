#!/bin/bash
# Builds Disk Visualizer in Release configuration and installs it into
# /Applications (or ~/Applications with -u).
#
# Usage: Scripts/install.sh [-u]
#   -u    install into ~/Applications instead of /Applications

set -euo pipefail

cd "$(dirname "$0")/.."

SCHEME="Disk Visualizer"
DEST_DIR="/Applications"

while getopts "u" opt; do
  case "$opt" in
    u) DEST_DIR="$HOME/Applications" ;;
    *) echo "Usage: $0 [-u]" >&2; exit 1 ;;
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
rm -rf "$DEST_DIR/$APP_NAME"
cp -R "$APP_PATH" "$DEST_DIR/"

echo "Installed: $DEST_DIR/$APP_NAME"
