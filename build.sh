#!/bin/bash
set -e
echo "=== 腾讯手机管家 Build ==="

APP="腾讯手机管家"
BUNDLE="com.tencent.phonemanager"
OUTPUT="output"
APP_DIR="$OUTPUT/Payload/$APP.app"
mkdir -p "$APP_DIR"

# 1. Metal shaders
echo "[1/3] Metal..."
xcrun -sdk iphoneos metal -c Shaders/shaders.metal -o "$APP_DIR/default.metallib" 2>/dev/null || echo "  (Metal skipped, no shaders needed for shell)"

# 2. Create Xcode project on-the-fly
echo "[2/3] Creating project..."
cat > build_app.swift << 'EOF'
import Foundation
import ProjectBuilder
// We'll use a different approach - direct xcodebuild with a generated project
EOF

# Use a pre-made xcconfig approach instead
SDK=$(xcrun --sdk iphoneos --show-sdk-path)
FW="$SDK/System/Library/Frameworks"

# Write the Swift source
cat > "$APP_DIR/main.swift" << 'SWIFT'
import UIKit
@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ app: UIApplication, didFinishLaunchingWithOptions opts: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UIViewController()
        window?.backgroundColor = UIColor(red:0.04, green:0.04, blue:0.10, alpha:1)
        let l = UILabel(frame: CGRect(x:0,y:200,width:UIScreen.main.bounds.width,height:100))
        l.text = "腾讯手机管家 PRO"
        l.textColor = UIColor(red:0,green:0.94,blue:1,alpha:1)
        l.font = UIFont.boldSystemFont(ofSize:24)
        l.textAlignment = .center
        window?.makeKeyAndVisible()
        return true
    }
}
SWIFT

# Compile with xcrun (proper SDK setup)
xcrun swiftc \
  -sdk "$SDK" \
  -target arm64-apple-ios14.0 \
  -F "$FW" \
  -Xlinker -rpath -Xlinker @executable_path/Frameworks \
  -framework UIKit -framework Foundation -framework CoreGraphics \
  -o "$APP_DIR/$APP" \
  "$APP_DIR/main.swift" \
  2>&1

echo "[3/3] Packaging..."
cp Info.plist "$APP_DIR/"
echo "APPL????" > "$APP_DIR/PkgInfo"
codesign -s - "$APP_DIR/$APP" 2>/dev/null || true

cd "$OUTPUT" && zip -r "../$APP.ipa" Payload/ && cd ..
echo "DONE: $APP.ipa"
ls -lh "$APP.ipa"
