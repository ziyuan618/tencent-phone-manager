#!/bin/bash
set -e
echo "=== 腾讯手机管家 Build ==="

cat > main.swift << 'SWIFT'
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
SWIFT

cat > Info.plist << 'PLIST'
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

# Build with -target instead of -scheme (no xcscheme needed!)
echo "Building..."
xcodebuild \
  -project TencentManager.xcodeproj \
  -target "腾讯手机管家" \
  -sdk iphoneos \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build \
  2>&1 | tail -40

APP=$(find build -name "腾讯手机管家.app" -type d 2>/dev/null | head -1)
if [ -z "$APP" ]; then
    APP=$(find build -name "*.app" -type d 2>/dev/null | head -1)
fi
if [ -z "$APP" ]; then
    echo "FAILED"; find build -type f 2>/dev/null | head -20
    exit 1
fi
echo "App: $APP"
mkdir -p output/Payload
cp -r "$APP" output/Payload/
cd output && zip -r "../腾讯手机管家.ipa" Payload/ && cd ..
ls -lh 腾讯手机管家.ipa
echo "SUCCESS"
