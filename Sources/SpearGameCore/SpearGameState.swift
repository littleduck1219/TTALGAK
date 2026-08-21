import Foundation

public struct PresentationPoint: Equatable {
    public let x: Double
    public let y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
    public static func + (lhs: Self, rhs: Self) -> Self { Self(x: lhs.x + rhs.x, y: lhs.y + rhs.y) }
    public static func - (lhs: Self, rhs: Self) -> Self { Self(x: lhs.x - rhs.x, y: lhs.y - rhs.y) }
    public static func * (lhs: Self, rhs: Double) -> Self { Self(x: lhs.x * rhs, y: lhs.y * rhs) }
    public var length: Double { hypot(x, y) }
    public var normalized: Self { length > 0 ? self * (1 / length) : Self(x: 1, y: 0) }
}

public enum GamePhase: Equatable { case ready, aiming, flying, hit, miss }

public struct FlightClock: Equatable {
    public let maximumDelta: Double
    private var lastTick: Double?
    public init(maximumDelta: Double = 0.25) { self.maximumDelta = maximumDelta }
    public mutating func advance(now: Double) -> Double {
        guard let lastTick else { self.lastTick = now; return 0 }
        guard now >= lastTick else { return 0 }
        self.lastTick = now
        return min(now - lastTick, maximumDelta)
    }
}

public struct FlightLayerContract: Equatable {
    public let ignoresMouseEvents: Bool
    public let canBecomeKey: Bool
    public let canBecomeMain: Bool
    public static let visibilityOnly = Self(ignoresMouseEvents: true, canBecomeKey: false, canBecomeMain: false)
}

public enum DragLaunch {
    // Asymmetric range around center 45: downward drag spans 35 degrees to the 10-degree floor,
    // upward drag spans 20 degrees to the 65-degree ceiling, both over the same 48pt travel.
    public static func angle(forVerticalDrag dy: Double) -> Double { min(max(45 + (dy < 0 ? 35 : 20) * dy / 48, 10), 65) }
    public static func tangent(angleDegrees: Double) -> PresentationPoint {
        let radians = angleDegrees * .pi / 180
        return PresentationPoint(x: cos(radians), y: sin(radians))
    }
    public static func power(reverse: Double) -> Double {
        if reverse <= 6 { return 0 }
        return min((reverse - 6) / 314, 1)
    }
    public static func power(displacement: PresentationPoint, angleDegrees: Double) -> Double {
        let tangent = tangent(angleDegrees: angleDegrees)
        return power(reverse: max(0, -(displacement.x * tangent.x + displacement.y * tangent.y)))
    }
    // Visible tension reads the raw frozen-axis pull, not normalized power: a full 320pt pull renders 160pt.
    public static func tensionLength(rawPull: Double) -> Double {
        rawPull <= 6 ? 0 : min(max(rawPull / 320 * 160, 0), 160)
    }
}

public struct GroundSpearRecord: Equatable {
    public let tail: PresentationPoint
    public let tip: PresentationPoint
    public init(tail: PresentationPoint, tip: PresentationPoint) { self.tail = tail; self.tip = tip }
}

/// In-memory-only FIFO of ground-miss spears; hits are never retained and nothing is persisted to disk or network.
public struct GroundSpearInventory: Equatable {
    public static let capacity = 50
    public private(set) var spears: [GroundSpearRecord] = []
    public init() {}
    public mutating func record(hit: Bool, tail: PresentationPoint, tip: PresentationPoint) {
        guard !hit else { return }
        spears.append(GroundSpearRecord(tail: tail, tip: tip))
        if spears.count > Self.capacity { spears.removeFirst(spears.count - Self.capacity) }
    }
}

