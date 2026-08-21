import Foundation

public enum GamePhase: Equatable { case ready, aiming, flying, hit, miss }
public enum AimDirection: Equatable { case increasing, decreasing }

public struct MotionPolicy: Equatable {
    public let aimingUpdateInterval: Double
    public let showsFlightAnimation: Bool
    public static let standard = MotionPolicy(aimingUpdateInterval: 1.0 / 60.0, showsFlightAnimation: true)
    public static let reducedMotion = MotionPolicy(aimingUpdateInterval: 0.3, showsFlightAnimation: false)
}

public enum PresentationPhase: Equatable { case ready, aiming, release, flying, cue }
public enum StickmanPose: Equatable { case ready, aiming, release, flying, recovery }

public struct PresentationPoint: Equatable {
    public let x: Double
    public let y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
    public static func + (lhs: Self, rhs: Self) -> Self { Self(x: lhs.x + rhs.x, y: lhs.y + rhs.y) }
    public static func - (lhs: Self, rhs: Self) -> Self { Self(x: lhs.x - rhs.x, y: lhs.y - rhs.y) }
    public static func * (lhs: Self, rhs: Double) -> Self { Self(x: lhs.x * rhs, y: lhs.y * rhs) }
    public var length: Double { hypot(x, y) }
    public var normalized: Self { let length = length; return length > 0 ? self * (1 / length) : Self(x: 1, y: 0) }
}

/// Pure y-up ballistic trajectory. Its position and velocity read only the frozen release snapshot.
public struct BallisticFlightPath: Equatable {
    public static let gravity = 2400.0
    public static let visualDuration = 0.820
    public static let shaftLength = 42.0
    public let start: PresentationPoint
    public let targetX: Double
    public let aimDegrees: Double
    public let launchCoefficient: Double
    public let vx: Double
    public let vy: Double
    public let physicsDuration: Double

    public static let h25 = -0.022
    public static let h45 = 0.0
    public static let h65 = 0.022
    public static let k25 = 1 / sqrt(2 * (tan(25 * .pi / 180) - h25))
    public static let k45 = 1 / sqrt(2 * (tan(45 * .pi / 180) - h45))
    public static let k65 = 1 / sqrt(2 * (tan(65 * .pi / 180) - h65))

    public init(start: PresentationPoint, targetX: Double, aimDegrees: Double) {
        precondition(targetX > start.x)
        self.start = start
        self.targetX = targetX
        self.aimDegrees = min(max(aimDegrees, 25), 65)
        launchCoefficient = Self.coefficient(for: self.aimDegrees)
        let dx = targetX - start.x
        vx = launchCoefficient * sqrt(Self.gravity * dx)
        vy = vx * tan(self.aimDegrees * .pi / 180)
        physicsDuration = dx / vx
    }

    public static func coefficient(for degrees: Double) -> Double {
        let angle = min(max(degrees, 25), 65)
        if angle <= 45 { return k25 + (angle - 25) / 20 * (k45 - k25) }
        return k45 + (angle - 45) / 20 * (k65 - k45)
    }

    public var apexElapsed: Double { min(max((vy / Self.gravity) / physicsDuration * Self.visualDuration, 0), Self.visualDuration) }

    public func sample(elapsed: Double) -> BallisticSample {
        let q = min(max(elapsed / Self.visualDuration, 0), 1)
        let tau = q * physicsDuration
        let tail = PresentationPoint(x: start.x + vx * tau, y: start.y + vy * tau - 0.5 * Self.gravity * tau * tau)
        let velocity = PresentationPoint(x: vx, y: vy - Self.gravity * tau)
        return BallisticSample(tail: tail, tip: tail + velocity.normalized * Self.shaftLength, velocity: velocity, physicalElapsed: tau)
    }
}

public struct BallisticSample: Equatable {
    public let tail: PresentationPoint
    public let tip: PresentationPoint
    public let velocity: PresentationPoint
    public let physicalElapsed: Double
    public var shaftAngleDegrees: Double { atan2(velocity.y, velocity.x) * 180 / .pi }
}

public struct BallisticTarget {
    public static func center(start: PresentationPoint, targetX: Double, position: TargetPosition) -> PresentationPoint {
        PresentationPoint(x: targetX, y: start.y + position.canonicalHeight * (targetX - start.x))
    }
}

