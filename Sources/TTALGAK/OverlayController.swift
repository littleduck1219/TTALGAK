import AppKit
import SpearGameCore

final class OverlayController {
    private let boxSize = NSSize(width: 180, height: 110)
    private var panels: [GamePanel] = []
    private var flightPanel: FlightPanel?
    private var game = SpearGameState()
    private var lifecycle = PresentationLifecycle(policy: .standard)
    private var aimingTimer: Timer?
    private var flightTimer: Timer?
    private var resultTimer: Timer?
    private var resetTimer: Timer?
    private var motionPolicy = MotionPolicy.standard
    private var presentationPolicy = PresentationPolicy.standard
    private var releaseElapsed = 0.0
    private var flightElapsed = 0.0
    private var flightPath: BallisticFlightPath?
    private var targetCenter = PresentationPoint(x: 0, y: 0)
    private var finalTip = PresentationPoint(x: 0, y: 0)

    var isVisible: Bool { !panels.isEmpty }
    func toggle() { isVisible ? hide() : show() }
    func show() {
        guard panels.isEmpty else { reposition(); return }
        let left = GamePanel(frame: .zero, interaction: .input)
        let right = GamePanel(frame: .zero, interaction: .displayOnly)
        left.contentView = SpearThrowView(frame: .zero) { [weak self] event in self?.handle(event) }
        right.contentView = TargetView(frame: .zero)
        panels = [left, right]; reposition(); render(); panels.forEach { $0.orderFrontRegardless() }
    }
    func reposition() {
        guard panels.count == 2, let screen = NSScreen.main else { return }
        let frame = screen.frame; let bottomY = frame.minY + min(max(frame.height * 0.08, 72), 120)
        panels[0].setFrame(NSRect(x: frame.minX, y: bottomY, width: boxSize.width, height: boxSize.height), display: true)
        panels[1].setFrame(NSRect(x: frame.maxX - boxSize.width, y: bottomY, width: boxSize.width, height: boxSize.height), display: true)
        setupReadyTarget()
    }
    func hide() { stopTimers(); hideFlight(); panels.forEach { $0.orderOut(nil) }; panels.removeAll() }

    private func setupReadyTarget() {
        guard let left = panels.first, let right = panels.last else { return }
        let geometry = SpearPresentationGeometry(pose: .release, aimDegrees: game.target.canonicalAimDegrees)
        let start = left.convertToScreen(NSRect(origin: geometry.flightStart.cgPoint, size: .zero)).origin
        let targetX = Double(right.frame.minX + 132)
        targetCenter = BallisticTarget.center(start: PresentationPoint(x: Double(start.x), y: Double(start.y)), targetX: targetX, position: game.target)
        (right.contentView as? TargetView)?.targetPoint = right.convertFromScreen(NSRect(origin: targetCenter.cgPoint, size: .zero)).origin
    }

    private func handle(_ event: SpearThrowView.Event) {
        switch event {
        case .press:
            motionPolicy = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? .reducedMotion : .standard
            presentationPolicy = motionPolicy.showsFlightAnimation ? .standard : .reducedMotion
            lifecycle = PresentationLifecycle(policy: presentationPolicy); game.beginAim(); lifecycle.beginAim(); guard game.phase == .aiming else { return }; startAiming()
        case .release:
            guard game.phase == .aiming else { return }
            game.release(); lifecycle.release(); aimingTimer?.invalidate()
            guard motionPolicy.showsFlightAnimation else { resolveFlight(hit: false); return }
            freezeFlightSnapshot(); startFlight()
        }
        render()
    }
    private func startAiming() { aimingTimer?.invalidate(); aimingTimer = Timer.scheduledTimer(withTimeInterval: motionPolicy.aimingUpdateInterval, repeats: true) { [weak self] _ in guard let self else { return }; self.game.advanceAim(by: self.motionPolicy.aimingUpdateInterval); self.render() } }

