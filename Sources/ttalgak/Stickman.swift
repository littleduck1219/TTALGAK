import SpriteKit

extension SKNode {
    // 하위 SKShapeNode 전부 색 변경 (테마 전환용)
    func tintShapes(_ c: SKColor) {
        var stack: [SKNode] = [self]
        while let n = stack.popLast() {
            if let s = n as? SKShapeNode {
                s.strokeColor = c
                if s.fillColor.alphaComponent > 0 { s.fillColor = c }
            }
            stack.append(contentsOf: n.children)
        }
    }
}

// 관절 각도 세트. 단위: 라디안.
// 팔: 부모(몸통) 축 기준. 몸통이 위(+90°)를 향하므로 -π = 팔 늘어뜨림, -π/2 = 전방 수평, 0 = 머리 위.
// 다리: 골반 기준. -π/2 = 수직 아래.
struct Pose {
    var lean: CGFloat = 0.04
    var shF: CGFloat = -2.75, elF: CGFloat = 0.5    // 던지는 팔
    var shB: CGFloat = -3.35, elB: CGFloat = 0.45   // 반대 팔
    var hipF: CGFloat = -1.45, kneeF: CGFloat = -0.12
    var hipB: CGFloat = -1.75, kneeB: CGFloat = -0.28

    static let idle = Pose()
    // 와인드업: 상체 뒤로, 창 든 손은 머리 뒤, 스탠스 넓게
    static let windup = Pose(lean: 0.32, shF: 0.45, elF: 1.25, shB: -2.1, elB: 0.5,
                             hipF: -1.15, kneeF: -0.15, hipB: -2.05, kneeB: -0.45)
    // 릴리즈: 상체 앞으로 휘두르며 팔 완전 신전
    static let release = Pose(lean: -0.35, shF: -0.85, elF: 0.12, shB: -3.6, elB: 0.4,
                              hipF: -1.3, kneeF: -0.4, hipB: -2.15, kneeB: -0.1)
    // 팔로우스루: 팔이 몸을 가로질러 내려감
    static let follow = Pose(lean: -0.5, shF: -2.3, elF: 0.45, shB: -3.7, elB: 0.5,
                             hipF: -1.35, kneeF: -0.45, hipB: -2.2, kneeB: -0.08)

    private static let keys: [WritableKeyPath<Pose, CGFloat>] =
        [\.lean, \.shF, \.elF, \.shB, \.elB, \.hipF, \.kneeF, \.hipB, \.kneeB]

    static func lerp(_ a: Pose, _ b: Pose, _ t: CGFloat) -> Pose {
        var p = a
        for k in keys { p[keyPath: k] = a[keyPath: k] + (b[keyPath: k] - a[keyPath: k]) * t }
        return p
    }
}

// 뼈대 스틱 피규어. +x 방향을 바라봄. xScale = -1 로 반전.
// 뼈대(보이지 않는 SKNode 계층)는 키네마틱만 담당하고,
// 그리기는 매 프레임 관절 위치를 지나는 곡선 경로로 스키닝한다 — 팔다리가 부드러운 호를 그림.
final class StickFigure: SKNode {
    static let thigh: CGFloat = 16, shin: CGFloat = 16
    static let torsoLen: CGFloat = 21, upper: CGFloat = 13.5, fore: CGFloat = 12
    static let headR: CGFloat = 6

    let hand = SKNode()
    private let pelvis = SKNode()
    private let torso = SKNode()
    private let upperF = SKNode(), foreF = SKNode(), upperB = SKNode(), foreB = SKNode()
    private let thighF = SKNode(), shinF = SKNode(), thighB = SKNode(), shinB = SKNode()

    private let torsoShape = SKShapeNode()
    private let armFShape = SKShapeNode(), armBShape = SKShapeNode()
    private let legFShape = SKShapeNode(), legBShape = SKShapeNode()

