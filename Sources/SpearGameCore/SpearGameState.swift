import Foundation

public enum GamePhase: Equatable {
    case ready
    case aiming
    case flying
    case hit
    case miss
}

public enum AimDirection: Equatable {
    case increasing
    case decreasing
}

/// Renderer timing policy; game-state timing and judgement remain independent.
public struct MotionPolicy: Equatable {
    public let aimingUpdateInterval: Double
    public let showsFlightAnimation: Bool

    public static let standard = MotionPolicy(aimingUpdateInterval: 1.0 / 60.0, showsFlightAnimation: true)
    public static let reducedMotion = MotionPolicy(aimingUpdateInterval: 0.3, showsFlightAnimation: false)
}

public enum PresentationPhase: Equatable {
    case ready
    case aiming
    case release
    case flying
    case cue
}

public enum StickmanPose: Equatable {
    case ready
    case aiming
    case release
    case flying
    case recovery
}

public struct PresentationPoint: Equatable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Pure y-up cubic Bézier flight path; visual-only and independent of game judgement.
public struct PresentationFlightPath: Equatable {
    public let start: PresentationPoint
    public let startControl: PresentationPoint
    public let endControl: PresentationPoint
    public let end: PresentationPoint
    public let startControlDistance: Double
    public let endControlDistance: Double

    public init(start: PresentationPoint, end: PresentationPoint, aimDegrees: Double) {
        precondition(end.x > start.x)
        self.start = start
        self.end = end
        let dx = end.x - start.x
        let theta = min(max(aimDegrees, 25), 65) * .pi / 180
        startControlDistance = min(max(0.12 * dx, 80), 160)
        endControlDistance = min(max(0.30 * dx, 180), 360)
        startControl = PresentationPoint(x: start.x + startControlDistance * cos(theta), y: start.y + startControlDistance * sin(theta))
        endControl = PresentationPoint(x: end.x - endControlDistance * cos(35 * .pi / 180), y: end.y + endControlDistance * sin(35 * .pi / 180))
    }

    public func point(at progress: Double) -> PresentationPoint {
        let t = min(max(progress, 0), 1)
        let u = 1 - t
        return PresentationPoint(
            x: u * u * u * start.x + 3 * u * u * t * startControl.x + 3 * u * t * t * endControl.x + t * t * t * end.x,
            y: u * u * u * start.y + 3 * u * u * t * startControl.y + 3 * u * t * t * endControl.y + t * t * t * end.y
        )
    }

    public func tangent(at progress: Double) -> PresentationPoint {
        let t = min(max(progress, 0), 1)
        let u = 1 - t
        return PresentationPoint(
            x: 3 * u * u * (startControl.x - start.x) + 6 * u * t * (endControl.x - startControl.x) + 3 * t * t * (end.x - endControl.x),
            y: 3 * u * u * (startControl.y - start.y) + 6 * u * t * (endControl.y - startControl.y) + 3 * t * t * (end.y - endControl.y)
        )
    }
}

/// Single deterministic presentation source for arm, held spear, and launch origin.
public struct SpearPresentationGeometry: Equatable {
    public let pose: StickmanPose
    public let aimDegrees: Double
    public let shoulder: PresentationPoint
    public let hand: PresentationPoint
    public let heldSpearOrigin: PresentationPoint
    public let heldSpearEnd: PresentationPoint
    public let flightStart: PresentationPoint

    public init(pose: StickmanPose, aimDegrees: Double) {
        self.pose = pose
        self.aimDegrees = min(max(aimDegrees, 25), 65)
        shoulder = PresentationPoint(x: 52, y: 56)
        let radians = self.aimDegrees * .pi / 180
        switch pose {
        case .aiming:
            hand = PresentationPoint(x: shoulder.x - cos(radians) * 18, y: shoulder.y + sin(radians) * 18)
        case .release, .flying, .recovery:
            hand = PresentationPoint(x: shoulder.x + cos(radians) * 18, y: shoulder.y + sin(radians) * 18)
        case .ready:
            hand = PresentationPoint(x: 68, y: 49)
        }
        heldSpearOrigin = hand
        heldSpearEnd = PresentationPoint(x: hand.x + cos(radians) * 36, y: hand.y + sin(radians) * 36)
        flightStart = hand
    }
}

public enum AnchorInteraction: Equatable {
    case input
    case displayOnly

    public var ignoresMouseEvents: Bool { self == .displayOnly }
}

/// Pure contract mirrored by the AppKit-only FlightPanel configuration.
public struct FlightLayerContract: Equatable {
    public let ignoresMouseEvents: Bool
    public let canBecomeKey: Bool
    public let canBecomeMain: Bool
    public let isNonactivating: Bool
    public let usesExplicitAppearance: Bool
    public let removesAtImpact: Bool

    public static let visibilityOnly = FlightLayerContract(
        ignoresMouseEvents: true, canBecomeKey: false, canBecomeMain: false,
        isNonactivating: true, usesExplicitAppearance: true, removesAtImpact: true
    )
}

/// Pure visual policy. It never changes normalized game judgement.
public struct PresentationPolicy: Equatable {
    public let aimingCycle: Double
    public let launchDuration: Double
    public let flightDuration: Double
    public let impactDuration: Double
    public let resultHoldDuration: Double
    public let resetDuration: Double
    public let staticResultDuration: Double
    public let showsFlightTranslation: Bool

