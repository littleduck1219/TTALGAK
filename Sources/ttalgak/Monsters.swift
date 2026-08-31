import SpriteKit

// 적 크리처 공통 인터페이스: 이동 사이클과 공격 스윙(0→1→0)
protocol CreatureFigure: SKNode {
    func animate(phase: CGFloat)
    func attack(_ s: CGFloat)
}

extension EnemyKind {
    func makeFigure(color: SKColor) -> any CreatureFigure {
        switch self {
        case .grunt: return GhoulFigure(color: color, lineWidth: lineWidth)
        case .runner: return HoundFigure(color: color, lineWidth: lineWidth)
        case .brute: return BruteFigure(color: color, lineWidth: lineWidth)
        case .wyvern: return WyvernFigure(color: color, lineWidth: lineWidth)
        case .reaper: return ReaperFigure(color: color, lineWidth: lineWidth)
        case .juggernaut: return JuggernautFigure(color: color, lineWidth: lineWidth)
        }
    }
}

// MARK: - 지오메트리 헬퍼

private func through(_ a: CGPoint, _ j: CGPoint, _ b: CGPoint) -> CGPath {
    let p = CGMutablePath()
    p.move(to: a)
    p.addQuadCurve(to: b, control: CGPoint(x: 2 * j.x - (a.x + b.x) / 2,
                                           y: 2 * j.y - (a.y + b.y) / 2))
    return p
}

// 2관절 사지: 시작점 + (각도, 굽힘)으로 경로 생성. 끝점도 돌려줌(발톱 부착용)
private func limb(from root: CGPoint, _ len1: CGFloat, _ len2: CGFloat,
                  angle: CGFloat, flex: CGFloat) -> (path: CGPath, end: CGPoint, dir: CGFloat) {
    let mid = CGPoint(x: root.x + cos(angle) * len1, y: root.y + sin(angle) * len1)
    let end = CGPoint(x: mid.x + cos(angle + flex) * len2, y: mid.y + sin(angle + flex) * len2)
    return (through(root, mid, end), end, angle + flex)
}

private func claws(at p: CGPoint, dir: CGFloat, len: CGFloat = 4.5) -> CGPath {
    let path = CGMutablePath()
    for k in -1 ... 1 {
        let a = dir + CGFloat(k) * 0.38
        path.move(to: p)
        path.addLine(to: CGPoint(x: p.x + cos(a) * len, y: p.y + sin(a) * len))
    }
    return path
}

private func makeShape(_ color: SKColor, _ width: CGFloat, z: CGFloat = 0, fill: Bool = false) -> SKShapeNode {
    let s = SKShapeNode()
    s.strokeColor = color
    s.lineWidth = width
    s.lineCap = .round
    s.lineJoin = .round
    if fill { s.fillColor = color }
    s.zPosition = z
    return s
}

// MARK: - 구울 (보병): 굽은 등, 땅에 끌리는 긴 팔과 발톱, 절뚝이는 걸음

final class GhoulFigure: SKNode, CreatureFigure {
    private let inner = SKNode()
    private let armF: SKShapeNode, armB: SKShapeNode
    private let clawF: SKShapeNode, clawB: SKShapeNode
    private let legF: SKShapeNode, legB: SKShapeNode

    init(color: SKColor, lineWidth: CGFloat) {
        armF = makeShape(color, lineWidth, z: 2)
        armB = makeShape(color, lineWidth, z: -2)
        clawF = makeShape(color, lineWidth * 0.55, z: 2)
        clawB = makeShape(color, lineWidth * 0.55, z: -2)
        legF = makeShape(color, lineWidth, z: 1)
        legB = makeShape(color, lineWidth, z: -1)
        super.init()
        addChild(inner)

        // 굽은 두꺼운 등
        let spine = makeShape(color, 9)
        spine.path = through(CGPoint(x: 2, y: 16), CGPoint(x: -3, y: 34), CGPoint(x: 12, y: 42))
        inner.addChild(spine)
        // 등 가시
        let spikes = makeShape(color, 1, fill: true)
        spikes.path = {
            let p = CGMutablePath()
            for (x, y) in [(-4.0, 36.0), (1.0, 40.0), (6.0, 43.0)] {
                p.move(to: CGPoint(x: x, y: y))
                p.addLine(to: CGPoint(x: x - 2.5, y: y + 6))
                p.addLine(to: CGPoint(x: x + 3, y: y + 1.5))
                p.closeSubpath()
            }
            return p
        }()
        inner.addChild(spikes)
        // 낮게 내민 머리
        let head = makeShape(color, 1, fill: true)
        head.path = {
            let p = CGMutablePath()
            p.addEllipse(in: CGRect(x: 10, y: 38, width: 11, height: 9))
            p.move(to: CGPoint(x: 19, y: 41))     // 주둥이
            p.addLine(to: CGPoint(x: 26, y: 39))
            p.addLine(to: CGPoint(x: 19, y: 38))
            p.closeSubpath()
            return p
        }()
        inner.addChild(head)
        for s in [armF, armB, clawF, clawB, legF, legB] { inner.addChild(s) }
    }
    required init?(coder: NSCoder) { fatalError() }

