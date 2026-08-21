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
    private var flightClock = FlightClock()
    private var flightPath: BallisticFlightPath?
    private var frozenAssetSnapshot: MotionAssetSnapshot?
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
        guard let left = panels.first?.contentView as? SpearThrowView, let right = panels.last else { return }
        let snapshot = left.assetSnapshot(for: MotionAssetBand.forRawAim(game.target.canonicalAimDegrees))
        let targetX = Double(right.frame.minX + 132)
        targetCenter = BallisticTarget.center(start: snapshot.flightStart, targetX: targetX, position: game.target)
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
            freezeFlightSnapshot(); startRelease()
        }
        render()
    }
    private func startAiming() { aimingTimer?.invalidate(); aimingTimer = Timer.scheduledTimer(withTimeInterval: motionPolicy.aimingUpdateInterval, repeats: true) { [weak self] _ in guard let self else { return }; self.game.advanceAim(by: self.motionPolicy.aimingUpdateInterval); self.render() } }

    private func freezeFlightSnapshot() {
        guard let left = panels.first?.contentView as? SpearThrowView else { return }
        let snapshot = left.assetSnapshot()
        frozenAssetSnapshot = snapshot
        flightPath = BallisticFlightPath(start: snapshot.flightStart, targetX: targetCenter.x, snapshot: snapshot)
        finalTip = flightPath?.sample(elapsed: BallisticFlightPath.visualDuration).tip ?? snapshot.flightStart
    }
    private func startRelease() {
        releaseElapsed = 0
        (panels.first?.contentView as? SpearThrowView)?.playReleaseFrames()
        DispatchQueue.main.asyncAfter(deadline: .now() + presentationPolicy.launchDuration) { [weak self] in
            guard let self, !self.panels.isEmpty, self.lifecycle.phase == .release else { return }
            self.releaseElapsed = self.presentationPolicy.launchDuration
            self.lifecycle.advance(by: self.presentationPolicy.launchDuration)
            self.showFlightPanel()
            self.startFlight()
            self.render()
        }
    }
    private func startFlight() {
        flightTimer?.invalidate()
        flightElapsed = 0
        flightClock = FlightClock()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.advanceFlight() }
        flightTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    private func advanceFlight() {
        guard lifecycle.phase == .flying, let path = flightPath else { return }
        let delta = flightClock.advance(now: ProcessInfo.processInfo.systemUptime)
        guard delta > 0 else { return }
        let previous = flightElapsed; flightElapsed = min(flightElapsed + delta, BallisticFlightPath.visualDuration)
        if let impact = SpearCollision.firstImpact(path: path, target: targetCenter, fromElapsed: previous, toElapsed: flightElapsed) { flightElapsed = impact; (flightPanel?.contentView as? FlightView)?.elapsed = impact; resolveFlight(hit: true); return }
        (flightPanel?.contentView as? FlightView)?.elapsed = flightElapsed
        lifecycle.advance(by: delta)
        if flightElapsed >= BallisticFlightPath.visualDuration { resolveFlight(hit: false) }
        render()
    }
    private func showFlightPanel() {
        guard let screen = NSScreen.main, let path = flightPath else { return }
        hideFlight()
        let panel = FlightPanel(frame: screen.frame, contract: .visibilityOnly); let flight = FlightView(frame: NSRect(origin: .zero, size: screen.frame.size)); flight.path = path; flight.elapsed = 0; panel.contentView = flight
        let contentOrigin = flight.convertToScreen(NSRect(origin: .zero, size: .zero)).origin
        flight.screenOrigin = PresentationPoint(x: contentOrigin.x, y: contentOrigin.y)
        flightPanel = panel; panel.orderFrontRegardless()
    }
    private func resolveFlight(hit: Bool) {
        guard game.phase == .flying else { return }
        flightTimer?.invalidate(); flightTimer = nil
        // Accepted M-01/M-02 contract: remove the visibility-only flight layer at impact; TargetView owns the result cue.
        hideFlight()
        game.resolveFlight(hit: hit); render()
        let resultDuration = presentationPolicy.showsFlightTranslation ? presentationPolicy.impactDuration + presentationPolicy.resultHoldDuration : presentationPolicy.staticResultDuration
        resultTimer = Timer.scheduledTimer(withTimeInterval: resultDuration, repeats: false) { [weak self] _ in guard let self else { return }; self.resetTimer = Timer.scheduledTimer(withTimeInterval: self.presentationPolicy.resetDuration, repeats: false) { [weak self] _ in guard let self else { return }; self.game.finishRound(); self.lifecycle = PresentationLifecycle(policy: self.presentationPolicy); self.frozenAssetSnapshot = nil; self.setupReadyTarget(); self.render() } }
    }
    private func hideFlight() { guard FlightLayerContract.visibilityOnly.removesAtImpact else { return }; flightPanel?.orderOut(nil); flightPanel = nil }
    private func render() { let left = panels.first?.contentView as? SpearThrowView; left?.state = game; left?.pose = lifecycle.pose; left?.aimDegrees = game.angleDegrees; let right = panels.last?.contentView as? TargetView; right?.state = game; right?.finalTip = (panels.last?.convertFromScreen(NSRect(origin: finalTip.cgPoint, size: .zero)).origin ?? .zero) }
    private func stopTimers() { [aimingTimer, flightTimer, resultTimer, resetTimer].forEach { $0?.invalidate() }; aimingTimer = nil; flightTimer = nil; resultTimer = nil; resetTimer = nil }
}
private extension PresentationPoint { var cgPoint: NSPoint { NSPoint(x: CGFloat(x), y: CGFloat(y)) } }
private final class GamePanel: NSPanel { init(frame: NSRect, interaction: AnchorInteraction) { super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false); isOpaque = false; backgroundColor = .clear; hasShadow = false; level = .floating; collectionBehavior = [.canJoinAllSpaces, .stationary]; ignoresMouseEvents = interaction.ignoresMouseEvents }; override var canBecomeKey: Bool { false }; override var canBecomeMain: Bool { false } }
private final class FlightPanel: NSPanel { init(frame: NSRect, contract: FlightLayerContract) { super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false); isOpaque = false; backgroundColor = .clear; hasShadow = false; level = .floating; ignoresMouseEvents = contract.ignoresMouseEvents; appearance = NSAppearance(named: .aqua) }; override var canBecomeKey: Bool { false }; override var canBecomeMain: Bool { false } }
