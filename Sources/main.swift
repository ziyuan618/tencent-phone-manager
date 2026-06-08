import UIKit
import Metal
import MetalKit
import AVFoundation
import Foundation

// ============================================
// AppDelegate - 入口
// ============================================
@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions opts: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = RootVC()
        window?.makeKeyAndVisible()
        return true
    }
}

// ============================================
// RootVC - 容器 + 内核初始化 + 许可证验证
// ============================================
class RootVC: UIViewController {
    private var metalRenderer: MetalRenderer!
    private var hudController: HUDController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        
        // TODO: 内核初始化 (通过 libxpf/kfd 运行时加载)
        // _ = kfd_init()
        // _ = init_game_offsets()
        
        // Metal 覆盖层
        metalRenderer = MetalRenderer(view: view)
        
        // HUD 菜单
        hudController = HUDController()
        addChild(hudController)
        view.addSubview(hudController.view)
        hudController.didMove(toParent: self)
        
        // 许可证验证
        LicenseManager.shared.verifyCached { valid in
            DispatchQueue.main.async {
                self.hudController.updateLicenseStatus(valid)
            }
        }
    }
}

// ============================================
// MetalRenderer - ESP/Loot 渲染引擎
// ============================================
class MetalRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let mtkView: MTKView
    
    // 管线状态
    private var linePipeline: MTLRenderPipelineState!
    private var pointPipeline: MTLRenderPipelineState!
    private var healthPipeline: MTLRenderPipelineState!
    
    // 顶点缓冲区 (预分配, 每帧复用)
    private var vertexBuffer: MTLBuffer!
    
    init(view: UIView) {
        device = MTLCreateSystemDefaultDevice()!
        queue = device.makeCommandQueue()!
        
        mtkView = MTKView(frame: view.bounds, device: device)
        mtkView.backgroundColor = .clear
        mtkView.isOpaque = false
        mtkView.framebufferOnly = false
        mtkView.delegate = self
        mtkView.preferredFramesPerSecond = 60
        
        super.init()
        setupPipelines()
        
        view.insertSubview(mtkView, at: 0)
        vertexBuffer = device.makeBuffer(length: 65536, options: .storageModeShared)
    }
    
    private func setupPipelines() {
        guard let lib = device.makeDefaultLibrary() else { return }
        
        let makeDescriptor = { (vert: String, frag: String, type: MTLPrimitiveType) -> MTLRenderPipelineDescriptor in
            let d = MTLRenderPipelineDescriptor()
            d.vertexFunction = lib.makeFunction(name: vert)
            d.fragmentFunction = lib.makeFunction(name: frag)
            d.colorAttachments[0].pixelFormat = self.mtkView.colorPixelFormat
            d.colorAttachments[0].isBlendingEnabled = true
            d.colorAttachments[0].rgbBlendOperation = .add
            d.colorAttachments[0].alphaBlendOperation = .add
            d.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            d.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            d.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            d.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            return d
        }
        
        linePipeline   = try? device.makeRenderPipelineState(descriptor: makeDescriptor("line_vertex", "line_fragment", .lineStrip))
        pointPipeline  = try? device.makeRenderPipelineState(descriptor: makeDescriptor("point_vertex", "point_fragment", .point))
        healthPipeline = try? device.makeRenderPipelineState(descriptor: makeDescriptor("health_vertex", "health_fragment", .triangleStrip))
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        guard HUDController.Features.menuVisible,
              let drawable = view.currentDrawable,
              let desc = view.currentRenderPassDescriptor,
              let cmd = queue.makeCommandBuffer(),
              let enc = cmd.makeRenderCommandEncoder(descriptor: desc) else { return }
        
        let vs = view.bounds.size
        
        // 遍历所有玩家, 绘制 ESP
        for i in 0..<GameData.shared.playerCount {
            let p = GameData.shared.players[i]
            guard p.isValid else { continue }
            
            let sc = worldToScreen(p.worldPos, vs)
            let headSc = worldToScreen(p.headWorldPos, vs)
            let footSc = worldToScreen(p.footWorldPos, vs)
            
            let color = enemyColor(p.teamId)
            
            // 方框
            if HUDController.Features.espBox {
                drawBox(enc, headSc, footSc, color, vs)
            }
            
            // 血量条
            if HUDController.Features.espHealth {
                drawHealthBar(enc, footSc, p.health, vs)
            }
            
            // 骨骼
            if HUDController.Features.espSkeleton && !p.bones.isEmpty {
                drawSkeleton(enc, p.bones.map{worldToScreen($0, vs)}, color)
            }
        }
        
        // 物资
        if HUDController.Features.lootWeapon {
            for i in 0..<GameData.shared.lootCount {
                let l = GameData.shared.loots[i]
                let sc = worldToScreen(l.worldPos, vs)
                drawPoint(enc, sc, lootColor(l.type), vs)
            }
        }
        
        enc.endEncoding()
        cmd.present(drawable)
        cmd.commit()
    }
    
    // MARK: - 绘制辅助
    private func drawBox(_ enc: MTLRenderCommandEncoder, _ head: CGPoint, _ foot: CGPoint, _ color: SIMD4<Float>, _ vs: CGSize) {
        let bw = abs(head.y - foot.y) * 0.35
        let h = simd2(Float(head.x), Float(head.y))
        let f = simd2(Float(foot.x), Float(foot.y))
        let b = simd2(Float(bw), 0)
        
        let verts: [SIMD2<Float>] = [
            h - b, h + b, f + b, f - b, h - b
        ].map { ndc($0, vs) }
        
        drawLine(enc, verts, color)
    }
    
    private func drawHealthBar(_ enc: MTLRenderCommandEncoder, _ pos: CGPoint, _ health: Float, _ vs: CGSize) {
        let bw: Float = 0.025
        let bh = bw * 5
        let x = ndc(simd2(Float(pos.x), Float(pos.y)), vs).x - bw * 2
        let y = ndc(simd2(0, Float(pos.y)), vs).y
        
        // 背景
        let bg: [SIMD2<Float>] = [simd2(x,y), simd2(x+bw,y), simd2(x,y-bh), simd2(x+bw,y-bh)]
        drawTriStrip(enc, bg, simd4(0.15,0.15,0.15,0.85))
        
        // 血量
        let h = max(0, min(bh, bh * health / 100))
        let hc: SIMD4<Float> = health > 60 ? simd4(0,1,0.3,1) : health > 30 ? simd4(1,0.8,0,1) : simd4(1,0.1,0.1,1)
        let hv: [SIMD2<Float>] = [simd2(x,y), simd2(x+bw,y), simd2(x,y-h), simd2(x+bw,y-h)]
        drawTriStrip(enc, hv, hc)
    }
    
    private func drawSkeleton(_ enc: MTLRenderCommandEncoder, _ bones: [simd_float2], _ color: SIMD4<Float>) {
        drawLine(enc, bones, color)
    }
    
    private func drawLine(_ enc: MTLRenderCommandEncoder, _ verts: [SIMD2<Float>], _ color: SIMD4<Float>) {
        guard verts.count >= 2 else { return }
        enc.setRenderPipelineState(linePipeline)
        verts.withUnsafeBytes { ptr in
            enc.setVertexBytes(ptr.baseAddress!, length: verts.count * 8, index: 0)
        }
        var c = color
        enc.setVertexBytes(&c, length: 16, index: 1)
        enc.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: verts.count)
    }
    
    private func drawPoint(_ enc: MTLRenderCommandEncoder, _ pt: CGPoint, _ color: SIMD4<Float>, _ vs: CGSize) {
        let v = ndc(simd2(Float(pt.x), Float(pt.y)), vs)
        enc.setRenderPipelineState(pointPipeline)
        var c = color
        withUnsafeBytes(of: v) { enc.setVertexBytes($0.baseAddress!, length: 8, index: 0) }
        enc.setVertexBytes(&c, length: 16, index: 1)
        enc.drawPrimitives(type: .point, vertexStart: 0, vertexCount: 1)
    }
    
    private func drawTriStrip(_ enc: MTLRenderCommandEncoder, _ verts: [SIMD2<Float>], _ color: SIMD4<Float>) {
        enc.setRenderPipelineState(healthPipeline)
        verts.withUnsafeBytes { enc.setVertexBytes($0.baseAddress!, length: verts.count*8, index: 0) }
        var c = color
        enc.setVertexBytes(&c, length: 16, index: 1)
        enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }
    
    private func ndc(_ p: simd_float2, _ vs: CGSize) -> simd_float2 {
        simd2(p.x / Float(vs.width) * 2 - 1, -(p.y / Float(vs.height) * 2 - 1))
    }
    
    private var viewMatrix: [Float] = Array(repeating: 0, count: 16)
    private var projMatrix: [Float] = Array(repeating: 0, count: 16)
    private var localTeam: Int32 = -1
    
    private func worldToScreen(_ world: simd_float3, _ vs: CGSize) -> CGPoint {
        let v = viewMatrix
        let p = projMatrix
        // 简化的 WorldToScreen
        let w = v[3]*world.x + v[7]*world.y + v[11]*world.z + v[15]
        if w < 0.01 { return CGPoint(x: -999, y: -999) }
        let sx = (v[0]*world.x + v[4]*world.y + v[8]*world.z + v[12]) / w
        let sy = (v[1]*world.x + v[5]*world.y + v[9]*world.z + v[13]) / w
        return CGPoint(x: CGFloat((sx+1)/2 * Float(vs.width)),
                       y: CGFloat((1-sy)/2 * Float(vs.height)))
    }
    
    private func enemyColor(_ teamId: Int32) -> SIMD4<Float> {
        teamId == localTeam ? simd4(0.48,0.18,1,1) : simd4(0,0.94,1,1)
    }
    private func lootColor(_ t: LootType) -> SIMD4<Float> {
        switch t {
        case .weapon: return simd4(1,0.6,0,1)
        case .ammo:   return simd4(1,0.8,0,1)
        case .armor:  return simd4(0,0.6,1,1)
        case .medical:return simd4(0,1,0.5,1)
        case .bag:    return simd4(0.8,0.4,1,1)
        }
    }
}

