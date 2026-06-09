#!/bin/bash
# 腾讯手机管家 - Mac 一键编译脚本
# 在 Mac 终端里运行: chmod +x build.sh && ./build.sh

set -e
echo "=== 腾讯手机管家 编译 ==="

# 1. 检查环境
echo "[1/5] 检查 Xcode..."
xcodebuild -version 2>&1 | head -3

# 2. 创建项目
echo "[2/5] 创建项目..."
rm -rf TXGJ_App 2>/dev/null
mkdir -p TXGJ_App/TXGJ.xcodeproj
mkdir -p TXGJ_App/TXGJ

# 写入 Swift 源码
cat > TXGJ_App/TXGJ/main.swift << 'SWIFT'
import UIKit

@main class AppDelegate: UIResponder, UIApplicationDelegate {
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
SWIFT

# 写入 Info.plist
cat > TXGJ_App/TXGJ/Info.plist << 'PLIST'
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

# 3. 编译
echo "[3/5] 编译..."
cd TXGJ_App
SDK=$(xcrun --sdk iphoneos --show-sdk-path 2>/dev/null)
echo "SDK: $SDK"

if [ -z "$SDK" ]; then
    echo "ERROR: No iOS SDK found!"
    echo "Available SDKs:"
    xcodebuild -showsdks 2>&1 | head -10
    exit 1
fi

xcrun swiftc \
  -sdk "$SDK" \
  -target arm64-apple-ios14.0 \
  -O \
  -framework UIKit -framework Foundation -framework CoreGraphics \
  -parse-as-library \
  -o TXGJ \
  TXGJ/main.swift 2>&1

if [ $? -ne 0 ]; then
    echo "=== swiftc failed, trying clang ObjC ==="
    
    cat > main.m << 'OBJC'
#import <UIKit/UIKit.h>
@interface App : UIResponder <UIApplicationDelegate>
@property UIWindow *window;
@end
@implementation App
- (BOOL)application:(UIApplication*)app didFinishLaunchingWithOptions:(NSDictionary*)opts {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    UIViewController *vc = [UIViewController new];
    vc.view.backgroundColor = [UIColor colorWithRed:0.04 green:0.04 blue:0.10 alpha:1];
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(0,200,[UIScreen mainScreen].bounds.size.width,100)];
    l.text = @"TXGJ";
    l.textColor = [UIColor systemCyanColor];
    l.font = [UIFont boldSystemFontOfSize:30];
    l.textAlignment = NSTextAlignmentCenter;
    [vc.view addSubview:l];
    self.window.rootViewController = vc;
    [self.window makeKeyAndVisible];
    return YES;
}
@end
int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass([App class])); }
}
OBJC

    xcrun clang -arch arm64 -isysroot "$SDK" -mios-version-min=14.0 \
      -framework UIKit -framework Foundation -framework CoreGraphics \
      -fobjc-arc -o TXGJ main.m 2>&1 || {
        echo "FATAL: Both swiftc and clang failed"
        exit 1
    }
fi

echo "Binary: $(file TXGJ)"

# 4. 打包
echo "[4/5] 打包..."
mkdir -p Payload/TXGJ.app
cp TXGJ Payload/TXGJ.app/
cp TXGJ/Info.plist Payload/TXGJ.app/
echo "APPL????" > Payload/TXGJ.app/PkgInfo
zip -r TXGJ.ipa Payload/
cd ..
ls -lh TXGJ_App/TXGJ.ipa

# 5. 完成
echo "[5/5] 完成!"
echo "IPA: $(pwd)/TXGJ_App/TXGJ.ipa"
echo ""
echo "=== 请把 TXGJ.ipa 发回给我 ==="
