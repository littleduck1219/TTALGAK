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
assert overlay.count('GamePanel(frame: .zero)') == 2
assert 'let screen = NSScreen.main' in overlay
assert 'let bottomSafeInset = min(max(frame.height * 0.08, 72), 120)' in overlay
assert 'let bottomY = frame.minY + bottomSafeInset' in overlay
assert 'x: frame.minX, y: bottomY' in overlay
assert 'x: frame.maxX - boxSize.width, y: bottomY' in overlay
assert '.borderless, .nonactivatingPanel' in overlay
assert 'override var canBecomeKey: Bool { false }' in overlay
assert 'override var canBecomeMain: Bool { false }' in overlay
assert 'No desktop-sized window' in overlay
assert 'SpearThrowView' in overlay and 'TargetView' in overlay
assert 'Timer.scheduledTimer(withTimeInterval: 0.21' in overlay
assert 'Timer.scheduledTimer(withTimeInterval: 1.0' in overlay
for removed in ('visibleFrame', 'baseline', 'Refresh placement baseline', 'refreshPlacementBaseline', 'didChangeScreenParametersNotification', 'NSWindow.didChangeOcclusionStateNotification'):
    assert removed not in overlay
assert '20.0' in core and '70.0' in core and '1.2' in core
assert 'normalizedLanding' in core and 'hitTolerance' in core
assert 'guard phase == .aiming else { return }' in core
assert 'guard phase == .flying, let landingHeight else { return }' in core
for expected in ('testReadyAimingFlyingHitReadyAddsOnePoint', 'testReadyAimingFlyingMissReadyKeepsScore', 'testAimReversesAtBothBounds', 'testInvalidInputIsNoOpAndReleaseOnlyStartsOneFlight', 'testNormalizedMappingHitsEachTargetAndMissesOutsideTolerance'):
    assert expected in tests
for expected in ('누르고 각도를 고르세요', '과녁', '✓ 딸깍!', '× 아쉽다', 'acceptsFirstMouse', 'mouseDown', 'mouseUp'):
    assert expected in view
for forbidden in ('ScreenCaptureKit', 'CGWindowList', 'AXUIElement', 'CGEventTap', 'CGEventPost', 'URLSession', 'NSPasteboard', 'NSEvent.addGlobalMonitorForEvents', 'NSEvent.addLocalMonitorForEvents', 'CGRequestScreenCaptureAccess'):
    assert forbidden not in all_source
assert 'Required Mac QA' in readme
assert 'Linux static pass is not a macOS runtime pass' in readme
print('PASS: TTALGAK v1 static scope, deterministic core, and overlay-policy checks')
