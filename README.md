# TTALGAK macOS overlay-box prototype

Native macOS menu-bar prototype: the primary display gets exactly two translucent `180 × 110 pt` AppKit panels at its lower-left and lower-right edges. Their X/size stay fixed; their Y follows the public `NSScreen.visibleFrame` bottom edge when a bottom Dock reserves space, otherwise the display bottom edge.

## Scope and privacy boundary

- `NSApplication` runs as an accessory app with an AppKit menu-bar item.
- `OverlayController` creates exactly two borderless, non-activating `NSPanel` windows. Their X positions and `180 × 110 pt` sizes use `NSScreen.main.frame`; their Y is `max(frame.minY, visibleFrame.minY)`, so a bottom Dock that reserves visible space lifts both boxes to its top and an auto-hidden Dock leaves them at the display edge.
- It repositions on initial show, public screen-configuration notification, app activation, and a 0.25-second main-run-loop observation of the public `visibleFrame` while boxes are visible. AppKit has no public Dock-state/height notification guarantee; this bounded observation catches a changed public frame after a Dock transition without private APIs, window/screen metadata, accessibility, capture, or permissions. It stops when boxes hide or the controller deinitializes.
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

1. On the primary display, launch the app and verify the TTALGAK menu-bar icon appears.
2. With the bottom Dock visible, verify exactly two translucent panels appear at `(screen.minX, screen.visibleFrame.minY, 180, 110)` and `(screen.maxX - 180, screen.visibleFrame.minY, 180, 110)`, retaining their X positions and sizes. Enable Dock auto-hide, move it down, and verify both panels move to `screen.frame.minY` within 0.25 seconds after the public `visibleFrame` changes.
3. Re-display the Dock without activating TTALGAK or changing display configuration. Verify both panels return to the current `screen.visibleFrame.minY` within 0.25 seconds after the public frame changes, with unchanged X and `180 × 110 pt` size. Record an observed delay or a public frame that does not update; Linux validation cannot certify this behavior.
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
