import XCTest
@testable import SpearGameCore

private let bounds1600 = ScreenBounds(minX: 0, maxX: 1600, minY: 0, maxY: 900)
private let screenStart400x300 = PresentationPoint(x: 400, y: 300)
// 45-degree reverse ray from (400,300) exits the bottom boundary first: 300 / sin(45) = 300 * sqrt(2).
private let maxPull45 = 300 * sqrt(2.0)
private func beginCentered(_ gesture: inout LocalGesture) -> Bool {
    gesture.begin(at: PresentationPoint(x: 48, y: 48), inStartZone: true, screenStart: screenStart400x300, screenBounds: bounds1600)
}

final class SpearGameStateTests: XCTestCase {
    func testDragMapsExactAngleAndReverseTangentPower() {
        XCTAssertEqual(DragLaunch.angle(forVerticalDrag: -48), 10, accuracy: 0.0001)
        XCTAssertEqual(DragLaunch.angle(forVerticalDrag: 0), 45, accuracy: 0.0001)
        XCTAssertEqual(DragLaunch.angle(forVerticalDrag: 48), 65, accuracy: 0.0001)
        XCTAssertEqual(DragLaunch.angle(forVerticalDrag: -24), 27.5, accuracy: 0.0001)
        XCTAssertEqual(DragLaunch.angle(forVerticalDrag: 24), 55, accuracy: 0.0001)
        XCTAssertEqual(DragLaunch.angle(forVerticalDrag: -96), 10, accuracy: 0.0001)
        XCTAssertEqual(DragLaunch.angle(forVerticalDrag: 96), 65, accuracy: 0.0001)
        let tangent = DragLaunch.tangent(angleDegrees: 45)
        XCTAssertEqual(DragLaunch.reversePull(displacement: PresentationPoint(x: -6 / sqrt(2), y: -6 / sqrt(2)), tangent: tangent), 6, accuracy: 0.0001)
        XCTAssertEqual(DragLaunch.reversePull(displacement: PresentationPoint(x: -100 / sqrt(2), y: -100 / sqrt(2)), tangent: tangent), 100, accuracy: 0.0001)
        XCTAssertEqual(DragLaunch.reversePull(displacement: PresentationPoint(x: 100 / sqrt(2), y: 100 / sqrt(2)), tangent: tangent), 0, accuracy: 0.0001)
        XCTAssertEqual(DragLaunch.power(rawPull: 6, maxPull: 400), 0, accuracy: 0.0001)
        XCTAssertEqual(DragLaunch.power(rawPull: 7, maxPull: 400), 1.0 / 394, accuracy: 0.0001)
        XCTAssertEqual(DragLaunch.power(rawPull: 203, maxPull: 400), 0.5, accuracy: 0.0001)
        XCTAssertEqual(DragLaunch.power(rawPull: 400, maxPull: 400), 1, accuracy: 0.0001)
        XCTAssertEqual(DragLaunch.power(rawPull: 999, maxPull: 400), 1, accuracy: 0.0001)
        XCTAssertEqual(DragLaunch.power(rawPull: 100, maxPull: 6), 0, accuracy: 0.0001)
        XCTAssertEqual(DragLaunch.power(rawPull: 100, maxPull: 0), 0, accuracy: 0.0001)
    }

    func testReverseRayHitsFirstScreenBoundary() {
        let t45 = DragLaunch.tangent(angleDegrees: 45)
        XCTAssertEqual(DragLaunch.maxPull(fromScreenStart: screenStart400x300, reverse: t45 * -1, bounds: bounds1600), maxPull45, accuracy: 1e-9)
        XCTAssertEqual(DragLaunch.maxPull(fromScreenStart: PresentationPoint(x: 200, y: 500), reverse: t45 * -1, bounds: bounds1600), 200 * sqrt(2.0), accuracy: 1e-9)
        let t10 = DragLaunch.tangent(angleDegrees: 10)
        XCTAssertEqual(DragLaunch.maxPull(fromScreenStart: screenStart400x300, reverse: t10 * -1, bounds: bounds1600), 400 / t10.x, accuracy: 1e-9)
        let t65 = DragLaunch.tangent(angleDegrees: 65)
        XCTAssertEqual(DragLaunch.maxPull(fromScreenStart: screenStart400x300, reverse: t65 * -1, bounds: bounds1600), 300 / t65.y, accuracy: 1e-9)
        XCTAssertEqual(DragLaunch.maxPull(fromScreenStart: screenStart400x300, reverse: t45, bounds: bounds1600), 600 * sqrt(2.0), accuracy: 1e-9)
        XCTAssertEqual(DragLaunch.maxPull(fromScreenStart: PresentationPoint(x: 0, y: 300), reverse: t45 * -1, bounds: bounds1600), 0, accuracy: 1e-9)
        XCTAssertEqual(DragLaunch.maxPull(fromScreenStart: PresentationPoint(x: 0, y: 0), reverse: t45 * -1, bounds: bounds1600), 0, accuracy: 1e-9)
        XCTAssertEqual(DragLaunch.maxPull(fromScreenStart: PresentationPoint(x: -10, y: -10), reverse: t45 * -1, bounds: bounds1600), 0, accuracy: 1e-9)
    }

