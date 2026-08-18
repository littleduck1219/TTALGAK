# TTALGAK macOS overlay-box prototype

Native macOS menu-bar prototype: the primary display gets exactly two translucent `180 × 110 pt` AppKit panels at its lower-left and lower-right edges.

## Scope and privacy boundary

- `NSApplication` runs as an accessory app with an AppKit menu-bar item.
- `OverlayController` creates exactly two borderless, non-activating `NSPanel` windows. The panels are the transparent overlay; there is intentionally no display-sized transparent window.
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
2. Verify exactly two translucent panels appear: left frame `(screen.minX, screen.minY, 180, 110)` and right frame `(screen.maxX - 180, screen.minY, 180, 110)`.
3. Choose **Hide boxes** then **Show boxes** and verify both panels hide/show together.
4. Place another normal app behind the gaps between and above the boxes. Click those empty regions; the underlying app must receive the click.
5. Click inside each visible box; it may consume that local click but must not activate a normal TTALGAK window or install a global input hook.
6. In System Settings → Privacy & Security, verify TTALGAK did not request Screen Recording, Accessibility, or Input Monitoring.
7. Record multi-display, Space, and full-screen-app behavior separately. Do not mark those environments supported unless this run confirms the intended visibility and non-interference policy.

## Linux static validation boundary

This checkout is prepared on Linux, where Swift/Xcode/AppKit compilation and interactive window verification are unavailable. Run only the platform-neutral source guardrail there:

```bash
python3 Tests/verify_project.py
```

A passing result does not certify macOS build, rendering, panel geometry, click-through, or permission behavior; those require the Mac procedure above.