    init(color: SKColor, lineWidth: CGFloat = 3.5) {
        super.init()

        // 키네마틱 뼈대
        pelvis.position = CGPoint(x: 0, y: Self.thigh + Self.shin - 4)
        addChild(pelvis)
        pelvis.addChild(torso)
        let shoulder = SKNode()
        shoulder.position = CGPoint(x: Self.torsoLen * 0.94, y: 0)
        torso.addChild(shoulder)
        shoulder.addChild(upperF)
        foreF.position = CGPoint(x: Self.upper, y: 0)
        upperF.addChild(foreF)
        shoulder.addChild(upperB)
        foreB.position = CGPoint(x: Self.upper, y: 0)
        upperB.addChild(foreB)
        hand.position = CGPoint(x: Self.fore, y: 0)
        foreF.addChild(hand)
        pelvis.addChild(thighF)
        shinF.position = CGPoint(x: Self.thigh, y: 0)
        thighF.addChild(shinF)
        pelvis.addChild(thighB)
        shinB.position = CGPoint(x: Self.thigh, y: 0)
        thighB.addChild(shinB)

        // 스킨 (실제로 그려지는 곡선들)
        for (s, z) in [(torsoShape, CGFloat(0)), (armFShape, 2), (armBShape, -2),
                       (legFShape, 1), (legBShape, -1)] {
            s.strokeColor = color
            s.lineWidth = lineWidth
            s.lineCap = .round
            s.lineJoin = .round
            s.zPosition = z
            addChild(s)
        }
        let head = SKShapeNode(circleOfRadius: Self.headR)
        head.fillColor = color
        head.strokeColor = color
        head.position = CGPoint(x: Self.torsoLen + Self.headR + 3, y: 0)
        head.zPosition = 0.5
        torso.addChild(head)
    }

    required init?(coder: NSCoder) { fatalError() }

    func apply(_ p: Pose) {
        torso.zRotation = .pi / 2 + p.lean
        upperF.zRotation = p.shF; foreF.zRotation = p.elF
        upperB.zRotation = p.shB; foreB.zRotation = p.elB
        thighF.zRotation = p.hipF; shinF.zRotation = p.kneeF
        thighB.zRotation = p.hipB; shinB.zRotation = p.kneeB
        redraw()
    }

    // 관절(팔꿈치/무릎)을 정확히 지나는 곡선: control = 2*관절 - (양끝 중점)
    private func redraw() {
        func through(_ a: CGPoint, _ joint: CGPoint, _ b: CGPoint) -> CGPath {
            let p = CGMutablePath()
            p.move(to: a)
            p.addQuadCurve(to: b, control: CGPoint(x: 2 * joint.x - (a.x + b.x) / 2,
                                                   y: 2 * joint.y - (a.y + b.y) / 2))
            return p
        }
        let hip = pelvis.position
        let neck = torso.convert(CGPoint(x: Self.torsoLen, y: 0), to: self)
        let shoulderPos = torso.convert(CGPoint(x: Self.torsoLen * 0.94, y: 0), to: self)

        // 척추: 등쪽으로 살짝 굽음
        let d = CGPoint(x: neck.x - hip.x, y: neck.y - hip.y)
        let len = max(1, hypot(d.x, d.y))
        let spineMid = CGPoint(x: (hip.x + neck.x) / 2 - d.y / len * 1.8,
                               y: (hip.y + neck.y) / 2 + d.x / len * 1.8)
        torsoShape.path = through(hip, spineMid, neck)

        armFShape.path = through(shoulderPos,
                                 foreF.convert(.zero, to: self),
                                 foreF.convert(CGPoint(x: Self.fore, y: 0), to: self))
        armBShape.path = through(shoulderPos,
                                 foreB.convert(.zero, to: self),
                                 foreB.convert(CGPoint(x: Self.fore, y: 0), to: self))
        legFShape.path = through(hip,
                                 shinF.convert(.zero, to: self),
                                 shinF.convert(CGPoint(x: Self.shin, y: 0), to: self))
        legBShape.path = through(hip,
                                 shinB.convert(.zero, to: self),
                                 shinB.convert(CGPoint(x: Self.shin, y: 0), to: self))
    }
}