    func testScreenEdgePowerAndTensionReachExactMaxAtBoundary() {
        XCTAssertEqual(DragLaunch.power(rawPull: maxPull45, maxPull: maxPull45), 1, accuracy: 1e-9)
        XCTAssertEqual(DragLaunch.tensionLength(rawPull: maxPull45, maxPull: maxPull45), 160, accuracy: 1e-9)
        XCTAssertEqual(DragLaunch.tensionLength(rawPull: 0, maxPull: 400), 0, accuracy: 0.0001)
        XCTAssertEqual(DragLaunch.tensionLength(rawPull: 6, maxPull: 400), 0, accuracy: 0.0001)
        XCTAssertEqual(DragLaunch.tensionLength(rawPull: 7, maxPull: 400), 2.8, accuracy: 0.0001)
        XCTAssertEqual(DragLaunch.tensionLength(rawPull: 200, maxPull: 400), 80, accuracy: 0.0001)
        XCTAssertEqual(DragLaunch.tensionLength(rawPull: 400, maxPull: 400), 160, accuracy: 0.0001)
        XCTAssertEqual(DragLaunch.tensionLength(rawPull: 500, maxPull: 400), 160, accuracy: 0.0001)
        XCTAssertEqual(DragLaunch.tensionLength(rawPull: 100, maxPull: 0), 0, accuracy: 0.0001)
        XCTAssertEqual(DragLaunch.tensionLength(rawPull: 100, maxPull: 4), 0, accuracy: 0.0001)
        let clamped = FrozenLaunch(angleDegrees: 45, power: 0.5, rawPull: -5, maxPull: -9, start: PresentationPoint(x: 0, y: 0))
        XCTAssertEqual(clamped.rawPull, 0, accuracy: 0.0001)
        XCTAssertEqual(clamped.maxPull, 0, accuracy: 0.0001)
    }

    func testBoundedCorridorTilesFollowFrozenRayToFirstBoundary() {
        let reverse = DragLaunch.tangent(angleDegrees: 45) * -1
        let corridor = PullCorridor(start: screenStart400x300, reverse: reverse, maxPull: maxPull45, bounds: bounds1600)
        XCTAssertEqual(PullCorridor.tileSide, 32, accuracy: 0.0001)
        XCTAssertEqual(PullCorridor.documentedWidth, 46, accuracy: 0.0001)
        XCTAssertEqual(corridor.end.x, 100, accuracy: 1e-9)
        XCTAssertEqual(corridor.end.y, 0, accuracy: 1e-9)
        XCTAssertFalse(corridor.tiles.isEmpty)
        XCTAssertTrue(corridor.tiles.allSatisfy { $0.width <= PullCorridor.tileSide && $0.height <= PullCorridor.tileSide })
        XCTAssertTrue(corridor.tiles.allSatisfy { $0.minX >= bounds1600.minX && $0.maxX <= bounds1600.maxX && $0.minY >= bounds1600.minY && $0.maxY <= bounds1600.maxY })
        XCTAssertTrue(corridor.tiles.contains { $0.contains(corridor.end) })
        XCTAssertFalse(corridor.tiles.contains { $0.contains(PresentationPoint(x: 1000, y: 700)) })
    }

