#!/bin/bash
set -e
echo "=== 腾讯手机管家 v3.0 Build ==="

APP_NAME="腾讯手机管家"
BUNDLE_ID="com.tencent.phonemanager"
TARGET="14.0"
OUTPUT="output"
APP="$OUTPUT/Payload/$APP_NAME.app"

mkdir -p "$APP"

# 1. Compile Metal shaders
echo "[1/4] Metal shaders..."
xcrun -sdk iphoneos metal -c Sources/Shaders.metal -o "$APP/default.metallib" 2>/dev/null || true

# 2. Generate minimal Xcode project + build
echo "[2/4] Building with xcodebuild..."

# Create a minimal Swift file that's the app entry
cat > main.swift << 'SWIFTEOF'
import UIKit
@main class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ app: UIApplication, didFinishLaunchingWithOptions opts: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UIViewController()
        window?.rootViewController?.view.backgroundColor = UIColor(red: 0.04, green: 0.04, blue: 0.10, alpha: 1)
        let label = UILabel(frame: CGRect(x: 0, y: 200, width: UIScreen.main.bounds.width, height: 100))
        label.text = "⬡ 腾讯手机管家 PRO"
        label.textColor = UIColor(red: 0, green: 0.94, blue: 1, alpha: 1)
        label.font = UIFont.boldSystemFont(ofSize: 22)
        label.textAlignment = .center
        window?.makeKeyAndVisible()
        return true
    }
}
SWIFTEOF

# Build using swiftc for iOS
SDK=$(xcrun --sdk iphoneos --show-sdk-path)
FW="$SDK/System/Library/Frameworks"

xcrun swiftc \
  -sdk "$SDK" \
  -target arm64-apple-ios14.0 \
  -F "$FW" \
  -framework UIKit \
  -framework Foundation \
  -framework CoreGraphics \
  -framework Metal \
  -framework MetalKit \
  -framework AVFoundation \
  -Xlinker -rpath -Xlinker @executable_path/Frameworks \
  -o "$APP/$APP_NAME" \
  main.swift \
  2>&1 | tail -5

# 3. Copy resources  
echo "[3/4] Packaging..."
cp Info.plist "$APP/"
echo "APPL????" > "$APP/PkgInfo"

# 4. Sign & IPA
echo "[4/4] Signing & zipping..."
codesign -s - "$APP/$APP_NAME" 2>/dev/null || true
cd "$OUTPUT" && zip -r "../$APP_NAME.ipa" Payload/ && cd ..

echo "DONE: $APP_NAME.ipa"
ls -lh "$APP_NAME.ipa"
