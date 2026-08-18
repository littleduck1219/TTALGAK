# TTALGAK macOS overlay-box prototype

Native macOS menu-bar prototype: the primary display gets exactly two translucent `180 × 110 pt` AppKit panels at its lower-left and lower-right edges. Their X/size stay fixed; their Y follows the public `NSScreen.visibleFrame` bottom edge when a bottom Dock reserves space, otherwise the display bottom edge.

## Scope and privacy boundary

- `NSApplication` runs as an accessory app with an AppKit menu-bar item.
- `OverlayController` creates exactly two borderless, non-activating `NSPanel` windows. Their X positions and `180 × 110 pt` sizes use `NSScreen.main.frame`; their Y is `max(frame.minY, visibleFrame.minY)`, so a bottom Dock that reserves visible space lifts both boxes to its top and an auto-hidden Dock leaves them at the display edge.
- It repositions on initial show, public screen-configuration notification, app activation, and each panel’s public `NSWindow.didChangeOcclusionStateNotification`. The occlusion callback defers one main-loop turn, then reuses the single `visibleFrame` geometry path; observers stop before panels hide or deinitialize. This replaces the rejected `Timer` polling path and adds no private Dock API, window/screen metadata, accessibility, capture, input monitoring, or permission.
- Event boundary: `didChangeOcclusionStateNotification` is a panel-occlusion event, not a Dock-state event. The required Mac QA must confirm that the Dock hide/show transition changes these panels’ occlusion state and that the deferred read sees the new `visibleFrame`; if either event/frame boundary does not occur, the permitted API set has no guaranteed Dock-specific subscription and this implementation must not be marked as a Mac pass.
- The visible box is the only local pointer target. There is no TTALGAK window outside either box, so macOS routes every empty overlay-area click to the app beneath it.
- The current boxes only consume their own clicks as future stickman hit areas. They do not read or generate keyboard input.
- No screen/window/file/clipboard capture or access, Accessibility, Screen Recording, Input Monitoring, global event tap/shortcut, network client, analytics SDK, or external transmission exists in this source tree.
- Full-screen-app and multi-Space behavior is not supported by claim. The panels join normal Spaces; a Mac QA pass must establish any wider compatibility before it is promised.

## Project layout

- `Package.swift` — macOS 13 Swift Package executable
- `Sources/TTALGAK/TTALGAKApp.swift` — AppKit accessory/menu-bar lifecycle
- `Sources/TTALGAK/OverlayController.swift` — panel geometry and click-through-by-absence policy
- `Tests/verify_project.py` — Linux-safe static guardrail

`CODEX.md`, `CLAUDE.md`, and `GEMINI.md` point to the AI OS Wiki and are intentionally ignored by Git.

## Build and run on a Mac

Requirements: macOS 13+ and Xcode 15+ (or a compatible Swift toolchain).

```bash
cd /path/to/TTALGAK
swift package describe
swift build
swift run TTALGAK
```

Xcode route: open `Package.swift`, choose the `TTALGAK` executable scheme and `My Mac`, then Run. The app is a menu-bar accessory app; use **Hide boxes**, **Show boxes**, and **Quit TTALGAK** from its icon menu.

## Mac verification procedure (required before release)

1. In Xcode, set a breakpoint inside the `NSWindow.didChangeOcclusionStateNotification` observer closure in `OverlayController.startObservingPanelOcclusion()`, then launch the app and verify the TTALGAK menu-bar icon appears. Ignore notifications caused by initial panel ordering; the two Dock transitions below are the test events.
2. With the bottom Dock visible, verify exactly two translucent panels appear at `(screen.minX, screen.visibleFrame.minY, 180, 110)` and `(screen.maxX - 180, screen.visibleFrame.minY, 180, 110)`, retaining their X positions and sizes. Enable Dock auto-hide, move it down, and verify the panel-occlusion callback followed by its next main-loop turn puts both panels at `screen.frame.minY`.
3. Re-display the Dock without activating TTALGAK or changing display configuration. Verify the panel-occlusion callback occurs, its deferred read sees the current `screen.visibleFrame.minY`, and both panels return there with unchanged X and `180 × 110 pt` size. If no callback arrives or the frame is stale at that boundary, record FAIL; do not use elapsed time as a substitute and do not claim macOS coverage from Linux validation.
4. Choose **Hide boxes** then **Show boxes** and verify both panels hide/show together.
5. Place another normal app behind the gaps between and above the boxes. Click those empty regions; the underlying app must receive the click.
6. Click inside each visible box; it may consume that local click but must not activate a normal TTALGAK window or install a global input hook.
7. In System Settings → Privacy & Security, verify TTALGAK did not request Screen Recording, Accessibility, or Input Monitoring.
8. Record multi-display, Space, and full-screen-app behavior separately. Do not mark those environments supported unless this run confirms the intended visibility and non-interference policy.

## Linux static validation boundary

This checkout is prepared on Linux, where Swift/Xcode/AppKit compilation and interactive window verification are unavailable. Run only the platform-neutral source guardrail there:

```bash
python3 Tests/verify_project.py
```

A passing result does not certify macOS build, rendering, panel geometry, click-through, or permission behavior; those require the Mac procedure above.
