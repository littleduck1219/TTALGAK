import XCTest
@testable import SpearGameCore

final class SpearGameStateTests: XCTestCase {
    func testCanonicalTargetSetupMatchesBallisticTailAtImpact() {
        let start = PresentationPoint(x: 48, y: 56)
        let targetX = 1232.0
        for target in TargetPosition.allCases {
            let center = BallisticTarget.center(start: start, targetX: targetX, position: target)
            let path = BallisticFlightPath(start: start, targetX: targetX, aimDegrees: target.canonicalAimDegrees)
            let tail = path.sample(elapsed: 0.82).tail
            XCTAssertEqual(tail.x, center.x, accuracy: 1e-6)
            XCTAssertEqual(tail.y, center.y, accuracy: 1e-6)
        }
    }

    func testBallisticLaunchApexAndDescentUseVelocityOnly() {
        let start = PresentationPoint(x: 48, y: 56)
        for angle in [25.0, 45.0, 65.0] {
            let path = BallisticFlightPath(start: start, targetX: 1232, aimDegrees: angle)
            XCTAssertEqual(path.sample(elapsed: 0).shaftAngleDegrees, angle, accuracy: 0.001)
            let apex = path.apexElapsed
            XCTAssertGreaterThan(apex, 0)
            XCTAssertLessThan(apex, 0.82)
            XCTAssertGreaterThan(path.sample(elapsed: apex - 0.001).velocity.y, 0)
            XCTAssertLessThan(path.sample(elapsed: apex + 0.001).velocity.y, 0)
            XCTAssertEqual(path.sample(elapsed: apex).shaftAngleDegrees, 0, accuracy: 0.001)
            XCTAssertLessThan(path.sample(elapsed: 0.82).velocity.y, 0)
        }
    }

    func testBallisticPositionIsMonotonicAndClampsAim() {
        let path = BallisticFlightPath(start: PresentationPoint(x: 48, y: 56), targetX: 1232, aimDegrees: 70)
        XCTAssertEqual(path.aimDegrees, 65, accuracy: 0.0001)
        var previous = path.sample(elapsed: 0).tail.x
        for step in 1...82 {
            let x = path.sample(elapsed: Double(step) / 100).tail.x
            XCTAssertGreaterThan(x, previous)
            previous = x
        }
    }

    func testCollisionSamplesShaftWithFourPointMaximumSubsteps() {
        let path = BallisticFlightPath(start: PresentationPoint(x: 48, y: 56), targetX: 1232, aimDegrees: 45)
        let target = BallisticTarget.center(start: PresentationPoint(x: 48, y: 56), targetX: 1232, position: .middle)
        XCTAssertNotNil(SpearCollision.firstImpact(path: path, target: target, fromElapsed: 0, toElapsed: 0.82))
        XCTAssertNil(SpearCollision.firstImpact(path: path, target: PresentationPoint(x: target.x, y: target.y + 100), fromElapsed: 0, toElapsed: 0.82))
    }

    func testCollisionIsTheOnlyOutcomeAuthority() {
        var game = SpearGameState(firstTarget: .top)
        game.beginAim(); game.setAim(angleDegrees: 20); game.release()
        game.resolveFlight(hit: true)
        XCTAssertEqual(game.phase, .hit)
        XCTAssertEqual(game.score, 1)

        game.finishRound(); game.beginAim(); game.setAim(angleDegrees: 70); game.release()
        game.resolveFlight(hit: false)
        XCTAssertEqual(game.phase, .miss)
        XCTAssertEqual(game.score, 1)
    }

    func testReleaseHandMovesContinuouslyWithoutBodyCrossAndFlightStartsAtFinalHand() {
        let aiming = SpearPresentationGeometry(pose: .aiming, aimDegrees: 45)
        let release = SpearPresentationGeometry(pose: .release, aimDegrees: 45)
        XCTAssertEqual(aiming.hand, release.releaseEntryHand)
        XCTAssertEqual(release.hand(atReleaseProgress: 0), release.releaseEntryHand)
        XCTAssertEqual(release.hand(atReleaseProgress: 1), release.finalReleaseHand)
        XCTAssertLessThanOrEqual(release.finalReleaseHand.x, release.shoulder.x)
        XCTAssertEqual(release.flightStart, release.finalReleaseHand)
    }

    func testPresentationPoliciesPreserveStandardAndReducedMotionBoundaries() {
        XCTAssertEqual(PresentationPolicy.standard.launchDuration, 0.16, accuracy: 0.0001)
        XCTAssertEqual(PresentationPolicy.standard.flightDuration, 0.82, accuracy: 0.0001)
        XCTAssertTrue(PresentationPolicy.standard.showsFlightTranslation)
        XCTAssertEqual(PresentationPolicy.reducedMotion.aimingCycle, 0.3, accuracy: 0.0001)
        XCTAssertFalse(PresentationPolicy.reducedMotion.showsFlightTranslation)
        XCTAssertEqual(PresentationPolicy.reducedMotion.staticResultDuration, 0.5, accuracy: 0.0001)
        XCTAssertEqual(FlightLayerContract.visibilityOnly.ignoresMouseEvents, true)
        XCTAssertEqual(AnchorInteraction.displayOnly.ignoresMouseEvents, true)
    }

    func testDiscreteBandFreezesAssetTangentAndFinalP0ForBallistics() {
        XCTAssertEqual(MotionAssetBand.forRawAim(20), .low25)
        XCTAssertEqual(MotionAssetBand.forRawAim(45), .mid45)
        XCTAssertEqual(MotionAssetBand.forRawAim(70), .high65)
        let snapshot = MotionAssetSnapshot.fixture(.mid45)
        let path = BallisticFlightPath(start: snapshot.flightStart, targetX: 1232, snapshot: snapshot)
        XCTAssertEqual(path.aimDegrees, 45, accuracy: 0.001)
        XCTAssertEqual(path.start, snapshot.flightStart)
        XCTAssertEqual(path.sample(elapsed: 0).shaftAngleDegrees, snapshot.flightAngleDegrees, accuracy: 0.001)
    }

    func testReleaseSequenceUsesDiscreteAssetFramesAtExactOffsets() {
        XCTAssertEqual(MotionAssetBand.low25.releaseFrameOffsetsMs, [0, 53, 107, 160])
        XCTAssertEqual(MotionAssetBand.mid45.releaseFrameOffsetsMs, [0, 53, 107, 160])
        XCTAssertEqual(MotionAssetBand.high65.releaseFrameOffsetsMs, [0, 53, 107, 160])
        XCTAssertEqual(MotionAssetBand.mid45.frameIndex(atReleaseElapsedMs: 0), 0)
        XCTAssertEqual(MotionAssetBand.mid45.frameIndex(atReleaseElapsedMs: 53), 1)
        XCTAssertEqual(MotionAssetBand.mid45.frameIndex(atReleaseElapsedMs: 107), 2)
        XCTAssertEqual(MotionAssetBand.mid45.frameIndex(atReleaseElapsedMs: 160), 3)
    }

    func testFallbackSnapshotStaysCodeDrawnAndNeverBlank() {
        let snapshot = MotionAssetSnapshot.fallback(for: .high65)
        XCTAssertTrue(snapshot.usesCodeFallback)
        XCTAssertEqual(snapshot.band, .high65)
        XCTAssertEqual(snapshot.flightStart, snapshot.finalP0)
    }
}
