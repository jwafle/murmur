#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Murmur"
BUNDLE_ID="com.murmur.app"
MIN_SYSTEM_VERSION="26.0"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
cd "$ROOT_DIR"
swift build --scratch-path "$ROOT_DIR/.build"
BUILD_BIN_DIR="$(swift build --scratch-path "$ROOT_DIR/.build" --show-bin-path)"
BUILD_BINARY="$BUILD_BIN_DIR/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_CONTENTS/Frameworks"
# The release ZIP expands framework symlinks into duplicate directories.
# Restore the standard versioned framework layout in the staged app.
FRAMEWORK="$APP_CONTENTS/Frameworks/CTranscribe.framework"
mkdir -p "$FRAMEWORK/Versions"
cp -R "$ROOT_DIR/vendor/TranscribeCpp.xcframework/macos-arm64_x86_64/CTranscribe.framework/Versions/A" "$FRAMEWORK/Versions/A"
ln -s A "$FRAMEWORK/Versions/Current"
for ITEM in CTranscribe Headers Modules Resources; do
  ln -s "Versions/Current/$ITEM" "$FRAMEWORK/$ITEM"
done
mkdir -p "$APP_CONTENTS/Resources/ThirdPartyLicenses"
cp -R "$BUILD_BIN_DIR/${APP_NAME}_Murmur.bundle" "$APP_CONTENTS/Resources/"
cp "$ROOT_DIR/vendor/TranscribeCpp.xcframework/LICENSE" "$APP_CONTENTS/Resources/ThirdPartyLicenses/transcribe.cpp.txt"
cp "$ROOT_DIR/vendor/TranscribeCpp.xcframework/LICENSE.ggml" "$APP_CONTENTS/Resources/ThirdPartyLicenses/ggml.txt"
cp "$BUILD_BINARY" "$APP_MACOS/$APP_NAME"
chmod +x "$APP_MACOS/$APP_NAME"
if ! /usr/bin/otool -l "$APP_MACOS/$APP_NAME" | /usr/bin/grep -q '@executable_path/../Frameworks'; then
  /usr/bin/install_name_tool -add_rpath @executable_path/../Frameworks "$APP_MACOS/$APP_NAME"
fi
cat >"$APP_CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSMicrophoneUsageDescription</key><string>Murmur listens for dictation and keeps a short in-memory audio buffer for pre-roll.</string>
  <key>NSSpeechRecognitionUsageDescription</key><string>The optional Apple Speech model transcribes your dictation on this Mac.</string>
</dict>
</plist>
PLIST

# Sign the completed bundle, including its identifier, plist and resources.
# Use a persistent Apple Development / Developer ID identity when available so
# privacy grants survive code changes. Ad hoc local builds need a fresh grant
# after their code changes; they must still have a valid bundle signature.
SIGNING_IDENTITY="${MURMUR_SIGNING_IDENTITY:--}"
/usr/bin/codesign --force --sign "$SIGNING_IDENTITY" "$APP_CONTENTS/Frameworks/CTranscribe.framework"
/usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --identifier "$BUNDLE_ID" "$APP_BUNDLE"
/usr/bin/codesign --verify --strict "$APP_BUNDLE"

open_app() { /usr/bin/open -n "$APP_BUNDLE"; }
case "$MODE" in
  run) open_app ;;
  --debug|debug) lldb -- "$APP_MACOS/$APP_NAME" ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *) echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2; exit 2 ;;
esac
