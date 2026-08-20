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
    private var motionPolicy = MotionPolicy.standard
    private var presentationPolicy = PresentationPolicy.standard
    private var flightElapsed = 0.0

    var isVisible: Bool { !panels.isEmpty }
    func toggle() { isVisible ? hide() : show() }

    func show() {
        guard panels.isEmpty else { reposition(); return }
        let left = GamePanel(frame: .zero)
        let right = GamePanel(frame: .zero)
        left.contentView = SpearThrowView(frame: .zero) { [weak self] event in self?.handle(event) }
        right.contentView = TargetView(frame: .zero)
        panels = [left, right]
        render(); reposition()
        panels.forEach { $0.orderFrontRegardless() }
    }

    func reposition() {
        guard panels.count == 2, let screen = NSScreen.main else { return }
        let frame = screen.frame
        let bottomSafeInset = min(max(frame.height * 0.08, 72), 120)
        let bottomY = frame.minY + bottomSafeInset
        panels[0].setFrame(NSRect(x: frame.minX, y: bottomY, width: boxSize.width, height: boxSize.height), display: true)
        panels[1].setFrame(NSRect(x: frame.maxX - boxSize.width, y: bottomY, width: boxSize.width, height: boxSize.height), display: true)
    }

    func hide() {
        stopTimers(); hideFlight()
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
    }

    private func handle(_ event: SpearThrowView.Event) {
        switch event {
        case .press:
            motionPolicy = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? .reducedMotion : .standard
            presentationPolicy = motionPolicy.showsFlightAnimation ? .standard : .reducedMotion
            lifecycle = PresentationLifecycle(policy: presentationPolicy)
            game.beginAim(); lifecycle.beginAim()
            guard game.phase == .aiming else { return }
            startAiming()
        case .release:
            guard game.phase == .aiming else { return }
            game.release(); lifecycle.release(); aimingTimer?.invalidate()
            guard motionPolicy.showsFlightAnimation else { resolveFlight(); return }
            startFlight()
        }
        render()
    }

    private func startAiming() {
        aimingTimer?.invalidate()
        aimingTimer = Timer.scheduledTimer(withTimeInterval: motionPolicy.aimingUpdateInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.game.advanceAim(by: self.motionPolicy.aimingUpdateInterval)
            self.render()
        }
    }

    private func startFlight() {
        guard let screen = NSScreen.main,
              let left = panels.first?.contentView as? SpearThrowView,
              let target = panels.last?.contentView as? TargetView,
              let leftPanel = panels.first, let rightPanel = panels.last else { return }
        let start = leftPanel.convertToScreen(NSRect(origin: left.handPoint, size: .zero)).origin
        let targetPoint = rightPanel.convertToScreen(NSRect(origin: target.targetPoint, size: .zero)).origin
        let hit = abs((game.landingHeight ?? 0.5) - game.target.normalizedHeight) <= SpearGameState.hitTolerance
        let end = hit ? targetPoint : NSPoint(x: targetPoint.x + 42, y: targetPoint.y + ((game.landingHeight ?? 0.5) > game.target.normalizedHeight ? 32 : -32))
        let panel = FlightPanel(frame: screen.frame)
        let flight = FlightView(frame: NSRect(origin: .zero, size: screen.frame.size))
        flight.start = NSPoint(x: start.x - screen.frame.minX, y: start.y - screen.frame.minY)
        flight.end = NSPoint(x: end.x - screen.frame.minX, y: end.y - screen.frame.minY)
        panel.contentView = flight
        flightPanel = panel
        panel.orderFrontRegardless()
        flightElapsed = 0
        flightTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.advanceFlight() }
    }

    private func advanceFlight() {
        let step = 1.0 / 60.0
        flightElapsed += step
        lifecycle.advance(by: step)
        if lifecycle.phase == .flying, let view = flightPanel?.contentView as? FlightView {
            view.progress = CGFloat(min(1, max(0, (flightElapsed - presentationPolicy.launchDuration) / presentationPolicy.flightDuration)))
        }
        if flightElapsed >= presentationPolicy.launchDuration + presentationPolicy.flightDuration { resolveFlight() }
        render()
    }

    private func resolveFlight() {
        flightTimer?.invalidate(); flightTimer = nil; hideFlight()
        game.resolveFlight(); render()
        let cueDuration = presentationPolicy.showsFlightTranslation
            ? presentationPolicy.resetDuration - presentationPolicy.launchDuration - presentationPolicy.flightDuration
            : presentationPolicy.resetDuration
        resultTimer = Timer.scheduledTimer(withTimeInterval: cueDuration, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.game.finishRound()
            self.lifecycle = PresentationLifecycle(policy: self.presentationPolicy)
            self.render()
        }
    }

    private func hideFlight() {
        flightPanel?.orderOut(nil)
        flightPanel = nil
    }

    private func render() {
        (panels.first?.contentView as? SpearThrowView)?.state = game
        (panels.first?.contentView as? SpearThrowView)?.pose = lifecycle.pose
        (panels.last?.contentView as? TargetView)?.state = game
    }

    private func stopTimers() {
        [aimingTimer, flightTimer, resultTimer].forEach { $0?.invalidate() }
        aimingTimer = nil; flightTimer = nil; resultTimer = nil
    }
}

private final class GamePanel: NSPanel {
    init(frame: NSRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false; backgroundColor = .clear; hasShadow = false; level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        ignoresMouseEvents = false
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class FlightPanel: NSPanel {
    init(frame: NSRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false; backgroundColor = .clear; hasShadow = false; level = .floating
        ignoresMouseEvents = true
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