    private func pose(armAngle: CGFloat, sway: CGFloat, walk s: CGFloat) {
        let f = limb(from: CGPoint(x: 10, y: 38), 13, 12, angle: armAngle + sway, flex: 0.45)
        armF.path = f.path
        clawF.path = claws(at: f.end, dir: f.dir - 0.5)
        let b = limb(from: CGPoint(x: 9, y: 39), 13, 12, angle: armAngle - sway - 0.25, flex: 0.5)
        armB.path = b.path
        clawB.path = claws(at: b.end, dir: b.dir - 0.5)
        legF.path = limb(from: CGPoint(x: 0, y: 16), 9, 9,
                         angle: -1.57 + 0.5 * s, flex: -0.3 - 0.5 * max(0, -s)).path
        legB.path = limb(from: CGPoint(x: 0, y: 16), 9, 9,
                         angle: -1.57 - 0.5 * s, flex: -0.3 - 0.5 * max(0, s)).path
    }

    func animate(phase: CGFloat) {
        inner.position.y = 1.2 * abs(sin(phase)) - 0.6      // 절뚝이는 들썩임
        pose(armAngle: -1.15, sway: 0.2 * sin(phase), walk: sin(phase))
    }

    func attack(_ s: CGFloat) {
        inner.position.y = 0
        pose(armAngle: -1.15 + 0.95 * s, sway: 0, walk: 0)  // 발톱 후려치기
    }
}

// MARK: - 하운드 (러너): 네발 질주, 벌어진 턱

final class HoundFigure: SKNode, CreatureFigure {
    private let body = SKNode()
    private let jaw: SKShapeNode
    private let tail: SKShapeNode
    private var legShapes: [SKShapeNode] = []

    init(color: SKColor, lineWidth: CGFloat) {
        jaw = makeShape(color, lineWidth * 1.1)
        tail = makeShape(color, lineWidth * 0.8)
        super.init()
        addChild(body)

        let torso = makeShape(color, 10)
        torso.path = through(CGPoint(x: -15, y: 24), CGPoint(x: -2, y: 28), CGPoint(x: 12, y: 27))
        body.addChild(torso)
        // 머리: 주둥이 쐐기 + 귀
        let head = makeShape(color, 1, fill: true)
        head.path = {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 11, y: 33))
            p.addLine(to: CGPoint(x: 29, y: 27))
            p.addLine(to: CGPoint(x: 12, y: 22))
            p.closeSubpath()
            p.move(to: CGPoint(x: 12, y: 33))    // 귀
            p.addLine(to: CGPoint(x: 15, y: 40))
            p.addLine(to: CGPoint(x: 18, y: 32))
            p.closeSubpath()
            return p
        }()
        body.addChild(head)
        jaw.position = CGPoint(x: 13, y: 23)
        jaw.path = {
            let p = CGMutablePath()
            p.move(to: .zero)
            p.addLine(to: CGPoint(x: 12, y: -1))
            return p
        }()
        body.addChild(jaw)
        body.addChild(tail)
        for z in [CGFloat(1), -1, 1, -1] {
            let s = makeShape(color, lineWidth, z: z)
            legShapes.append(s)
            body.addChild(s)
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    func animate(phase: CGFloat) {
        body.position = CGPoint(x: 0, y: 1.6 * sin(phase * 2))
        body.zRotation = 0.045 * sin(phase * 2 + 1)
        let hips: [(CGPoint, CGFloat)] = [
            (CGPoint(x: 10, y: 22), phase),
            (CGPoint(x: 10, y: 22), phase + 0.5),
            (CGPoint(x: -13, y: 22), phase + .pi),
            (CGPoint(x: -13, y: 22), phase + .pi + 0.5),
        ]
        for (i, (hip, ph)) in hips.enumerated() {
            let s = sin(ph)
            legShapes[i].path = limb(from: hip, 11, 11,
                                     angle: -1.57 + 0.62 * s,
                                     flex: -0.4 - 0.5 * max(0, -s)).path
        }
        tail.path = through(CGPoint(x: -15, y: 26),
                            CGPoint(x: -22, y: 30 + 1.5 * sin(phase)),
                            CGPoint(x: -27, y: 34 + 2.5 * sin(phase)))
        jaw.zRotation = -0.18 - 0.08 * sin(phase * 2)
    }

    func attack(_ s: CGFloat) {
        body.position = CGPoint(x: 6 * s, y: 0)     // 달려들며
        body.zRotation = -0.14 * s
        jaw.zRotation = -0.18 - 0.85 * s            // 턱 크게 벌림
    }
}

