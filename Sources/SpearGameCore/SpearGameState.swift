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
