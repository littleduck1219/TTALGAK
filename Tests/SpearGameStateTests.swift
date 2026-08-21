import XCTest
@testable import SpearGameCore

final class SpearGameStateTests: XCTestCase {
    func testDragMapsExactAngleAndReverseTangentPower() {
        XCTAssertEqual(DragLaunch.angle(forVerticalDrag: -48), 25, accuracy: 0.0001)
        XCTAssertEqual(DragLaunch.angle(forVerticalDrag: 0), 45, accuracy: 0.0001)
        XCTAssertEqual(DragLaunch.angle(forVerticalDrag: 48), 65, accuracy: 0.0001)
        let angle = 45.0
        XCTAssertEqual(DragLaunch.power(displacement: PresentationPoint(x: -6 / sqrt(2), y: -6 / sqrt(2)), angleDegrees: angle), 0, accuracy: 0.0001)
        XCTAssertEqual(DragLaunch.power(displacement: PresentationPoint(x: -83 / sqrt(2), y: -83 / sqrt(2)), angleDegrees: angle), 0.5, accuracy: 0.0001)
        XCTAssertEqual(DragLaunch.power(displacement: PresentationPoint(x: -160 / sqrt(2), y: -160 / sqrt(2)), angleDegrees: angle), 1, accuracy: 0.0001)
        XCTAssertEqual(DragLaunch.power(displacement: PresentationPoint(x: -72 / sqrt(2), y: -72 / sqrt(2)), angleDegrees: angle), (72.0 - 6) / 154, accuracy: 0.0001)
        XCTAssertEqual(DragLaunch.power(displacement: PresentationPoint(x: 160 / sqrt(2), y: 160 / sqrt(2)), angleDegrees: angle), 0, accuracy: 0.0001)
    }

    func testGroundInventoryKeepsMissesCapsAtFiftyAndEvictsOldest() {
        XCTAssertEqual(GroundSpearInventory.capacity, 50)
        var inventory = GroundSpearInventory()
        for index in 0..<51 {
            inventory.record(hit: false, tail: PresentationPoint(x: Double(index), y: 16), tip: PresentationPoint(x: Double(index) + 42, y: 16))
        }
        XCTAssertEqual(inventory.spears.count, 50)
        XCTAssertEqual(inventory.spears.first?.tail.x ?? -1, 1, accuracy: 0.0001)
        XCTAssertEqual(inventory.spears.last?.tail.x ?? -1, 50, accuracy: 0.0001)
    }

    func testHitSpearsAreNeverAddedToGroundInventory() {
        var inventory = GroundSpearInventory()
        inventory.record(hit: true, tail: PresentationPoint(x: 300, y: 200), tip: PresentationPoint(x: 342, y: 200))
        XCTAssertTrue(inventory.spears.isEmpty)
        inventory.record(hit: false, tail: PresentationPoint(x: 400, y: 16), tip: PresentationPoint(x: 442, y: 16))
        XCTAssertEqual(inventory.spears.count, 1)
        XCTAssertEqual(inventory.spears[0].tail, PresentationPoint(x: 400, y: 16))
        XCTAssertEqual(inventory.spears[0].tip, PresentationPoint(x: 442, y: 16))
    }

    func testTargetSpawnsWithinRightInsetRangeAndDeterministicSeedHeights() {
        var units = [0.0, 0.5, 1.0, 2.0]
        var lifecycle = TargetLifecycle(unit: { units.removeFirst() })
        let spawns = (0..<4).map { _ in lifecycle.spawn(screenMinX: 0, screenMaxX: 1600, groundY: 100) }
        XCTAssertEqual(spawns[0].x, 1600 - 280, accuracy: 0.0001)
        XCTAssertEqual(spawns[1].x, 1600 - 400, accuracy: 0.0001)
        XCTAssertEqual(spawns[2].x, 1600 - 520, accuracy: 0.0001)
        XCTAssertEqual(spawns[3].x, 1600 - 520, accuracy: 0.0001)
        XCTAssertEqual(spawns.map(\.y), [164, 232, 300, 164])
        for spawn in spawns {
            XCTAssertGreaterThanOrEqual(1600 - spawn.x, 280)
            XCTAssertLessThanOrEqual(1600 - spawn.x, 520)
        }
        var narrow = TargetLifecycle(unit: { 1 })
        let clamped = narrow.spawn(screenMinX: 1500, screenMaxX: 1600, groundY: 0)
        XCTAssertEqual(clamped.x, 1500 + 22, accuracy: 0.0001)
    }