public enum SpearCollision {
    public static let radius = 16.0
    /// Samples a dropped frame at <=4pt tip movement; every interpolated shaft segment uses exact segment-circle intersection.
    public static func firstImpact(path: BallisticFlightPath, target: PresentationPoint, fromElapsed: Double, toElapsed: Double) -> Double? {
        let start = path.sample(elapsed: fromElapsed)
        let end = path.sample(elapsed: toElapsed)
        let steps = max(1, Int(ceil((end.tip - start.tip).length / 4)))
        for index in 0...steps {
            let t = Double(index) / Double(steps)
            let tail = start.tail + (end.tail - start.tail) * t
            let tip = start.tip + (end.tip - start.tip) * t
            if intersectsSegment(tail, tip, center: target, radius: radius) { return fromElapsed + (toElapsed - fromElapsed) * t }
        }
        return nil
    }

    public static func intersectsSegment(_ tail: PresentationPoint, _ tip: PresentationPoint, center: PresentationPoint, radius: Double = SpearCollision.radius) -> Bool {
        let segment = tip - tail
        let lengthSquared = segment.x * segment.x + segment.y * segment.y
        let projection = lengthSquared == 0 ? 0 : min(max(((center.x - tail.x) * segment.x + (center.y - tail.y) * segment.y) / lengthSquared, 0), 1)
        let nearest = tail + segment * projection
        let delta = center - nearest
        return delta.x * delta.x + delta.y * delta.y <= radius * radius
    }
}

/// One geometry source for held spear, 160ms release hand motion, and frozen flight P0.
public struct SpearPresentationGeometry: Equatable {
    public let pose: StickmanPose
    public let aimDegrees: Double
    public let shoulder: PresentationPoint
    public let releaseEntryHand: PresentationPoint
    public let finalReleaseHand: PresentationPoint

    public init(pose: StickmanPose, aimDegrees: Double) {
        self.pose = pose
        self.aimDegrees = min(max(aimDegrees, 25), 65)
        shoulder = PresentationPoint(x: 52, y: 56)
        let radians = self.aimDegrees * .pi / 180
        releaseEntryHand = PresentationPoint(x: shoulder.x - cos(radians) * 18, y: shoulder.y + sin(radians) * 18)
        // The final hand stays on the aiming side of the shoulder: no centerline crossing or sign-flip teleport.
        finalReleaseHand = PresentationPoint(x: shoulder.x - cos(radians) * 6, y: shoulder.y + sin(radians) * 18)
    }

    public var hand: PresentationPoint { pose == .release || pose == .flying || pose == .recovery ? finalReleaseHand : releaseEntryHand }
    public func hand(atReleaseProgress progress: Double) -> PresentationPoint {
        releaseEntryHand + (finalReleaseHand - releaseEntryHand) * min(max(progress, 0), 1)
    }
    public var heldSpearOrigin: PresentationPoint { hand }
    public var heldSpearEnd: PresentationPoint {
        let radians = aimDegrees * .pi / 180
        return PresentationPoint(x: hand.x + cos(radians) * 42, y: hand.y + sin(radians) * 42)
    }
    public var flightStart: PresentationPoint { finalReleaseHand }
}

public enum AnchorInteraction: Equatable { case input, displayOnly; public var ignoresMouseEvents: Bool { self == .displayOnly } }
public struct FlightLayerContract: Equatable {
    public let ignoresMouseEvents: Bool; public let canBecomeKey: Bool; public let canBecomeMain: Bool; public let isNonactivating: Bool; public let usesExplicitAppearance: Bool; public let removesAtImpact: Bool
    public static let visibilityOnly = FlightLayerContract(ignoresMouseEvents: true, canBecomeKey: false, canBecomeMain: false, isNonactivating: true, usesExplicitAppearance: true, removesAtImpact: true)
}

