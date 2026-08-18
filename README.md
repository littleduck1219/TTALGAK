# TTALGAK 창던지기 v1

Native macOS 13+ menu-bar mini game. The primary display has exactly two bounded `180 × 110 pt` AppKit nonactivating panels: left is local throw control; right is target/result only. Their X and size are fixed; Y is Dock-independent: `screen.frame.minY + clamp(screen.frame.height × 0.08, 72, 120)`.

## Product loop

- Hold the left panel: the pure core deterministically sweeps `20° → 70° → 20°` in 1.2 seconds low-to-high. Standard rendering presents that shared angle, marker, and spear with ease-in-out; judgement remains the core's normalized deterministic value.
- Release once: only `Aiming` may enter `Flying`. Standard motion shows a right-panel-only 210 ms symbolic flight; Reduce Motion resolves directly to Hit/Miss without a flight animation.
- macOS's public `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` is read locally at press. Under Reduce Motion, aiming advances angle/marker/number together every 300 ms; easing and scale motion are not used. Text, target/landing shape and location cues, state transition, and score contract remain.
- The right panel has top/middle/bottom targets, exactly one active target, a fixed score slot, and text/shape/color result cues. Non-active targets render at 40% opacity.
- The pure Swift core maps angle to normalized height (`0…1`), not desktop coordinates or a physics engine. Hit gives `+1`/`✓ 딸깍!`; miss gives `+0`/`× 아쉽다`; result remains for 1 second, then deterministically prepares the next target.
- v1 is silent unlimited practice. No physics engine, sound, keyboard control, global input, screen-spanning overlay, network, files, clipboard, capture, analytics, or permissions are included.

## Safety and UI boundary

- `OverlayController` creates two borderless, nonactivating `NSPanel` instances only. There is no TTALGAK window outside either panel: empty-area click-through is by absence.
- Only left-panel `mouseDown`/`mouseUp` invokes game input. The right panel has no game action. Neither panel can become key/main.
- Light surface (94% white), 1 px border, 14 pt radius, no shadow, linear stickman/spear/target, 16 pt bold state/angle/score, 12 pt endpoint labels, track marker tick, and non-color state cues are rendered locally. The bounded left panel is larger than the required `44 × 44 pt` local target.
- SUIT is used when installed; otherwise `NSFont.systemFont` is the intentional local fallback. Mac QA must record which path rendered.
- No Screen Recording, Accessibility, Input Monitoring, screen/window/file/clipboard access, `CGEventTap`, global/local monitor/shortcut, or external transmission exists in the source tree.

## Layout

- `Package.swift` — SwiftPM executable, cross-platform pure-core target, XCTest target.
- `Sources/SpearGameCore/SpearGameState.swift` — deterministic state machine, normalized judgement, and renderer timing policy seam.
- `Sources/TTALGAK/OverlayController.swift` — two-panel placement, local timers, local public reduced-motion preference read, no desktop-sized window.
- `Sources/TTALGAK/SpearThrowView.swift` — AppKit rendering and local pointer adapter.
- `Tests/SpearGameStateTests.swift` — core state semantics plus motion policy contract.
- `Tests/verify_project.py` — Linux-safe static guardrail.

## Build and test on a Mac

```bash
cd /path/to/TTALGAK
swift package describe
swift test
swift build
swift run TTALGAK
```

Xcode route: open `Package.swift`, select `TTALGAK` and `My Mac`, then Run. The accessory/menu-bar app has **Hide boxes**, **Show boxes**, and **Quit TTALGAK**.

## Required Mac QA (M-01–M-10; not certified by Linux)

| ID | Action | Expected PASS |
|---|---|---|
| M-01 | Run `swift package describe`, `swift test`, and `swift build`. | Every command exits 0 and XCTest passes. |
| M-02 | Run `swift run TTALGAK`. | Menu-bar app and exactly two `180 × 110 pt` panels appear. |
| M-03 | Calculate `expectedY = screen.frame.minY + clamp(screen.frame.height × 0.08, 72, 120)`; change Dock visibility, size, and edge. | Both panels retain formula Y, left/right X, and size; Dock does not affect placement. |
| M-04 | Type a sentinel in another editor, press/hold/release left panel, then continue typing. | Editor retains text focus; TTALGAK never becomes key/main. |
| M-05 | Hold left panel through low→high→low without release. | Angle, marker, and spear change together; no flight before release. Also inspect 16 pt bold Ready/Aiming/Flying/Hit/Miss labels and 16 pt angle/score for clipping or collision within `180 × 110 pt`. |
| M-06 | Release once at matching and mismatching angles. | Standard motion: one right-panel-only 180–240 ms flight, Hit check/`딸깍!`/+1 or Miss X/`아쉽다`/+0, then Ready after 0.8–1.2 s. No duplicate score/result. |
| M-07 | Press left, move pointer outside, and release. | Record actual AppKit capture/release PASS or FAIL; no global capture is added. |
| M-08 | Click gaps/desktop and right panel. | Gaps pass through to the underlying app; right panel never starts the game. |
| M-09 | Check Privacy & Security and launch dialogs; record SUIT/fallback. | No Screen Recording, Accessibility, or Input Monitoring prompt/request; rendered font path is recorded. |
| M-10 | Enable System Settings Reduce Motion, then repeat M-05 and M-06. | 300 ms angle/marker/number steps; release goes directly to static Hit/Miss with text, target/landing shape, and location cues; no ease-in-out, panel-local flight, Hit scale, or other scale motion. State and score remain identical to standard policy. Verify 12 pt `20°`/`70°` labels and marker tick do not clip/collide. |

Multi-display, Spaces, and full-screen apps remain unsupported unless separately tested and documented.

## Linux static validation boundary

Linux may run only the source guardrail:

```bash
python3 Tests/verify_project.py
python3 -m py_compile Tests/verify_project.py
swift test  # only when a Swift toolchain is installed
```

A Linux static pass is not a macOS runtime pass. It does not certify Swift/AppKit compilation, rendering, press/hold/release, pointer capture, focus retention, click-through, reduced-motion behavior, typography collision, or permission behavior.
