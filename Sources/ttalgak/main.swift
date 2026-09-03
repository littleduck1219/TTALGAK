import AppKit
import SpriteKit

if CommandLine.arguments.contains("--muted") {
    Sound.forceMuted = true
}

if CommandLine.arguments.contains("--selftest") {
    runSelfTest()
    exit(0)
}

// 밸런스 자동 테스트: --simulate [maxWave] — 봇이 정확도별로 플레이해 난이도 곡선 출력
if let idx = CommandLine.arguments.firstIndex(of: "--simulate") {
    let maxWave = CommandLine.arguments.count > idx + 1 ? Int(CommandLine.arguments[idx + 1]) ?? 30 : 30
    let simDiff = CommandLine.arguments.count > idx + 2
        ? (Difficulty(rawValue: CommandLine.arguments[idx + 2]) ?? .normal) : .normal
    print("=== ttalgak 밸런스 시뮬레이션 (최대 \(maxWave)웨이브, 난이도 \(simDiff.rawValue)) ===")
    for acc in [CGFloat(0.95), 0.8, 0.6] {
        for run in 1 ... 3 {
            let view = SKView(frame: NSRect(x: 0, y: 0, width: Tuning.sceneW, height: Tuning.sceneH))
            let scene = GameScene(size: CGSize(width: Tuning.sceneW, height: Tuning.sceneH))
            scene.scaleMode = .resizeFill
            scene.difficulty = simDiff
            view.presentScene(scene)
            var frame = 0
            var lastWave = 1
            var minHP = Tuning.playerMaxHP
            var waveLog: [String] = []
            var result = "생존"
            while frame < 60 * 60 * 30 {   // 상한 30분
                scene.update(Double(frame) / 60)
                let st = scene.simState
                minHP = min(minHP, st.hp)
                if st.over {
                    result = "사망 @웨이브 \(st.wave) (\(frame / 60)초)"
                    break
                }
                if st.wave > maxWave { break }
                if st.wave != lastWave {
                    waveLog.append("w\(lastWave):hp\(Int(st.hp))")
                    lastWave = st.wave
                }
                if st.choosing {
                    scene.simChooseBest()
                } else if let aim = scene.simAimPoint(accuracy: acc) {
                    scene.requestThrow(at: aim)
                }
                frame += 1
            }
            print("acc \(acc) run\(run): \(result), 최저HP \(Int(minHP)) | \(waveLog.suffix(12).joined(separator: " "))")
        }
    }
    exit(0)
}

// 오프스크린 렌더 검증용: --snapshot <outDir> — 프레임 몇 개를 PNG로 저장
if let idx = CommandLine.arguments.firstIndex(of: "--snapshot") {
    let outDir = CommandLine.arguments.count > idx + 1 ? CommandLine.arguments[idx + 1] : "."
    let size = CGSize(width: Tuning.sceneW, height: Tuning.sceneH)
    let view = SKView(frame: NSRect(origin: .zero, size: size))
    let scene = GameScene(size: size)
    scene.scaleMode = .resizeFill
    view.presentScene(scene)
    scene.backgroundColor = SKColor(white: 0.85, alpha: 1)   // 기본 검정 테마가 보이도록 밝은 배경

    func save(_ name: String) {
        if let tex = view.texture(from: scene) {
            let rep = NSBitmapImageRep(cgImage: tex.cgImage())
            try! rep.representation(using: .png, properties: [:])!
                .write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
        }
    }

    // 크리처 라인업 검증 샷 (하급 3 + 정예 3)
    let lineup: [any CreatureFigure] = EnemyKind.allCases.map { $0.makeFigure(color: .black) }
    for (i, f) in lineup.enumerated() {
        f.position = CGPoint(x: 210 + CGFloat(i) * 125, y: 26)
        f.animate(phase: 1.2)
        scene.addChild(f)
    }
    save("kinds")
    // 공격 포즈 샷
    lineup.forEach { $0.attack(1.0) }
    save("kinds_attack")
    lineup.forEach { $0.removeFromParent() }

    // 등급 카드 UI 검증 샷
    scene.debugShowUpgradeCards()
    save("cards")
    scene.restart()

    var shot = 0
    for frame in 0 ..< (60 * 6) {
        scene.update(Double(frame) / 60)
        if frame == 40 || frame == 170 { scene.requestThrow(at: CGPoint(x: 780, y: 70)) }
        if [58, 70, 90, 200, 300].contains(frame) {
            save("snap\(shot)_f\(frame)")
            shot += 1
        }
    }
    print("snapshots: \(shot + 2)")
    exit(0)
}

