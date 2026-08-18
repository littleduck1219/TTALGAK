import AppKit
import SpearGameCore

final class OverlayController {
    private let boxSize = NSSize(width: 180, height: 110)
    private var panels: [GamePanel] = []
    private var game = SpearGameState()
    private var aimingTimer: Timer?
    private var flightTimer: Timer?
    private var resultTimer: Timer?
    private var motionPolicy = MotionPolicy.standard

    var isVisible: Bool { !panels.isEmpty }

    func toggle() { isVisible ? hide() : show() }

    func show() {
        guard panels.isEmpty else { reposition(); return }
        // No desktop-sized window exists: points outside these panels remain owned by the app below.
        let left = GamePanel(frame: .zero)
        let right = GamePanel(frame: .zero)
        let leftView = SpearThrowView(frame: .zero) { [weak self] event in self?.handle(event) }
        left.contentView = leftView
        right.contentView = TargetView(frame: .zero)
        panels = [left, right]
        render()
        reposition()
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
        stopTimers()
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
    }

    private func handle(_ event: SpearThrowView.Event) {
        switch event {
        case .press:
            motionPolicy = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? .reducedMotion : .standard
            game.beginAim()
            guard game.phase == .aiming else { return }
            startAiming()
        case .release:
            let wasAiming = game.phase == .aiming
            game.release()
            guard wasAiming, game.phase == .flying else { return }
            aimingTimer?.invalidate()
            if motionPolicy.showsFlightAnimation {
                flightTimer = Timer.scheduledTimer(withTimeInterval: 0.21, repeats: false) { [weak self] _ in self?.resolveFlight() }
            } else {
                resolveFlight()
            }
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

    private func resolveFlight() {
        game.resolveFlight()
        render()
        resultTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.game.finishRound()
            self?.render()
        }
    }

    private func render() {
        let reducesMotion = !motionPolicy.showsFlightAnimation
        (panels.first?.contentView as? SpearThrowView)?.state = game
        (panels.first?.contentView as? SpearThrowView)?.reducesMotion = reducesMotion
        (panels.last?.contentView as? TargetView)?.state = game
        (panels.last?.contentView as? TargetView)?.reducesMotion = reducesMotion
    }

    private func stopTimers() {
        [aimingTimer, flightTimer, resultTimer].forEach { $0?.invalidate() }
        aimingTimer = nil; flightTimer = nil; resultTimer = nil
    }
}

private final class GamePanel: NSPanel {
    init(frame: NSRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        ignoresMouseEvents = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
