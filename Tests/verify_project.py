#!/usr/bin/env python3
"""Platform-neutral guardrail for the intentionally small macOS prototype."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
package = (root / "Package.swift").read_text()
source = (root / "Sources/TTALGAK/OverlayController.swift").read_text()
app = (root / "Sources/TTALGAK/TTALGAKApp.swift").read_text()
readme = (root / "README.md").read_text()
all_source = "\n".join(path.read_text() for path in (root / "Sources").rglob("*.swift"))

assert '.macOS(.v13)' in package
assert 'NSStatusBar.system.statusItem' in app
assert source.count('PlaceholderPanel(frame:') == 2
assert 'width: 180, height: 110' in source
assert 'let screen = NSScreen.main' in source
assert 'let bottomSafeInset = min(max(frame.height * 0.08, 72), 120)' in source
assert 'let bottomY = frame.minY + bottomSafeInset' in source
clamp_bottom_safe_inset = lambda height: min(max(height * 0.08, 72), 120)
assert (clamp_bottom_safe_inset(800), clamp_bottom_safe_inset(1000), clamp_bottom_safe_inset(2000)) == (72, 80, 120)
assert 'x: frame.minX, y: bottomY' in source
assert 'x: frame.maxX - boxSize.width, y: bottomY' in source
for removed in ('visibleFrame', 'baseline', 'Refresh placement baseline', 'refreshPlacementBaseline', 'didChangeScreenParametersNotification'):
    assert removed not in source
    assert removed not in app
assert 'NSWindow.didChangeOcclusionStateNotification' not in source
assert 'visibleFrameTimer' not in source
assert 'Timer(' not in source
assert 'RunLoop.main.add' not in source
assert '.borderless, .nonactivatingPanel' in source
assert 'override var canBecomeKey: Bool { false }' in source
assert 'No desktop-sized window' in source
assert 'every empty point belongs to the app below it' in source
for forbidden in ('ScreenCaptureKit', 'CGWindowList', 'AXUIElement', 'CGEventTap', 'URLSession', 'NSPasteboard'):
    assert forbidden not in all_source
assert 'Mac verification procedure' in readme
assert 'No screen/window/file/clipboard capture or access' in readme
print('PASS: TTALGAK static scope and overlay-policy checks')