    func testCorridorOpensOnlyAtLatchAndScreenMovesPreserveFrozenGeometry() {
        var gesture = LocalGesture()
        XCTAssertTrue(beginCentered(&gesture))
        XCTAssertNil(gesture.corridor)
        XCTAssertNotNil(gesture.move(to: PresentationPoint(x: 46, y: 48), isInsideInput: true))
        XCTAssertNil(gesture.corridor)
        let latched = gesture.move(to: PresentationPoint(x: 28, y: 48), isInsideInput: true)
        let corridor = gesture.corridor
        XCTAssertNotNil(corridor)
        XCTAssertEqual(corridor?.maxPull, latched?.maxPull)
        let edge = corridor?.end ?? screenStart400x300
        let full = gesture.move(toScreenPoint: edge, start: PresentationPoint(x: 10, y: 20))
        XCTAssertEqual(full?.maxPull, latched?.maxPull)
        XCTAssertEqual(full?.power ?? 0, 1, accuracy: 1e-9)
        XCTAssertEqual(full?.rawPull, full?.maxPull)
        XCTAssertEqual(gesture.corridor, corridor)
        XCTAssertNotNil(gesture.release(isInsideInput: false))
        XCTAssertNil(gesture.corridor)
    }

    func testGestureCancellationReleasesCorridorAndLaunch() {
        var gesture = LocalGesture()
        XCTAssertTrue(beginCentered(&gesture))
        XCTAssertNotNil(gesture.move(to: PresentationPoint(x: 28, y: 48), isInsideInput: true))
        XCTAssertNotNil(gesture.corridor)
        gesture.cancel()
        XCTAssertNil(gesture.corridor)
        XCTAssertNil(gesture.launch)
        XCTAssertNil(gesture.release(isInsideInput: false))
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
        let paths = [10.0, 45.0, 65.0].map { BallisticFlightPath(start: PresentationPoint(x: 48, y: 108), angleDegrees: $0, power: 0.5, groundY: 16) }
        XCTAssertGreaterThan(abs(paths[0].apex.y - paths[1].apex.y), 0.001)
        XCTAssertGreaterThan(abs(paths[1].apex.y - paths[2].apex.y), 0.001)
        XCTAssertGreaterThan(abs(paths[0].groundCrossing.tail.x - paths[1].groundCrossing.tail.x), 0.001)
        XCTAssertGreaterThan(abs(paths[1].groundCrossing.tail.x - paths[2].groundCrossing.tail.x), 0.001)
    }

    func testLaunchAndFlightClampAnglesToTenSixtyFive() {
        let start = PresentationPoint(x: 48, y: 108)
        XCTAssertEqual(FrozenLaunch(angleDegrees: 5, power: 0.5, start: start).angleDegrees, 10, accuracy: 0.0001)
        XCTAssertEqual(FrozenLaunch(angleDegrees: 80, power: 0.5, start: start).angleDegrees, 65, accuracy: 0.0001)
        XCTAssertEqual(BallisticFlightPath(start: start, angleDegrees: 5, power: 0.5, groundY: 16).angleDegrees, 10, accuracy: 0.0001)
        XCTAssertEqual(BallisticFlightPath(start: start, angleDegrees: 80, power: 0.5, groundY: 16).angleDegrees, 65, accuracy: 0.0001)
        let low = BallisticFlightPath(start: start, angleDegrees: 10, power: 0.5, groundY: 16)
        XCTAssertEqual(low.groundCrossing.tip.y, 16, accuracy: 0.001)
        XCTAssertGreaterThan(low.groundCrossing.elapsed, 0)
        XCTAssertLessThan(low.apex.y, BallisticFlightPath(start: start, angleDegrees: 45, power: 0.5, groundY: 16).apex.y)
    }

    func testTargetIsNotLaunchInputAndGroundCrossingIsPhysical() {
        let path = BallisticFlightPath(start: PresentationPoint(x: 48, y: 108), angleDegrees: 45, power: 0.5, groundY: 16)
        XCTAssertEqual(path.gravity, 2400, accuracy: 0.0001)
        XCTAssertEqual(path.v0, 1400, accuracy: 0.0001)
        XCTAssertEqual(path.groundCrossing.tip.y, 16, accuracy: 0.001)
        XCTAssertGreaterThan(path.groundCrossing.elapsed, 0)
    }

    func testActualShaftSegmentCollisionAndGroundMiss() {
        // firstImpact linearizes between its two samples, so query it per frame like the flight timer does.
        func frameSweptImpact(path: BallisticFlightPath, target: PresentationPoint) -> Double? {
            var elapsed = 0.0
            while elapsed < path.groundCrossing.elapsed {
                let next = min(elapsed + 1.0 / 60, path.groundCrossing.elapsed)
                if let hit = SpearCollision.firstImpact(path: path, target: target, fromElapsed: elapsed, toElapsed: next) { return hit }
                elapsed = next
            }
            return nil
        }
        let path = BallisticFlightPath(start: PresentationPoint(x: 48, y: 108), angleDegrees: 45, power: 0.5, groundY: 16)
        XCTAssertNotNil(frameSweptImpact(path: path, target: PresentationPoint(x: 280, y: 270)))
        XCTAssertNil(frameSweptImpact(path: path, target: PresentationPoint(x: 260, y: 700)))
    }

