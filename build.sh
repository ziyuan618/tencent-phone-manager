#!/bin/bash
set -e
echo "Build..."

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
        l.font = UIFont.boldSystemFont(ofSize:24)
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
<key>CFBundleExecutable</key><string>Tencent</string>
<key>CFBundleIdentifier</key><string>com.tencent.phonemanager</string>
<key>CFBundleName</key><string>TXGJ</string>
<key>CFBundleDisplayName</key><string>TXGJ</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSRequiresIPhoneOS</key><true/>
<key>MinimumOSVersion</key><string>14.0</string>
<key>UIDeviceFamily</key><array><integer>1</integer><integer>2</integer></array>
</dict></plist>
PLIST

# Try simplest possible compile
SDK=$(xcrun --sdk iphoneos --show-sdk-path)
FW="$SDK/System/Library/Frameworks"
SWLIB=$(xcrun --sdk iphoneos --show-sdk-platform-path)/Developer/usr/lib

# Method: swiftc directly with all needed flags
xcrun swiftc \
  -sdk "$SDK" \
  -target arm64-apple-ios14.0 \
  -F "$FW" \
  -I "$FW" \
  -L "$SWLIB" \
  -Xlinker -rpath -Xlinker @executable_path/Frameworks \
  -Xlinker -rpath -Xlinker /usr/lib/swift \
  -Xlinker -add_empty_section -Xlinker __TEXT -Xlinker __swift5_types \
  -framework UIKit -framework Foundation -framework CoreGraphics \
  -o Tencent \
  main.swift \
  2>&1

echo "Compile OK: $(file Tencent)"

# Package
mkdir -p output/Payload/TXGJ.app
cp Tencent output/Payload/TXGJ.app/
cp Info.plist output/Payload/TXGJ.app/
echo "APPL????" > output/Payload/TXGJ.app/PkgInfo
cd output && zip -r ../TXGJ.ipa Payload/ && cd ..
ls -lh TXGJ.ipa
echo "SUCCESS"
