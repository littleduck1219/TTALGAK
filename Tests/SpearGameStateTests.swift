import XCTest
@testable import SpearGameCore

final class SpearGameStateTests: XCTestCase {
    func testReadyAimingFlyingHitReadyAddsOnePoint() {
        var game = SpearGameState(firstTarget: .middle)
        XCTAssertEqual(game.phase, .ready)

        game.beginAim()
        game.setAim(angleDegrees: 45)
        game.release()
        XCTAssertEqual(game.phase, .flying)

        game.resolveFlight()
        XCTAssertEqual(game.phase, .hit)
        XCTAssertEqual(game.score, 1)

        game.finishRound()
        XCTAssertEqual(game.phase, .ready)
        XCTAssertEqual(game.score, 1)
    }

    func testReadyAimingFlyingMissReadyKeepsScore() {
        var game = SpearGameState(firstTarget: .top)
        game.beginAim()
        game.setAim(angleDegrees: 20)
        game.release()
        game.resolveFlight()

        XCTAssertEqual(game.phase, .miss)
        XCTAssertEqual(game.score, 0)
        game.finishRound()
        XCTAssertEqual(game.phase, .ready)
    }

    func testAimReversesAtBothBounds() {
        var game = SpearGameState(firstTarget: .middle)
        game.beginAim()
        game.advanceAim(by: 1.2)
        XCTAssertEqual(game.angleDegrees, 70, accuracy: 0.0001)
        XCTAssertEqual(game.direction, .decreasing)

        game.advanceAim(by: 1.2)
        XCTAssertEqual(game.angleDegrees, 20, accuracy: 0.0001)
        XCTAssertEqual(game.direction, .increasing)
    }

    func testInvalidInputIsNoOpAndReleaseOnlyStartsOneFlight() {
        var game = SpearGameState(firstTarget: .middle)
        let ready = game
        game.advanceAim(by: 0.1)
        game.release()
        XCTAssertEqual(game, ready)

        game.beginAim()
        game.release()
        let flight = game
        game.release()
        game.beginAim()
        XCTAssertEqual(game, flight)
    }

    func testMotionPolicyKeepsCoreTimingSeparateFromReducedMotionRendering() {
        XCTAssertEqual(MotionPolicy.standard.aimingUpdateInterval, 1.0 / 60.0, accuracy: 0.0001)
        XCTAssertTrue(MotionPolicy.standard.showsFlightAnimation)
        XCTAssertEqual(MotionPolicy.reducedMotion.aimingUpdateInterval, 0.3, accuracy: 0.0001)
        XCTAssertFalse(MotionPolicy.reducedMotion.showsFlightAnimation)
    }

    func testNormalizedMappingHitsEachTargetAndMissesOutsideTolerance() {
        for (target, angle) in [(TargetPosition.bottom, 20.0), (.middle, 45.0), (.top, 70.0)] {
            var game = SpearGameState(firstTarget: target)
            game.beginAim()
            game.setAim(angleDegrees: angle)
            game.release()
            game.resolveFlight()
            XCTAssertEqual(game.phase, .hit)
        }

        var game = SpearGameState(firstTarget: .top)
        game.beginAim()
        game.setAim(angleDegrees: 20)
        game.release()
        game.resolveFlight()
        XCTAssertEqual(game.phase, .miss)
    }

    func testV2StandardPresentationPolicyUsesExactRepresentativeTiming() {
        let policy = PresentationPolicy.standard
        XCTAssertEqual(policy.aimingCycle, 0.6, accuracy: 0.0001)
        XCTAssertEqual(policy.launchDuration, 0.16, accuracy: 0.0001)
        XCTAssertEqual(policy.flightDuration, 0.82, accuracy: 0.0001)
        XCTAssertEqual(policy.impactDuration, 0.14, accuracy: 0.0001)
        XCTAssertEqual(policy.resultHoldDuration, 0.36, accuracy: 0.0001)
        XCTAssertEqual(policy.resetDuration, 0.22, accuracy: 0.0001)
        XCTAssertEqual(policy.releaseToImpact, 0.98, accuracy: 0.0001)
        XCTAssertEqual(policy.releaseToReady, 1.48, accuracy: 0.0001)
        XCTAssertTrue(policy.showsFlightTranslation)
    }

