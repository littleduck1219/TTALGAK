import AppKit
import SpearGameCore

final class OverlayController {
    private let boxSize = NSSize(width: 180, height: 110)
    private let leftInset = 96.0
    private var panels: [GamePanel] = []
    private var scenePanel: DisplayPanel?
    private var game = SpearGameState()
    private var gesture = LocalGesture()
    private var currentLaunch: FrozenLaunch?
    private var path: BallisticFlightPath?
    private var target = PresentationPoint(x: 0, y: 0)
    private var groundY = 0.0
    private var flightElapsed = 0.0
    private var flightClock = FlightClock()
    private var flightTimer: Timer?
    private var resetTimer: Timer?
    private var round = 0
    private var reducedMotion = false

    var isVisible: Bool { !panels.isEmpty }
    func toggle() { isVisible ? hide() : show() }
    func show() {
        guard panels.isEmpty else { reposition(); return }
        let left = GamePanel(frame: .zero, interaction: .input)
        let right = GamePanel(frame: .zero, interaction: .displayOnly)
        left.contentView = SpearThrowView(frame: .zero) { [weak self] event in self?.handle(event) }
        panels = [left, right]
        reposition()
        panels.forEach { $0.orderFrontRegardless() }
        showScene()
    }
    func hide() { stopTimers(); scenePanel?.orderOut(nil); scenePanel = nil; panels.forEach { $0.orderOut(nil) }; panels.removeAll() }

    func reposition() {
        guard panels.count == 2, let screen = NSScreen.main else { return }
        let frame = screen.frame
        let bottomY = frame.minY + min(max(frame.height * 0.08, 72), 120)
        panels[0].setFrame(NSRect(x: frame.minX + leftInset, y: bottomY, width: boxSize.width, height: boxSize.height), display: true)
        panels[1].setFrame(NSRect(x: frame.maxX - boxSize.width, y: bottomY, width: boxSize.width, height: boxSize.height), display: true)
        groundY = Double(bottomY + 16)
        let seedY = [64.0, 132.0, 200.0][round % 3]
        target = PresentationPoint(x: Double(panels[1].frame.minX + 132), y: groundY + seedY)
        refreshScene()
    }

    private func showScene() {
        guard let screen = NSScreen.main else { return }
        let panel = DisplayPanel(frame: screen.frame)
        let scene = SceneView(frame: NSRect(origin: .zero, size: screen.frame.size))
        let origin = panel.convertToScreen(NSRect(origin: .zero, size: .zero)).origin
        scene.screenOrigin = PresentationPoint(x: Double(origin.x), y: Double(origin.y))
        panel.contentView = scene
        scenePanel = panel
        refreshScene()
        panel.orderFrontRegardless()
    }

    private func refreshScene(result: (Bool, PresentationPoint)? = nil) {
        guard let scene = scenePanel?.contentView as? SceneView else { return }
        scene.inputFrame = panels.first?.frame ?? .zero
        scene.target = target
        scene.aiming = game.phase == .aiming ? currentLaunch : nil
        scene.result = result.map { (hit: $0.0, point: $0.1) }
    }

    private func handle(_ event: SpearThrowView.Event) {
        guard let left = panels.first else { return }
        let start = PresentationPoint(x: Double(left.frame.minX + 66), y: groundY + 42)
        switch event {
        case .down(let point):
            guard game.phase == .ready, gesture.begin(at: point, inStartZone: true) else { return }
            game.beginAim()
            currentLaunch = FrozenLaunch(angleDegrees: 45, power: 0, start: start)
            reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        case .move(let point, let inside):
            guard game.phase == .aiming else { return }
            currentLaunch = gesture.move(to: point, isInsideInput: inside, start: start)
            if currentLaunch == nil { game.reset() }
        case .up(let inside):
            guard game.phase == .aiming else { return }
            guard let launch = gesture.release(isInsideInput: inside), launch.power > 0 else { game.reset(); currentLaunch = nil; refreshScene(); return }
            currentLaunch = launch
            game.launch()
            path = BallisticFlightPath(start: launch.start, angleDegrees: launch.angleDegrees, power: launch.power, groundY: groundY)
            if reducedMotion { resolveReduced() } else { startFlight() }
        }
        refreshScene()
    }

    private func resolveReduced() {
        guard let path else { return }
        let hit = SpearCollision.firstImpact(path: path, target: target, fromElapsed: 0, toElapsed: path.groundCrossing.elapsed)
        resolve(hit: hit != nil, point: hit.map { path.sample(elapsed: $0).tip } ?? path.groundCrossing.tip)
    }

    private func startFlight() {
        guard let path, let scene = scenePanel?.contentView as? SceneView else { return }
        scene.flightPath = path
        scene.flightElapsed = 0
        flightElapsed = 0
        flightClock = FlightClock()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.advanceFlight() }
        flightTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func advanceFlight() {
        guard let path, game.phase == .flying, let scene = scenePanel?.contentView as? SceneView else { return }
        let delta = flightClock.advance(now: ProcessInfo.processInfo.systemUptime)
        guard delta > 0 else { return }
        let previous = flightElapsed
        flightElapsed = min(flightElapsed + delta, path.groundCrossing.elapsed)
        if let hit = SpearCollision.firstImpact(path: path, target: target, fromElapsed: previous, toElapsed: flightElapsed) { resolve(hit: true, point: path.sample(elapsed: hit).tip); return }
        scene.flightElapsed = flightElapsed
        if flightElapsed >= path.groundCrossing.elapsed {
            let point = path.groundCrossing.tip
            if let screen = NSScreen.main, point.x < Double(screen.frame.minX) || point.x > Double(screen.frame.maxX) { resolve(hit: false, point: point) } else { resolve(hit: false, point: point) }
        }
    }

    private func resolve(hit: Bool, point: PresentationPoint) {
        guard game.phase == .flying else { return }
        flightTimer?.invalidate(); flightTimer = nil
        (scenePanel?.contentView as? SceneView)?.flightPath = nil
        game.resolve(hit: hit)
        refreshScene(result: (hit, point))
        resetTimer?.invalidate()
        resetTimer = Timer.scheduledTimer(withTimeInterval: reducedMotion ? 0.5 : 0.36, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.game.reset(); self.currentLaunch = nil; self.path = nil; self.round += 1
            self.reposition(); self.refreshScene()
        }
    }

    private func stopTimers() { [flightTimer, resetTimer].forEach { $0?.invalidate() }; flightTimer = nil; resetTimer = nil }
}

private final class GamePanel: NSPanel {
    init(frame: NSRect, interaction: AnchorInteraction) { super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false); isOpaque = false; backgroundColor = .clear; hasShadow = false; level = .floating; collectionBehavior = [.canJoinAllSpaces, .stationary]; ignoresMouseEvents = interaction.ignoresMouseEvents }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private enum AnchorInteraction { case input, displayOnly; var ignoresMouseEvents: Bool { self == .displayOnly } }
private final class DisplayPanel: NSPanel {
    init(frame: NSRect) { super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false); isOpaque = false; backgroundColor = .clear; hasShadow = false; level = .floating; collectionBehavior = [.canJoinAllSpaces, .stationary]; ignoresMouseEvents = FlightLayerContract.visibilityOnly.ignoresMouseEvents }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
