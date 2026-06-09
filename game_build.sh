# Mac 终端 — 一步编译完整游戏 App
cat > /tmp/game.swift << 'SWIFT'
import UIKit
// ============================================================
// 腾讯手机管家 v8.0 — KFD内核 + 游戏功能
// Delta Force Mobile offsets
// ============================================================

// KFD Bridge (libxpf symbols)
@_silgen_name("xpf_common_init") func xpf_common_init() -> Int32
@_silgen_name("xpf_bad_recovery_init") func xpf_bad_recovery_init() -> Int32
@_silgen_name("xpf_start_with_kernel_path") func xpf_start(_ path: UnsafePointer<CChar>) -> Int32
@_silgen_name("kread64") func kread64(_ addr: UInt64) -> UInt64
@_silgen_name("proc_find") func proc_find(_ name: UnsafePointer<CChar>) -> UInt64
@_silgen_name("vm_read") func vm_read(_ task: UInt32, _ addr: UInt64, _ size: UInt, _ data: UnsafeMutablePointer<UInt64>) -> Int32

// Game Offsets (Delta Force Mobile)
let GAME_PROCESS = "ShadowTrackerExtra"
let GWORLD_OFFSET: UInt64 = 0x400000
let ULEVEL_OFFSET: UInt64 = 0x30
let ACTORS_OFFSET: UInt64 = 0xA0
let ACTOR_COUNT_OFFSET: UInt64 = 0xA8
let ROOT_COMPONENT: UInt64 = 0x1A0
let RELATIVE_LOCATION: UInt64 = 0x120
let MESH_COMPONENT: UInt64 = 0x2A8
let BONE_ARRAY: UInt64 = 0x5A0
let BONE_COUNT: UInt64 = 0x5A8

struct Vector3 { var x,y,z: Float }
struct Vector2 { var x,y: Float }

var gProcessBase: UInt64 = 0
var gWorldPtr: UInt64 = 0
var gKfdReady = false

@main class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ app: UIApplication, didFinishLaunchingWithOptions opts: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        
        // Init KFD
        if xpf_common_init() == 0 || xpf_bad_recovery_init() == 0 {
            gKfdReady = true
            // Find game process
            GAME_PROCESS.withCString { ptr in
                gProcessBase = proc_find(ptr)
            }
            if gProcessBase != 0 {
                gWorldPtr = kread64(gProcessBase + GWORLD_OFFSET)
            }
        }
        
        let vc = UIViewController()
        vc.view.backgroundColor = UIColor(red:0.04,green:0.04,blue:0.10,alpha:1)
        
        let status = UILabel(frame:CGRect(x:20,y:80,width:UIScreen.main.bounds.width-40,height:400))
        status.numberOfLines = 0
        status.textColor = UIColor(red:0,green:0.94,blue:1,alpha:1)
        status.font = .systemFont(ofSize:14)
        status.text = "TXGJ v8.0\n\nKFD: \(gKfdReady ? "ACTIVE":"FAIL")\nGame: \(gProcessBase != 0 ? "FOUND":"NOT FOUND")\nWorld: 0x\(String(gWorldPtr, radix:16))\n\nOffsets:\n GWorld=0x400000\n ULevel=0x30\n Actors=0xA0\n Count=0xA8\n RootComp=0x1A0\n Location=0x120\n Mesh=0x2A8\n Bone=0x5A0\n\nInstall via TrollStore\nOpen game first, then app"
        vc.view.addSubview(status)
        
        window!.rootViewController = vc
        window!.makeKeyAndVisible()
        return true
    }
}
SWIFT

SDK=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.5.sdk
xcrun swiftc -sdk "$SDK" -target arm64-apple-ios14.0 -O \
  -framework UIKit -framework Foundation -framework CoreGraphics \
  -parse-as-library -o TXGJ8 /tmp/game.swift 2>&1
EC=$?
echo "Exit: $EC"
file TXGJ8 2>/dev/null
ls -la TXGJ8 2>/dev/null

if [ $EC -eq 0 ]; then
    rm -rf Payload && mkdir -p Payload/TXGJ.app/Frameworks
    cp TXGJ8 Payload/TXGJ.app/TXGJ
    cp ~/Desktop/Payload/Stocks.app/Frameworks/libjailbreak.dylib Payload/TXGJ.app/Frameworks/
    cp ~/Desktop/Payload/Stocks.app/Frameworks/libchoma.dylib Payload/TXGJ.app/Frameworks/
    cp ~/Desktop/Payload/Stocks.app/Frameworks/libxpf.dylib Payload/TXGJ.app/Frameworks/ 2>/dev/null
    cat > Payload/TXGJ.app/Info.plist << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>TXGJ</string>
<key>CFBundleIdentifier</key><string>com.txg.v8</string>
<key>CFBundleName</key><string>TXGJ</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>8.0</string>
<key>LSRequiresIPhoneOS</key><true/>
<key>MinimumOSVersion</key><string>14.0</string>
</dict></plist>
PLIST
    echo "APPL????" > Payload/TXGJ.app/PkgInfo
    zip -r ~/Desktop/TXGJ_v8.0.ipa Payload/
    ls -lh ~/Desktop/TXGJ_v8.0.ipa
    echo "SUCCESS"
fi
