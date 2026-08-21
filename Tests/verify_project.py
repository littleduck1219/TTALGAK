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

# 160pt reverse pull: dead zone 6pt, power = clamp((r-6)/154, 0, 1); the old 72pt maximum (denominator 66) must fail.
assert '(reverse - 6) / 154' in core
assert '(reverse - 6) / 66' not in core
assert '160 / sqrt(2)' in tests and '(72.0 - 6) / 154' in tests
assert 'testMaxPowerNeedsFullOneSixtyPullOutsideLocalInput' in tests

# Power latch: first 6pt dead-zone crossing freezes the tangent; afterwards power is measured only along
# that frozen axis (-dx / tangent.x). Per-current-angle re-projection of power on every move must fail.
assert 'latchedTangent' in core
assert 'DragLaunch.power(reverse: -displacement.x / $0.x)' in core
assert 'latchedTangent = DragLaunch.tangent(angleDegrees: angle)' in core
assert 'latchedTangent = nil' in core
assert 'power: DragLaunch.power(displacement: displacement, angleDegrees: angle)' not in core
assert 'testAngleOnlyVerticalMoveKeepsLatchedPowerExactlyWhileAngleChanges' in tests
assert 'testFurtherPullAlongFrozenReverseTangentRaisesLatchedPower' in tests
assert 'testFrozenAxisFullPullReachesExactMaxAtOneSixty' in tests
assert 'testNoDeadZoneCrossingMeansAngleMovesNeverLatchPower' in tests
assert 'XCTAssertEqual(raised?.power, latched?.power)' in tests
assert 'XCTAssertEqual(lowered?.power, latched?.power)' in tests

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
for expected in ('gravity = 2400.0', 'shaftLength = 42.0', 'v0 = 900 + 1000 * self.power', 'cos(radians)', 'sin(radians)', 'reverse <= 6', '(reverse - 6) / 154', 'ceil((end.tip - start.tip).length / 4)', 'radius = 16.0', 'firstGroundCrossing', 'LocalGesture'):
    assert expected in core
for forbidden in ('targetX', 'canonicalHeight', 'canonicalAim', 'launchCoefficient', 'coefficient(for:', 'normalizedLanding', 'PresentationFlightPath', 'CGEventTap', 'CGEventPost', 'CGEventSource', 'CGWarpMouseCursorPosition', 'CGAssociateMouseAndMouseCursorPosition', 'NSEvent.mouseLocation', 'NSEvent.addGlobalMonitorForEvents', 'NSEvent.addLocalMonitorForEvents', 'ScreenCaptureKit', 'AXUIElement', 'AXIsProcessTrusted', 'URLSession', 'NSPasteboard', 'UserDefaults', 'FileManager', 'NSKeyedArchiver'):
    assert forbidden not in all_source
for expected in ('testDragMapsExactAngleAndReverseTangentPower', 'testPowerProducesStrictlyIncreasingGroundDistanceAtSameAngle', 'testAnglesHaveDifferentApexAndLandingAtSamePower', 'testTargetIsNotLaunchInputAndGroundCrossingIsPhysical', 'testActualShaftSegmentCollisionAndGroundMiss', 'testGestureKeepsOutsideDragAndReleasesOnce', 'testGestureNextValidDownDiscardsStaleLaunch', 'testMaxPowerNeedsFullOneSixtyPullOutsideLocalInput', 'testGroundInventoryKeepsMissesCapsAtFiftyAndEvictsOldest', 'testHitSpearsAreNeverAddedToGroundInventory', 'testTargetSpawnsWithinRightInsetRangeAndDeterministicSeedHeights', 'testTargetStableOnMissAndChangesOnlyOnHit'):
    assert expected in tests
assert 'RunLoop.main.add(timer, forMode: .common)' in overlay and 'ProcessInfo.processInfo.systemUptime' in overlay
print('PASS: TTALGAK v3 local drag (160pt pull), ground-miss FIFO 50, hit-only target lifecycle 280...520, true ballistic physics, non-clipping display scene, and safety guardrails')