    func testGestureKeepsOutsideDragAndReleasesOnce() {
        var gesture = LocalGesture()
        XCTAssertTrue(beginCentered(&gesture))
        let outside = gesture.move(to: PresentationPoint(x: -100, y: 0), isInsideInput: false)
        XCTAssertNotNil(outside)
        XCTAssertEqual(outside?.angleDegrees ?? 0, 10, accuracy: 0.0001)
        XCTAssertGreaterThan(outside?.power ?? 0, 0)
        XCTAssertEqual(gesture.release(isInsideInput: false), outside)
        XCTAssertNil(gesture.release(isInsideInput: false))
    }

    func testMaxPowerAtScreenEdgeOutsideLocalInput() {
        var gesture = LocalGesture()
        XCTAssertTrue(beginCentered(&gesture))
        let t10 = DragLaunch.tangent(angleDegrees: 10)
        let edgePull = 400 / t10.x
        let almost = gesture.move(to: PresentationPoint(x: 48 - 399, y: 0), isInsideInput: false)
        XCTAssertEqual(almost?.angleDegrees ?? 0, 10, accuracy: 0.0001)
        XCTAssertEqual(almost?.maxPull ?? 0, edgePull, accuracy: 1e-9)
        XCTAssertLessThan(almost?.power ?? 1, 1)
        let full = gesture.move(to: PresentationPoint(x: 48 - 400, y: 0), isInsideInput: false)
        XCTAssertEqual(full?.rawPull ?? 0, edgePull, accuracy: 1e-9)
        XCTAssertEqual(full?.power ?? 0, 1, accuracy: 1e-9)
        XCTAssertEqual(DragLaunch.tensionLength(rawPull: full?.rawPull ?? 0, maxPull: full?.maxPull ?? 0), 160, accuracy: 1e-9)
        XCTAssertEqual(gesture.release(isInsideInput: false), full)
    }

    func testAngleOnlyVerticalMoveKeepsLatchedPowerExactlyWhileAngleChanges() {
        var gesture = LocalGesture()
        XCTAssertTrue(beginCentered(&gesture))
        let latched = gesture.move(to: PresentationPoint(x: 28, y: 48), isInsideInput: true)
        XCTAssertEqual(latched?.angleDegrees ?? 0, 45, accuracy: 0.0001)
        XCTAssertGreaterThan(latched?.power ?? 0, 0)
        XCTAssertEqual(latched?.maxPull ?? 0, maxPull45, accuracy: 1e-9)
        let raised = gesture.move(to: PresentationPoint(x: 28, y: 72), isInsideInput: true)
        XCTAssertEqual(raised?.angleDegrees ?? 0, 55, accuracy: 0.0001)
        XCTAssertEqual(raised?.power, latched?.power)
        XCTAssertEqual(raised?.maxPull, latched?.maxPull)
        let lowered = gesture.move(to: PresentationPoint(x: 28, y: 24), isInsideInput: true)
        XCTAssertEqual(lowered?.angleDegrees ?? 0, 27.5, accuracy: 0.0001)
        XCTAssertEqual(lowered?.power, latched?.power)
        XCTAssertEqual(lowered?.maxPull, latched?.maxPull)
        XCTAssertEqual(gesture.release(isInsideInput: true), lowered)
    }

    func testFurtherPullAlongFrozenReverseTangentRaisesLatchedPower() {
        var gesture = LocalGesture()
        XCTAssertTrue(beginCentered(&gesture))
        let tangent = DragLaunch.tangent(angleDegrees: 45)
        let latched = gesture.move(to: PresentationPoint(x: 28, y: 48), isInsideInput: true)
        XCTAssertGreaterThan(latched?.power ?? 0, 0)
        let pulled = gesture.move(to: PresentationPoint(x: 28 - tangent.x * 40, y: 48 - tangent.y * 40), isInsideInput: true)
        XCTAssertEqual(pulled?.power ?? 0, (latched?.power ?? 0) + 40 / (maxPull45 - 6), accuracy: 0.0001)
        XCTAssertGreaterThan(pulled?.power ?? 0, latched?.power ?? 1)
    }

