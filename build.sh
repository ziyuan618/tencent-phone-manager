#!/bin/bash
set -e
echo "=== 腾讯手机管家 v4.0 Build ==="

APP="腾讯手机管家"
OUTPUT="output"
APP_DIR="$OUTPUT/Payload/$APP.app"
mkdir -p "$APP_DIR"

SDK=$(xcrun --sdk iphoneos --show-sdk-path)
FW="$SDK/System/Library/Frameworks"
SWIFT_LIB=$(xcrun --sdk iphoneos --show-sdk-platform-path)/Developer/usr/lib
echo "SDK: $SDK"

# Swift source
cat > Sources/main.swift << 'EOF'
import UIKit
@main class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ app: UIApplication, didFinishLaunchingWithOptions opts: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        let vc = UIViewController()
        vc.view.backgroundColor = UIColor(red:0.04,green:0.04,blue:0.10,alpha:1)
        let l = UILabel(frame:CGRect(x:0,y:200,width:UIScreen.main.bounds.width,height:100))
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

# Step 1: Compile to .o
echo "[1/3] Compiling Swift..."
xcrun swiftc -c \
  -sdk "$SDK" \
  -target arm64-apple-ios14.0 \
  -F "$FW" \
  -O \
  Sources/main.swift \
  -o main.o \
  2>&1

# Step 2: Link
echo "[2/3] Linking..."
xcrun clang -arch arm64 \
  -isysroot "$SDK" \
  -mios-version-min=14.0 \
  -F "$FW" \
  -L "$SWIFT_LIB" \
  -Xlinker -rpath -Xlinker @executable_path/Frameworks \
  -Xlinker -rpath -Xlinker /usr/lib/swift \
  -Xlinker -add_empty_section -Xlinker __TEXT -Xlinker __swift5_types \
  main.o \
  -o "$APP_DIR/$APP" \
  -framework UIKit -framework Foundation -framework CoreGraphics \
  -lSystem \
  2>&1

echo "[3/3] Packaging..."
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
<key>UIDeviceFamily</key><array><integer>1</integer><integer>2</integer></array>
</dict></plist>
PLIST
echo "APPL????" > "$APP_DIR/PkgInfo"

codesign -s - "$APP_DIR/$APP" 2>/dev/null || true
cd "$OUTPUT" && zip -r "../$APP.ipa" Payload/ && cd ..

ls -lh "$APP.ipa"
file "$APP_DIR/$APP"
echo "DONE"
