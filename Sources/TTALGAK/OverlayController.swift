import AppKit

final class OverlayController {
    private let boxSize = NSSize(width: 180, height: 110)
    private var panels: [PlaceholderPanel] = []
    private var screenParametersObserver: NSObjectProtocol?
    private var baselineScreenFrame: NSRect?
    private var baselineBottomInset: CGFloat = 0

    init() {
        screenParametersObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clearPlacementBaseline()
            self?.reposition()
        }
    }

    deinit {
        if let screenParametersObserver {
            NotificationCenter.default.removeObserver(screenParametersObserver)
        }
    }

    var isVisible: Bool { !panels.isEmpty }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        guard panels.isEmpty else {
            reposition()
            return
        }
        // Two bounded transparent panels are the overlay. No desktop-sized window
        // exists, so every empty point belongs to the app below it.
        panels = [
            PlaceholderPanel(frame: .zero, label: "TTALGAK LEFT"),
            PlaceholderPanel(frame: .zero, label: "TTALGAK RIGHT")
        ]
        refreshPlacementBaseline()
        panels.forEach { $0.orderFrontRegardless() }
    }

    /// Samples the current public visible-frame bottom once; it does not observe Dock state.
    func refreshPlacementBaseline() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        baselineScreenFrame = frame
        baselineBottomInset = max(0, screen.visibleFrame.minY - frame.minY)
        reposition()
    }

    private func clearPlacementBaseline() {
        baselineScreenFrame = nil
        baselineBottomInset = 0
    }

    func reposition() {
        guard panels.count == 2, let screen = NSScreen.main else { return }
        let frame = screen.frame
        let inset = baselineScreenFrame == frame ? baselineBottomInset : 0
        // ponytail: one snapshot per display geometry; add a Dock-specific public event only
        // if macOS ships one. Dock changes require the explicit refresh action.
        let bottomY = frame.minY + inset
        panels[0].setFrame(NSRect(x: frame.minX, y: bottomY, width: boxSize.width, height: boxSize.height), display: true)
        panels[1].setFrame(NSRect(x: frame.maxX - boxSize.width, y: bottomY, width: boxSize.width, height: boxSize.height), display: true)
    }

    func hide() {
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
    }
}

private final class PlaceholderPanel: NSPanel {
    init(frame: NSRect, label: String) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        ignoresMouseEvents = false
        contentView = PlaceholderBoxView(frame: NSRect(origin: .zero, size: frame.size), label: label)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Input policy: only these two bounded 180x110pt panels receive mouse events.
/// There is deliberately no full-screen overlay window, so every point outside
/// the visible boxes is owned by the underlying application and clicks pass through.
private final class PlaceholderBoxView: NSView {
    private let label: String

    init(frame: NSRect, label: String) {
        self.label = label
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.systemTeal.withAlphaComponent(0.32).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 12, yRadius: 12).fill()
        NSColor.white.withAlphaComponent(0.72).setStroke()
        let border = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 12, yRadius: 12)
        border.lineWidth = 1
        border.stroke()

        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white.withAlphaComponent(0.9),
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        ]
        let text = NSAttributedString(string: label, attributes: attributes)
        let size = text.size()
        text.draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2))
    }

    override func mouseDown(with event: NSEvent) {
        // Placeholder policy: consume clicks inside the visible box only.
        // Future stickman hit-testing must shrink this to the character shape.
    }
}
