#!/usr/bin/env python3
"""Linux-safe static guardrail; macOS/AppKit runtime remains Mac QA only."""
from pathlib import Path
import json

root = Path(__file__).resolve().parents[1]
resources = root / "Sources" / "TTALGAK" / "Resources" / "StickmanMotion"
manifest_path = resources / "asset-manifest.json"
assert manifest_path.exists(), "RED: tracked stickman manifest is required"
manifest = json.loads(manifest_path.read_text())
assert manifest["artboard"]["logicalUnits"] == {"width": 180, "height": 110}
assert manifest["releaseSweepSequences"]["durationMs"] == 160
for band, degree in (("low25", 25), ("mid45", 45), ("high65", 65)):
    sequence = manifest["releaseSweepSequences"][band]["frameOrder"]
    assert len(sequence) == 4 and sequence[0].startswith("release-entry-") and sequence[-1].endswith("-160.svg")
    for frame in sequence:
        assert (resources / "source" / frame).exists(), f"missing tracked SVG {frame}"
        assert (resources / "runtime" / (Path(frame).stem + ".png")).exists(), f"missing runtime PNG {frame}"
    final = manifest["releaseSweepSequences"][band]["contact"]["final"]
    assert final["hand"] == final["tail"] == final["ballisticP0"]
    assert degree in (25, 45, 65)

package = (root / "Package.swift").read_text()
overlay = (root / "Sources/TTALGAK/OverlayController.swift").read_text()
view = (root / "Sources/TTALGAK/SpearThrowView.swift").read_text()
core = (root / "Sources/SpearGameCore/SpearGameState.swift").read_text()
app = (root / "Sources/TTALGAK/TTALGAKApp.swift").read_text()
readme = (root / "README.md").read_text()
tests = (root / "Tests/SpearGameStateTests.swift").read_text()
all_source = "\n".join(path.read_text() for path in (root / "Sources").rglob("*.swift"))

assert '.macOS(.v13)' in package and '.target(name: "SpearGameCore")' in package
assert '.copy("Resources/StickmanMotion")' in package
assert 'NSStatusBar.system.statusItem' in app
assert 'width: 180, height: 110' in overlay and overlay.count('GamePanel(frame: .zero, interaction:') == 2
assert 'frame.minY + min(max(frame.height * 0.08, 72), 120)' in overlay
assert '.borderless, .nonactivatingPanel' in overlay and 'ignoresMouseEvents = contract.ignoresMouseEvents' in overlay
assert 'BallisticFlightPath' in core and 'SpearCollision' in core and 'BallisticTarget' in core
for expected in ('gravity = 2400.0', 'h25 = -0.022', 'h45 = 0.0', 'h65 = 0.022', 'visualDuration = 0.820', 'shaftLength = 42.0', 'q = min(max(elapsed / Self.visualDuration, 0), 1)', 'vy - Self.gravity * tau', 'ceil((end.tip - start.tip).length / 4)', 'radius = 16.0', 'resolveFlight(hit: Bool)', 'hand(atReleaseProgress', 'finalReleaseHand'):
    assert expected in core
for forbidden in ('PresentationFlightPath', 'startControl', 'endControl', 'normalizedLanding', 'hitTolerance', 'standardEaseInOut', 'P3', 'quadratic', 'smoothstep'):
    assert forbidden not in all_source
assert 'path.sample(elapsed: elapsed)' in view and 'var targetPoint' in view and 'var finalTip' in view
assert 'NSColor.black' in view and 'let origin = NSPoint(x: 48, y: 33)' in view
assert 'lineWidth = 3' in view and 'lineWidth = 3.5' in view
assert 'showsFlightTranslation: false' in core and 'staticResultDuration: 0.5' in core
for expected in ('testCanonicalTargetSetupMatchesBallisticTailAtImpact', 'testBallisticLaunchApexAndDescentUseVelocityOnly', 'testCollisionSamplesShaftWithFourPointMaximumSubsteps', 'testCollisionIsTheOnlyOutcomeAuthority', 'testReleaseHandMovesContinuouslyWithoutBodyCrossAndFlightStartsAtFinalHand', 'testDiscreteBandFreezesAssetTangentAndFinalP0ForBallistics', 'testReleaseSequenceUsesDiscreteAssetFramesAtExactOffsets', 'testFlightClockUsesFirstTickAsBaselineThenMonotonicActualDeltaWithClamp', 'testFlightPanelCoordinatesConvertGlobalScreenPointToContentLocal', 'testFallbackSnapshotStaysCodeDrawnAndNeverBlank'):
    assert expected in tests
assert 'struct FlightClock' in core and 'maximumDelta' in core and 'enum FlightPanelCoordinates' in core
assert 'RunLoop.main.add(timer, forMode: .common)' in overlay and 'ProcessInfo.processInfo.systemUptime' in overlay
assert 'Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0' not in overlay and 'let step = 1.0 / 60.0' not in overlay
assert 'FlightPanelCoordinates.local(sample.tail, screenOrigin: screenOrigin)' in view
for expected in ('enum MotionAssetBand', 'struct MotionAssetSnapshot', 'forRawAim', 'releaseFrameOffsetsMs', 'init(start: PresentationPoint, targetX: Double, snapshot: MotionAssetSnapshot)', 'CAKeyframeAnimation(keyPath: "contents")', 'entry → 053 → 107 → 160', 'StickmanMotionAssets', 'usesAssetFrame', 'BallisticFlightPath(start: snapshot.flightStart, targetX: targetCenter.x, snapshot: snapshot)', 'hideFlight()'):
    assert expected in all_source
assert 'SpearPresentationGeometry(pose: .release, aimDegrees: left.aimDegrees)' not in overlay
for forbidden in ('ScreenCaptureKit', 'CGWindowList', 'AXUIElement', 'CGEventTap', 'CGEventPost', 'URLSession', 'NSPasteboard', 'NSEvent.addGlobalMonitorForEvents', 'NSEvent.addLocalMonitorForEvents', 'CGRequestScreenCaptureAccess', 'CGDisplayStream', 'CGWindowImage'):
    assert forbidden not in all_source
assert 'ballistic' in readme.lower() and 'Linux static validation' in readme
print('PASS: TTALGAK ballistic physics, collision truth, continuity, and safety static guardrails')