// MARK: - 브루트: 거대한 몸통, 너클 워크, 내려찍기

final class BruteFigure: SKNode, CreatureFigure {
    private let body = SKNode()
    private let armF: SKShapeNode, armB: SKShapeNode
    private let legF: SKShapeNode, legB: SKShapeNode

    init(color: SKColor, lineWidth: CGFloat) {
        armF = makeShape(color, lineWidth * 1.15, z: 3)
        armB = makeShape(color, lineWidth * 1.0, z: 2)
        legF = makeShape(color, lineWidth, z: 1)
        legB = makeShape(color, lineWidth, z: -1)
        super.init()
        addChild(body)

        let torso = makeShape(color, lineWidth * 0.6, fill: true)
        torso.path = CGPath(ellipseIn: CGRect(x: -17, y: 24, width: 34, height: 40), transform: nil)
        body.addChild(torso)
        let head = makeShape(color, 1, fill: true)
        head.path = CGPath(ellipseIn: CGRect(x: 3, y: 60, width: 11, height: 10), transform: nil)
        body.addChild(head)
        body.addChild(armF)
        body.addChild(armB)
        addChild(legF)
        addChild(legB)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func arms(angle: CGFloat, flex: CGFloat, sway: CGFloat) {
        // 어깨를 몸통 타원 바깥쪽 앞에 두어 팔이 실루엣 밖으로 드러나게
        armF.path = limb(from: CGPoint(x: 16, y: 50), 19, 17, angle: angle + sway, flex: flex).path
        armB.path = limb(from: CGPoint(x: 13, y: 53), 18, 16, angle: angle - sway - 0.2, flex: flex).path
    }

    func animate(phase: CGFloat) {
        body.zRotation = 0.05 * sin(phase)
        body.position.y = 1.2 * abs(sin(phase))
        arms(angle: -1.2, flex: 0.3, sway: 0.14 * sin(phase))
        let s = sin(phase)
        legF.path = limb(from: CGPoint(x: 4, y: 27), 14, 13,
                         angle: -1.57 + 0.34 * s, flex: -0.2 - 0.35 * max(0, -s)).path
        legB.path = limb(from: CGPoint(x: -4, y: 27), 14, 13,
                         angle: -1.57 - 0.34 * s, flex: -0.2 - 0.35 * max(0, s)).path
    }

    func attack(_ s: CGFloat) {
        body.zRotation = -0.06 * s
        arms(angle: -1.2 + 2.2 * s, flex: 0.3 - 0.45 * s, sway: 0)   // 들어올려 내려찍기
    }
}

// MARK: - 와이번 (정예): 공중 비행, 날개 펄럭임, 급강하 공격

final class WyvernFigure: SKNode, CreatureFigure {
    private let inner = SKNode()          // 부양 바디 (지면 기준 ~65 높이)
    private let wingF: SKShapeNode
    private let wingB: SKShapeNode

