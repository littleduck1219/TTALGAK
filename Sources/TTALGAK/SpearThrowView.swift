import AppKit
import SpearGameCore

private let ink = NSColor.black

final class SpearThrowView: NSView {
    enum Event { case press, release }
    var state = SpearGameState() { didSet { needsDisplay = true } }
    var pose = StickmanPose.ready { didSet { updateAssetFrame(); needsDisplay = true } }
    var aimDegrees = 45.0 { didSet { updateAssetFrame(); needsDisplay = true } }
    var releaseProgress = 1.0 { didSet { updateAssetFrame(); needsDisplay = true } }
    private let onEvent: (Event) -> Void
    private let assets = StickmanMotionAssets()
    private let assetLayer = CALayer()
    private var usesAssetFrame = false

    init(frame: NSRect, onEvent: @escaping (Event) -> Void) {
        self.onEvent = onEvent
        super.init(frame: frame)
        wantsLayer = true
        assetLayer.contentsGravity = .resize
        layer?.addSublayer(assetLayer)
        updateAssetFrame()
    }
    required init?(coder: NSCoder) { nil }
    override func layout() { super.layout(); assetLayer.frame = bounds; assetLayer.contentsScale = window?.backingScaleFactor ?? 1 }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { onEvent(.press) }
    override func mouseUp(with event: NSEvent) { onEvent(.release) }
    override func draw(_ dirtyRect: NSRect) { if !usesAssetFrame { drawStickman(geometry: geometry) } }
    var geometry: SpearPresentationGeometry { SpearPresentationGeometry(pose: pose, aimDegrees: aimDegrees) }
    var selectedBand: MotionAssetBand { MotionAssetBand.forRawAim(aimDegrees) }
    func assetSnapshot() -> MotionAssetSnapshot { assetSnapshot(for: selectedBand) }
    func assetSnapshot(for band: MotionAssetBand) -> MotionAssetSnapshot {
        if let snapshot = assets?.snapshot(for: band, in: self) { return snapshot }
        let fallback = MotionAssetSnapshot.fallback(for: band)
        let local = NSPoint(x: fallback.finalP0.x, y: 110 - fallback.finalP0.y)
        let screen = convertToScreen(NSRect(origin: local, size: .zero)).origin
        return fallback.withFlightStart(PresentationPoint(x: screen.x, y: screen.y))
    }

    /// Core Animation switches only the selected discrete source frames: entry → 053 → 107 → 160 over 160ms.
    func playReleaseFrames() {
        guard let assets, let images = selectedBand.releaseFiles.compactMap({ assets.image(named: $0) as NSImage? }), images.count == 4 else { return }
        let cgImages = images.compactMap { $0.cgImage(forProposedRect: nil, context: nil, hints: nil) }
        guard cgImages.count == 4 else { return }
        assetLayer.contents = cgImages[3]
        let animation = CAKeyframeAnimation(keyPath: "contents")
        animation.values = cgImages
        animation.keyTimes = [0, 0.33125, 0.66875, 1]
        animation.duration = 0.160
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        assetLayer.add(animation, forKey: "ttalgak.release.frames")
        usesAssetFrame = true
    }

    private func updateAssetFrame() {
        guard let assets else { showFallback(); return }
        let name: String
        switch pose {
        case .ready: name = "ready.png"
        case .aiming: name = selectedBand.aimFile
        case .release:
            let milliseconds = Int((min(max(releaseProgress, 0), 1) * 160).rounded())
            name = selectedBand.releaseFiles[selectedBand.frameIndex(atReleaseElapsedMs: milliseconds)]
        case .flying, .recovery: name = "recovery.png" // held preview is hidden before the code-flight boundary.
        }
        guard let image = assets.image(named: name), let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { showFallback(); return }
        assetLayer.removeAnimation(forKey: "ttalgak.release.frames")
        assetLayer.contents = cgImage
        usesAssetFrame = true
        needsDisplay = true
    }

    private func showFallback() { assetLayer.removeAllAnimations(); assetLayer.contents = nil; usesAssetFrame = false; needsDisplay = true }