    public var releaseToImpact: Double { launchDuration + flightDuration }
    public var releaseToReady: Double { releaseToImpact + impactDuration + resultHoldDuration + resetDuration }

    public static let standard = PresentationPolicy(
        aimingCycle: 0.6, launchDuration: 0.16, flightDuration: 0.82,
        impactDuration: 0.14, resultHoldDuration: 0.36, resetDuration: 0.22,
        staticResultDuration: 0, showsFlightTranslation: true
    )
    public static let reducedMotion = PresentationPolicy(
        aimingCycle: 0.3, launchDuration: 0, flightDuration: 0,
        impactDuration: 0, resultHoldDuration: 0, resetDuration: 0,
        staticResultDuration: 0.5, showsFlightTranslation: false
    )
}

/// Time-only presentation state; AppKit owns drawing and timers.
public struct PresentationLifecycle: Equatable {
    public private(set) var phase: PresentationPhase = .ready
    public let policy: PresentationPolicy
    private var elapsed = 0.0

    public init(policy: PresentationPolicy) {
        self.policy = policy
    }

    public var pose: StickmanPose {
        switch phase {
        case .ready: return .ready
        case .aiming: return .aiming
        case .release: return .release
        case .flying: return .flying
        case .cue: return .recovery
        }
    }

    public mutating func beginAim() {
        guard phase == .ready else { return }
        phase = .aiming
        elapsed = 0
    }

    public mutating func release() {
        guard phase == .aiming else { return }
        elapsed = 0
        phase = policy.showsFlightTranslation ? .release : .cue
    }

    public mutating func advance(by seconds: Double) {
        guard seconds > 0 else { return }
        elapsed += seconds
        switch phase {
        case .release where elapsed >= policy.launchDuration:
            phase = .flying
            elapsed = 0
        case .flying where elapsed >= policy.flightDuration:
            phase = .cue
            elapsed = 0
        case .cue where elapsed >= cueDuration:
            phase = .ready
            elapsed = 0
        default:
            break
        }
    }

    private var cueDuration: Double {
        policy.showsFlightTranslation
            ? policy.impactDuration + policy.resultHoldDuration + policy.resetDuration
            : policy.staticResultDuration
    }
}

public enum TargetPosition: CaseIterable, Equatable {
    case bottom
    case middle
    case top

    public var normalizedHeight: Double {
        switch self {
        case .bottom: 0.2
        case .middle: 0.5
        case .top: 0.8
        }
    }

    public var next: TargetPosition {
        switch self {
        case .bottom: .middle
        case .middle: .top
        case .top: .bottom
        }
    }
}

public struct SpearGameState: Equatable {
    public static let lowAngle = 20.0
    public static let highAngle = 70.0
    public static let lowToHighDuration = 1.2
    public static let hitTolerance = 0.08

    public private(set) var phase: GamePhase = .ready
    public private(set) var angleDegrees = 45.0
    public private(set) var direction: AimDirection = .increasing
    public private(set) var score = 0
    public private(set) var target: TargetPosition
    public private(set) var landingHeight: Double?

    public init(firstTarget: TargetPosition = .middle) {
        target = firstTarget
    }

    public mutating func beginAim() {
        guard phase == .ready else { return }
        phase = .aiming
        angleDegrees = Self.lowAngle
        direction = .increasing
        landingHeight = nil
    }

    public mutating func advanceAim(by seconds: Double) {
        guard phase == .aiming, seconds > 0 else { return }
        var remaining = seconds
        let speed = (Self.highAngle - Self.lowAngle) / Self.lowToHighDuration
        while remaining > 0 {
            let boundary = direction == .increasing ? Self.highAngle : Self.lowAngle
            let duration = abs(boundary - angleDegrees) / speed
            if remaining < duration {
                angleDegrees += (direction == .increasing ? 1 : -1) * speed * remaining
                return
            }
            angleDegrees = boundary
            direction = direction == .increasing ? .decreasing : .increasing
            remaining -= duration
        }
    }

    public mutating func setAim(angleDegrees: Double) {
        guard phase == .aiming, (Self.lowAngle...Self.highAngle).contains(angleDegrees) else { return }
        self.angleDegrees = angleDegrees
    }

    public mutating func release() {
        guard phase == .aiming else { return }
        phase = .flying
        landingHeight = Self.normalizedLanding(for: angleDegrees)
    }

    public mutating func resolveFlight() {
        guard phase == .flying, let landingHeight else { return }
        if abs(landingHeight - target.normalizedHeight) <= Self.hitTolerance {
            score += 1
            phase = .hit
        } else {
            phase = .miss
        }
    }

    public mutating func finishRound() {
        guard phase == .hit || phase == .miss else { return }
        target = target.next
        phase = .ready
        angleDegrees = 45
        direction = .increasing
        landingHeight = nil
    }

    public static func normalizedLanding(for angleDegrees: Double) -> Double {
        let clamped = min(max(angleDegrees, lowAngle), highAngle)
        return 0.2 + (clamped - lowAngle) / (highAngle - lowAngle) * 0.6
    }
}