    func testV2ReducedMotionHasOnlyDiscreteAimAndStaticResult() {
        let policy = PresentationPolicy.reducedMotion
        XCTAssertEqual(policy.aimingCycle, 0.3, accuracy: 0.0001)
        XCTAssertFalse(policy.showsFlightTranslation)
        XCTAssertEqual(policy.launchDuration, 0, accuracy: 0.0001)
        XCTAssertEqual(policy.flightDuration, 0, accuracy: 0.0001)
        XCTAssertEqual(policy.staticResultDuration, 0.5, accuracy: 0.0001)
    }

    func testCubicFlightPathStartsAtHeldTailWithExactTangentAtVisibleAimBoundsAndMidpoint() {
        let start = PresentationPoint(x: 48, y: 20)
        let end = PresentationPoint(x: 1232, y: 80)
        for aimDegrees in [25.0, 45.0, 65.0] {
            let geometry = SpearPresentationGeometry(pose: .release, aimDegrees: aimDegrees)
            let path = PresentationFlightPath(start: start, end: end, aimDegrees: geometry.aimDegrees)
            let held = subtract(geometry.heldSpearEnd, geometry.heldSpearOrigin)
            let tangent = path.tangent(at: 0)
            XCTAssertEqual(path.point(at: 0), start)
            XCTAssertGreaterThanOrEqual(dot(normalized(tangent), normalized(held)), 0.999999)
            XCTAssertLessThanOrEqual(angularDeltaDegrees(tangent, held), 0.001)
        }
    }

    func testCubicFlightPathEndsAtExactTargetOrMissEndpointWithDescendingApproach() {
        let target = PresentationPoint(x: 1232, y: 80)
        let lowMiss = PresentationPoint(x: 1274, y: 48)
        let highMiss = PresentationPoint(x: 1274, y: 112)
        let expectedEndTangent = PresentationPoint(x: cos(35 * .pi / 180), y: -sin(35 * .pi / 180))
        for (aimDegrees, endpoint) in [(25.0, target), (65.0, target), (25.0, lowMiss), (65.0, highMiss)] {
            let path = PresentationFlightPath(start: PresentationPoint(x: 48, y: 20), end: endpoint, aimDegrees: aimDegrees)
            XCTAssertEqual(path.point(at: 1), endpoint)
            XCTAssertGreaterThanOrEqual(dot(normalized(path.tangent(at: 1)), expectedEndTangent), 0.999999)
            XCTAssertLessThanOrEqual(angularDeltaDegrees(path.tangent(at: 1), expectedEndTangent), 0.001)
        }
        XCTAssertEqual(resolvedPhase(target: .bottom, rawAim: 20), .hit)
        XCTAssertEqual(resolvedPhase(target: .top, rawAim: 70), .hit)
        XCTAssertEqual(resolvedPhase(target: .top, rawAim: 20), .miss)
        XCTAssertEqual(resolvedPhase(target: .bottom, rawAim: 70), .miss)
    }

    private func resolvedPhase(target: TargetPosition, rawAim: Double) -> GamePhase {
        var game = SpearGameState(firstTarget: target)
        game.beginAim()
        game.setAim(angleDegrees: rawAim)
        game.release()
        game.resolveFlight()
        return game.phase
    }

