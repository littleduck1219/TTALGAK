#!/usr/bin/env python3
"""Linux-safe v3 static guardrail; macOS/AppKit runtime remains Mac QA only."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
package = (root / "Package.swift").read_text()
core = (root / "Sources/SpearGameCore/SpearGameState.swift").read_text()
overlay = (root / "Sources/TTALGAK/OverlayController.swift").read_text()
view = (root / "Sources/TTALGAK/SpearThrowView.swift").read_text()
tests = (root / "Tests/SpearGameStateTests.swift").read_text()
all_source = "\n".join(path.read_text() for path in (root / "Sources").rglob("*.swift"))
v3_runtime_source = "\n".join(path.read_text() for path in (root / "Sources/TTALGAK").glob("*.swift") if path.name != "StickmanMotionAssets.swift")

assert 'exclude: ["verify_project.py"]' in package
assert 'exclude: ["Resources", "StickmanMotionAssets.swift"]' in package and 'resources:' not in package
assert 'StickmanMotionAssets' not in v3_runtime_source and 'MotionAssetBand' not in v3_runtime_source and 'MotionAssetSnapshot' not in v3_runtime_source
assert 'testGestureKeepsOutsideDragAndReleasesOnce' in tests
assert 'XCTAssertNotNil(outside)' in tests
assert 'XCTAssertEqual(gesture.release(isInsideInput: false), outside)' in tests
assert 'XCTAssertNil(gesture.release(isInsideInput: false))' in tests
assert 'testGestureNextValidDownDiscardsStaleLaunch' in tests
assert 'width: 180, height: 110' in overlay and overlay.count('GamePanel(frame: .zero, interaction:') == 2
assert 'leftInset = 96.0' in overlay and 'x: frame.minX + leftInset' in overlay
assert 'PresentationPoint(x: Double(left.frame.minX + 66), y: groundY + 42)' in overlay
assert 'groundY = Double(bottomY + 16)' in overlay

# Dynamic screen-edge max pull: any fixed full-pull threshold (320pt, denominators 314/154/66) is
# forbidden in core. maxPull is the slab-exit ray distance from the screen-converted press point along
# the frozen reverse tangent to the FIRST primary-screen boundary; power = clamp((r-6)/(maxPull-6),0,1)
# with a fail-closed maxPull > 6 validation (never remapped to any fixed constant).
assert '320' not in core and '/ 314' not in core and '/ 154' not in core and '/ 66' not in core
assert 'struct ScreenBounds' in core
assert 'deadZone = 6.0' in core
assert 'func maxPull(fromScreenStart start: PresentationPoint, reverse: PresentationPoint, bounds: ScreenBounds)' in core
assert 'reverse.x < 0 ? bounds.minX : bounds.maxX' in core
assert 'reverse.y < 0 ? bounds.minY : bounds.maxY' in core
assert 'guard let first = exits.min(), first > 0 else { return 0 }' in core
assert '(rawPull - deadZone) / (maxPull - deadZone)' in core
assert core.count('guard maxPull > deadZone, rawPull > deadZone else { return 0 }') == 2
assert 'testReverseRayHitsFirstScreenBoundary' in tests
assert 'testScreenEdgePowerAndTensionReachExactMaxAtBoundary' in tests
assert 'testMaxPowerAtScreenEdgeOutsideLocalInput' in tests
assert 'testFailClosedScreenGeometryYieldsZeroPower' in tests
assert '300 * sqrt(2.0)' in tests and '400 / t10.x' in tests

# Asymmetric angle range 10...65 around center 45: dy=-48 -> 10 (slope 35/48 down), dy=+48 -> 65 (slope 20/48 up).
# The old symmetric mapping and any 25-degree minimum clamp must fail.
assert '45 + (dy < 0 ? 35 : 20) * dy / 48, 10), 65' in core
assert '45 + 20 * dy / 48, 25' not in core
assert ', 25), 65)' not in core
assert core.count('min(max(angleDegrees, 10), 65)') == 2
assert 'forVerticalDrag: -48), 10' in tests and 'forVerticalDrag: 48), 65' in tests
assert 'forVerticalDrag: -24), 27.5' in tests and 'forVerticalDrag: 24), 55' in tests
assert 'forVerticalDrag: -96), 10' in tests and 'forVerticalDrag: 96), 65' in tests
assert '[10.0, 45.0, 65.0]' in tests and '[25.0, 45.0, 65.0]' not in tests
assert 'testLaunchAndFlightClampAnglesToTenSixtyFive' in tests
assert 'tangent(angleDegrees: 25)' not in tests

# Power latch: first 6pt dead-zone crossing freezes the tangent AND the screen-edge maxPull together;
# afterwards power is measured only along that frozen axis (-dx / tangent.x) against the frozen maxPull.
# Per-current-angle re-projection or per-move maxPull recomputation must fail.
assert 'latchedTangent' in core
assert 'latchedTangent.map { max(0, -displacement.x / $0.x) }' in core
assert 'DragLaunch.power(rawPull: rawPull, maxPull: frozenMaxPull)' in core
assert 'latchedTangent = tangent' in core
assert 'frozenMaxPull = DragLaunch.maxPull(fromScreenStart: screenStart, reverse: tangent * -1, bounds: screenBounds)' in core
assert core.count('frozenMaxPull = DragLaunch.maxPull(') == 1
assert 'latchedTangent = nil' in core
assert 'DragLaunch.power(reverse:' not in core and 'power(displacement:' not in core
assert 'testAngleOnlyVerticalMoveKeepsLatchedPowerExactlyWhileAngleChanges' in tests
assert 'testFurtherPullAlongFrozenReverseTangentRaisesLatchedPower' in tests
assert 'testFrozenAxisFullPullReachesExactMaxAtScreenEdge' in tests
assert 'testNoDeadZoneCrossingMeansAngleMovesNeverLatchPower' in tests
assert 'XCTAssertEqual(raised?.power, latched?.power)' in tests
assert 'XCTAssertEqual(lowered?.power, latched?.power)' in tests

# Visible pull: FrozenLaunch retains both the raw frozen-axis pull and the frozen screen-edge maxPull,
# and the renderer maps tension = clamp(rawPull/maxPull*160, 0, 160), hidden inside the 6pt dead zone,
# so exactly the first display boundary shows the full 160pt line. Fixed-320 tension mapping must fail.
assert 'public let rawPull: Double' in core and 'public let maxPull: Double' in core
assert 'self.rawPull = max(rawPull, 0)' in core and 'self.maxPull = max(maxPull, 0)' in core
assert 'rawPull / maxPull * 160' in core
assert 'rawPull: rawPull, maxPull: frozenMaxPull' in core
assert 'DragLaunch.tensionLength(rawPull: launch.rawPull, maxPull: launch.maxPull)' in view
assert '6 + 24 * launch.power' not in view
assert 'guard launch.power > 0' not in view
assert 'drawHeld(from: NSPoint(x: feet.x + 18, y: feet.y + 42), launch: aiming)' in view
assert 'testVerticalAngleOnlyMovePreservesRawPullMaxPullPowerAndTension' in tests
assert 'testFurtherFrozenAxisPullGrowsRawPullVisibleTensionAndPower' in tests
assert 'tensionLength(rawPull: 200, maxPull: 400), 80' in tests
assert 'tensionLength(rawPull: 400, maxPull: 400), 160' in tests

# Screen-start geometry seam: the local mouseDown point converts only through the local
# NSView -> NSWindow -> convertToScreen chain, screen bounds come from NSScreen.main.frame at gesture
# begin, and both are injected into the pure core (no global pointer/location query anywhere).
assert 'case down(PresentationPoint, screen: PresentationPoint)' in view
assert 'convert(NSPoint(x: CGFloat(p.x), y: CGFloat(p.y)), to: nil)' in view
assert 'window.convertToScreen' in view
assert 'screenStart: PresentationPoint, screenBounds: ScreenBounds' in core
assert 'ScreenBounds(minX: Double(frame.minX), maxX: Double(frame.maxX), minY: Double(frame.minY), maxY: Double(frame.maxY))' in overlay
assert 'screenStart: screenPoint, screenBounds: bounds' in overlay
assert 'mouseLocation' not in all_source
assert 'testExplicitScreenStartGeometrySeamControlsMaxPull' in tests

# Accepted recovery is a temporary union of documented 32pt bounded tiles along only the frozen ray,
# never a fullscreen input window. It opens after latch and is torn down on every terminal lifecycle.
assert 'struct PullCorridor' in core and 'static let tileSide = 32.0' in core and 'static let documentedWidth = 46.0' in core
assert 'public private(set) var corridor: PullCorridor?' in core
assert 'corridor = PullCorridor(start: screenStart, reverse: tangent * -1, maxPull: frozenMaxPull, bounds: screenBounds)' in core
assert 'func move(toScreenPoint point: PresentationPoint' in core
assert 'final class GestureCorridor' in overlay and 'final class CorridorPanel' in overlay
assert 'geometry.tiles.map' in overlay and 'only overlapping 32pt tiles' in overlay
assert 'openCorridor(' in overlay and 'closeCorridor()' in overlay
assert overlay.count('closeCorridor()') >= 7
assert overlay.count('game.launch()') == 1 and 'guard game.phase == .aiming else { return }' in overlay
assert 'DisplayPanel(frame: screen.frame)' in overlay
assert 'CorridorPanel(frame: screen.frame)' not in overlay
assert 'GestureCorridor(frame: screen.frame)' not in overlay
assert 'NSScreen.main?.frame' not in view
assert 'testBoundedCorridorTilesFollowFrozenRayToFirstBoundary' in tests
assert 'testCorridorOpensOnlyAtLatchAndScreenMovesPreserveFrozenGeometry' in tests
assert 'testGestureCancellationReleasesCorridorAndLaunch' in tests

# In-memory ground-miss FIFO (50, oldest evicted); hits never retained; renderer draws stored spears, no ground line.
assert 'GroundSpearInventory' in core and 'capacity = 50' in core and 'guard !hit else { return }' in core
assert 'groundInventory.record(hit: hit' in overlay
assert 'scene.groundSpears = groundInventory.spears' in overlay
assert 'var groundSpears: [GroundSpearRecord]' in view and 'for spear in groundSpears' in view

# Target lifecycle: right-inset 280...520 spawn with deterministic injectable provider; spawn only at show and on hit.
assert 'minInset = 280.0' in core and 'maxInset = 520.0' in core and 'edgeMargin = 22.0' in core
assert 'seedHeights = [64.0, 132.0, 200.0]' in core
assert 'TargetLifecycle' in core and 'targetLifecycle.spawn' in overlay
assert 'if hit { self.spawnTarget() }' in overlay and overlay.count('spawnTarget()') == 3
# Old canonical right-edge target and target-reset-on-miss patterns must fail.
assert 'minX + 132' not in overlay and 'round % 3' not in overlay and 'seedY' not in overlay
assert 'self.reposition()' not in overlay
assert 'DisplayPanel(frame: screen.frame)' in overlay and 'SceneView' in overlay
# Scene owns actor, target, result, and the one ephemeral flying spear; flight must not replace it.
assert 'private var flightPanel' not in overlay
assert 'flightPanel?.orderOut' not in overlay
assert overlay.count('scenePanel?.orderOut(nil)') == 1
assert 'scene.flightPath = path' in overlay and 'scene.flightElapsed = 0' in overlay
assert 'scene.flightElapsed = flightElapsed' in overlay
assert 'flightPath = nil' in overlay
assert 'var flightPath: BallisticFlightPath?' in view
assert 'var flightElapsed = 0.0' in view
assert 'if let flightPath { drawSpear(path: flightPath, elapsed: flightElapsed) }' in view
assert 'final class FlightView' not in view
assert 'override var isOpaque: Bool { false }' in view
assert 'actorStartZone: NSRect { NSRect(x: 44, y: 36, width: 44, height: 44) }' in view
assert 'let ground = NSBezierPath()' not in view and 'ground.stroke()' not in view
assert 'ignoresMouseEvents = FlightLayerContract.visibilityOnly.ignoresMouseEvents' in overlay
assert 'canBecomeKey: Bool { false }' in overlay and 'canBecomeMain: Bool { false }' in overlay
assert 'mouseDown' in view and 'mouseDragged' in view and 'mouseUp' in view
assert 'actorStartZone' in view and 'width: 44, height: 44' in view
assert 'bounds.contains' in view and 'drawHeld' in view and 'tension' in view
assert 'local drag/up containment is deliberately ignored' in core
assert re.search(r'func move\(to point: PresentationPoint, isInsideInput _: Bool', core)
assert re.search(r'func release\(isInsideInput _: Bool\)', core)
assert not re.search(r'guard\s+let down[^\n]*\bisInsideInput\b', core)
assert not re.search(r'return\s+isInsideInput\b', core)
for expected in ('gravity = 2400.0', 'shaftLength = 42.0', 'v0 = 900 + 1000 * self.power', 'cos(radians)', 'sin(radians)', 'deadZone = 6.0', 'ceil((end.tip - start.tip).length / 4)', 'radius = 16.0', 'firstGroundCrossing', 'LocalGesture'):
    assert expected in core
for forbidden in ('targetX', 'canonicalHeight', 'canonicalAim', 'launchCoefficient', 'coefficient(for:', 'normalizedLanding', 'PresentationFlightPath', 'CGEventTap', 'CGEventPost', 'CGEventSource', 'CGWarpMouseCursorPosition', 'CGAssociateMouseAndMouseCursorPosition', 'NSEvent.mouseLocation', 'mouseLocationOutsideOfEventStream', 'NSEvent.addGlobalMonitorForEvents', 'NSEvent.addLocalMonitorForEvents', 'ScreenCaptureKit', 'AXUIElement', 'AXIsProcessTrusted', 'URLSession', 'NSPasteboard', 'UserDefaults', 'FileManager', 'NSKeyedArchiver', 'CGWindowList', 'NSWindowSharing'):
    assert forbidden not in all_source
for expected in ('testDragMapsExactAngleAndReverseTangentPower', 'testPowerProducesStrictlyIncreasingGroundDistanceAtSameAngle', 'testAnglesHaveDifferentApexAndLandingAtSamePower', 'testTargetIsNotLaunchInputAndGroundCrossingIsPhysical', 'testActualShaftSegmentCollisionAndGroundMiss', 'testGestureKeepsOutsideDragAndReleasesOnce', 'testGestureNextValidDownDiscardsStaleLaunch', 'testMaxPowerAtScreenEdgeOutsideLocalInput', 'testGroundInventoryKeepsMissesCapsAtFiftyAndEvictsOldest', 'testHitSpearsAreNeverAddedToGroundInventory', 'testTargetSpawnsWithinRightInsetRangeAndDeterministicSeedHeights', 'testTargetStableOnMissAndChangesOnlyOnHit'):
    assert expected in tests
assert 'RunLoop.main.add(timer, forMode: .common)' in overlay and 'ProcessInfo.processInfo.systemUptime' in overlay
print('PASS: TTALGAK v3 local drag (dynamic screen-edge max pull, asymmetric angle 10...65), ground-miss FIFO 50, hit-only target lifecycle 280...520, true ballistic physics, non-clipping display scene, and safety guardrails')
