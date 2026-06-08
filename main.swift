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