    func testFrozenAxisFullPullReachesExactMaxAtScreenEdge() {
        var gesture = LocalGesture()
        XCTAssertTrue(beginCentered(&gesture))
        let latched = gesture.move(to: PresentationPoint(x: 28, y: 48), isInsideInput: true)
        XCTAssertGreaterThan(latched?.power ?? 0, 0)
        let halfway = gesture.move(to: PresentationPoint(x: 48 - 150, y: 48), isInsideInput: true)
        XCTAssertEqual(halfway?.rawPull ?? 0, 150 * sqrt(2.0), accuracy: 1e-9)
        XCTAssertEqual(halfway?.power ?? 0, (150 * sqrt(2.0) - 6) / (maxPull45 - 6), accuracy: 0.0001)
        let full = gesture.move(to: PresentationPoint(x: 48 - 300, y: 48), isInsideInput: true)
        XCTAssertEqual(full?.rawPull ?? 0, maxPull45, accuracy: 1e-9)
        XCTAssertEqual(full?.power ?? 0, 1, accuracy: 1e-9)
        XCTAssertEqual(full?.angleDegrees ?? 0, 45, accuracy: 0.0001)
        XCTAssertEqual(DragLaunch.tensionLength(rawPull: full?.rawPull ?? 0, maxPull: full?.maxPull ?? 0), 160, accuracy: 1e-9)
        XCTAssertEqual(gesture.release(isInsideInput: true), full)
    }

    func testVerticalAngleOnlyMovePreservesRawPullMaxPullPowerAndTension() {
        var gesture = LocalGesture()
        XCTAssertTrue(beginCentered(&gesture))
        XCTAssertNotNil(gesture.move(to: PresentationPoint(x: 28, y: 48), isInsideInput: true))
        let pulled = gesture.move(to: PresentationPoint(x: 48 - 150, y: 48), isInsideInput: true)
        XCTAssertEqual(pulled?.rawPull ?? 0, 150 * sqrt(2.0), accuracy: 1e-9)
        XCTAssertEqual(DragLaunch.tensionLength(rawPull: pulled?.rawPull ?? 0, maxPull: pulled?.maxPull ?? 0), 80, accuracy: 1e-9)
        let raised = gesture.move(to: PresentationPoint(x: 48 - 150, y: 72), isInsideInput: true)
        XCTAssertEqual(raised?.angleDegrees ?? 0, 55, accuracy: 0.0001)
        XCTAssertEqual(raised?.rawPull, pulled?.rawPull)
        XCTAssertEqual(raised?.maxPull, pulled?.maxPull)
        XCTAssertEqual(raised?.power, pulled?.power)
        let lowered = gesture.move(to: PresentationPoint(x: 48 - 150, y: 24), isInsideInput: true)
        XCTAssertEqual(lowered?.angleDegrees ?? 0, 27.5, accuracy: 0.0001)
        XCTAssertEqual(lowered?.rawPull, pulled?.rawPull)
        XCTAssertEqual(lowered?.maxPull, pulled?.maxPull)
        XCTAssertEqual(lowered?.power, pulled?.power)
        XCTAssertEqual(DragLaunch.tensionLength(rawPull: lowered?.rawPull ?? 0, maxPull: lowered?.maxPull ?? 0), 80, accuracy: 1e-9)
    }

    func testFurtherFrozenAxisPullGrowsRawPullVisibleTensionAndPower() {
        var gesture = LocalGesture()
        XCTAssertTrue(beginCentered(&gesture))
        XCTAssertNotNil(gesture.move(to: PresentationPoint(x: 28, y: 48), isInsideInput: true))
        let halfway = gesture.move(to: PresentationPoint(x: 48 - 150, y: 48), isInsideInput: true)
        XCTAssertEqual(halfway?.rawPull ?? 0, 150 * sqrt(2.0), accuracy: 1e-9)
        let full = gesture.move(to: PresentationPoint(x: 48 - 300, y: 48), isInsideInput: true)
        XCTAssertEqual(full?.rawPull ?? 0, maxPull45, accuracy: 1e-9)
        XCTAssertEqual(DragLaunch.tensionLength(rawPull: full?.rawPull ?? 0, maxPull: full?.maxPull ?? 0), 160, accuracy: 1e-9)
        XCTAssertEqual(full?.power ?? 0, 1, accuracy: 1e-9)
        XCTAssertGreaterThan(full?.rawPull ?? 0, halfway?.rawPull ?? 1)
        XCTAssertEqual(gesture.release(isInsideInput: true), full)
        XCTAssertNil(gesture.release(isInsideInput: true))
    }

