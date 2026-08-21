#!/usr/bin/env python3
"""Linux-safe static guardrail; macOS/AppKit runtime remains Mac QA only."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
package = (root / "Package.swift").read_text()
overlay = (root / "Sources/TTALGAK/OverlayController.swift").read_text()
view = (root / "Sources/TTALGAK/SpearThrowView.swift").read_text()
core = (root / "Sources/SpearGameCore/SpearGameState.swift").read_text()
app = (root / "Sources/TTALGAK/TTALGAKApp.swift").read_text()
readme = (root / "README.md").read_text()
tests = (root / "Tests/SpearGameStateTests.swift").read_text()
all_source = "\n".join(path.read_text() for path in (root / "Sources").rglob("*.swift"))

assert '.macOS(.v13)' in package
assert '.target(name: "SpearGameCore")' in package
assert '.testTarget(name: "SpearGameCoreTests"' in package
assert 'path: "Tests"' in package
assert 'NSStatusBar.system.statusItem' in app
assert 'width: 180, height: 110' in overlay
assert overlay.count('GamePanel(frame: .zero, interaction:') == 2
assert 'let screen = NSScreen.main' in overlay
assert 'let bottomSafeInset = min(max(frame.height * 0.08, 72), 120)' in overlay
assert 'let bottomY = frame.minY + bottomSafeInset' in overlay
assert 'x: frame.minX, y: bottomY' in overlay
assert 'x: frame.maxX - boxSize.width, y: bottomY' in overlay
assert '.borderless, .nonactivatingPanel' in overlay
assert overlay.count('override var canBecomeKey: Bool { false }') >= 2
assert overlay.count('override var canBecomeMain: Bool { false }') >= 2
assert 'FlightPanel' in overlay and 'FlightView' in overlay
assert 'ignoresMouseEvents = contract.ignoresMouseEvents' in overlay
assert 'orderOut(nil)' in overlay and 'flightPanel = nil' in overlay
assert 'convertToScreen' in overlay
assert 'PresentationPolicy' in core and 'PresentationLifecycle' in core
assert 'SpearPresentationGeometry' in core
assert 'FlightLayerContract' in core
assert 'AnchorInteraction' in overlay
assert 'interaction: .input' in overlay and 'interaction: .displayOnly' in overlay
assert 'ignoresMouseEvents = interaction.ignoresMouseEvents' in overlay
assert 'let geometry = left.geometry' in overlay
assert 'render()\n            startFlight()' in overlay
assert 'origin: geometry.flightStart' in overlay
assert 'flight.aimDegrees = geometry.aimDegrees' in overlay
assert 'var geometry: SpearPresentationGeometry' in view
assert 'geometry.heldSpearOrigin' in view and 'geometry.heldSpearEnd' in view
assert 'FlightLayerContract.visibilityOnly' in overlay
assert 'appearance = NSAppearance(named: .aqua)' in overlay
assert 'FlightLayerContract.visibilityOnly.removesAtImpact' in overlay
assert 'aimingCycle: 0.6' in core and 'launchDuration: 0.16' in core
assert 'flightDuration: 0.82' in core and 'impactDuration: 0.14' in core
assert 'resultHoldDuration: 0.36' in core and 'resetDuration: 0.22' in core
assert 'releaseToImpact' in core and 'releaseToReady' in core
assert 'PresentationFlightPath' in core
assert 'precondition(end.x > start.x)' in core
assert 'min(max(0.12 * dx, 80), 160)' in core
assert 'min(max(0.30 * dx, 180), 360)' in core
assert 'startControl = PresentationPoint(x: start.x + startControlDistance * cos(theta)' in core
assert 'endControl = PresentationPoint(x: end.x - endControlDistance * cos(35 * .pi / 180)' in core
assert 'u * u * u * start.x + 3 * u * u * t * startControl.x + 3 * u * t * t * endControl.x + t * t * t * end.x' in core
assert '3 * u * u * (startControl.x - start.x)' in core
assert 'quadratic' not in core.lower()
assert 'public let height: Double' not in core and '0.14 * dx' not in core and 'midpoint' not in core
assert 'aimingCycle: 0.3' in core and 'showsFlightTranslation: false' in core
assert 'staticResultDuration: 0.5' in core
assert 'NSColor.black' in view
assert 'NSColor(calibratedRed:' not in view and 'NSColor.system' not in view
assert 'private let ink = NSColor.black' in view
assert 'let origin = NSPoint(x: 48, y: 33)' in view
assert 'NSPoint(x: 132, y:' in view
assert 'lineWidth = 3' in view and 'lineWidth = 3.5' in view
assert 'sin(t * .pi)' not in view and 'PresentationFlightPath' in view
assert 'aimDegrees' in view and 'tail = NSPoint(x: CGFloat(point.x), y: CGFloat(point.y))' in view
assert 'tip = NSPoint(x: tail.x + cos(angle) * length, y: tail.y + sin(angle) * length)' in view
assert 'normalizedLanding' in core and 'hitTolerance' in core
assert 'guard phase == .aiming else { return }' in core
assert 'guard phase == .flying, let landingHeight else { return }' in core
for expected in ('testV2StandardPresentationPolicyUsesExactRepresentativeTiming', 'testV2ReducedMotionHasOnlyDiscreteAimAndStaticResult', 'testCubicFlightPathStartsAtHeldTailWithExactTangentAtVisibleAimBoundsAndMidpoint', 'testCubicFlightPathEndsAtExactTargetOrMissEndpointWithDescendingApproach', 'testCubicFlightPathUsesExactControlDistanceClamps', 'testPresentationLifecycleUsesReleaseFlyingCueThenReady', 'testReducedMotionLifecycleResolvesImmediatelyToStaticCue', 'testPresentationGeometryClampsCurrentAimToTheVisible25To65Sweep', 'testReleaseGeometrySharesRenderedHandHeldSpearOriginAndFlightStart', 'testVisibilityOnlyFlightContractAndDisplayOnlyAnchorAreExplicit'):
    assert expected in tests
for removed in ('roundedRect', 'borderColor', '날아가는 중', '각도 선택', '점', 'drawTrack', 'visibleFrame', 'baseline', 'Refresh placement baseline', 'refreshPlacementBaseline', 'didChangeScreenParametersNotification', 'NSWindow.didChangeOcclusionStateNotification'):
    assert removed not in all_source
for expected in ('StickmanPose', 'drawStickman', 'drawTarget', 'mouseDown', 'mouseUp', 'acceptsFirstMouse', 'drawSpear'):
    assert expected in all_source
for forbidden in ('ScreenCaptureKit', 'CGWindowList', 'AXUIElement', 'CGEventTap', 'CGEventPost', 'URLSession', 'NSPasteboard', 'NSEvent.addGlobalMonitorForEvents', 'NSEvent.addLocalMonitorForEvents', 'CGRequestScreenCaptureAccess', 'CGDisplayStream', 'CGWindowImage'):
    assert forbidden not in all_source
assert 'v2' in readme and 'visibility-only' in readme
assert 'cubic Bézier' in readme and 'dx=P3.x-P0.x' in readme
assert 'M-01/M-02 motion lifecycle reconciliation' in readme
assert 'Linux static pass is not a macOS runtime pass' in readme
print('PASS: TTALGAK v2 static scope, pure presentation lifecycle, and visibility-only flight-layer checks')
