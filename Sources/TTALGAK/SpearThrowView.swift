import AppKit
import SpearGameCore

private let textColor = NSColor(calibratedRed: 25/255, green: 31/255, blue: 40/255, alpha: 1)
private let borderColor = NSColor(calibratedRed: 229/255, green: 232/255, blue: 235/255, alpha: 1)
private let blue = NSColor(calibratedRed: 45/255, green: 100/255, blue: 241/255, alpha: 1)
private let yellow = NSColor(calibratedRed: 243/255, green: 182/255, blue: 31/255, alpha: 1)
private let green = NSColor(calibratedRed: 17/255, green: 122/255, blue: 70/255, alpha: 1)
private let red = NSColor(calibratedRed: 217/255, green: 45/255, blue: 32/255, alpha: 1)

private func font(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    NSFont(name: "SUIT", size: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
}

private func drawText(_ text: String, at point: NSPoint, size: CGFloat = 12, weight: NSFont.Weight = .medium, color: NSColor = textColor) {
    NSAttributedString(string: text, attributes: [.font: font(size, weight), .foregroundColor: color]).draw(at: point)
}

class PanelView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.withAlphaComponent(0.94).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 14, yRadius: 14).fill()
        borderColor.setStroke()
        let border = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 14, yRadius: 14)
        border.lineWidth = 1
        border.stroke()
    }
}

final class SpearThrowView: PanelView {
    enum Event { case press, release }
    var state = SpearGameState() { didSet { needsDisplay = true } }
    var reducesMotion = false { didSet { needsDisplay = true } }
    private let onEvent: (Event) -> Void

    init(frame: NSRect, onEvent: @escaping (Event) -> Void) {
        self.onEvent = onEvent
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { nil }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let status: String
        switch state.phase {
        case .ready: status = "준비"
        case .aiming: status = "각도 선택"
        case .flying: status = "발사"
        case .hit: status = "명중"
        case .miss: status = "결과"
        }
        let angle = presentationAngle
        drawText(status, at: NSPoint(x: 12, y: 84), size: 16, weight: .bold)
        drawText("\(Int(angle.rounded()))°", at: NSPoint(x: 140, y: 82), size: 16, weight: .bold, color: blue)
        drawStickman(at: NSPoint(x: 36, y: 45), angle: state.phase == .flying ? nil : angle)
        drawTrack()
        if state.phase == .ready { drawText("누르고 각도를 고르세요", at: NSPoint(x: 12, y: 66), size: 12, weight: .medium) }
    }

    override func mouseDown(with event: NSEvent) { onEvent(.press) }
    override func mouseUp(with event: NSEvent) { onEvent(.release) }

    private func drawStickman(at origin: NSPoint, angle: Double?) {
        textColor.setStroke()
        let head = NSBezierPath(ovalIn: NSRect(x: origin.x - 5, y: origin.y + 20, width: 10, height: 10)); head.lineWidth = 2; head.stroke()
        let body = NSBezierPath(); body.move(to: NSPoint(x: origin.x, y: origin.y + 20)); body.line(to: NSPoint(x: origin.x, y: origin.y + 5)); body.move(to: NSPoint(x: origin.x, y: origin.y + 14)); body.line(to: NSPoint(x: origin.x + 12, y: origin.y + 13)); body.move(to: NSPoint(x: origin.x, y: origin.y + 5)); body.line(to: NSPoint(x: origin.x - 8, y: origin.y)); body.move(to: NSPoint(x: origin.x, y: origin.y + 5)); body.line(to: NSPoint(x: origin.x + 8, y: origin.y)); body.lineWidth = 2; body.lineCapStyle = .round; body.stroke()
        guard let angle else { return }
        let radians = angle * .pi / 180
        let start = NSPoint(x: origin.x + 12, y: origin.y + 13)
        let end = NSPoint(x: start.x + cos(radians) * 36, y: start.y + sin(radians) * 36)
        blue.setStroke(); let spear = NSBezierPath(); spear.move(to: start); spear.line(to: end); spear.lineWidth = 2; spear.lineCapStyle = .round; spear.stroke()
        let tip = NSBezierPath(); tip.move(to: end); tip.line(to: NSPoint(x: end.x - 5, y: end.y - 3)); tip.move(to: end); tip.line(to: NSPoint(x: end.x - 4, y: end.y + 4)); tip.stroke()
    }

