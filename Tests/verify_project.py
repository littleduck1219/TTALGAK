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
readme = (root / "README.md").read_text()
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

# Fixed 160pt physical pull: 6pt dead zone and exact 154pt live denominator.
assert '320' not in core and '/ 314' not in core and '/ 66' not in core
assert 'deadZone = 6.0' in core
assert 'fullPowerPull = 160.0' in core
assert '(rawPull - deadZone) / 154' in core
assert 'testFixedOneSixtyPullPowerAndSubstantialTension' in tests
assert 'testFixedFullPowerNeedsOneSixtyPullOutsideLocalInput' in tests
assert 'testGestureNeedsNoScreenEdgeData' in tests

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

# Power latch: first 6pt dead-zone crossing freezes the tangent; afterwards power is measured only
# along that frozen axis (-dx / tangent.x). Per-current-angle re-projection must fail.
assert 'latchedTangent' in core
assert 'latchedTangent.map { max(0, -displacement.x / $0.x) }' in core
assert 'DragLaunch.power(rawPull: rawPull)' in core
assert 'latchedTangent = tangent' in core
assert 'latchedTangent = nil' in core
assert 'DragLaunch.power(reverse:' not in core and 'power(displacement:' not in core
assert 'testAngleOnlyVerticalMoveKeepsLatchedPowerExactlyWhileAngleChanges' in tests
assert 'testFurtherPullAlongFrozenReverseTangentRaisesLatchedPower' in tests
assert 'testFrozenAxisFullPullReachesExactFixedMax' in tests
assert 'testNoDeadZoneCrossingMeansAngleMovesNeverLatchPower' in tests
assert 'XCTAssertEqual(raised?.power, latched?.power)' in tests
assert 'XCTAssertEqual(lowered?.power, latched?.power)' in tests

# Visible pull uses the fixed physical pull and remains a full 160pt at full raw pull.
assert 'public let rawPull: Double' in core and 'self.rawPull = max(rawPull, 0)' in core
assert 'rawPull / 160 * 160' in core
assert 'rawPull: rawPull, start: start' in core
assert 'DragLaunch.tensionLength(rawPull: launch.rawPull)' in view
assert '6 + 24 * launch.power' not in view
assert 'guard launch.power > 0' not in view
assert 'drawHeld(from: NSPoint(x: feet.x + 18, y: feet.y + 42), launch: aiming)' in view
assert 'testVerticalAngleOnlyMovePreservesRawPullPowerAndTension' in tests
assert 'testFurtherFrozenAxisPullGrowsRawPullVisibleTensionAndPower' in tests
assert 'tensionLength(rawPull: 80), 80' in tests
assert 'tensionLength(rawPull: 160), 160' in tests

# Rejected screen-bound, capture-corridor, and screen conversion features must stay absent.
for forbidden in ('ScreenBounds', 'PullCorridor', 'CorridorTile', 'GestureCorridor', 'CorridorPanel', 'CorridorView', 'dynamic max pull', 'move(toScreenPoint'):
    assert forbidden not in all_source
    assert forbidden not in tests
    assert forbidden not in readme
assert 'case down(PresentationPoint)' in view
assert 'convertToScreen' not in view
assert 'mouseLocation' not in all_source
assert overlay.count('game.launch()') == 1 and 'guard game.phase == .aiming else { return }' in overlay
assert 'DisplayPanel(frame: screen.frame)' in overlay
assert 'NSScreen.main?.frame' not in view

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
for expected in ('testDragMapsExactAngleAndReverseTangentPower', 'testPowerProducesStrictlyIncreasingGroundDistanceAtSameAngle', 'testAnglesHaveDifferentApexAndLandingAtSamePower', 'testTargetIsNotLaunchInputAndGroundCrossingIsPhysical', 'testActualShaftSegmentCollisionAndGroundMiss', 'testGestureKeepsOutsideDragAndReleasesOnce', 'testGestureNextValidDownDiscardsStaleLaunch', 'testFixedFullPowerNeedsOneSixtyPullOutsideLocalInput', 'testGroundInventoryKeepsMissesCapsAtFiftyAndEvictsOldest', 'testHitSpearsAreNeverAddedToGroundInventory', 'testTargetSpawnsWithinRightInsetRangeAndDeterministicSeedHeights', 'testTargetStableOnMissAndChangesOnlyOnHit'):
    assert expected in tests
assert 'RunLoop.main.add(timer, forMode: .common)' in overlay and 'ProcessInfo.processInfo.systemUptime' in overlay
print('PASS: TTALGAK v3 local drag (fixed 160pt full pull, asymmetric angle 10...65), ground-miss FIFO 50, hit-only target lifecycle 280...520, true ballistic physics, non-clipping display scene, and safety guardrails')
