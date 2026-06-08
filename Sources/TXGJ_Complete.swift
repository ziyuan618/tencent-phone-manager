// ============================================================
// 腾讯手机管家 - 独立 iOS App 完整源码
// 编译: Xcode 14+ | iOS 14-16.5 | arm64
// ============================================================

import UIKit
import AVFoundation
import Network

// ============================================================
// MARK: - App入口
// ============================================================
@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = SplashViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

// ============================================================
// MARK: - 启动页 (许可证验证)
// ============================================================
class SplashViewController: UIViewController {
    private let serverURL = "http://localhost:8848"  // 改为你的服务器地址
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.04, green: 0.04, blue: 0.10, alpha: 1)
        setupUI()
        checkLicense()
    }
    
    private func setupUI() {
        let logo = UILabel(frame: CGRect(x: 0, y: 180, width: view.bounds.width, height: 60))
        logo.text = "⬡ 腾讯手机管家"
        logo.textColor = UIColor(red: 0, green: 0.94, blue: 1, alpha: 1)
        logo.font = UIFont.boldSystemFont(ofSize: 28)
        logo.textAlignment = .center
        view.addSubview(logo)
        
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.center = CGPoint(x: view.center.x, y: 300)
        spinner.color = UIColor(red: 0, green: 0.94, blue: 1, alpha: 1)
        spinner.startAnimating()
        spinner.tag = 999
        view.addSubview(spinner)
        
        let status = UILabel(frame: CGRect(x: 0, y: 360, width: view.bounds.width, height: 30))
        status.text = "正在验证许可证..."
        status.textColor = .lightGray
        status.font = .systemFont(ofSize: 14)
        status.textAlignment = .center
        status.tag = 998
        view.addSubview(status)
    }
    
    private func checkLicense() {
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        guard let url = URL(string: "\(serverURL)/api/verify") else {
            showLicenseScreen(); return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["device_id": deviceId])
        
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let valid = json["valid"] as? Bool else {
                DispatchQueue.main.async { self?.showLicenseScreen() }; return
            }
            DispatchQueue.main.async {
                if valid {
                    self?.transitionToMain()
                } else {
                    self?.showLicenseScreen()
                }
            }
        }.resume()
    }
    
    private func showLicenseScreen() {
        let vc = LicenseViewController()
        vc.serverURL = serverURL
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: false)
    }
    
    private func transitionToMain() {
        UIView.animate(withDuration: 0.5) {
            self.view.alpha = 0
        } completion: { _ in
            self.view.window?.rootViewController = MainViewController()
        }
    }
}

// ============================================================
// MARK: - 许可证激活页
// ============================================================
class LicenseViewController: UIViewController, UITextFieldDelegate {
    var serverURL = "http://localhost:8848"
    private var keyField: UITextField!
    private var statusLabel: UILabel!
    private var activateButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.04, green: 0.04, blue: 0.10, alpha: 1)
        setupUI()
    }
    
    private func setupUI() {
        let title = UILabel(frame: CGRect(x: 0, y: 100, width: view.bounds.width, height: 60))
        title.text = "⬡ 激活许可证"
        title.textColor = UIColor(red: 0, green: 0.94, blue: 1, alpha: 1)
        title.font = .boldSystemFont(ofSize: 26)
        title.textAlignment = .center
        view.addSubview(title)
        
        keyField = UITextField(frame: CGRect(x: 30, y: 200, width: view.bounds.width - 60, height: 50))
        keyField.placeholder = "输入16位卡密 (XXXX-XXXX-XXXX-XXXX)"
        keyField.backgroundColor = UIColor(white: 0.1, alpha: 1)
        keyField.textColor = .white
        keyField.layer.cornerRadius = 10
        keyField.layer.borderWidth = 1.5
        keyField.layer.borderColor = UIColor(red: 0, green: 0.94, blue: 1, alpha: 0.4).cgColor
        keyField.textAlignment = .center
        keyField.font = .systemFont(ofSize: 16)
        keyField.autocapitalizationType = .allCharacters
        keyField.delegate = self
        keyField.tag = 100
        view.addSubview(keyField)
        
        activateButton = UIButton(frame: CGRect(x: 30, y: 280, width: view.bounds.width - 60, height: 50))
        activateButton.setTitle("激活", for: .normal)
        activateButton.titleLabel?.font = .boldSystemFont(ofSize: 17)
        activateButton.backgroundColor = UIColor(red: 0, green: 0.6, blue: 1, alpha: 1)
        activateButton.layer.cornerRadius = 10
        activateButton.addTarget(self, action: #selector(activate), for: .touchUpInside)
        view.addSubview(activateButton)
        
        statusLabel = UILabel(frame: CGRect(x: 30, y: 350, width: view.bounds.width - 60, height: 40))
        statusLabel.text = ""
        statusLabel.textColor = .red
        statusLabel.font = .systemFont(ofSize: 13)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 2
        view.addSubview(statusLabel)
    }
    
    @objc private func activate() {
        guard let key = keyField.text?.trimmingCharacters(in: .whitespaces).uppercased(), key.count >= 16 else {
            statusLabel.text = "请输入完整卡密"; return
        }
        activateButton.isEnabled = false
        activateButton.alpha = 0.5
        statusLabel.text = "验证中..."
        
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        guard let url = URL(string: "\(serverURL)/api/activate") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["key": key, "device_id": deviceId])
        
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            DispatchQueue.main.async {
                self?.activateButton.isEnabled = true
                self?.activateButton.alpha = 1
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self?.statusLabel.text = "服务器连接失败"; return
                }
                if json["success"] as? Bool == true {
                    self?.statusLabel.textColor = .green
                    self?.statusLabel.text = "激活成功！"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self?.view.window?.rootViewController = MainViewController()
                    }
                } else {
                    self?.statusLabel.text = json["error"] as? String ?? "激活失败"
                }
            }
        }.resume()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        activate(); return true
    }
}

