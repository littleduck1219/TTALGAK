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
}