    func testCubicFlightPathUsesExactControlDistanceClamps() {
        let short = PresentationFlightPath(start: PresentationPoint(x: 0, y: 0), end: PresentationPoint(x: 100, y: 0), aimDegrees: 25)
        let long = PresentationFlightPath(start: PresentationPoint(x: 0, y: 0), end: PresentationPoint(x: 2000, y: 0), aimDegrees: 65)
        XCTAssertEqual(short.startControlDistance, 80, accuracy: 0.0001)
        XCTAssertEqual(short.endControlDistance, 180, accuracy: 0.0001)
        XCTAssertEqual(long.startControlDistance, 160, accuracy: 0.0001)
        XCTAssertEqual(long.endControlDistance, 360, accuracy: 0.0001)
    }

    private func subtract(_ lhs: PresentationPoint, _ rhs: PresentationPoint) -> PresentationPoint {
        PresentationPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    private func normalized(_ vector: PresentationPoint) -> PresentationPoint {
        let length = hypot(vector.x, vector.y)
        return PresentationPoint(x: vector.x / length, y: vector.y / length)
    }

    private func dot(_ lhs: PresentationPoint, _ rhs: PresentationPoint) -> Double {
        lhs.x * rhs.x + lhs.y * rhs.y
    }

    private func angularDeltaDegrees(_ lhs: PresentationPoint, _ rhs: PresentationPoint) -> Double {
        acos(min(1, max(-1, dot(normalized(lhs), normalized(rhs))))) * 180 / .pi
    }

    func testPresentationLifecycleUsesReleaseFlyingCueThenReady() {
        var lifecycle = PresentationLifecycle(policy: .standard)
        XCTAssertEqual(lifecycle.phase, .ready)
        lifecycle.beginAim()
        XCTAssertEqual(lifecycle.pose, .aiming)
        lifecycle.release()
        XCTAssertEqual(lifecycle.phase, .release)
        lifecycle.advance(by: 0.16)
        XCTAssertEqual(lifecycle.phase, .flying)
        lifecycle.advance(by: 0.82)
        XCTAssertEqual(lifecycle.phase, .cue)
        lifecycle.advance(by: 0.72)
        XCTAssertEqual(lifecycle.phase, .ready)
    }

    func testReducedMotionLifecycleResolvesImmediatelyToStaticCue() {
        var lifecycle = PresentationLifecycle(policy: .reducedMotion)
        lifecycle.beginAim()
        lifecycle.release()
        XCTAssertEqual(lifecycle.phase, .cue)
        XCTAssertEqual(lifecycle.pose, .recovery)
    }

    func testPresentationGeometryClampsCurrentAimToTheVisible25To65Sweep() {
        let low = SpearPresentationGeometry(pose: .aiming, aimDegrees: 20)
        let high = SpearPresentationGeometry(pose: .aiming, aimDegrees: 70)

        XCTAssertEqual(low.aimDegrees, 25, accuracy: 0.0001)
        XCTAssertEqual(high.aimDegrees, 65, accuracy: 0.0001)
        XCTAssertNotEqual(low.hand, high.hand)
        XCTAssertNotEqual(low.heldSpearEnd, high.heldSpearEnd)
    }

    func testReleaseGeometrySharesRenderedHandHeldSpearOriginAndFlightStart() {
        let geometry = SpearPresentationGeometry(pose: .release, aimDegrees: 45)

        XCTAssertEqual(geometry.hand, geometry.heldSpearOrigin)
        XCTAssertEqual(geometry.hand, geometry.flightStart)
    }

    func testVisibilityOnlyFlightContractAndDisplayOnlyAnchorAreExplicit() {
        XCTAssertEqual(FlightLayerContract.visibilityOnly, FlightLayerContract(
            ignoresMouseEvents: true, canBecomeKey: false, canBecomeMain: false,
            isNonactivating: true, usesExplicitAppearance: true, removesAtImpact: true
        ))
        XCTAssertEqual(AnchorInteraction.displayOnly.ignoresMouseEvents, true)
        XCTAssertEqual(AnchorInteraction.input.ignoresMouseEvents, false)
    }
}