// ============================================
// HUDController - 音量键菜单
// ============================================
class HUDController: UIViewController {
    struct Features {
        static var menuVisible  = false
        static var espBox       = true
        static var espSkeleton  = false
        static var espHealth    = true
        static var espDistance  = true
        static var espName      = true
        static var lootWeapon   = true
        static var lootAmmo     = true
        static var lootArmor    = true
        static var lootMedical  = true
        static var lootBackpack = true
    }
    
    private var menuView: UIView!
    private var statusDot: UIView!
    private var licenseLabel: UILabel!
    
    // 颜色
    private let cyan   = UIColor(red:0, green:0.94, blue:1, alpha:1)
    private let purple = UIColor(red:0.48, green:0.18, blue:1, alpha:1)
    private let darkBg = UIColor(red:0.04, green:0.04, blue:0.10, alpha:0.94)
    private let cardBg = UIColor(red:0.08, green:0.08, blue:0.18, alpha:0.95)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupVolumeHook()
        buildMenu()
    }
    
    private func setupVolumeHook() {
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(true)
        var observer: NSKeyValueObservation?
        observer = session.observe(\.outputVolume) { [weak self] _, _ in
            self?.toggleMenu()
        }
        // 保持引用
        objc_setAssociatedObject(self, "vol_observer", observer, .OBJC_ASSOCIATION_RETAIN)
    }
    
    @objc private func toggleMenu() {
        Features.menuVisible.toggle()
        UIView.animate(withDuration: 0.2) {
            self.menuView.alpha = Features.menuVisible ? 1 : 0
            self.menuView.transform = Features.menuVisible ? .identity : CGAffineTransform(scaleX: 0.85, y: 0.85)
        }
    }
    
    func updateLicenseStatus(_ valid: Bool) {
        licenseLabel?.text = valid ? "● 已激活" : "○ 未激活"
        licenseLabel?.textColor = valid ? .green : .red
    }
    
    // MARK: - 科技风菜单构建
    private func buildMenu() {
        let w: CGFloat = 290, h: CGFloat = 480
        menuView = UIView(frame: CGRect(x: UIScreen.main.bounds.width - w - 12,
                                         y: 70, width: w, height: h))
        menuView.backgroundColor = darkBg
        menuView.layer.cornerRadius = 14
        menuView.layer.borderWidth = 1
        menuView.layer.borderColor = cyan.withAlphaComponent(0.35).cgColor
        menuView.layer.shadowColor = cyan.cgColor
        menuView.layer.shadowRadius = 10
        menuView.layer.shadowOpacity = 0.25
        menuView.alpha = 0
        view.addSubview(menuView)
        
        var y: CGFloat = 14
        
        // 标题
        y = addGlowText("⬡ 腾讯手机管家 PRO", y, cyan, 15, menuView)
        y += 6
        y = addSep(y, cyan.withAlphaComponent(0.25), menuView)
        
        // 战斗视觉
        y = addSection("🎯 战斗视觉", y, menuView)
        y = addToggle("人物绘制",   y, \Features.espBox,      menuView)
        y = addToggle("骨骼显示",   y, \Features.espSkeleton,  menuView)
        y = addToggle("血量条",     y, \Features.espHealth,    menuView)
        y = addToggle("距离显示",   y, \Features.espDistance,  menuView)
        y = addToggle("名字显示",   y, \Features.espName,      menuView)
        
        y = addSep(y, purple.withAlphaComponent(0.25), menuView)
        
        // 物资
        y = addSection("📦 物资显示", y, menuView)
        y = addToggle("武器",       y, \Features.lootWeapon,   menuView)
        y = addToggle("弹药",       y, \Features.lootAmmo,     menuView)
        y = addToggle("护甲/头盔",  y, \Features.lootArmor,    menuView)
        y = addToggle("医疗品",     y, \Features.lootMedical,  menuView)
        y = addToggle("背包",       y, \Features.lootBackpack, menuView)
        
        y = addSep(y, cyan.withAlphaComponent(0.2), menuView)
        
        // 系统
        y = addInfo("版本",   "3.0.0 Pro",   y, menuView)
        licenseLabel = addInfo("许可证", "● 已激活", y, menuView, .green) as? UILabel
        _ = addInfo("防护",   "🛡 7层防御",   y, menuView, cyan)
        
        // 状态灯
        statusDot = UIView(frame: CGRect(x: w-22, y: 18, width: 8, height: 8))
        statusDot.backgroundColor = .green
        statusDot.layer.cornerRadius = 4
        menuView.addSubview(statusDot)
    }
    
    private func addGlowText(_ t: String, _ y: CGFloat, _ c: UIColor, _ s: CGFloat, _ v: UIView) -> CGFloat {
        let l = UILabel(frame: CGRect(x: 14, y: y, width: v.bounds.width-28, height: 22))
        l.text = t; l.font = .systemFont(ofSize: s, weight: .bold); l.textColor = c
        v.addSubview(l); return y + 28
    }
    
    private func addSection(_ t: String, _ y: CGFloat, _ v: UIView) -> CGFloat {
        let l = UILabel(frame: CGRect(x: 14, y: y, width: v.bounds.width-28, height: 20))
        l.text = t; l.font = .systemFont(ofSize: 11, weight: .bold); l.textColor = purple
        v.addSubview(l); return y + 22
    }
    
    private func addToggle(_ title: String, _ y: CGFloat, _ key: WritableKeyPath<Features.Type, Bool>, _ v: UIView) -> CGFloat {
        let row = UIView(frame: CGRect(x: 10, y: y, width: v.bounds.width - 20, height: 34))
        row.backgroundColor = cardBg; row.layer.cornerRadius = 7
        
        let l = UILabel(frame: CGRect(x: 10, y: 0, width: 170, height: 34))
        l.text = title; l.font = .systemFont(ofSize: 12); l.textColor = .white
        row.addSubview(l)
        
        let sw = UISwitch(frame: CGRect(x: row.bounds.width - 52, y: 2, width: 0, height: 0))
        sw.isOn = Features.self[keyPath: key]; sw.onTintColor = cyan
        sw.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        sw.addAction(UIAction { _ in Features.self[keyPath: key] = sw.isOn }, for: .valueChanged)
        row.addSubview(sw)
        
        v.addSubview(row); return y + 38
    }
    
    private func addSep(_ y: CGFloat, _ c: UIColor, _ v: UIView) -> CGFloat {
        let s = UIView(frame: CGRect(x: 14, y: y+2, width: v.bounds.width-28, height: 0.5))
        s.backgroundColor = c; v.addSubview(s); return y + 10
    }
    
    private func addInfo(_ title: String, _ value: String, _ y: CGFloat, _ v: UIView, _ vc: UIColor = .white) -> UIView {
        let row = UIView(frame: CGRect(x: 10, y: y, width: v.bounds.width-20, height: 26))
        let t = UILabel(frame: CGRect(x: 10, y: 0, width: 80, height: 26))
        t.text = title; t.font = .systemFont(ofSize: 11); t.textColor = UIColor(white:0.55, alpha:1)
        row.addSubview(t)
        let val = UILabel(frame: CGRect(x: 100, y: 0, width: row.bounds.width-110, height: 26))
        val.text = value; val.font = .systemFont(ofSize: 11, weight: .medium); val.textColor = vc
        val.textAlignment = .right; row.addSubview(val); v.addSubview(row)
        return y + 28
    }
}

