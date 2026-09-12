#!/bin/zsh
# Assembles a double-clickable Fovea.app from the SwiftPM build.
# Usage: scripts/bundle-app.sh [debug|release]   → build/Fovea.app
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-release}"
cd "$ROOT"
swift build -c "$CONFIG"
BIN="$ROOT/.build/$CONFIG"
APP_NAME="${APP_NAME:-Fovea}"
APP="$ROOT/build/$APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Fovea" "$APP/Contents/MacOS/Fovea"
cp -R "$BIN/Fovea_FoveaCore.bundle" "$APP/Contents/Resources/"
if [ -n "${REHEARSAL_DATA:-}" ]; then cp "$REHEARSAL_DATA" "$APP/Contents/Resources/rehearsal-data.json"; fi
# App icon: convert the bundled PNG into an .icns.
ICONSET="$ROOT/build/AppIcon.iconset"
rm -rf "$ICONSET"; mkdir -p "$ICONSET"
SRC="$ROOT/Sources/FoveaCore/Resources/AppIcon.png"
for size in 16 32 128 256 512; do
  sips -z $size $size "$SRC" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size*2)) $((size*2)) "$SRC" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID:-app.fovea.prototype}</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleExecutable</key><string>Fovea</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSMicrophoneUsageDescription</key><string>Fovea listens after you press the VoiceFlow shortcut so it can transcribe your intent.</string>
  <key>NSScreenCaptureUsageDescription</key><string>Fovea captures the region you point at so it can be sent along with your words.</string>
  <key>NSAccessibilityUsageDescription</key><string>Fovea needs Accessibility to notice the fn shortcut in any app, read on-screen text and track gaze targets.</string>
  <key>NSSpeechRecognitionUsageDescription</key><string>Fovea transcribes your words on this Mac between two presses of the VoiceFlow shortcut.</string>
</dict>
</plist>
PLIST
# Sign with a stable identity so macOS keeps Accessibility / Microphone trust across
# rebuilds (ad-hoc signatures change their hash every build and lose the grants).
# Override with CODESIGN_IDENTITY=…; falls back to ad-hoc when no identity exists.
IDENTITY="${CODESIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | grep -o '"Apple Development[^"]*"' | head -1 | tr -d '"')}"
if [[ -n "$IDENTITY" ]]; then
  codesign --force --deep --sign "$IDENTITY" "$APP" 2>&1 | grep -v "replacing existing signature" || true
  echo "signed as $IDENTITY"
else
  codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
  echo "signed ad hoc (no identity found)"
fi
echo "built $APP"
