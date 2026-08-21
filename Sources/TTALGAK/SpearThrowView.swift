import AppKit
import SpearGameCore

private let ink = NSColor.black

final class SpearThrowView: NSView {
    enum Event { case down(PresentationPoint), move(PresentationPoint, Bool), up(Bool) }
    private let onEvent: (Event) -> Void
    init(frame: NSRect, onEvent: @escaping (Event) -> Void) { self.onEvent = onEvent; super.init(frame: frame); wantsLayer = true }
    required init?(coder: NSCoder) { nil }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    private func point(_ event: NSEvent) -> PresentationPoint { let p = convert(event.locationInWindow, from: nil); return PresentationPoint(x: Double(p.x), y: Double(p.y)) }
    private var actorStartZone: NSRect { NSRect(x: 44, y: 36, width: 44, height: 44) }
    override func mouseDown(with event: NSEvent) { let p = point(event); guard actorStartZone.contains(NSPoint(x: CGFloat(p.x), y: CGFloat(p.y))) else { return }; onEvent(.down(p)) }
    override func mouseDragged(with event: NSEvent) { let p = point(event); onEvent(.move(p, bounds.contains(NSPoint(x: CGFloat(p.x), y: CGFloat(p.y))))) }
    override func mouseUp(with event: NSEvent) { let p = point(event); onEvent(.up(bounds.contains(NSPoint(x: CGFloat(p.x), y: CGFloat(p.y))))) }
}

final class SceneView: NSView {
    var inputFrame = NSRect.zero { didSet { needsDisplay = true } }
    var target = PresentationPoint(x: 0, y: 0) { didSet { needsDisplay = true } }

    var aiming: FrozenLaunch? { didSet { needsDisplay = true } }
    var result: (hit: Bool, point: PresentationPoint)? { didSet { needsDisplay = true } }
    var screenOrigin = PresentationPoint(x: 0, y: 0)
    private func local(_ p: PresentationPoint) -> NSPoint { NSPoint(x: CGFloat(p.x - screenOrigin.x), y: CGFloat(p.y - screenOrigin.y)) }
    override func draw(_ dirtyRect: NSRect) {
        ink.setStroke()
        let localGround = inputFrame.minY + 16 - CGFloat(screenOrigin.y)
        let feet = NSPoint(x: inputFrame.minX + 48 - CGFloat(screenOrigin.x), y: localGround)
        drawActor(feet: feet)
        let center = local(target); for radius: CGFloat in [22, 10] { let ring = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)); ring.lineWidth = 3.5; ring.stroke() }
        if let aiming { drawHeld(from: NSPoint(x: feet.x + 18, y: feet.y + 42), launch: aiming) }
        if let result { drawResult(result) }
    }
    private func drawActor(feet: NSPoint) {
        let head = NSBezierPath(ovalIn: NSRect(x: feet.x + 12, y: feet.y + 58, width: 12, height: 12)); head.lineWidth = 3; head.stroke()
        let body = NSBezierPath(); body.move(to: NSPoint(x: feet.x + 18, y: feet.y + 58)); body.line(to: NSPoint(x: feet.x + 18, y: feet.y + 22)); body.line(to: NSPoint(x: feet.x + 8, y: feet.y)); body.move(to: NSPoint(x: feet.x + 18, y: feet.y + 22)); body.line(to: NSPoint(x: feet.x + 28, y: feet.y)); body.lineWidth = 3; body.lineCapStyle = .round; body.stroke()
    }
    private func drawHeld(from hand: NSPoint, launch: FrozenLaunch) {
        let t = DragLaunch.tangent(angleDegrees: launch.angleDegrees)
        let end = NSPoint(x: hand.x + CGFloat(t.x * 42), y: hand.y + CGFloat(t.y * 42))
        let arm = NSBezierPath(); arm.move(to: NSPoint(x: hand.x - 8, y: hand.y + 2)); arm.line(to: hand); arm.lineWidth = 3; arm.stroke()
        let spear = NSBezierPath(); spear.move(to: hand); spear.line(to: end); spear.lineWidth = 3; spear.lineCapStyle = .round; spear.stroke()
        guard launch.power > 0 else { return }
        let length = 6 + 24 * launch.power; let tension = NSBezierPath(); tension.move(to: hand); tension.line(to: NSPoint(x: hand.x - CGFloat(t.x * length), y: hand.y - CGFloat(t.y * length))); tension.lineWidth = 2; tension.lineCapStyle = .round; tension.stroke()
    }
    private func drawResult(_ result: (hit: Bool, point: PresentationPoint)) {
        let p = local(result.point); let mark = NSBezierPath()
        if result.hit { mark.appendArc(withCenter: p, radius: 28, startAngle: 0, endAngle: 360, clockwise: false) } else { mark.move(to: NSPoint(x: p.x - 6, y: p.y - 6)); mark.line(to: NSPoint(x: p.x + 6, y: p.y + 6)); mark.move(to: NSPoint(x: p.x - 6, y: p.y + 6)); mark.line(to: NSPoint(x: p.x + 6, y: p.y - 6)) }
        mark.lineWidth = 2.5; mark.stroke()
    }
}

final class FlightView: NSView {
    var path: BallisticFlightPath? { didSet { needsDisplay = true } }
    var elapsed = 0.0 { didSet { needsDisplay = true } }
    var screenOrigin = PresentationPoint(x: 0, y: 0)
    override func draw(_ dirtyRect: NSRect) { guard let path else { return }; let sample = path.sample(elapsed: elapsed); drawSpear(tail: NSPoint(x: CGFloat(sample.tail.x - screenOrigin.x), y: CGFloat(sample.tail.y - screenOrigin.y)), tip: NSPoint(x: CGFloat(sample.tip.x - screenOrigin.x), y: CGFloat(sample.tip.y - screenOrigin.y))) }
    private func drawSpear(tail: NSPoint, tip: NSPoint) { ink.setStroke(); let spear = NSBezierPath(); spear.move(to: tail); spear.line(to: tip); spear.lineWidth = 3.5; spear.lineCapStyle = .round; spear.stroke() }
}