/// Target spawns only at show/new-game and on an actual hit; misses, resets, and flight never move it,
/// and the stored position never feeds launch velocity or physics.
public struct TargetLifecycle {
    public static let minInset = 280.0
    public static let maxInset = 520.0
    public static let edgeMargin = 22.0
    public static let seedHeights = [64.0, 132.0, 200.0]
    public private(set) var target: PresentationPoint?
    private let unit: () -> Double
    private var spawnCount = 0
    public init(unit: @escaping () -> Double = { Double.random(in: 0...1) }) { self.unit = unit }
    @discardableResult
    public mutating func spawn(screenMinX: Double, screenMaxX: Double, groundY: Double) -> PresentationPoint {
        let clampedUnit = min(max(unit(), 0), 1)
        let inset = Self.minInset + (Self.maxInset - Self.minInset) * clampedUnit
        let x = min(max(screenMaxX - inset, screenMinX + Self.edgeMargin), screenMaxX - Self.edgeMargin)
        let value = PresentationPoint(x: x, y: groundY + Self.seedHeights[spawnCount % Self.seedHeights.count])
        spawnCount += 1
        target = value
        return value
    }
    public mutating func resolve(hit: Bool, screenMinX: Double, screenMaxX: Double, groundY: Double) {
        guard hit else { return }
        spawn(screenMinX: screenMinX, screenMaxX: screenMaxX, groundY: groundY)
    }
}

public struct FrozenLaunch: Equatable {
    public let angleDegrees: Double
    public let power: Double
    public let rawPull: Double
    public let start: PresentationPoint
    public init(angleDegrees: Double, power: Double, rawPull: Double = 0, start: PresentationPoint) {
        self.angleDegrees = min(max(angleDegrees, 10), 65)
        self.power = min(max(power, 0), 1)
        self.rawPull = max(rawPull, 0)
        self.start = start
    }
}

/// Local-only gesture state. After a valid local start-zone down, local drag/up containment is deliberately ignored until that NSView receives mouseUp; it never queries global pointer state.
public struct LocalGesture: Equatable {
    private var down: PresentationPoint?
    private var latchedTangent: PresentationPoint?
    public private(set) var launch: FrozenLaunch?
    public init() {}
    public mutating func begin(at point: PresentationPoint, inStartZone: Bool) -> Bool {
        down = inStartZone ? point : nil
        latchedTangent = nil
        launch = nil
        return inStartZone
    }
    public mutating func move(to point: PresentationPoint, isInsideInput _: Bool, start: PresentationPoint = PresentationPoint(x: 0, y: 0)) -> FrozenLaunch? {
        guard let down else { return nil }
        let displacement = point - down
        let angle = DragLaunch.angle(forVerticalDrag: displacement.y)
        if latchedTangent == nil, DragLaunch.power(displacement: displacement, angleDegrees: angle) > 0 {
            latchedTangent = DragLaunch.tangent(angleDegrees: angle)
        }
        // Displacement decomposes as a*latchedTangent + b*(0,1): pull power reads only a = dx/tangent.x,
        // so vertical (angle-only) moves can never shrink or grow a latched power or its raw pull distance.
        let rawPull = latchedTangent.map { max(0, -displacement.x / $0.x) } ?? 0
        let value = FrozenLaunch(angleDegrees: angle, power: DragLaunch.power(reverse: rawPull), rawPull: rawPull, start: start)
        launch = value
        return value
    }
    public mutating func release(isInsideInput _: Bool) -> FrozenLaunch? {
        defer { down = nil; launch = nil }
        return launch
    }
}

/// Pure y-up physics. Target/result never participate in this initializer.
public struct BallisticFlightPath: Equatable {
    public static let gravity = 2400.0
    public static let shaftLength = 42.0
    public let start: PresentationPoint
    public let angleDegrees: Double
    public let power: Double
    public let groundY: Double
    public let v0: Double
    public let vx: Double
    public let vy: Double
    public let groundCrossing: BallisticSample
    public var gravity: Double { Self.gravity }

    public init(start: PresentationPoint, angleDegrees: Double, power: Double, groundY: Double) {
        self.start = start
        self.angleDegrees = min(max(angleDegrees, 10), 65)
        self.power = min(max(power, 0), 1)
        self.groundY = groundY
        v0 = 900 + 1000 * self.power
        let radians = self.angleDegrees * .pi / 180
        vx = v0 * cos(radians)
        vy = v0 * sin(radians)
        groundCrossing = Self.firstGroundCrossing(start: start, vx: vx, vy: vy, groundY: groundY)
    }

