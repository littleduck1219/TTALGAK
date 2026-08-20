# TTALGAK 창던지기 v2

Native macOS 13+ menu-bar mini game. The primary display keeps exactly two transparent `180 × 110 pt` AppKit anchors: left is the only local press/hold/release surface and visually contains one stickman plus held spear; right is noninteractive and visually contains one target. Their X positions and app-owned Y inset are fixed: `screen.frame.minY + clamp(screen.frame.height × 0.08, 72, 120)`. Windows is out of scope.

## Product and motion contract

- No visible panel/card surface: no fill, border, radius, shadow, status, angle, track, persistent score, or “flying” UI.
- The pure `SpearGameCore` owns normalized deterministic hit/miss and score semantics. `PresentationPolicy`/`PresentationLifecycle` are pure visual timing only; trajectory never changes judgement.
- Standard: aiming pose cycle 600 ms ease-in-out; launch 120 ms; screen-space flight 500 ms (within 420–620 ms; release→impact ≤700 ms); result cue/reset completes release→Ready in 1.1 s.
- Stickman poses are Ready, Aiming arm-back/body lean, Release forward arm/body shift, Flying, and recovery. Aiming derives its visible 25°↔65° sweep from the current game aim through one deterministic presentation geometry value; standard keeps the 600 ms policy and Reduced Motion keeps the 300 ms/no-translation contract.
- The shared presentation geometry is the sole source of rendered arm/hand, held-spear origin/end, and FlightPanel start. A release produces exactly one detached spear from the rendered release hand to target or deterministic miss endpoint without a separate coordinate.
- Hit shows target/check plus short `+1`; miss shows only endpoint/X. There is no persistent score.
- Reduced Motion: 300 ms aiming step; no translation, arc, scale, body-shift, or fade trajectory. Release resolves to a static Hit/Miss cue; pure judgement and reset semantics remain.

## Visibility-only flight layer

During standard release only, a temporary transparent primary-display `FlightPanel` renders the spear. It uses public AppKit and is `.borderless` + `.nonactivatingPanel`, `ignoresMouseEvents = true`, cannot become key/main, has explicit `.aqua` appearance, and is ordered out/released at impact. The pure `FlightLayerContract` and Linux static verifier guard this configuration; real AppKit routing remains Mac QA only.

Left anchor is the sole `input` panel. Right anchor is an explicit `displayOnly` panel with window-level `ignoresMouseEvents = true`; it cannot consume click, drag, or text input. It remains visible, nonactivating, non-key, and non-main.

This is explicit mouse-ignore click-through, not v1’s click-through-by-absence. During flight, desktop and underlying app click/button/text/drag input must still route below it. Left anchor local mouse down/up remains the only input. Right anchor and flight layer are visual-only.

No global/local monitor, event tap/post, Accessibility/Input Monitoring/Screen Recording permission, capture, clipboard/file/network/data access, private API, sound, Dock tracking/baseline/Refresh, multi-display, Space, or full-screen support is added or claimed.

## Layout

- `Package.swift` — SwiftPM executable, pure core, XCTest target.
- `Sources/SpearGameCore/SpearGameState.swift` — normalized game state plus pure presentation policy/lifecycle.
- `Sources/TTALGAK/OverlayController.swift` — two local anchors, temporary visibility-only flight-layer lifecycle, local timers, reduced-motion preference read.
- `Sources/TTALGAK/SpearThrowView.swift` — transparent AppKit stickman/target/spear renderers; local left pointer adapter only.
- `Tests/SpearGameStateTests.swift` — pure state plus v2 timing/lifecycle tests.
- `Tests/verify_project.py` — Linux-safe static guardrail.

## Representative Mac commands

```bash
cd /Users/littleduck/Documents/GitHub/TTALGAK
git pull --ff-only origin main
swift package describe
swift test
swift build
swift run TTALGAK
```

Xcode route: open `Package.swift`, select `TTALGAK` and `My Mac`, then Run. The menu-bar app offers Hide/Show TTALGAK and Quit.

## Required Mac QA (pending until representative output)

1. Run every command above; return stdout/stderr and exit results.
2. Confirm only one stickman/held spear at left and one target at right; no card, text/status, angle/track, or persistent score.
3. Standard hit and miss: hold to observe Ready→Aiming arm-back/body lean, release to observe forward throw/recovery and one continuous hand→target/miss flight. Confirm impact occurs within 700 ms and Ready by 1.1–1.3 s.
4. Focus: type a sentinel into another app, press/hold/release, then keep typing. TTALGAK must never become key/main.
5. During the visible flight layer, click an underlying button/text field and start an underlying drag. All must route beneath the layer; right anchor must never start a throw.
6. Confirm each layer appears only for standard flight, has `ignoresMouseEvents = true`, is non-key/non-main, disappears before next Ready, and creates no duplicate spear.
7. Enable Reduce Motion and repeat hit/miss. Observe 300 ms aim steps and immediate static result; no translation, arc, scale, body shift, or trajectory fade.
8. Check Privacy & Security and launch dialogs: no Screen Recording, Accessibility, or Input Monitoring prompt/request. Record font behavior if relevant.
9. Confirm Dock visible/hidden/size/edge does not change anchor X/Y/size or flight start/end source. Do not report multi-display, Spaces, or full-screen support without separate Mac QA.

## Linux static validation boundary

```bash
python3 Tests/verify_project.py
python3 -m py_compile Tests/verify_project.py
swift test  # only when Swift is installed
```

A Linux static pass is not a macOS runtime pass. It does not certify Swift/AppKit compilation, rendering, pose timing, real cross-screen flight, focus retention, click/drag/input pass-through, layer lifecycle, reduced-motion behavior, or permission behavior.
