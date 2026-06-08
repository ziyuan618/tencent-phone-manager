#!/bin/bash
set -e
echo "=== ObjC Build ==="

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
    l.text = @"TXGJ PRO";
    l.textColor = [UIColor colorWithRed:0 green:0.94 blue:1 alpha:1];
    l.font = [UIFont boldSystemFontOfSize:24];
    l.textAlignment = NSTextAlignmentCenter;
    [vc.view addSubview:l];
    self.window.rootViewController = vc;
    [self.window makeKeyAndVisible];
    return YES;
}
@end
int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([App class]));
    }
}
OBJC

cat > Info.plist << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>TXGJ</string>
<key>CFBundleIdentifier</key><string>com.txg.protect</string>
<key>CFBundleName</key><string>TXGJ</string>
<key>CFBundleDisplayName</key><string>TXGJ</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSRequiresIPhoneOS</key><true/>
<key>MinimumOSVersion</key><string>14.0</string>
<key>UIDeviceFamily</key><array><integer>1</integer><integer>2</integer></array>
</dict></plist>
PLIST

SDK=$(xcrun --sdk iphoneos --show-sdk-path)
echo "SDK: $SDK"

xcrun clang -arch arm64 \
  -isysroot "$SDK" \
  -mios-version-min=14.0 \
  -framework UIKit -framework Foundation -framework CoreGraphics \
  -fobjc-arc \
  -o TXGJ \
  main.m 2>&1

echo "Compiled: $(file TXGJ)"

mkdir -p output/Payload/TXGJ.app
cp TXGJ output/Payload/TXGJ.app/
cp Info.plist output/Payload/TXGJ.app/
echo "APPL????" > output/Payload/TXGJ.app/PkgInfo
cd output && zip -r ../TXGJ.ipa Payload/ && cd ..
ls -lh TXGJ.ipa
echo "SUCCESS"
