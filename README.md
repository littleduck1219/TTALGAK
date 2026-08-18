# TTALGAK 창던지기 v1

Native macOS 13+ menu-bar mini game. The primary display has exactly two bounded `180 × 110 pt` AppKit nonactivating panels: left is local throw control; right is target/result only. Their X and size are fixed; Y is Dock-independent: `screen.frame.minY + clamp(screen.frame.height × 0.08, 72, 120)`.

## Product loop

- Hold the left panel: angle sweeps `20° → 70° → 20°` with ease-free deterministic timing of 1.2 seconds from low to high. Spear direction, track marker, and number change together.
- Release once: only `Aiming` may enter `Flying`; the right panel shows a panel-local 210 ms symbolic flight.
- The right panel has top/middle/bottom targets, exactly one active target, a fixed score slot, and text/shape/color result cues.
- The pure Swift core maps angle to normalized height (`0…1`), not desktop coordinates or a physics engine. Hit gives `+1`/`✓ 딸깍!`; miss gives `+0`/`× 아쉽다`; result remains for 1 second, then deterministically prepares the next target.
- v1 is silent unlimited practice. No physics engine, sound, keyboard control, global input, screen-spanning overlay, network, files, clipboard, capture, analytics, or permissions are included.

## Safety and UI boundary

- `OverlayController` creates two borderless, nonactivating `NSPanel` instances only. There is no TTALGAK window outside either panel: empty-area click-through is by absence.
- Only left-panel `mouseDown`/`mouseUp` invokes game input. The right panel has no game action. Neither panel can become key/main.
- Light surface (94% white), 1 px border, 14 pt radius, no shadow, linear stickman/spear/target, and non-color state cues are rendered locally. The bounded left panel is larger than the required `44 × 44 pt` local target.
- SUIT is used when installed; otherwise `NSFont.systemFont` is the intentional local fallback. Mac QA must record which path rendered.
- No Screen Recording, Accessibility, Input Monitoring, screen/window/file/clipboard access, `CGEventTap`, global monitor/shortcut, or external transmission exists in the source tree.

## Layout

- `Package.swift` — SwiftPM executable, cross-platform pure-core target, XCTest target.
- `Sources/SpearGameCore/SpearGameState.swift` — deterministic state machine and normalized judgement.
- `Sources/TTALGAK/OverlayController.swift` — two-panel placement, local timers, no desktop-sized window.
- `Sources/TTALGAK/SpearThrowView.swift` — AppKit rendering and local pointer adapter.
- `Tests/SpearGameStateTests.swift` — Ready → Aiming → Flying → Hit/Miss → Ready, reversal, no-op/single release, and score tests.
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

## Required Mac QA (not certified by Linux)

1. Launch TTALGAK and verify exactly two `180 × 110 pt` panels at primary-screen left/right X and `expectedY = screen.frame.minY + clamp(screen.frame.height × 0.08, 72, 120)`. Toggle Dock visibility, size, and edge: Y/X/size must remain unchanged.
2. Put a text editor behind the panels, type a sentinel string, then press/hold/release on the left panel and continue typing without manually refocusing. Record whether the other app retained text focus; TTALGAK must not become key/main.
3. Hold long enough to observe low→high and high→low reversal. Confirm spear, marker, and angle number move together; no release means no flight.
4. Release exactly once at an angle that hits the current top/middle/bottom target, then repeat with a deliberately mismatched angle. Confirm right-panel-only 180–240 ms flight, one active target, check/+1 versus X/+0, and Ready after 0.8–1.2 seconds.
5. Start a press inside the left panel, move pointer outside, and release. Record the observed AppKit capture/release behavior. Do not claim outside-release semantics until this test passes; no global capture may be added.
6. Click all gaps and desktop area outside panels with another app behind them. The underlying app must receive clicks. Confirm right-panel clicks do not start a game action.
7. In System Settings → Privacy & Security, verify no Screen Recording, Accessibility, or Input Monitoring prompt/request. Record whether SUIT or the system font fallback rendered.
8. Multi-display, Spaces, and full-screen apps remain unsupported unless separately tested and documented.

## Linux static validation boundary

Linux may run only the source guardrail:

```bash
python3 Tests/verify_project.py
python3 -m py_compile Tests/verify_project.py
swift test  # only when a Swift toolchain is installed
```

A Linux static pass is not a macOS runtime pass. It does not certify Swift/AppKit compilation, rendering, press/hold/release, pointer capture, focus retention, click-through, or permission behavior.
