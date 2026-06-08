#!/bin/bash
set -e
echo "=== 腾讯手机管家 v3.0 Build ==="

APP_NAME="腾讯手机管家"
BUNDLE_ID="com.tencent.phonemanager"
SDK=$(xcrun --sdk iphoneos --show-sdk-path)
TARGET="arm64-apple-ios14.0"
OUTPUT="output"
APP="$OUTPUT/Payload/$APP_NAME.app"
SWIFT_SOURCES="Sources/*.swift"
METAL_SOURCES="Shaders/*.metal"

mkdir -p "$APP"

# 1. Compile Metal shaders → default.metallib
echo "[1/4] Compiling Metal shaders..."
xcrun -sdk iphoneos metal -c $METAL_SOURCES -o "$APP/default.metallib"

# 2. Compile Swift sources → binary
echo "[2/4] Compiling Swift..."
FWPATH="$SDK/System/Library/Frameworks"
xcrun swiftc \
  -sdk "$SDK" \
  -target "$TARGET" \
  -F "$FWPATH" \
  -O -whole-module-optimization \
  -framework UIKit \
  -framework Metal \
  -framework MetalKit \
  -framework AVFoundation \
  -framework Foundation \
  -framework CoreGraphics \
  -framework QuartzCore \
  -import-objc-header Sources/Bridging.h \
  -o "$APP/$APP_NAME" \
  $SWIFT_SOURCES

# 3. Copy resources
echo "[3/4] Packaging..."
cp Info.plist "$APP/"
cp -r Assets.xcassets/AppIcon.appiconset/*.png "$APP/" 2>/dev/null || true
echo "APPL????" > "$APP/PkgInfo"

# 4. Sign & Package IPA
echo "[4/4] Signing & zipping..."
codesign -s - --entitlements Entitlements.plist \
  --timestamp=none \
  "$APP/$APP_NAME" 2>/dev/null || true

cd "$OUTPUT"
zip -r "../$APP_NAME.ipa" Payload/
cd ..

echo "DONE: $APP_NAME.ipa"
ls -lh "$APP_NAME.ipa"