// ============================================
// GameData - 游戏内存数据模型
// ============================================
class GameData {
    static let shared = GameData()
    
    struct Player {
        var isValid: Bool
        var worldPos: simd_float3
        var headWorldPos: simd_float3
        var footWorldPos: simd_float3
        var health: Float
        var teamId: Int32
        var name: String
        var bones: [simd_float3]
    }
    
    enum LootType { case weapon, ammo, armor, medical, bag }
    struct Loot {
        var worldPos: simd_float3
        var type: LootType
        var name: String
        var distance: Float
    }
    
    var players: [Player] = []
    var playerCount: Int { players.count }
    var loots: [Loot] = []
    var lootCount: Int { loots.count }
    
    func refresh() {
        // 通过 kread64 从游戏内存读取玩家和物资数据
        // 实际实现由 libxpf 提供
    }
}

// ============================================
// LicenseManager
// ============================================
class LicenseManager {
    static let shared = LicenseManager()
    private let server = "http://127.0.0.1:8848"
    private var valid = false
    
    func verifyCached(completion: @escaping (Bool) -> Void) {
        let savedKey = UserDefaults.standard.string(forKey: "license_key") ?? ""
        guard !savedKey.isEmpty else { completion(false); return }
        verify(key: savedKey, completion: completion)
    }
    
    func verify(key: String, completion: @escaping (Bool) -> Void) {
        post("/api/verify", ["key":key, "device_id": deviceId()]) { json in
            let ok = json?["valid"] as? Bool ?? false
            if ok { UserDefaults.standard.set(key, forKey: "license_key") }
            self.valid = ok
            completion(ok)
        }
    }
    
    func activate(key: String, completion: @escaping (Bool, String) -> Void) {
        post("/api/activate", ["key":key, "device_id": deviceId()]) { json in
            if let ok = json?["success"] as? Bool, ok {
                UserDefaults.standard.set(key, forKey: "license_key")
                self.valid = true
                completion(true, "激活成功")
            } else {
                completion(false, json?["error"] as? String ?? "失败")
            }
        }
    }
    
    private func post(_ path: String, _ body: [String:Any], cb: @escaping ([String:Any]?) -> Void) {
        guard let url = URL(string: server + path) else { cb(nil); return }
        var r = URLRequest(url: url)
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: r) { d, _, _ in
            guard let d = d else { cb(nil); return }
            cb(try? JSONSerialization.jsonObject(with: d) as? [String:Any])
        }.resume()
    }
    
    private func deviceId() -> String {
        UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }
}
