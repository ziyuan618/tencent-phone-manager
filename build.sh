#!/bin/bash
set -e
echo "=== Environment ==="
sw_vers
echo "---"
xcodebuild -version 2>&1 | head -5
echo "---"
xcode-select -p
echo "---"
ls /Applications/Xcode*.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/ 2>/dev/null
echo "---"
xcrun --sdk iphoneos --show-sdk-path 2>&1
SDK=$(xcrun --sdk iphoneos --show-sdk-path 2>/dev/null)
echo "---"
xcrun -sdk iphoneos swiftc -version 2>&1
echo "---"

if [ -n "$SDK" ]; then
    echo "=== Attempting compilation ==="
    # Use clang instead of swiftc - ObjC is simpler
    cat > main.m << 'EOF'
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
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([App class]));
    }
}
EOF

    echo "=== Compiling ObjC ==="
    xcrun clang -v \
      -arch arm64 \
      -isysroot "$SDK" \
      -mios-version-min=14.0 \
      -framework UIKit -framework Foundation -framework CoreGraphics \
      -fobjc-arc \
      -o TXGJ \
      main.m 2>&1
    
    EC=$?
    echo "Exit code: $EC"
    
    if [ $EC -eq 0 ] && [ -f TXGJ ]; then
        echo "=== Packaging ==="
        file TXGJ
        mkdir -p Payload/TXGJ.app
        cp TXGJ Payload/TXGJ.app/
        echo '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleExecutable</key><string>TXGJ</string><key>CFBundleIdentifier</key><string>com.txg.app</string><key>CFBundleName</key><string>TXGJ</string><key>CFBundlePackageType</key><string>APPL</string><key>LSRequiresIPhoneOS</key><true/><key>MinimumOSVersion</key><string>14.0</string></dict></plist>' > Payload/TXGJ.app/Info.plist
        echo "APPL????" > Payload/TXGJ.app/PkgInfo
        cd Payload && zip -r ../TXGJ.ipa . && cd ..
        ls -lh TXGJ.ipa
        echo "SUCCESS"
        exit 0
    fi
    
    # Fallback: swiftc
    echo "=== Swift fallback ==="
    cat > main.swift << 'SWIFT'
import UIKit
class App: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ app: UIApplication, didFinishLaunchingWithOptions opts: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        let vc = UIViewController()
        vc.view.backgroundColor = UIColor(cgColor: CGColor(red:0.04,green:0.04,blue:0.10,alpha:1))
        window!.rootViewController = vc
        window!.makeKeyAndVisible()
        return true
    }
}
UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(App.self))
SWIFT
    
    xcrun swiftc \
      -sdk "$SDK" \
      -target arm64-apple-ios14.0 \
      -framework UIKit -framework Foundation \
      -o TXGJ main.swift 2>&1
    
    if [ $? -eq 0 ] && [ -f TXGJ ]; then
        file TXGJ
        echo "=== Swift compiled OK ==="
        mkdir -p Payload/TXGJ.app
        cp TXGJ Payload/TXGJ.app/
        echo '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleExecutable</key><string>TXGJ</string><key>CFBundleIdentifier</key><string>com.txg.app</string><key>CFBundleName</key><string>TXGJ</string><key>CFBundlePackageType</key><string>APPL</string><key>LSRequiresIPhoneOS</key><true/><key>MinimumOSVersion</key><string>14.0</string></dict></plist>' > Payload/TXGJ.app/Info.plist
        echo "APPL????" > Payload/TXGJ.app/PkgInfo
        cd Payload && zip -r ../TXGJ.ipa . && cd ..
        ls -lh TXGJ.ipa
        echo "SUCCESS"
    else
        echo "=== All attempts failed ==="
        exit 1
    fi
else
    echo "=== No SDK found ==="
    exit 1
fi