// 플레이어: 키포즈 타임라인 기반 던지기 모션
final class Player: SKNode {
    let fig = StickFigure(color: .white)
    private let heldSpear = Spear(color: .white)
    private var idleTime: TimeInterval = 0

    private struct Seg {
        let to: Pose
        let dur: TimeInterval
        let ease: (CGFloat) -> CGFloat
    }
    private var segs: [Seg] = []
    private var segIndex = 0
    private var segT: TimeInterval = 0
    private var fromPose = Pose.idle
    private var released = false
    private var heldRotFrom: CGFloat = 0.9

    var isThrowing: Bool { !segs.isEmpty }
    var onRelease: (() -> Void)?   // 손의 월드 위치는 씬이 fig.hand로 읽음

    override init() {
        super.init()
        addChild(fig)
        heldSpear.zPosition = 3
        addChild(heldSpear)
        fig.apply(.idle)
        syncHeldSpear(rotation: 0.9)
    }
    required init?(coder: NSCoder) { fatalError() }

    func setColor(_ c: SKColor) {
        fig.tintShapes(c)
        heldSpear.tintShapes(c)
    }

    func startThrow() {
        guard segs.isEmpty else { return }
        let easeInOut: (CGFloat) -> CGFloat = { $0 * $0 * (3 - 2 * $0) }
        let easeIn: (CGFloat) -> CGFloat = { $0 * $0 }
        let easeOut: (CGFloat) -> CGFloat = { 1 - (1 - $0) * (1 - $0) }
        segs = [
            Seg(to: .windup, dur: Tuning.windupDur, ease: easeInOut),
            Seg(to: .release, dur: Tuning.throwDur, ease: easeIn),     // 이 구간 끝에서 릴리즈
            Seg(to: .follow, dur: Tuning.followDur, ease: easeOut),
            Seg(to: .idle, dur: Tuning.recoverDur, ease: easeInOut),
        ]
        segIndex = 0
        segT = 0
        released = false
        fromPose = currentIdlePose()
        heldRotFrom = heldSpear.zRotation
    }

    private var idleAccum: TimeInterval = 0

    func update(dt: TimeInterval) {
        idleTime += dt
        guard !segs.isEmpty else {
            idleAccum += dt   // 대기 호흡은 30fps 리샘플로 충분 (던질 때는 60fps 유지)
            if idleAccum >= 1.0 / 30 {
                idleAccum = 0
                fig.apply(currentIdlePose())
                syncHeldSpear(rotation: 0.9)
            }
            return
        }
        segT += dt
        while segIndex < segs.count, segT >= segs[segIndex].dur {
            segT -= segs[segIndex].dur
            fromPose = segs[segIndex].to
            segIndex += 1
            if segIndex == 2, !released {   // release/throw 구간 종료 = 창이 손을 떠남
                released = true
                fig.apply(fromPose)
                heldSpear.isHidden = true
                onRelease?()
            }
        }
        if segIndex >= segs.count {
            segs = []
            heldSpear.isHidden = false      // 새 창을 쥔다
            fig.apply(.idle)
            syncHeldSpear(rotation: 0.9)
            return
        }
        let seg = segs[segIndex]
        let t = seg.ease(CGFloat(segT / seg.dur))
        fig.apply(Pose.lerp(fromPose, seg.to, t))
        // 들고 있는 창의 기울기: 와인드업 동안 수평으로 눕힘
        if segIndex == 0 {
            syncHeldSpear(rotation: heldRotFrom + (0.12 - heldRotFrom) * t)
        } else if segIndex == 1 {
            syncHeldSpear(rotation: 0.12 * (1 - t))
        }
    }

    private func currentIdlePose() -> Pose {
        var p = Pose.idle
        p.lean += 0.03 * sin(CGFloat(idleTime) * 2.2)   // 호흡
        p.shB += 0.05 * sin(CGFloat(idleTime) * 2.2)
        return p
    }

    private func syncHeldSpear(rotation: CGFloat) {
        heldSpear.position = fig.hand.convert(.zero, to: self)
        heldSpear.zRotation = rotation
    }
}
