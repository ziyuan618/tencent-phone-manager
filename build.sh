#!/bin/bash
set -e
echo "=== 腾讯手机管家 CI Build ==="

APP="腾讯手机管家"
OUTPUT="output"
APP_DIR="$OUTPUT/Payload/$APP.app"
mkdir -p "$APP_DIR"

# Find SDK
SDK=$(xcrun --sdk iphoneos --show-sdk-path)
SWIFT_LIB=$(xcrun --sdk iphoneos --show-sdk-platform-path)/Developer/usr/lib
echo "SDK: $SDK"

# Create minimal Swift source
cat > main.swift << 'EOF'
import UIKit
@main class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ app: UIApplication, didFinishLaunchingWithOptions opts: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        let vc = UIViewController()
        vc.view.backgroundColor = UIColor(red:0.04,green:0.04,blue:0.10,alpha:1)
        let l = UILabel(frame: CGRect(x:0,y:200,width:UIScreen.main.bounds.width,height:100))
        l.text = "腾讯手机管家 PRO"
        l.textColor = UIColor(red:0,green:0.94,blue:1,alpha:1)
        l.font = UIFont.boldSystemFont(ofSize:24)
        l.textAlignment = .center
        vc.view.addSubview(l)
        window!.rootViewController = vc
        window!.makeKeyAndVisible()
        return true
    }
}
EOF

# Compile as iOS executable
echo "Compiling..."
swiftc \
  -sdk "$SDK" \
  -target arm64-apple-ios14.0 \
  -F "$SDK/System/Library/Frameworks" \
  -L "$SWIFT_LIB" \
  -lswiftUIKit \
  -framework UIKit \
  -framework Foundation \
  -framework CoreGraphics \
  -Xlinker -rpath -Xlinker @executable_path/Frameworks \
  -Xlinker -rpath -Xlinker /usr/lib/swift \
  -o "$APP_DIR/$APP" \
  main.swift \
  2>&1

echo "Packaging..."
cp Info.plist "$APP_DIR/" 2>/dev/null || cat > "$APP_DIR/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>腾讯手机管家</string>
<key>CFBundleIdentifier</key><string>com.tencent.phonemanager</string>
<key>CFBundleName</key><string>腾讯手机管家</string>
<key>CFBundleDisplayName</key><string>腾讯手机管家</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSRequiresIPhoneOS</key><true/>
<key>MinimumOSVersion</key><string>14.0</string>
<key>UIDeviceFamily</key><array><integer>1</integer></array>
</dict></plist>
PLIST

echo "APPL????" > "$APP_DIR/PkgInfo"

# Fake sign (TrollStore will handle real signing)
codesign -s - "$APP_DIR/$APP" 2>/dev/null || true

# Package
cd "$OUTPUT"
zip -r "../$APP.ipa" Payload/
cd ..

ls -lh "$APP.ipa"
echo "BUILD SUCCESS"