    func testExplicitScreenStartGeometrySeamControlsMaxPull() {
        var near = LocalGesture()
        var far = LocalGesture()
        XCTAssertTrue(near.begin(at: PresentationPoint(x: 48, y: 48), inStartZone: true, screenStart: PresentationPoint(x: 400, y: 150), screenBounds: bounds1600))
        XCTAssertTrue(beginCentered(&far))
        XCTAssertNotNil(near.move(to: PresentationPoint(x: 28, y: 48), isInsideInput: true))
        XCTAssertNotNil(far.move(to: PresentationPoint(x: 28, y: 48), isInsideInput: true))
        let nearFull = near.move(to: PresentationPoint(x: 48 - 150, y: 48), isInsideInput: true)
        let farSame = far.move(to: PresentationPoint(x: 48 - 150, y: 48), isInsideInput: true)
        XCTAssertEqual(nearFull?.maxPull ?? 0, 150 * sqrt(2.0), accuracy: 1e-9)
        XCTAssertEqual(farSame?.maxPull ?? 0, 300 * sqrt(2.0), accuracy: 1e-9)
        XCTAssertEqual(nearFull?.power ?? 0, 1, accuracy: 1e-9)
        XCTAssertEqual(DragLaunch.tensionLength(rawPull: nearFull?.rawPull ?? 0, maxPull: nearFull?.maxPull ?? 0), 160, accuracy: 1e-9)
        XCTAssertLessThan(farSame?.power ?? 1, 1)
    }

    func testFailClosedScreenGeometryYieldsZeroPower() {
        var corner = LocalGesture()
        XCTAssertTrue(corner.begin(at: PresentationPoint(x: 48, y: 48), inStartZone: true, screenStart: PresentationPoint(x: 0, y: 0), screenBounds: bounds1600))
        let cornered = corner.move(to: PresentationPoint(x: 48 - 300, y: 48), isInsideInput: true)
        XCTAssertEqual(cornered?.maxPull ?? -1, 0, accuracy: 1e-9)
        XCTAssertEqual(cornered?.power ?? 1, 0, accuracy: 1e-9)
        XCTAssertEqual(DragLaunch.tensionLength(rawPull: cornered?.rawPull ?? 0, maxPull: cornered?.maxPull ?? 0), 0, accuracy: 1e-9)
        var tiny = LocalGesture()
        XCTAssertTrue(tiny.begin(at: PresentationPoint(x: 48, y: 48), inStartZone: true, screenStart: PresentationPoint(x: 3, y: 3), screenBounds: ScreenBounds(minX: 0, maxX: 8, minY: 0, maxY: 8)))
        let squeezed = tiny.move(to: PresentationPoint(x: 28, y: 48), isInsideInput: true)
        XCTAssertLessThanOrEqual(squeezed?.maxPull ?? 7, 6)
        XCTAssertEqual(squeezed?.power ?? 1, 0, accuracy: 1e-9)
        XCTAssertEqual(DragLaunch.tensionLength(rawPull: squeezed?.rawPull ?? 0, maxPull: squeezed?.maxPull ?? 0), 0, accuracy: 1e-9)
    }

    func testNoDeadZoneCrossingMeansAngleMovesNeverLatchPower() {
        var gesture = LocalGesture()
        XCTAssertTrue(beginCentered(&gesture))
        let up = gesture.move(to: PresentationPoint(x: 48, y: 96), isInsideInput: true)
        XCTAssertEqual(up?.angleDegrees ?? 0, 65, accuracy: 0.0001)
        XCTAssertEqual(up?.power ?? 1, 0, accuracy: 0.0001)
        let down = gesture.move(to: PresentationPoint(x: 48, y: 44), isInsideInput: true)
        XCTAssertEqual(down?.power ?? 1, 0, accuracy: 0.0001)
    }

    func testGestureNextValidDownDiscardsStaleLaunch() {
        var gesture = LocalGesture()
        XCTAssertTrue(beginCentered(&gesture))
        XCTAssertNotNil(gesture.move(to: PresentationPoint(x: -100, y: 0), isInsideInput: false))
        XCTAssertTrue(beginCentered(&gesture))
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
