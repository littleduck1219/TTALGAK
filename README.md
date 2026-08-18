# TTALGAK macOS overlay-box prototype

Native macOS menu-bar prototype: the primary display gets exactly two translucent `180 × 110 pt` AppKit panels at its lower-left and lower-right edges. Their X/size stay fixed; their Y uses a user-session baseline sampled from the public `NSScreen.visibleFrame` while the bottom Dock is visible, and does not move when that Dock later auto-hides.

## Scope and privacy boundary

- `NSApplication` runs as an accessory app with an AppKit menu-bar item.
- `OverlayController` creates exactly two borderless, non-activating `NSPanel` windows. On **Show boxes** and **Refresh placement baseline**, it snapshots `max(0, screen.visibleFrame.minY - screen.frame.minY)` and uses that value as Y for the current main-display geometry. Dock show/hide creates no observer and cannot move the panels; this removes the rejected Timer and panel-occlusion guesses.
- The baseline is only valid for the same `NSScreen.main.frame`. A public screen-configuration notification clears it and temporarily places panels at the display bottom; use **Refresh placement baseline** with the intended bottom Dock visible after changing display, resolution, Dock size, or Dock position. A Dock on the left or right has zero bottom inset, so panels remain at the display bottom.
- Public-API limit: if TTALGAK first samples while an auto-hidden bottom Dock is hidden, `visibleFrame` reports no bottom reservation and the app cannot infer the later Dock height. Open/show or refresh with the Dock visible. There is no public Dock-state subscription used or required by this policy.
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

Xcode route: open `Package.swift`, choose the `TTALGAK` executable scheme and `My Mac`, then Run. The app is a menu-bar accessory app; use **Hide boxes**, **Show boxes**, **Refresh placement baseline**, and **Quit TTALGAK** from its icon menu.

## Mac verification procedure (required before release)

1. Start with the bottom Dock visible, launch TTALGAK (or choose **Refresh placement baseline**), and verify exactly two translucent panels at `(screen.minX, screen.visibleFrame.minY, 180, 110)` and `(screen.maxX - 180, screen.visibleFrame.minY, 180, 110)`.
2. Enable Dock auto-hide and hide/re-show the Dock without activating TTALGAK or changing display configuration. Both panels must retain the Y from step 1, with unchanged X and `180 × 110 pt` size. No Dock callback is expected or required.
3. Change Dock size/position, resolution, or main display. The screen-configuration event clears the old baseline; with the intended bottom Dock visible, choose **Refresh placement baseline** and verify the new Y equals the new `screen.visibleFrame.minY`. For a left/right Dock, verify bottom Y equals `screen.frame.minY`.
4. Launch or refresh while the auto-hidden Dock is hidden: verify Y is `screen.frame.minY`, then reveal the Dock and use **Refresh placement baseline** to establish its height. This is the documented public-API fallback, not an automatic Dock-state recovery.
5. Choose **Hide boxes** then **Show boxes** and verify both panels hide/show together.
6. Place another normal app behind the gaps between and above the boxes. Click those empty regions; the underlying app must receive the click.
7. Click inside each visible box; it may consume that local click but must not activate a normal TTALGAK window or install a global input hook.
8. In System Settings → Privacy & Security, verify TTALGAK did not request Screen Recording, Accessibility, or Input Monitoring.
9. Record multi-display, Space, and full-screen-app behavior separately. Do not mark those environments supported unless this run confirms the intended visibility and non-interference policy.

## Linux static validation boundary

This checkout is prepared on Linux, where Swift/Xcode/AppKit compilation and interactive window verification are unavailable. Run only the platform-neutral source guardrail there:

```bash
python3 Tests/verify_project.py
```

A passing result does not certify macOS build, rendering, panel geometry, click-through, or permission behavior; those require the Mac procedure above.
