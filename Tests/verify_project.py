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
assert 'XCTAssertNil(gesture.move(to: PresentationPoint(x: 40, y: 100), isInsideInput: false))' in tests
assert 'width: 180, height: 110' in overlay and overlay.count('GamePanel(frame: .zero, interaction:') == 2
assert 'groundY = Double(bottomY + 16)' in overlay and 'seedY = [64.0, 132.0, 200.0]' in overlay
assert 'DisplayPanel(frame: screen.frame)' in overlay and 'SceneView' in overlay and 'FlightView' in overlay
assert 'ignoresMouseEvents = FlightLayerContract.visibilityOnly.ignoresMouseEvents' in overlay
assert 'canBecomeKey: Bool { false }' in overlay and 'canBecomeMain: Bool { false }' in overlay
assert 'mouseDown' in view and 'mouseDragged' in view and 'mouseUp' in view
assert 'actorStartZone' in view and 'width: 44, height: 44' in view
assert 'bounds.contains' in view and 'drawHeld' in view and 'tension' in view
for expected in ('gravity = 2400.0', 'shaftLength = 42.0', 'v0 = 900 + 1000 * self.power', 'cos(radians)', 'sin(radians)', 'reverse <= 6', '(reverse - 6) / 66', 'ceil((end.tip - start.tip).length / 4)', 'radius = 16.0', 'firstGroundCrossing', 'LocalGesture'):
    assert expected in core
for forbidden in ('targetX', 'canonicalHeight', 'canonicalAim', 'launchCoefficient', 'coefficient(for:', 'normalizedLanding', 'PresentationFlightPath', 'CGEventTap', 'CGEventPost', 'NSEvent.addGlobalMonitorForEvents', 'NSEvent.addLocalMonitorForEvents', 'ScreenCaptureKit', 'AXUIElement', 'URLSession', 'NSPasteboard'):
    assert forbidden not in all_source
for expected in ('testDragMapsExactAngleAndReverseTangentPower', 'testPowerProducesStrictlyIncreasingGroundDistanceAtSameAngle', 'testAnglesHaveDifferentApexAndLandingAtSamePower', 'testTargetIsNotLaunchInputAndGroundCrossingIsPhysical', 'testActualShaftSegmentCollisionAndGroundMiss', 'testGestureCancelsOutsideAndStaleDownResets'):
    assert expected in tests
assert 'RunLoop.main.add(timer, forMode: .common)' in overlay and 'ProcessInfo.processInfo.systemUptime' in overlay
print('PASS: TTALGAK v3 local drag, true ballistic physics, non-clipping display scene, and safety guardrails')
