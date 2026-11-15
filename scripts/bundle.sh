#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MyNotchApp"
BUNDLE_ID="com.pawalit.MyNotchApp"
CONFIG="${1:-release}"
BUILD_DIR="$ROOT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

cd "$ROOT_DIR"

echo "Building $APP_NAME ($CONFIG)..."
swift build -c "$CONFIG" --product "$APP_NAME"
BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)/$APP_NAME"

if [[ ! -f "$BIN_PATH" ]]; then
    echo "Error: binary not found at $BIN_PATH" >&2
    exit 1
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

if [[ -f "$ROOT_DIR/Sources/MediaRemoteBridge/bridge.m" ]]; then
    echo "Building MediaRemoteBridge.dylib..."
    clang -shared -fobjc-arc -framework Foundation \
        "$ROOT_DIR/Sources/MediaRemoteBridge/bridge.m" \
        -o "$RESOURCES_DIR/MediaRemoteBridge.dylib"
fi

cat > "$CONTENTS/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>MyNotchApp uses Apple Events to read Now Playing metadata and control Spotify or Apple Music.</string>
    <key>NSCameraUsageDescription</key>
    <string>MyNotchApp uses the camera for the Camera Mirror preview inside the notch.</string>
    <key>NSCalendarsFullAccessUsageDescription</key>
    <string>MyNotchApp reads upcoming calendar events to show meeting countdowns and join links.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>MyNotchApp uses the microphone for Voice-to-Notch AI commands.</string>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>MyNotchApp uses on-device speech recognition for Voice-to-Notch AI commands.</string>
</dict>
</plist>
EOF

SIGN_IDENTITY="${SIGN_IDENTITY:-}"
if [[ -z "$SIGN_IDENTITY" ]]; then
    if security find-identity -v -p codesigning | grep -q '"MyNotchApp Local Dev"'; then
        SIGN_IDENTITY="MyNotchApp Local Dev"
    else
        APPLE_DEV_ID="$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development:/ {print $2; exit}')"
        if [[ -n "$APPLE_DEV_ID" ]]; then
            SIGN_IDENTITY="$APPLE_DEV_ID"
        fi
    fi
fi

if [[ -n "$SIGN_IDENTITY" ]]; then
    echo "Signing $APP_BUNDLE with '$SIGN_IDENTITY' (TCC permissions will persist across rebuilds)..."
    codesign --force --deep --sign "$SIGN_IDENTITY" --identifier "$BUNDLE_ID" "$APP_BUNDLE"
else
    echo "Ad-hoc signing $APP_BUNDLE..."
    echo "Tip: Run ./scripts/setup-signing.sh once so Camera/Accessibility permissions survive rebuilds."
    codesign --force --deep --sign - --identifier "$BUNDLE_ID" "$APP_BUNDLE"
fi
codesign --verify --verbose=2 "$APP_BUNDLE"

echo "Done: $APP_BUNDLE"