public struct PresentationPolicy: Equatable {
    public let aimingCycle: Double; public let launchDuration: Double; public let flightDuration: Double; public let impactDuration: Double; public let resultHoldDuration: Double; public let resetDuration: Double; public let staticResultDuration: Double; public let showsFlightTranslation: Bool
    public var releaseToImpact: Double { launchDuration + flightDuration }
    public var releaseToReady: Double { releaseToImpact + impactDuration + resultHoldDuration + resetDuration }
    public static let standard = PresentationPolicy(aimingCycle: 0.6, launchDuration: 0.16, flightDuration: 0.82, impactDuration: 0.14, resultHoldDuration: 0.36, resetDuration: 0.22, staticResultDuration: 0, showsFlightTranslation: true)
    public static let reducedMotion = PresentationPolicy(aimingCycle: 0.3, launchDuration: 0, flightDuration: 0, impactDuration: 0, resultHoldDuration: 0, resetDuration: 0, staticResultDuration: 0.5, showsFlightTranslation: false)
}

public struct PresentationLifecycle: Equatable {
    public private(set) var phase: PresentationPhase = .ready
    public let policy: PresentationPolicy
    private var elapsed = 0.0
    public init(policy: PresentationPolicy) { self.policy = policy }
    public var pose: StickmanPose { switch phase { case .ready: return .ready; case .aiming: return .aiming; case .release: return .release; case .flying: return .flying; case .cue: return .recovery } }
    public mutating func beginAim() { guard phase == .ready else { return }; phase = .aiming; elapsed = 0 }
    public mutating func release() { guard phase == .aiming else { return }; elapsed = 0; phase = policy.showsFlightTranslation ? .release : .cue }
    public mutating func advance(by seconds: Double) { guard seconds > 0 else { return }; elapsed += seconds; switch phase { case .release where elapsed >= policy.launchDuration: phase = .flying; elapsed = 0; case .flying where elapsed >= policy.flightDuration: phase = .cue; elapsed = 0; case .cue where elapsed >= cueDuration: phase = .ready; elapsed = 0; default: break } }
    private var cueDuration: Double { policy.showsFlightTranslation ? policy.impactDuration + policy.resultHoldDuration + policy.resetDuration : policy.staticResultDuration }
}

public enum TargetPosition: CaseIterable, Equatable {
    case bottom, middle, top
    public var canonicalAimDegrees: Double { switch self { case .bottom: return 25; case .middle: return 45; case .top: return 65 } }
    public var canonicalHeight: Double { switch self { case .bottom: return BallisticFlightPath.h25; case .middle: return BallisticFlightPath.h45; case .top: return BallisticFlightPath.h65 } }
    public var next: Self { switch self { case .bottom: return .middle; case .middle: return .top; case .top: return .bottom } }
}

public struct SpearGameState: Equatable {
    public static let lowAngle = 20.0; public static let highAngle = 70.0; public static let lowToHighDuration = 1.2
    public private(set) var phase: GamePhase = .ready
    public private(set) var angleDegrees = 45.0
    public private(set) var direction: AimDirection = .increasing
    public private(set) var score = 0
    public private(set) var target: TargetPosition
    public init(firstTarget: TargetPosition = .middle) { target = firstTarget }
    public mutating func beginAim() { guard phase == .ready else { return }; phase = .aiming; angleDegrees = Self.lowAngle; direction = .increasing }
    public mutating func advanceAim(by seconds: Double) { guard phase == .aiming, seconds > 0 else { return }; var remaining = seconds; let speed = (Self.highAngle - Self.lowAngle) / Self.lowToHighDuration; while remaining > 0 { let boundary = direction == .increasing ? Self.highAngle : Self.lowAngle; let duration = abs(boundary - angleDegrees) / speed; if remaining < duration { angleDegrees += (direction == .increasing ? 1 : -1) * speed * remaining; return }; angleDegrees = boundary; direction = direction == .increasing ? .decreasing : .increasing; remaining -= duration } }
    public mutating func setAim(angleDegrees: Double) { guard phase == .aiming, (Self.lowAngle...Self.highAngle).contains(angleDegrees) else { return }; self.angleDegrees = angleDegrees }
    public mutating func release() { guard phase == .aiming else { return }; phase = .flying }
    public mutating func resolveFlight(hit: Bool) { guard phase == .flying else { return }; if hit { score += 1; phase = .hit } else { phase = .miss } }
    public mutating func finishRound() { guard phase == .hit || phase == .miss else { return }; target = target.next; phase = .ready; angleDegrees = 45; direction = .increasing }
}