final class GameWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: GameWindow!
    var scene: GameScene!
    var skView: SKView!
    var statusItem: NSStatusItem!
    var diffItems: [Difficulty: NSMenuItem] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        let screen = NSScreen.main!.visibleFrame   // 독/메뉴바 제외 영역
        let size = NSSize(width: Tuning.sceneW, height: Tuning.sceneH)
        let origin = NSPoint(x: screen.midX - size.width / 2, y: screen.minY + Tuning.dockGap)

        window = GameWindow(contentRect: NSRect(origin: origin, size: size),
                            styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.ignoresMouseEvents = false   // 클릭 = 조준 투척이므로 게임 밴드는 클릭을 받는다

        skView = SKView(frame: NSRect(origin: .zero, size: size))
        skView.allowsTransparency = true
        skView.ignoresSiblingOrder = true
        skView.preferredFramesPerSecond = 60   // ProMotion(120Hz)에서 렌더 부하 2배 방지
        scene = GameScene(size: CGSize(width: size.width, height: size.height))
        scene.scaleMode = .resizeFill
        scene.onInteractive = { [weak self] interactive in
            if interactive { self?.window.makeKeyAndOrderFront(nil) }
        }
        scene.onHide = { [weak self] in self?.window.orderOut(nil) }
        window.contentView = skView
        skView.presentScene(scene)
        window.makeFirstResponder(scene)   // 스페이스바 일시정지 수신
        window.orderFrontRegardless()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🎯"
        let menu = NSMenu()
        let flip = NSMenuItem(title: "좌우 반전", action: #selector(flipSides), keyEquivalent: "")
        flip.target = self
        flip.state = UserDefaults.standard.bool(forKey: "mirrored") ? .on : .off
        menu.addItem(flip)
        let diffMenu = NSMenu()
        for d in Difficulty.allCases {
            let item = NSMenuItem(title: d.title, action: #selector(pickDifficulty(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = d.rawValue
            item.state = Difficulty.saved == d ? .on : .off
            diffMenu.addItem(item)
            diffItems[d] = item
        }
        let diff = NSMenuItem(title: "난이도", action: nil, keyEquivalent: "")
        diff.submenu = diffMenu
        menu.addItem(diff)
        let sound = NSMenuItem(title: "소리", action: #selector(toggleSound), keyEquivalent: "")
        sound.target = self
        sound.state = Sound.shared.enabled ? .on : .off
        menu.addItem(sound)
        let theme = NSMenuItem(title: "흰색 테마", action: #selector(toggleTheme), keyEquivalent: "")
        theme.target = self
        theme.state = UserDefaults.standard.bool(forKey: "whiteTheme") ? .on : .off
        menu.addItem(theme)
        let pause = NSMenuItem(title: "일시정지/재개 (Space)", action: #selector(togglePause), keyEquivalent: "")
        pause.target = self
        menu.addItem(pause)
        let hide = NSMenuItem(title: "숨기기/보이기 (우클릭)", action: #selector(toggleHide), keyEquivalent: "")
        hide.target = self
        menu.addItem(hide)
        let restart = NSMenuItem(title: "다시 시작", action: #selector(restartGame), keyEquivalent: "")
        restart.target = self
        menu.addItem(restart)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "종료", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu

        // 화면 잠금/해제: 잠금 중 일시정지, 해제 시 죽은 Metal 레이어(회색 박스) 복구
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(self, selector: #selector(screenLocked),
                        name: NSNotification.Name("com.apple.screenIsLocked"), object: nil)
        dnc.addObserver(self, selector: #selector(screenUnlocked),
                        name: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(screenUnlocked),
            name: NSWorkspace.screensDidWakeNotification, object: nil)
    }

    private var lockPaused = false   // 실제 잠금이 있었을 때만 복구 동작

    @objc func screenLocked() {
        lockPaused = true
        skView.isPaused = true
    }

    @objc func screenUnlocked() {
        // 재부착(렌더러 재생성)은 비싸다 — 실제 잠금 후 해제일 때만 1회.
        // screensDidWake는 디스플레이 dim/절전 복귀마다 오므로 가드 없으면 렌더 루프가 누적돼 시스템이 버벅임
        guard lockPaused else { return }
        lockPaused = false
        skView.presentScene(nil)
        skView.allowsTransparency = true
        skView.presentScene(scene)
        window.makeFirstResponder(scene)
        skView.isPaused = false   // 게임 일시정지는 씬 레벨(isGamePaused)이라 뷰는 항상 렌더
        window.orderFrontRegardless()
    }

    @objc func flipSides(_ sender: NSMenuItem) {
        let flag = !UserDefaults.standard.bool(forKey: "mirrored")
        scene.setMirrored(flag)
        sender.state = flag ? .on : .off
    }

    @objc func toggleTheme(_ sender: NSMenuItem) {
        let white = !UserDefaults.standard.bool(forKey: "whiteTheme")
        scene.setTheme(white: white)
        sender.state = white ? .on : .off
    }

    @objc func pickDifficulty(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let d = Difficulty(rawValue: raw) else { return }
        UserDefaults.standard.set(d.rawValue, forKey: "difficulty")
        scene.difficulty = d   // 새 스폰/다음 웨이브부터 적용
        for (k, item) in diffItems { item.state = k == d ? .on : .off }
    }

    @objc func toggleSound(_ sender: NSMenuItem) {
        Sound.shared.enabled.toggle()
        sender.state = Sound.shared.enabled ? .on : .off
        Sound.shared.play("card")   // 켤 때 확인음
    }

    @objc func togglePause() { scene.setGamePaused(!scene.isGamePaused) }

    @objc func toggleHide() {
        if window.isVisible {
            scene.setGamePaused(true)
            window.orderOut(nil)
        } else {
            window.orderFrontRegardless()
            scene.setGamePaused(false)
        }
    }

    @objc func restartGame() { scene.restart() }
    @objc func quitApp() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)   // 독 아이콘 없음, 상태바 메뉴만
app.run()
