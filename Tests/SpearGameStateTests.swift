import XCTest
@testable import SpearGameCore

final class SpearGameStateTests: XCTestCase {
    func testDragMapsExactAngleAndReverseTangentPower() {
        XCTAssertEqual(DragLaunch.angle(forVerticalDrag: -48), 25, accuracy: 0.0001)
        XCTAssertEqual(DragLaunch.angle(forVerticalDrag: 0), 45, accuracy: 0.0001)
        XCTAssertEqual(DragLaunch.angle(forVerticalDrag: 48), 65, accuracy: 0.0001)
        let angle = 45.0
        XCTAssertEqual(DragLaunch.power(displacement: PresentationPoint(x: -6 / sqrt(2), y: -6 / sqrt(2)), angleDegrees: angle), 0, accuracy: 0.0001)
        XCTAssertEqual(DragLaunch.power(displacement: PresentationPoint(x: -72 / sqrt(2), y: -72 / sqrt(2)), angleDegrees: angle), 1, accuracy: 0.0001)
        XCTAssertEqual(DragLaunch.power(displacement: PresentationPoint(x: 72 / sqrt(2), y: 72 / sqrt(2)), angleDegrees: angle), 0, accuracy: 0.0001)
    }

    func testPowerProducesStrictlyIncreasingGroundDistanceAtSameAngle() {
        let start = PresentationPoint(x: 48, y: 108)
        let paths = [0.15, 0.50, 0.85].map { BallisticFlightPath(start: start, angleDegrees: 45, power: $0, groundY: 16) }
        let landings = paths.map { $0.groundCrossing.tail.x }
        XCTAssertLessThan(landings[0], landings[1])
        XCTAssertLessThan(landings[1], landings[2])
    }

    func testAnglesHaveDifferentApexAndLandingAtSamePower() {
        let paths = [25.0, 45.0, 65.0].map { BallisticFlightPath(start: PresentationPoint(x: 48, y: 108), angleDegrees: $0, power: 0.5, groundY: 16) }
        XCTAssertGreaterThan(abs(paths[0].apex.y - paths[1].apex.y), 0.001)
        XCTAssertGreaterThan(abs(paths[1].apex.y - paths[2].apex.y), 0.001)
        XCTAssertGreaterThan(abs(paths[0].groundCrossing.tail.x - paths[1].groundCrossing.tail.x), 0.001)
        XCTAssertGreaterThan(abs(paths[1].groundCrossing.tail.x - paths[2].groundCrossing.tail.x), 0.001)
    }

    func testTargetIsNotLaunchInputAndGroundCrossingIsPhysical() {
        let path = BallisticFlightPath(start: PresentationPoint(x: 48, y: 108), angleDegrees: 45, power: 0.5, groundY: 16)
        XCTAssertEqual(path.gravity, 2400, accuracy: 0.0001)
        XCTAssertEqual(path.v0, 1400, accuracy: 0.0001)
        XCTAssertEqual(path.groundCrossing.tail.y, 16, accuracy: 0.0001)
        XCTAssertGreaterThan(path.groundCrossing.elapsed, 0)
    }

    func testActualShaftSegmentCollisionAndGroundMiss() {
        let path = BallisticFlightPath(start: PresentationPoint(x: 48, y: 108), angleDegrees: 45, power: 0.5, groundY: 16)
        let hit = PresentationPoint(x: 280, y: 270)
        XCTAssertNotNil(SpearCollision.firstImpact(path: path, target: hit, fromElapsed: 0, toElapsed: path.groundCrossing.elapsed))
        XCTAssertNil(SpearCollision.firstImpact(path: path, target: PresentationPoint(x: 260, y: 700), fromElapsed: 0, toElapsed: path.groundCrossing.elapsed))
    }

    func testGestureCancelsOutsideAndStaleDownResets() {
        var gesture = LocalGesture()
        XCTAssertTrue(gesture.begin(at: PresentationPoint(x: 48, y: 48), inStartZone: true))
        gesture.move(to: PresentationPoint(x: 40, y: 100), isInsideInput: false)
        XCTAssertNil(gesture.release(isInsideInput: false))
        XCTAssertTrue(gesture.begin(at: PresentationPoint(x: 48, y: 48), inStartZone: true))
    }

    func testFlightClockAndDisplayContractsRemainLocalAndNonactivating() {
        var clock = FlightClock(maximumDelta: 0.25)
        XCTAssertEqual(clock.advance(now: 10), 0)
        XCTAssertEqual(clock.advance(now: 10.08), 0.08, accuracy: 0.000_001)
        XCTAssertEqual(clock.advance(now: 11), 0.25, accuracy: 0.000_001)
        XCTAssertTrue(FlightLayerContract.visibilityOnly.ignoresMouseEvents)
        XCTAssertFalse(FlightLayerContract.visibilityOnly.canBecomeKey)
        XCTAssertFalse(FlightLayerContract.visibilityOnly.canBecomeMain)
        XCTAssertEqual(BallisticFlightPath.shaftLength, 42, accuracy: 0.0001)
    }
}