    private func drawStickman(geometry: SpearPresentationGeometry) {
        let origin = NSPoint(x: 48, y: 33); let pose = geometry.pose; ink.setStroke()
        let head = NSBezierPath(ovalIn: NSRect(x: origin.x - 6, y: origin.y + 30, width: 12, height: 12)); head.lineWidth = 3; head.lineCapStyle = .round; head.lineJoinStyle = .round; head.stroke()
        let lean: CGFloat = pose == .aiming ? -3 : pose == .release ? 4 : 0
        let body = NSBezierPath(); body.move(to: NSPoint(x: origin.x, y: origin.y + 30)); body.line(to: NSPoint(x: origin.x + lean, y: origin.y + 10)); body.move(to: NSPoint(x: origin.x + lean, y: origin.y + 10)); body.line(to: NSPoint(x: origin.x - 9, y: origin.y)); body.move(to: NSPoint(x: origin.x + lean, y: origin.y + 10)); body.line(to: NSPoint(x: origin.x + 9, y: origin.y))
        let handPoint = pose == .release ? geometry.hand(atReleaseProgress: releaseProgress) : geometry.hand
        let shoulder = NSPoint(x: CGFloat(geometry.shoulder.x), y: CGFloat(geometry.shoulder.y)); let hand = NSPoint(x: CGFloat(handPoint.x), y: CGFloat(handPoint.y))
        body.move(to: shoulder); body.line(to: hand); body.lineWidth = 3; body.lineCapStyle = .round; body.lineJoinStyle = .round; body.stroke()
        guard pose == .ready || pose == .aiming || pose == .release else { return }
        let radians = CGFloat(geometry.aimDegrees * .pi / 180)
        drawHeldSpear(from: hand, to: NSPoint(x: hand.x + cos(radians) * 42, y: hand.y + sin(radians) * 42))
    }
    private func drawHeldSpear(from start: NSPoint, to end: NSPoint) {
        ink.setStroke(); let spear = NSBezierPath(); spear.move(to: start); spear.line(to: end); spear.lineWidth = 3; spear.lineCapStyle = .round; spear.lineJoinStyle = .round; spear.stroke()
        let tip = NSBezierPath(); tip.move(to: end); tip.line(to: NSPoint(x: end.x - 5, y: end.y - 3)); tip.move(to: end); tip.line(to: NSPoint(x: end.x - 4, y: end.y + 4)); tip.lineWidth = 2.5; tip.lineCapStyle = .round; tip.lineJoinStyle = .round; tip.stroke()
    }
}

final class TargetView: NSView {
    var state = SpearGameState() { didSet { needsDisplay = true } }
    var targetPoint = NSPoint(x: 132, y: 55) { didSet { needsDisplay = true } }
    var finalTip = NSPoint.zero { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) { drawTarget(at: targetPoint); if state.phase == .hit { drawCheck(at: targetPoint) }; if state.phase == .miss { drawMiss(at: finalTip) } }
    private func drawTarget(at point: NSPoint) { ink.setStroke(); for radius: CGFloat in [16, 10] { let circle = NSBezierPath(ovalIn: NSRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)); circle.lineWidth = 3.5; circle.lineCapStyle = .round; circle.lineJoinStyle = .round; circle.stroke() }; ink.setFill(); NSBezierPath(ovalIn: NSRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)).fill() }
    private func drawCheck(at point: NSPoint) { ink.setStroke(); let mark = NSBezierPath(); mark.move(to: NSPoint(x: point.x + 16, y: point.y - 4)); mark.line(to: NSPoint(x: point.x + 21, y: point.y - 9)); mark.line(to: NSPoint(x: point.x + 30, y: point.y + 6)); mark.lineWidth = 3.5; mark.lineCapStyle = .round; mark.lineJoinStyle = .round; mark.stroke(); NSAttributedString(string: "+1", attributes: [.font: NSFont.systemFont(ofSize: 14, weight: .bold), .foregroundColor: ink]).draw(at: NSPoint(x: point.x - 7, y: point.y + 22)) }
    private func drawMiss(at point: NSPoint) { ink.setStroke(); let mark = NSBezierPath(); mark.move(to: NSPoint(x: point.x - 5, y: point.y - 5)); mark.line(to: NSPoint(x: point.x + 5, y: point.y + 5)); mark.move(to: NSPoint(x: point.x - 5, y: point.y + 5)); mark.line(to: NSPoint(x: point.x + 5, y: point.y - 5)); mark.lineWidth = 3.5; mark.lineCapStyle = .round; mark.lineJoinStyle = .round; mark.stroke() }
}

final class FlightView: NSView {
    var path: BallisticFlightPath? { didSet { needsDisplay = true } }
    var elapsed = 0.0 { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) { guard let path else { return }; let sample = path.sample(elapsed: elapsed); drawSpear(tail: NSPoint(x: CGFloat(sample.tail.x), y: CGFloat(sample.tail.y)), tip: NSPoint(x: CGFloat(sample.tip.x), y: CGFloat(sample.tip.y))) }
    private func drawSpear(tail: NSPoint, tip: NSPoint) { ink.setStroke(); let spear = NSBezierPath(); spear.move(to: tail); spear.line(to: tip); spear.lineWidth = 3.5; spear.lineCapStyle = .round; spear.lineJoinStyle = .round; spear.stroke(); let head = NSBezierPath(); head.move(to: tip); head.line(to: NSPoint(x: tip.x - 6, y: tip.y - 3)); head.move(to: tip); head.line(to: NSPoint(x: tip.x - 5, y: tip.y + 4)); head.lineWidth = 3; head.lineCapStyle = .round; head.lineJoinStyle = .round; head.stroke() }
}