    func testTargetStableOnMissAndChangesOnlyOnHit() {
        var units = [0.0, 1.0]
        var lifecycle = TargetLifecycle(unit: { units.removeFirst() })
        let initial = lifecycle.spawn(screenMinX: 0, screenMaxX: 1600, groundY: 100)
        lifecycle.resolve(hit: false, screenMinX: 0, screenMaxX: 1600, groundY: 100)
        XCTAssertEqual(lifecycle.target, initial)
        lifecycle.resolve(hit: false, screenMinX: 0, screenMaxX: 1600, groundY: 100)
        XCTAssertEqual(lifecycle.target, initial)
        lifecycle.resolve(hit: true, screenMinX: 0, screenMaxX: 1600, groundY: 100)
        XCTAssertNotEqual(lifecycle.target, initial)
        XCTAssertEqual(lifecycle.target?.x ?? 0, 1600 - 520, accuracy: 0.0001)
        XCTAssertEqual(lifecycle.target?.y ?? 0, 232, accuracy: 0.0001)
        XCTAssertTrue(units.isEmpty)
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

    func testGestureKeepsOutsideDragAndReleasesOnce() {
        var gesture = LocalGesture()
        XCTAssertTrue(gesture.begin(at: PresentationPoint(x: 48, y: 48), inStartZone: true))
        let outside = gesture.move(to: PresentationPoint(x: -100, y: 0), isInsideInput: false)
        XCTAssertNotNil(outside)
        XCTAssertEqual(outside?.angleDegrees ?? 0, 25, accuracy: 0.0001)
        XCTAssertGreaterThan(outside?.power ?? 0, 0)
        XCTAssertEqual(gesture.release(isInsideInput: false), outside)
        XCTAssertNil(gesture.release(isInsideInput: false))
    }

    func testMaxPowerNeedsFullOneSixtyPullOutsideLocalInput() {
        var gesture = LocalGesture()
        XCTAssertTrue(gesture.begin(at: PresentationPoint(x: 48, y: 48), inStartZone: true))
        let tangent = DragLaunch.tangent(angleDegrees: 25)
        let almost = gesture.move(to: PresentationPoint(x: 48 - tangent.x * 159, y: 48 - tangent.y * 159), isInsideInput: false)
        XCTAssertLessThan(almost?.power ?? 1, 1)
        let full = gesture.move(to: PresentationPoint(x: 48 - tangent.x * 160, y: 48 - tangent.y * 160), isInsideInput: false)
        XCTAssertEqual(full?.angleDegrees ?? 0, 25, accuracy: 0.0001)
        XCTAssertEqual(full?.power ?? 0, 1, accuracy: 0.0001)
        XCTAssertEqual(gesture.release(isInsideInput: false), full)
    }

    func testAngleOnlyVerticalMoveKeepsLatchedPowerExactlyWhileAngleChanges() {
        var gesture = LocalGesture()
        XCTAssertTrue(gesture.begin(at: PresentationPoint(x: 48, y: 48), inStartZone: true))
        let latched = gesture.move(to: PresentationPoint(x: 28, y: 48), isInsideInput: true)
        XCTAssertEqual(latched?.angleDegrees ?? 0, 45, accuracy: 0.0001)
        XCTAssertGreaterThan(latched?.power ?? 0, 0)
        let raised = gesture.move(to: PresentationPoint(x: 28, y: 72), isInsideInput: true)
        XCTAssertEqual(raised?.angleDegrees ?? 0, 55, accuracy: 0.0001)
        XCTAssertEqual(raised?.power, latched?.power)
        let lowered = gesture.move(to: PresentationPoint(x: 28, y: 24), isInsideInput: true)
        XCTAssertEqual(lowered?.angleDegrees ?? 0, 35, accuracy: 0.0001)
        XCTAssertEqual(lowered?.power, latched?.power)
        XCTAssertEqual(gesture.release(isInsideInput: true), lowered)
    }

    func testFurtherPullAlongFrozenReverseTangentRaisesLatchedPower() {
        var gesture = LocalGesture()
        XCTAssertTrue(gesture.begin(at: PresentationPoint(x: 48, y: 48), inStartZone: true))
        let tangent = DragLaunch.tangent(angleDegrees: 45)
        let latched = gesture.move(to: PresentationPoint(x: 28, y: 48), isInsideInput: true)
        XCTAssertGreaterThan(latched?.power ?? 0, 0)
        let pulled = gesture.move(to: PresentationPoint(x: 28 - tangent.x * 40, y: 48 - tangent.y * 40), isInsideInput: true)
        XCTAssertEqual(pulled?.power ?? 0, (latched?.power ?? 0) + 40.0 / 154, accuracy: 0.0001)
        XCTAssertGreaterThan(pulled?.power ?? 0, latched?.power ?? 1)
    }

    func testFrozenAxisFullPullReachesExactMaxAtOneSixty() {
        var gesture = LocalGesture()
        XCTAssertTrue(gesture.begin(at: PresentationPoint(x: 48, y: 48), inStartZone: true))
        let tangent = DragLaunch.tangent(angleDegrees: 45)
        let latched = gesture.move(to: PresentationPoint(x: 28, y: 48), isInsideInput: true)
        XCTAssertGreaterThan(latched?.power ?? 0, 0)
        let full = gesture.move(to: PresentationPoint(x: 48 - tangent.x * 160, y: 48 - tangent.y * 160), isInsideInput: true)
        XCTAssertEqual(full?.power ?? 0, 1, accuracy: 0.0001)
        XCTAssertEqual(full?.angleDegrees ?? 0, 25, accuracy: 0.0001)
        XCTAssertEqual(gesture.release(isInsideInput: true), full)
    }

    func testNoDeadZoneCrossingMeansAngleMovesNeverLatchPower() {
        var gesture = LocalGesture()
        XCTAssertTrue(gesture.begin(at: PresentationPoint(x: 48, y: 48), inStartZone: true))
        let up = gesture.move(to: PresentationPoint(x: 48, y: 96), isInsideInput: true)
        XCTAssertEqual(up?.angleDegrees ?? 0, 65, accuracy: 0.0001)
        XCTAssertEqual(up?.power ?? 1, 0, accuracy: 0.0001)
        let down = gesture.move(to: PresentationPoint(x: 48, y: 44), isInsideInput: true)
        XCTAssertEqual(down?.power ?? 1, 0, accuracy: 0.0001)
    }

    func testGestureNextValidDownDiscardsStaleLaunch() {
        var gesture = LocalGesture()
        XCTAssertTrue(gesture.begin(at: PresentationPoint(x: 48, y: 48), inStartZone: true))
        XCTAssertNotNil(gesture.move(to: PresentationPoint(x: -100, y: 0), isInsideInput: false))
        XCTAssertTrue(gesture.begin(at: PresentationPoint(x: 48, y: 48), inStartZone: true))
        XCTAssertNil(gesture.release(isInsideInput: false))
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