    init(color: SKColor, lineWidth: CGFloat) {
        func wing(_ scale: CGFloat) -> SKShapeNode {
            let w = makeShape(color, 1, fill: true)
            let p = CGMutablePath()
            p.move(to: .zero)
            p.addQuadCurve(to: CGPoint(x: -16 * scale, y: 20 * scale),
                           control: CGPoint(x: -4 * scale, y: 16 * scale))
            // 박쥐 날개 스캘럽 가장자리
            p.addLine(to: CGPoint(x: -26 * scale, y: 12 * scale))
            p.addQuadCurve(to: CGPoint(x: -20 * scale, y: 4 * scale),
                           control: CGPoint(x: -21 * scale, y: 9 * scale))
            p.addQuadCurve(to: CGPoint(x: -10 * scale, y: -1 * scale),
                           control: CGPoint(x: -14 * scale, y: 2 * scale))
            p.closeSubpath()
            return w.with(path: p)
        }
        wingF = wing(1.0)
        wingF.zPosition = 2
        wingB = wing(0.85)
        wingB.zPosition = -2
        super.init()
        addChild(inner)
        inner.position = CGPoint(x: 0, y: 65)

        let body = makeShape(color, 9)
        body.path = through(CGPoint(x: -9, y: 0), CGPoint(x: 0, y: 2), CGPoint(x: 8, y: 1))
        inner.addChild(body)
        // 머리: 뿔 달린 쐐기
        let head = makeShape(color, 1, fill: true)
        head.path = {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 8, y: 6))
            p.addLine(to: CGPoint(x: 22, y: 1))
            p.addLine(to: CGPoint(x: 9, y: -3))
            p.closeSubpath()
            p.move(to: CGPoint(x: 9, y: 6))     // 뿔
            p.addLine(to: CGPoint(x: 7, y: 13))
            p.addLine(to: CGPoint(x: 13, y: 5))
            p.closeSubpath()
            return p
        }()
        inner.addChild(head)
        // 꼬리
        let tail = makeShape(color, lineWidth * 0.8)
        tail.path = through(CGPoint(x: -9, y: 0), CGPoint(x: -18, y: -4), CGPoint(x: -26, y: 2))
        inner.addChild(tail)
        // 늘어진 다리
        let legs = makeShape(color, lineWidth * 0.7)
        legs.path = {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 2, y: -3)); p.addLine(to: CGPoint(x: 4, y: -11))
            p.move(to: CGPoint(x: -3, y: -3)); p.addLine(to: CGPoint(x: -2, y: -11))
            return p
        }()
        inner.addChild(legs)
        wingF.position = CGPoint(x: -2, y: 3)
        wingB.position = CGPoint(x: -4, y: 3)
        inner.addChild(wingF)
        inner.addChild(wingB)
    }
    required init?(coder: NSCoder) { fatalError() }

    func animate(phase: CGFloat) {
        inner.position.y = 65 + 4 * sin(phase * 0.6)
        inner.zRotation = 0.04 * sin(phase * 0.6 + 1)
        wingF.zRotation = 0.55 * sin(phase) + 0.15
        wingB.zRotation = -0.45 * sin(phase) - 0.1
    }

    func attack(_ s: CGFloat) {
        inner.position.y = 65 - 44 * s          // 급강하
        inner.zRotation = -0.35 * s
        wingF.zRotation = 0.8 * s
        wingB.zRotation = -0.7 * s
    }
}

// MARK: - 리퍼 (정예): 낫 든 그림자, 순간이동은 Enemy 로직이 담당

final class ReaperFigure: SKNode, CreatureFigure {
    private let inner = SKNode()
    private let scythe = SKNode()

    init(color: SKColor, lineWidth: CGFloat) {
        super.init()
        addChild(inner)

        // 망토: 후드부터 너덜한 밑단까지 한 덩어리 실루엣
        let cloak = makeShape(color, 1, fill: true)
        cloak.path = {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -9, y: 0))
            p.addQuadCurve(to: CGPoint(x: -6, y: 40), control: CGPoint(x: -12, y: 22))
            p.addQuadCurve(to: CGPoint(x: 2, y: 56), control: CGPoint(x: -6, y: 52))   // 후드 뒤
            p.addQuadCurve(to: CGPoint(x: 10, y: 46), control: CGPoint(x: 9, y: 55))   // 후드 앞
            p.addQuadCurve(to: CGPoint(x: 7, y: 24), control: CGPoint(x: 10, y: 36))
            p.addQuadCurve(to: CGPoint(x: 9, y: 0), control: CGPoint(x: 9, y: 10))
            // 너덜한 밑단
            p.addLine(to: CGPoint(x: 5, y: 6)); p.addLine(to: CGPoint(x: 1, y: 0))
            p.addLine(to: CGPoint(x: -3, y: 6)); p.addLine(to: CGPoint(x: -6, y: 0))
            p.closeSubpath()
            return p
        }()
        inner.addChild(cloak)

        // 낫: 자루 + 초승달 날
        scythe.position = CGPoint(x: 4, y: 26)
        let staff = makeShape(color, lineWidth * 0.8)
        staff.path = {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -5, y: -16))
            p.addLine(to: CGPoint(x: 7, y: 32))
            return p
        }()
        scythe.addChild(staff)
        let blade = makeShape(color, 1, fill: true)
        blade.path = {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 7, y: 32))
            p.addQuadCurve(to: CGPoint(x: 28, y: 22), control: CGPoint(x: 24, y: 34))
            p.addQuadCurve(to: CGPoint(x: 8, y: 28), control: CGPoint(x: 21, y: 25))
            p.closeSubpath()
            return p
        }()
        scythe.addChild(blade)
        inner.addChild(scythe)
    }
    required init?(coder: NSCoder) { fatalError() }

    func animate(phase: CGFloat) {
        inner.position.y = 1.5 * sin(phase * 0.8)      // 유령처럼 부유
        inner.zRotation = 0.035 * sin(phase * 0.8 + 1)
        scythe.zRotation = 0.08 * sin(phase * 0.8)
    }

    func attack(_ s: CGFloat) {
        inner.zRotation = -0.18 * s
        scythe.zRotation = -1.5 * s                     // 큰 낫 휘두르기
    }
}