    public func sample(elapsed: Double) -> BallisticSample {
        let t = max(elapsed, 0)
        let tail = PresentationPoint(x: start.x + vx * t, y: start.y + vy * t - 0.5 * Self.gravity * t * t)
        let velocity = PresentationPoint(x: vx, y: vy - Self.gravity * t)
        return BallisticSample(tail: tail, tip: tail + velocity.normalized * Self.shaftLength, velocity: velocity, elapsed: t)
    }
    public var apex: PresentationPoint { sample(elapsed: vy / Self.gravity).tail }

    private static func firstGroundCrossing(start: PresentationPoint, vx: Double, vy: Double, groundY: Double) -> BallisticSample {
        func sample(_ t: Double) -> BallisticSample {
            let tail = PresentationPoint(x: start.x + vx * t, y: start.y + vy * t - 0.5 * gravity * t * t)
            let velocity = PresentationPoint(x: vx, y: vy - gravity * t)
            return BallisticSample(tail: tail, tip: tail + velocity.normalized * shaftLength, velocity: velocity, elapsed: t)
        }
        let tailLanding = (vy + sqrt(vy * vy + 2 * gravity * max(start.y - groundY, 0))) / gravity
        var previous = sample(0)
        let step = 1.0 / 960.0
        var t = step
        while t <= tailLanding + 1 {
            let current = sample(t)
            let previousLow = min(previous.tail.y, previous.tip.y)
            let currentLow = min(current.tail.y, current.tip.y)
            if previousLow > groundY && currentLow <= groundY {
                let ratio = (previousLow - groundY) / (previousLow - currentLow)
                return sample(previous.elapsed + (current.elapsed - previous.elapsed) * ratio)
            }
            previous = current
            t += step
        }
        return sample(tailLanding)
    }
}

public struct BallisticSample: Equatable {
    public let tail: PresentationPoint
    public let tip: PresentationPoint
    public let velocity: PresentationPoint
    public let elapsed: Double
    fileprivate static let placeholder = BallisticSample(tail: PresentationPoint(x: 0, y: 0), tip: PresentationPoint(x: 0, y: 0), velocity: PresentationPoint(x: 1, y: 0), elapsed: 0)
}

public enum SpearCollision {
    public static let radius = 16.0
    public static func firstImpact(path: BallisticFlightPath, target: PresentationPoint, fromElapsed: Double, toElapsed: Double) -> Double? {
        let start = path.sample(elapsed: fromElapsed)
        let end = path.sample(elapsed: toElapsed)
        let steps = max(1, Int(ceil((end.tip - start.tip).length / 4)))
        for index in 0...steps {
            let q = Double(index) / Double(steps)
            let tail = start.tail + (end.tail - start.tail) * q
            let tip = start.tip + (end.tip - start.tip) * q
            if intersectsSegment(tail, tip, center: target) { return fromElapsed + (toElapsed - fromElapsed) * q }
        }
        return nil
    }
    public static func intersectsSegment(_ tail: PresentationPoint, _ tip: PresentationPoint, center: PresentationPoint, radius: Double = Self.radius) -> Bool {
        let segment = tip - tail
        let lengthSquared = segment.x * segment.x + segment.y * segment.y
        let q = lengthSquared == 0 ? 0 : min(max(((center.x - tail.x) * segment.x + (center.y - tail.y) * segment.y) / lengthSquared, 0), 1)
        let nearest = tail + segment * q
        let delta = center - nearest
        return delta.x * delta.x + delta.y * delta.y <= radius * radius
    }
}

public struct SpearGameState: Equatable {
    public private(set) var phase: GamePhase = .ready
    public private(set) var score = 0
    public init() {}
    public mutating func beginAim() { guard phase == .ready else { return }; phase = .aiming }
    public mutating func launch() { guard phase == .aiming else { return }; phase = .flying }
    public mutating func resolve(hit: Bool) { guard phase == .flying else { return }; if hit { score += 1; phase = .hit } else { phase = .miss } }
    public mutating func reset() { phase = .ready }
}