// ============================================================
// MARK: - 主页面
// ============================================================
class MainViewController: UIViewController {
    private var statusDot: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.04, green: 0.04, blue: 0.10, alpha: 1)
        setupUI()
    }
    
    private func setupUI() {
        let title = UILabel(frame: CGRect(x: 0, y: 80, width: view.bounds.width, height: 60))
        title.text = "⬡ 腾讯手机管家 PRO"
        title.textColor = UIColor(red: 0, green: 0.94, blue: 1, alpha: 1)
        title.font = .boldSystemFont(ofSize: 22)
        title.textAlignment = .center
        view.addSubview(title)
        
        // 状态指示
        statusDot = UIView(frame: CGRect(x: view.bounds.width/2 - 4, y: 160, width: 8, height: 8))
        statusDot.backgroundColor = .green
        statusDot.layer.cornerRadius = 4
        view.addSubview(statusDot)
        
        let statusLabel = UILabel(frame: CGRect(x: 0, y: 175, width: view.bounds.width, height: 30))
        statusLabel.text = "防护已激活"
        statusLabel.textColor = .green
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textAlignment = .center
        view.addSubview(statusLabel)
        
        // 功能卡片
        let cardData = [
            ("🎯", "战斗视觉", "人物绘制 · 物资显示"),
            ("🛡", "7层防护", "反调试 · 环境清理 · 隐身"),
            ("🔑", "许可证", "已激活"),
            ("📡", "服务器", "在线")
        ]
        
        for (i, (icon, title, desc)) in cardData.enumerated() {
            let card = createCard(icon: icon, title: title, desc: desc, index: i)
            view.addSubview(card)
        }
        
        // 底部版本
        let version = UILabel(frame: CGRect(x: 0, y: view.bounds.height - 60, width: view.bounds.width, height: 30))
        version.text = "v4.0 · 腾讯手机管家 · 独立版"
        version.textColor = .darkGray
        version.font = .systemFont(ofSize: 11)
        version.textAlignment = .center
        view.addSubview(version)
    }
    
    private func createCard(icon: String, title: String, desc: String, index: Int) -> UIView {
        let cardW = view.bounds.width - 40
        let card = UIView(frame: CGRect(x: 20, y: 220 + index * 90, width: cardW, height: 75))
        card.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.18, alpha: 0.95)
        card.layer.cornerRadius = 12
        card.layer.borderWidth = 0.5
        card.layer.borderColor = UIColor(red: 0, green: 0.94, blue: 1, alpha: 0.2).cgColor
        
        let iconLabel = UILabel(frame: CGRect(x: 16, y: 12, width: 40, height: 50))
        iconLabel.text = icon
        iconLabel.font = .systemFont(ofSize: 30)
        card.addSubview(iconLabel)
        
        let titleLabel = UILabel(frame: CGRect(x: 68, y: 14, width: cardW - 88, height: 24))
        titleLabel.text = title
        titleLabel.textColor = .white
        titleLabel.font = .boldSystemFont(ofSize: 16)
        card.addSubview(titleLabel)
        
        let descLabel = UILabel(frame: CGRect(x: 68, y: 38, width: cardW - 88, height: 20))
        descLabel.text = desc
        descLabel.textColor = UIColor(white: 0.55, alpha: 1)
        descLabel.font = .systemFont(ofSize: 12)
        card.addSubview(descLabel)
        
        return card
    }
}
