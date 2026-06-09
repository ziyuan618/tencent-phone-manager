#!/bin/bash
set -e
echo "=== Build ==="

# Swift source
cat > main.swift << 'SWIFT'
import UIKit
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ app: UIApplication, didFinishLaunchingWithOptions opts: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        let vc = UIViewController()
        vc.view.backgroundColor = UIColor(red:0.04,green:0.04,blue:0.10,alpha:1)
        let l = UILabel(frame:CGRect(x:0,y:200,width:UIScreen.main.bounds.width,height:100))
        l.text = "TXGJ PRO"
        l.textColor = UIColor(red:0,green:0.94,blue:1,alpha:1)
        l.font = .boldSystemFont(ofSize:24)
        l.textAlignment = .center
        vc.view.addSubview(l)
        window!.rootViewController = vc
        window!.makeKeyAndVisible()
        return true
    }
}
UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(AppDelegate.self))
SWIFT

cat > Info.plist << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>TXGJ</string>
<key>CFBundleIdentifier</key><string>com.txg.app</string>
<key>CFBundleName</key><string>TXGJ</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSRequiresIPhoneOS</key><true/>
<key>MinimumOSVersion</key><string>14.0</string>
</dict></plist>
PLIST

# Show Xcode environment
echo "Xcode: $(xcodebuild -version 2>&1 | head -1)"
echo "SDK: $(xcrun --sdk iphoneos --show-sdk-path)"

# Try building with xcodebuild using the project
if [ -f TencentManager.xcodeproj/project.pbxproj ]; then
    echo "Using xcodebuild..."
    xcodebuild \
      -project TencentManager.xcodeproj \
      -alltargets \
      -sdk iphoneos \
      -configuration Release \
      -derivedDataPath build \
      CODE_SIGNING_ALLOWED=NO \
      build 2>&1 | tail -30
    
    APP=$(find build -name "*.app" -type d 2>/dev/null | head -1)
    if [ -n "$APP" ]; then
        cp -r "$APP" Payload/ 2>/dev/null || mkdir -p Payload && cp -r "$APP" Payload/
        cd Payload && zip -r ../TXGJ.ipa . && cd ..
        ls -lh TXGJ.ipa
        echo "SUCCESS"
        exit 0
    fi
    echo "xcodebuild produced no .app"
fi

# Fallback: direct swiftc
echo "Trying swiftc..."
SDK=$(xcrun --sdk iphoneos --show-sdk-path)
FW="$SDK/System/Library/Frameworks"

xcrun swiftc \
  -sdk "$SDK" \
  -target arm64-apple-ios14.0 \
  -F "$FW" \
  -framework UIKit \
  -framework Foundation \
  -framework CoreGraphics \
  -Xlinker -rpath -Xlinker @executable_path/Frameworks \
  -o TXGJ \
  main.swift 2>&1

echo "Compile OK: $(file TXGJ)"
mkdir -p Payload/TXGJ.app
cp TXGJ Payload/TXGJ.app/
cp Info.plist Payload/TXGJ.app/
echo "APPL????" > Payload/TXGJ.app/PkgInfo
cd Payload && zip -r ../TXGJ.ipa . && cd ..
ls -lh TXGJ.ipa
echo "SUCCESS"
