import AppKit
import SpearGameCore

private let ink = NSColor.black

final class SpearThrowView: NSView {
    enum Event { case press, release }
    var state = SpearGameState() { didSet { needsDisplay = true } }
    var pose = StickmanPose.ready { didSet { needsDisplay = true } }
    var aimDegrees = 45.0 { didSet { needsDisplay = true } }
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
        drawStickman(geometry: geometry)
    }

    var geometry: SpearPresentationGeometry { SpearPresentationGeometry(pose: pose, aimDegrees: aimDegrees) }

    private func drawStickman(geometry: SpearPresentationGeometry) {
        let origin = NSPoint(x: 48, y: 33)
        let pose = geometry.pose
        ink.setStroke()
        let head = NSBezierPath(ovalIn: NSRect(x: origin.x - 6, y: origin.y + 30, width: 12, height: 12))
        head.lineWidth = 3; head.lineCapStyle = .round; head.lineJoinStyle = .round; head.stroke()
        let lean: CGFloat = pose == .aiming ? -3 : pose == .release ? 4 : 0
        let body = NSBezierPath()
        body.move(to: NSPoint(x: origin.x, y: origin.y + 30)); body.line(to: NSPoint(x: origin.x + lean, y: origin.y + 10))
        body.move(to: NSPoint(x: origin.x + lean, y: origin.y + 10)); body.line(to: NSPoint(x: origin.x - 9, y: origin.y))
        body.move(to: NSPoint(x: origin.x + lean, y: origin.y + 10)); body.line(to: NSPoint(x: origin.x + 9, y: origin.y))
        let shoulder = NSPoint(x: CGFloat(geometry.shoulder.x), y: CGFloat(geometry.shoulder.y))
        let hand = NSPoint(x: CGFloat(geometry.hand.x), y: CGFloat(geometry.hand.y))
        body.move(to: shoulder); body.line(to: hand)
        body.lineWidth = 3; body.lineCapStyle = .round; body.lineJoinStyle = .round; body.stroke()
        guard pose == .ready || pose == .aiming else { return }
        drawHeldSpear(from: NSPoint(x: CGFloat(geometry.heldSpearOrigin.x), y: CGFloat(geometry.heldSpearOrigin.y)), to: NSPoint(x: CGFloat(geometry.heldSpearEnd.x), y: CGFloat(geometry.heldSpearEnd.y)))
    }

    private func drawHeldSpear(from start: NSPoint, to end: NSPoint) {
        ink.setStroke()
        let spear = NSBezierPath(); spear.move(to: start); spear.line(to: end); spear.lineWidth = 3; spear.lineCapStyle = .round; spear.lineJoinStyle = .round; spear.stroke()
        let tip = NSBezierPath(); tip.move(to: end); tip.line(to: NSPoint(x: end.x - 5, y: end.y - 3)); tip.move(to: end); tip.line(to: NSPoint(x: end.x - 4, y: end.y + 4)); tip.lineWidth = 2.5; tip.lineCapStyle = .round; tip.lineJoinStyle = .round; tip.stroke()
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
        NSPoint(x: 132, y: 22 + CGFloat(state.target.normalizedHeight) * 66)
    }

    private var missPoint: NSPoint {
        let landedAboveTarget = (state.landingHeight ?? 0.5) > state.target.normalizedHeight
        return NSPoint(x: 134, y: targetPoint.y + (landedAboveTarget ? 26 : -26))
    }

    private func drawTarget(at point: NSPoint) {
        ink.setStroke()
        for radius: CGFloat in [16, 10] {
            let circle = NSBezierPath(ovalIn: NSRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
            circle.lineWidth = 3.5; circle.lineCapStyle = .round; circle.lineJoinStyle = .round; circle.stroke()
        }
        ink.setFill(); NSBezierPath(ovalIn: NSRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)).fill()
    }

    private func drawCheck(at point: NSPoint) {
        ink.setStroke(); let mark = NSBezierPath(); mark.move(to: NSPoint(x: point.x + 16, y: point.y - 4)); mark.line(to: NSPoint(x: point.x + 21, y: point.y - 9)); mark.line(to: NSPoint(x: point.x + 30, y: point.y + 6)); mark.lineWidth = 3.5; mark.lineCapStyle = .round; mark.lineJoinStyle = .round; mark.stroke()
        NSAttributedString(string: "+1", attributes: [.font: NSFont.systemFont(ofSize: 14, weight: .bold), .foregroundColor: ink]).draw(at: NSPoint(x: point.x - 7, y: point.y + 22))
    }

    private func drawMiss(at point: NSPoint) {
        ink.setStroke(); let mark = NSBezierPath(); mark.move(to: NSPoint(x: point.x - 5, y: point.y - 5)); mark.line(to: NSPoint(x: point.x + 5, y: point.y + 5)); mark.move(to: NSPoint(x: point.x - 5, y: point.y + 5)); mark.line(to: NSPoint(x: point.x + 5, y: point.y - 5)); mark.lineWidth = 3.5; mark.lineCapStyle = .round; mark.lineJoinStyle = .round; mark.stroke()
    }
}

final class FlightView: NSView {
    var start = NSPoint.zero { didSet { needsDisplay = true } }
    var end = NSPoint.zero { didSet { needsDisplay = true } }
    var aimDegrees = 45.0 { didSet { needsDisplay = true } }
    var progress: CGFloat = 0 { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        let path = PresentationFlightPath(
            start: PresentationPoint(x: Double(start.x), y: Double(start.y)),
            end: PresentationPoint(x: Double(end.x), y: Double(end.y)),
            aimDegrees: aimDegrees
        )
        let point = path.point(at: Double(progress))
        let tangent = path.tangent(at: Double(progress))
        drawSpear(at: NSPoint(x: CGFloat(point.x), y: CGFloat(point.y)), angle: atan2(CGFloat(tangent.y), CGFloat(tangent.x)))
    }

    private func drawSpear(at point: NSPoint, angle: CGFloat) {
        let length: CGFloat = 42
        let tail = NSPoint(x: CGFloat(point.x), y: CGFloat(point.y))
        let tip = NSPoint(x: tail.x + cos(angle) * length, y: tail.y + sin(angle) * length)
        ink.setStroke(); let spear = NSBezierPath(); spear.move(to: tail); spear.line(to: tip); spear.lineWidth = 3.5; spear.lineCapStyle = .round; spear.lineJoinStyle = .round; spear.stroke()
        let head = NSBezierPath(); head.move(to: tip); head.line(to: NSPoint(x: tip.x - 6, y: tip.y - 3)); head.move(to: tip); head.line(to: NSPoint(x: tip.x - 5, y: tip.y + 4)); head.lineWidth = 3; head.lineCapStyle = .round; head.lineJoinStyle = .round; head.stroke()
    }
}
