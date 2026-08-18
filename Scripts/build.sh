#!/bin/bash
#
# Builds Keep Awake in release mode, assembles it into a proper .app bundle
# (with the LSUIElement Info.plist so it's menu-bar-only, no Dock icon),
# ad-hoc code-signs it, and packages it into a distributable wakeup.dmg.
#
# Must run on macOS with Xcode command line tools installed. Produces
# ./dist/wakeup.dmg.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="KeepAwake"
DISPLAY_NAME="Keep Awake"
BUILD_DIR="$ROOT_DIR/.build"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/${DISPLAY_NAME}.app"
DMG_NAME="wakeup.dmg"

echo "==> Cleaning previous build output"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

echo "==> Building universal (arm64 + x86_64) release binary via SwiftPM"
swift build -c release --arch arm64 --arch x86_64

BIN_PATH="$BUILD_DIR/apple/Products/Release/${APP_NAME}"
if [[ ! -f "$BIN_PATH" ]]; then
    # Fallback path used by some toolchains for single/multi-arch release builds.
    BIN_PATH="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/${APP_NAME}"
fi

if [[ ! -f "$BIN_PATH" ]]; then
    echo "error: could not locate built binary" >&2
    exit 1
fi

echo "==> Assembling ${DISPLAY_NAME}.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/${APP_NAME}"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

echo "==> Code signing (ad-hoc)"
codesign --force --deep --options runtime \
    --entitlements "$ROOT_DIR/Resources/KeepAwake.entitlements" \
    --sign - \
    "$APP_BUNDLE"

codesign --verify --deep --strict "$APP_BUNDLE"

echo "==> Building ${DMG_NAME}"
STAGING_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGING_DIR"' EXIT

cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
    -volname "$DISPLAY_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov -format UDZO \
    "$DIST_DIR/$DMG_NAME"

echo "==> Done: $DIST_DIR/$DMG_NAME"
ls -lh "$DIST_DIR/$DMG_NAME"

echo ""
echo "NOTE: this build is ad-hoc signed only (no Apple Developer ID / notarization"
echo "credentials were used). First launch will require right-click > Open, or"
echo "'xattr -dr com.apple.quarantine \"${DISPLAY_NAME}.app\"' after mounting the DMG."
