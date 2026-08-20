import AppKit
import SpearGameCore

private let charcoal = NSColor(calibratedRed: 25/255, green: 31/255, blue: 40/255, alpha: 1)
private let blue = NSColor(calibratedRed: 45/255, green: 100/255, blue: 241/255, alpha: 1)
private let yellow = NSColor(calibratedRed: 243/255, green: 182/255, blue: 31/255, alpha: 1)
private let green = NSColor(calibratedRed: 17/255, green: 122/255, blue: 70/255, alpha: 1)
private let red = NSColor(calibratedRed: 217/255, green: 45/255, blue: 32/255, alpha: 1)

final class SpearThrowView: NSView {
    enum Event { case press, release }
    var state = SpearGameState() { didSet { needsDisplay = true } }
    var pose = StickmanPose.ready { didSet { needsDisplay = true } }
    private let onEvent: (Event) -> Void

    init(frame: NSRect, onEvent: @escaping (Event) -> Void) {
        self.onEvent = onEvent
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { nil }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { onEvent(.press) }
    override func mouseUp(with event: NSEvent) { onEvent(.release) }

    override func draw(_ dirtyRect: NSRect) {
        drawStickman(at: NSPoint(x: 52, y: 33), pose: pose)
    }

    var handPoint: NSPoint { NSPoint(x: 68, y: 49) }

    private func drawStickman(at origin: NSPoint, pose: StickmanPose) {
        charcoal.setStroke()
        let head = NSBezierPath(ovalIn: NSRect(x: origin.x - 6, y: origin.y + 30, width: 12, height: 12))
        head.lineWidth = 2; head.stroke()
        let lean: CGFloat = pose == .aiming ? -3 : pose == .release ? 4 : 0
        let body = NSBezierPath()
        body.move(to: NSPoint(x: origin.x, y: origin.y + 30)); body.line(to: NSPoint(x: origin.x + lean, y: origin.y + 10))
        body.move(to: NSPoint(x: origin.x + lean, y: origin.y + 10)); body.line(to: NSPoint(x: origin.x - 9, y: origin.y))
        body.move(to: NSPoint(x: origin.x + lean, y: origin.y + 10)); body.line(to: NSPoint(x: origin.x + 9, y: origin.y))
        let shoulder = NSPoint(x: origin.x, y: origin.y + 23)
        let hand: NSPoint
        switch pose {
        case .aiming: hand = NSPoint(x: origin.x - 15, y: origin.y + 25)
        case .release: hand = NSPoint(x: origin.x + 18, y: origin.y + 25)
        case .flying: hand = NSPoint(x: origin.x + 15, y: origin.y + 20)
        default: hand = NSPoint(x: origin.x + 16, y: origin.y + 16)
        }
        body.move(to: shoulder); body.line(to: hand)
        body.lineWidth = 2; body.lineCapStyle = .round; body.stroke()
        guard pose == .ready || pose == .aiming else { return }
        let angle: CGFloat = pose == .aiming ? 0.9 : 0.45
        drawSpear(from: hand, angle: angle, color: blue)
    }

    private func drawSpear(from start: NSPoint, angle: CGFloat, color: NSColor) {
        let end = NSPoint(x: start.x + cos(angle) * 36, y: start.y + sin(angle) * 36)
        color.setStroke()
        let spear = NSBezierPath(); spear.move(to: start); spear.line(to: end); spear.lineWidth = 2; spear.lineCapStyle = .round; spear.stroke()
        let tip = NSBezierPath(); tip.move(to: end); tip.line(to: NSPoint(x: end.x - 5, y: end.y - 3)); tip.move(to: end); tip.line(to: NSPoint(x: end.x - 4, y: end.y + 4)); tip.lineWidth = 2; tip.stroke()
    }
}

final class TargetView: NSView {
    var state = SpearGameState() { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        let point = targetPoint
        drawTarget(at: point)
        if state.phase == .hit { drawCheck(at: point) }
        if state.phase == .miss { drawMiss(at: missPoint) }
    }

    var targetPoint: NSPoint {
        NSPoint(x: 90, y: 22 + CGFloat(state.target.normalizedHeight) * 66)
    }

    private var missPoint: NSPoint {
        let landedAboveTarget = (state.landingHeight ?? 0.5) > state.target.normalizedHeight
        return NSPoint(x: 134, y: targetPoint.y + (landedAboveTarget ? 26 : -26))
    }

    private func drawTarget(at point: NSPoint) {
        charcoal.setStroke()
        for radius: CGFloat in [16, 10] {
            let circle = NSBezierPath(ovalIn: NSRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
            circle.lineWidth = 2; circle.stroke()
        }
        yellow.setFill(); NSBezierPath(ovalIn: NSRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)).fill()
    }

    private func drawCheck(at point: NSPoint) {
        green.setStroke(); let mark = NSBezierPath(); mark.move(to: NSPoint(x: point.x + 16, y: point.y - 4)); mark.line(to: NSPoint(x: point.x + 21, y: point.y - 9)); mark.line(to: NSPoint(x: point.x + 30, y: point.y + 6)); mark.lineWidth = 2; mark.stroke()
        NSAttributedString(string: "+1", attributes: [.font: NSFont.systemFont(ofSize: 12, weight: .bold), .foregroundColor: green]).draw(at: NSPoint(x: point.x - 7, y: point.y + 22))
    }

    private func drawMiss(at point: NSPoint) {
        red.setStroke(); let mark = NSBezierPath(); mark.move(to: NSPoint(x: point.x - 5, y: point.y - 5)); mark.line(to: NSPoint(x: point.x + 5, y: point.y + 5)); mark.move(to: NSPoint(x: point.x - 5, y: point.y + 5)); mark.line(to: NSPoint(x: point.x + 5, y: point.y - 5)); mark.lineWidth = 2; mark.stroke()
    }
}

final class FlightView: NSView {
    var start = NSPoint.zero { didSet { needsDisplay = true } }
    var end = NSPoint.zero { didSet { needsDisplay = true } }
    var progress: CGFloat = 0 { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        let t = min(max(progress, 0), 1)
        let x = start.x + (end.x - start.x) * t
        let arch = sin(t * .pi) * min(48, abs(end.x - start.x) * 0.06)
        let y = start.y + (end.y - start.y) * t + arch
        drawSpear(at: NSPoint(x: x, y: y), angle: atan2(end.y - start.y, end.x - start.x))
    }

    private func drawSpear(at point: NSPoint, angle: CGFloat) {
        let length: CGFloat = 42
        let tail = NSPoint(x: point.x - cos(angle) * length / 2, y: point.y - sin(angle) * length / 2)
        let tip = NSPoint(x: point.x + cos(angle) * length / 2, y: point.y + sin(angle) * length / 2)
        blue.setStroke(); let spear = NSBezierPath(); spear.move(to: tail); spear.line(to: tip); spear.lineWidth = 2; spear.lineCapStyle = .round; spear.stroke()
        let head = NSBezierPath(); head.move(to: tip); head.line(to: NSPoint(x: tip.x - 6, y: tip.y - 3)); head.move(to: tip); head.line(to: NSPoint(x: tip.x - 5, y: tip.y + 4)); head.stroke()
    }
}
