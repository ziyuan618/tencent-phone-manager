#!/bin/bash
set -e
echo "=== 腾讯手机管家 xcodebuild ==="

# Create source
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

# Create Info.plist
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

echo "Building..."
xcodebuild \
  -project TencentManager.xcodeproj \
  -scheme "腾讯手机管家" \
  -sdk iphoneos \
  -configuration Release \
  -derivedDataPath build \
  -archivePath build/App.xcarchive \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  ONLY_ACTIVE_ARCH=NO \
  archive \
  2>&1 | tail -30

# Copy app from archive
APP=$(find build -name "腾讯手机管家.app" -type d | head -1)
if [ -z "$APP" ]; then
    echo "ERROR: No .app found in build output"
    find build -name "*.app" -type d 2>/dev/null
    exit 1
fi

echo "Found app: $APP"
mkdir -p output/Payload
cp -r "$APP" output/Payload/
cd output && zip -r "../腾讯手机管家.ipa" Payload/ && cd ..

ls -lh 腾讯手机管家.ipa
echo "BUILD SUCCESS"
