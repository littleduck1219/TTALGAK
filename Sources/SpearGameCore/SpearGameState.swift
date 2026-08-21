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

/// Primary-screen frame in points, injected from AppKit so the pure core stays deterministic.
public struct ScreenBounds: Equatable {
    public let minX: Double
    public let maxX: Double
    public let minY: Double
    public let maxY: Double
    public init(minX: Double, maxX: Double, minY: Double, maxY: Double) {
        self.minX = minX; self.maxX = maxX; self.minY = minY; self.maxY = maxY
    }
}

public struct CorridorTile: Equatable {
    public let minX: Double
    public let minY: Double
    public let width: Double
    public let height: Double
    public var maxX: Double { minX + width }
    public var maxY: Double { minY + height }
    public func contains(_ point: PresentationPoint) -> Bool {
        point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY
    }
}

/// Ephemeral local input geometry. Overlapping 32pt tiles form a narrow stair-step corridor along
/// the frozen reverse ray; only those bounded windows exist, so the rest of the desktop has no input window.
public struct PullCorridor: Equatable {
    public static let tileSide = 32.0
    /// Conservative outer width of the stair-step union around any ray (32 * sqrt(2), rounded up).
    public static let documentedWidth = 46.0
    public static let step = tileSide / 2
    public let start: PresentationPoint
    public let end: PresentationPoint
    public let reverse: PresentationPoint
    public let maxPull: Double
    public let tiles: [CorridorTile]

    public init(start: PresentationPoint, reverse: PresentationPoint, maxPull: Double, bounds: ScreenBounds) {
        let direction = reverse.normalized
        self.start = start
        self.reverse = direction
        self.maxPull = max(maxPull, 0)
        end = start + direction * self.maxPull
        guard self.maxPull > DragLaunch.deadZone else { tiles = []; return }
        let count = max(1, Int(ceil(self.maxPull / Self.step)))
        tiles = (0...count).compactMap { index in
            let distance = min(Double(index) * Self.step, self.maxPull)
            let center = start + direction * distance
            let minX = max(center.x - Self.tileSide / 2, bounds.minX)
            let maxX = min(center.x + Self.tileSide / 2, bounds.maxX)
            let minY = max(center.y - Self.tileSide / 2, bounds.minY)
            let maxY = min(center.y + Self.tileSide / 2, bounds.maxY)
            guard maxX > minX, maxY > minY else { return nil }
            return CorridorTile(minX: minX, minY: minY, width: maxX - minX, height: maxY - minY)
        }
    }
}