    private func drawTrack() {
        let start = NSPoint(x: 12, y: 15), end = NSPoint(x: 168, y: 15)
        borderColor.setStroke(); let line = NSBezierPath(); line.move(to: start); line.line(to: end); line.lineWidth = 2; line.stroke()
        let fraction = (presentationAngle - SpearGameState.lowAngle) / (SpearGameState.highAngle - SpearGameState.lowAngle)
        let x = start.x + (end.x - start.x) * fraction
        blue.setFill(); NSBezierPath(ovalIn: NSRect(x: x - 4, y: 11, width: 8, height: 8)).fill()
        blue.setStroke(); let tick = NSBezierPath(); tick.move(to: NSPoint(x: x, y: 9)); tick.line(to: NSPoint(x: x, y: 21)); tick.lineWidth = 2; tick.stroke()
        drawText("20°", at: NSPoint(x: 12, y: 2), size: 12)
        drawText("70°", at: NSPoint(x: 144, y: 2), size: 12)
    }

    private var presentationAngle: Double {
        guard state.phase == .aiming, !reducesMotion else { return state.angleDegrees }
        let fraction = (state.angleDegrees - SpearGameState.lowAngle) / (SpearGameState.highAngle - SpearGameState.lowAngle)
        let eased = fraction * fraction * (3 - 2 * fraction)
        return SpearGameState.lowAngle + eased * (SpearGameState.highAngle - SpearGameState.lowAngle)
    }
}

final class TargetView: PanelView {
    var state = SpearGameState() { didSet { needsDisplay = true } }
    var reducesMotion = false { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawText("과녁", at: NSPoint(x: 12, y: 84), weight: .semibold)
        drawText("\(state.score)점", at: NSPoint(x: 146, y: 84), size: 16, weight: .bold)
        let ys: [CGFloat] = [30, 51, 72]
        for (index, y) in ys.enumerated() { drawTarget(at: NSPoint(x: 136, y: y), active: index == targetIndex) }
        drawFlight(at: NSPoint(x: 92, y: ys[targetIndex]))
        let result: (String, NSColor)
        switch state.phase {
        case .flying: result = ("날아가는 중", blue)
        case .hit: result = ("✓ 딸깍!", green)
        case .miss: result = ("× 아쉽다", red)
        default: result = ("연습 중", textColor)
        }
        drawText(result.0, at: NSPoint(x: 12, y: 10), weight: .semibold, color: result.1)
    }

    private var targetIndex: Int {
        switch state.target {
        case .bottom: return 0
        case .middle: return 1
        case .top: return 2
        }
    }

    private func drawTarget(at point: NSPoint, active: Bool) {
        let alpha: CGFloat = active ? 1 : 0.4
        let color = (active ? textColor : borderColor).withAlphaComponent(alpha)
        color.setStroke()
        for radius in [11.0, 7.0] { let p = NSBezierPath(ovalIn: NSRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)); p.lineWidth = active ? 2 : 1; p.stroke() }
        (active ? yellow : borderColor).withAlphaComponent(alpha).setFill(); NSBezierPath(ovalIn: NSRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)).fill()
    }

    private func drawFlight(at point: NSPoint) {
        guard state.phase == .flying || state.phase == .hit || state.phase == .miss else { return }
        let landing = state.landingHeight ?? state.target.normalizedHeight
        let y = 25 + CGFloat(landing * 55)
        let end = NSPoint(x: !reducesMotion && state.phase == .flying ? 112 : 126, y: y)
        blue.setStroke(); let spear = NSBezierPath(); spear.move(to: NSPoint(x: 78, y: point.y)); spear.line(to: end); spear.lineWidth = 2; spear.lineCapStyle = .round; spear.stroke()
        blue.setFill(); NSBezierPath(ovalIn: NSRect(x: end.x - 2, y: end.y - 2, width: 4, height: 4)).fill()
    }
}