    private func freezeFlightSnapshot() {
        guard let left = panels.first?.contentView as? SpearThrowView, let leftPanel = panels.first else { return }
        let geometry = SpearPresentationGeometry(pose: .release, aimDegrees: left.aimDegrees)
        let start = leftPanel.convertToScreen(NSRect(origin: geometry.flightStart.cgPoint, size: .zero)).origin
        flightPath = BallisticFlightPath(start: PresentationPoint(x: start.x, y: start.y), targetX: targetCenter.x, aimDegrees: geometry.aimDegrees)
        finalTip = flightPath?.sample(elapsed: BallisticFlightPath.visualDuration).tip ?? PresentationPoint(x: start.x, y: start.y)
    }
    private func startFlight() { releaseElapsed = 0; flightElapsed = 0; flightTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.advanceFlight() } }
    private func advanceFlight() {
        let step = 1.0 / 60.0
        if lifecycle.phase == .release {
            releaseElapsed += step; lifecycle.advance(by: step)
            (panels.first?.contentView as? SpearThrowView)?.releaseProgress = min(releaseElapsed / presentationPolicy.launchDuration, 1)
            if lifecycle.phase == .flying { showFlightPanel() }
            render(); return
        }
        guard lifecycle.phase == .flying, let path = flightPath else { return }
        let previous = flightElapsed; flightElapsed = min(flightElapsed + step, BallisticFlightPath.visualDuration)
        if let impact = SpearCollision.firstImpact(path: path, target: targetCenter, fromElapsed: previous, toElapsed: flightElapsed) { flightElapsed = impact; (flightPanel?.contentView as? FlightView)?.elapsed = impact; resolveFlight(hit: true); return }
        (flightPanel?.contentView as? FlightView)?.elapsed = flightElapsed
        lifecycle.advance(by: step)
        if flightElapsed >= BallisticFlightPath.visualDuration { resolveFlight(hit: false) }
        render()
    }
    private func showFlightPanel() {
        guard let screen = NSScreen.main, let path = flightPath else { return }
        let panel = FlightPanel(frame: screen.frame, contract: .visibilityOnly); let flight = FlightView(frame: NSRect(origin: .zero, size: screen.frame.size)); flight.path = path; flight.elapsed = 0; panel.contentView = flight; flightPanel = panel; panel.orderFrontRegardless()
    }
    private func resolveFlight(hit: Bool) {
        flightTimer?.invalidate(); flightTimer = nil; game.resolveFlight(hit: hit); render()
        let resultDuration = presentationPolicy.showsFlightTranslation ? presentationPolicy.impactDuration + presentationPolicy.resultHoldDuration : presentationPolicy.staticResultDuration
        resultTimer = Timer.scheduledTimer(withTimeInterval: resultDuration, repeats: false) { [weak self] _ in guard let self else { return }; self.hideFlight(); self.resetTimer = Timer.scheduledTimer(withTimeInterval: self.presentationPolicy.resetDuration, repeats: false) { [weak self] _ in guard let self else { return }; self.game.finishRound(); self.lifecycle = PresentationLifecycle(policy: self.presentationPolicy); self.setupReadyTarget(); self.render() } }
    }
    private func hideFlight() { guard FlightLayerContract.visibilityOnly.removesAtImpact else { return }; flightPanel?.orderOut(nil); flightPanel = nil }
    private func render() { let left = panels.first?.contentView as? SpearThrowView; left?.state = game; left?.pose = lifecycle.pose; left?.aimDegrees = game.angleDegrees; let right = panels.last?.contentView as? TargetView; right?.state = game; right?.finalTip = (panels.last?.convertFromScreen(NSRect(origin: finalTip.cgPoint, size: .zero)).origin ?? .zero) }
    private func stopTimers() { [aimingTimer, flightTimer, resultTimer, resetTimer].forEach { $0?.invalidate() }; aimingTimer = nil; flightTimer = nil; resultTimer = nil; resetTimer = nil }
}
private extension PresentationPoint { var cgPoint: NSPoint { NSPoint(x: CGFloat(x), y: CGFloat(y)) } }
private final class GamePanel: NSPanel { init(frame: NSRect, interaction: AnchorInteraction) { super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false); isOpaque = false; backgroundColor = .clear; hasShadow = false; level = .floating; collectionBehavior = [.canJoinAllSpaces, .stationary]; ignoresMouseEvents = interaction.ignoresMouseEvents }; override var canBecomeKey: Bool { false }; override var canBecomeMain: Bool { false } }
private final class FlightPanel: NSPanel { init(frame: NSRect, contract: FlightLayerContract) { super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false); isOpaque = false; backgroundColor = .clear; hasShadow = false; level = .floating; ignoresMouseEvents = contract.ignoresMouseEvents; appearance = NSAppearance(named: .aqua) }; override var canBecomeKey: Bool { false }; override var canBecomeMain: Bool { false } }