public enum DragLaunch {
    public static let deadZone = 6.0
    // Asymmetric range around center 45: downward drag spans 35 degrees to the 10-degree floor,
    // upward drag spans 20 degrees to the 65-degree ceiling, both over the same 48pt travel.
    public static func angle(forVerticalDrag dy: Double) -> Double { min(max(45 + (dy < 0 ? 35 : 20) * dy / 48, 10), 65) }
    public static func tangent(angleDegrees: Double) -> PresentationPoint {
        let radians = angleDegrees * .pi / 180
        return PresentationPoint(x: cos(radians), y: sin(radians))
    }
    public static func reversePull(displacement: PresentationPoint, tangent: PresentationPoint) -> Double {
        max(0, -(displacement.x * tangent.x + displacement.y * tangent.y))
    }
    // Dynamic max pull: slab-exit ray distance from the screen-converted press point along the frozen
    // reverse direction to the FIRST primary-screen boundary; a start on/past an edge fails closed to 0.
    public static func maxPull(fromScreenStart start: PresentationPoint, reverse: PresentationPoint, bounds: ScreenBounds) -> Double {
        var exits: [Double] = []
        if reverse.x != 0 { exits.append(((reverse.x < 0 ? bounds.minX : bounds.maxX) - start.x) / reverse.x) }
        if reverse.y != 0 { exits.append(((reverse.y < 0 ? bounds.minY : bounds.maxY) - start.y) / reverse.y) }
        guard let first = exits.min(), first > 0 else { return 0 }
        return first
    }
    // Full power lands exactly when the pointer reaches the first screen boundary; a maxPull at or
    // inside the dead zone fails closed to 0 instead of remapping to any fixed pull constant.
    public static func power(rawPull: Double, maxPull: Double) -> Double {
        guard maxPull > deadZone, rawPull > deadZone else { return 0 }
        return min((rawPull - deadZone) / (maxPull - deadZone), 1)
    }
    // Visible tension reads the raw frozen-axis pull against the frozen screen-edge max:
    // the exact boundary pull renders the full 160pt line, hidden inside the 6pt dead zone.
    public static func tensionLength(rawPull: Double, maxPull: Double) -> Double {
        guard maxPull > deadZone, rawPull > deadZone else { return 0 }
        return min(rawPull / maxPull * 160, 160)
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
    public let maxPull: Double
    public let start: PresentationPoint
    public init(angleDegrees: Double, power: Double, rawPull: Double = 0, maxPull: Double = 0, start: PresentationPoint) {
        self.angleDegrees = min(max(angleDegrees, 10), 65)
        self.power = min(max(power, 0), 1)
        self.rawPull = max(rawPull, 0)
        self.maxPull = max(maxPull, 0)
        self.start = start
    }
}

/// Local-only gesture state. After a valid local start-zone down, local drag/up containment is deliberately ignored until that NSView receives mouseUp; it never queries global pointer state.
public struct LocalGesture: Equatable {
    private var down: PresentationPoint?
    private var screenStart: PresentationPoint?
    private var screenBounds: ScreenBounds?
    private var latchedTangent: PresentationPoint?
    private var frozenMaxPull = 0.0
    public private(set) var launch: FrozenLaunch?
    public private(set) var corridor: PullCorridor?
    public init() {}
    public mutating func begin(at point: PresentationPoint, inStartZone: Bool, screenStart: PresentationPoint, screenBounds: ScreenBounds) -> Bool {
        down = inStartZone ? point : nil
        self.screenStart = inStartZone ? screenStart : nil
        self.screenBounds = inStartZone ? screenBounds : nil
        latchedTangent = nil
        frozenMaxPull = 0
        launch = nil
        corridor = nil
        return inStartZone
    }
    public mutating func move(to point: PresentationPoint, isInsideInput _: Bool, start: PresentationPoint = PresentationPoint(x: 0, y: 0)) -> FrozenLaunch? {
        guard let down, let screenStart, let screenBounds else { return nil }
        let displacement = point - down
        let angle = DragLaunch.angle(forVerticalDrag: displacement.y)
        if latchedTangent == nil {
            let tangent = DragLaunch.tangent(angleDegrees: angle)
            if DragLaunch.reversePull(displacement: displacement, tangent: tangent) > DragLaunch.deadZone {
                latchedTangent = tangent
                frozenMaxPull = DragLaunch.maxPull(fromScreenStart: screenStart, reverse: tangent * -1, bounds: screenBounds)
                corridor = PullCorridor(start: screenStart, reverse: tangent * -1, maxPull: frozenMaxPull, bounds: screenBounds)
            }
        }
        // Displacement decomposes as a*latchedTangent + b*(0,1): pull power reads only a = dx/tangent.x,
        // so vertical (angle-only) moves can never shrink or grow a latched power, its raw pull, or maxPull.
        let rawPull = latchedTangent.map { max(0, -displacement.x / $0.x) } ?? 0
        let value = FrozenLaunch(angleDegrees: angle, power: DragLaunch.power(rawPull: rawPull, maxPull: frozenMaxPull), rawPull: rawPull, maxPull: frozenMaxPull, start: start)
        launch = value
        return value
    }
    public mutating func move(toScreenPoint point: PresentationPoint, start: PresentationPoint = PresentationPoint(x: 0, y: 0)) -> FrozenLaunch? {
        guard let down, let screenStart else { return nil }
        return move(to: down + (point - screenStart), isInsideInput: false, start: start)
    }
    public mutating func release(isInsideInput _: Bool) -> FrozenLaunch? {
        defer { down = nil; screenStart = nil; screenBounds = nil; latchedTangent = nil; frozenMaxPull = 0; launch = nil; corridor = nil }
        return launch
    }
    public mutating func cancel() {
        down = nil; screenStart = nil; screenBounds = nil; latchedTangent = nil; frozenMaxPull = 0; launch = nil; corridor = nil
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
