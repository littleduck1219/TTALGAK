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

    func testV2StandardPresentationPolicyMeetsMotionBudget() {
        let policy = PresentationPolicy.standard
        XCTAssertEqual(policy.aimingCycle, 0.6, accuracy: 0.0001)
        XCTAssertEqual(policy.launchDuration, 0.12, accuracy: 0.0001)
        XCTAssertGreaterThanOrEqual(policy.flightDuration, 0.42)
        XCTAssertLessThanOrEqual(policy.flightDuration, 0.62)
        XCTAssertLessThanOrEqual(policy.launchDuration + policy.flightDuration, 0.7)
        XCTAssertGreaterThanOrEqual(policy.resetDuration, 1.1)
        XCTAssertLessThanOrEqual(policy.resetDuration, 1.3)
        XCTAssertTrue(policy.showsFlightTranslation)
    }

    func testV2ReducedMotionHasStaticResultWithoutFlightTranslation() {
        let policy = PresentationPolicy.reducedMotion
        XCTAssertEqual(policy.aimingCycle, 0.3, accuracy: 0.0001)
        XCTAssertFalse(policy.showsFlightTranslation)
        XCTAssertEqual(policy.launchDuration, 0, accuracy: 0.0001)
        XCTAssertEqual(policy.flightDuration, 0, accuracy: 0.0001)
    }

    func testPresentationLifecycleUsesReleaseFlyingCueThenReady() {
        var lifecycle = PresentationLifecycle(policy: .standard)
        XCTAssertEqual(lifecycle.phase, .ready)
        lifecycle.beginAim()
        XCTAssertEqual(lifecycle.pose, .aiming)
        lifecycle.release()
        XCTAssertEqual(lifecycle.phase, .release)
        lifecycle.advance(by: 0.12)
        XCTAssertEqual(lifecycle.phase, .flying)
        lifecycle.advance(by: 0.5)
        XCTAssertEqual(lifecycle.phase, .cue)
        lifecycle.advance(by: 0.48)
        XCTAssertEqual(lifecycle.phase, .ready)
    }

    func testReducedMotionLifecycleResolvesImmediatelyToStaticCue() {
        var lifecycle = PresentationLifecycle(policy: .reducedMotion)
        lifecycle.beginAim()
        lifecycle.release()
        XCTAssertEqual(lifecycle.phase, .cue)
        XCTAssertEqual(lifecycle.pose, .recovery)
    }
}