// MARK: - 저거너트 (정예): 각진 장갑 덩치, 넉백 면역급

final class JuggernautFigure: SKNode, CreatureFigure {
    private let body = SKNode()
    private let armF: SKShapeNode, armB: SKShapeNode
    private let legF: SKShapeNode, legB: SKShapeNode

    init(color: SKColor, lineWidth: CGFloat) {
        armF = makeShape(color, lineWidth * 1.4, z: 3)
        armB = makeShape(color, lineWidth * 1.2, z: 2)
        legF = makeShape(color, lineWidth * 1.2, z: 1)
        legB = makeShape(color, lineWidth * 1.2, z: -1)
        super.init()
        addChild(body)

        // 각진 장갑 몸통: 넓은 어깨 사다리꼴 + 어깨 갑주 + 투구
        let torso = makeShape(color, lineWidth * 0.5, fill: true)
        torso.path = {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -14, y: 24))
            p.addLine(to: CGPoint(x: -20, y: 58))
            p.addLine(to: CGPoint(x: 20, y: 58))
            p.addLine(to: CGPoint(x: 14, y: 24))
            p.closeSubpath()
            // 어깨 갑주
            p.addEllipse(in: CGRect(x: -25, y: 50, width: 12, height: 11))
            p.addEllipse(in: CGRect(x: 13, y: 50, width: 12, height: 11))
            // 투구 (사다리꼴)
            p.move(to: CGPoint(x: -6, y: 58))
            p.addLine(to: CGPoint(x: -4, y: 70))
            p.addLine(to: CGPoint(x: 6, y: 70))
            p.addLine(to: CGPoint(x: 8, y: 58))
            p.closeSubpath()
            return p
        }()
        body.addChild(torso)
        body.addChild(armF)
        body.addChild(armB)
        addChild(legF)
        addChild(legB)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func arms(angle: CGFloat, flex: CGFloat, sway: CGFloat) {
        armF.path = limb(from: CGPoint(x: 20, y: 52), 17, 15, angle: angle + sway, flex: flex).path
        armB.path = limb(from: CGPoint(x: -18, y: 52), 16, 14, angle: angle - sway - 0.3, flex: flex).path
    }

    func animate(phase: CGFloat) {
        body.zRotation = 0.035 * sin(phase)
        body.position.y = 1.0 * abs(sin(phase))
        arms(angle: -1.35, flex: 0.15, sway: 0.1 * sin(phase))
        let s = sin(phase)
        legF.path = limb(from: CGPoint(x: 6, y: 25), 13, 12,
                         angle: -1.57 + 0.3 * s, flex: -0.15 - 0.3 * max(0, -s)).path
        legB.path = limb(from: CGPoint(x: -6, y: 25), 13, 12,
                         angle: -1.57 - 0.3 * s, flex: -0.15 - 0.3 * max(0, s)).path
    }

    func attack(_ s: CGFloat) {
        body.zRotation = -0.05 * s
        arms(angle: -1.25 + 2.1 * s, flex: 0.25 - 0.4 * s, sway: 0)
    }
}

private extension SKShapeNode {
    func with(path p: CGPath) -> SKShapeNode { self.path = p; return self }
}
