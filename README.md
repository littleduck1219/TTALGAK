# TTALGAK 창던지기 v2

Native macOS 13+ menu-bar mini game. The primary display keeps exactly two transparent `180 × 110 pt` AppKit anchors: left is the only local press/hold/release surface and visually contains one black stickman plus held spear with its body at `screen.frame.minX + 48 pt`; right is noninteractive and visually contains one black target centered at `screen.frame.maxX - 48 pt`. Their structural X bounds and app-owned Y inset remain `screen.frame.minY + clamp(screen.frame.height × 0.08, 72, 120)`. Windows is out of scope.

## Product and motion contract

- No visible panel/card surface: no fill, border, radius, shadow, status, angle, track, persistent score, or “flying” UI.
- All visible ink is `#000000` at alpha 1.0: no tint, opacity, shadow, gradient, blue/yellow/green/red accent, or color exception. Background remains transparent; hit/miss use black shape cues only.
- Stickman head/body/limbs and held shaft are 3 pt (held tip 2.5 pt); flight shaft/tip are 3.5/3 pt; target rings/check/X are 3.5 pt; target center is a solid 8 pt black circle. Every stroked path uses round caps and joins.
- The pure `SpearGameCore` owns normalized deterministic hit/miss and score semantics. `PresentationPolicy`/`PresentationLifecycle`/`PresentationFlightPath` are pure visual timing and cubic Bézier geometry only; trajectory never changes judgement.
- Standard: aiming pose cycle 600 ms; launch 160 ms ease-out; flight 820 ms ease-in-out along one cubic Bézier; impact 140 ms; static hold 360 ms; reset 220 ms ease-in-out. Release→impact is 980 ms and release→Ready is 1,480 ms. There is no bounce, shake, spin, flash, or target scale.
- Flight is primary-display local y-up: `P0` is the rendered release-hand/held-shaft-tail contact and `P3` is the deterministic target/miss endpoint. `dx=P3.x-P0.x` must be positive or the visual launch fails closed. `θ=clamp(current visible aim,25°,65°)`, `u0=(cos θ,sin θ)`, `D1=clamp(.12dx,80,160)`, `P1=P0+D1u0`; `u3=(cos35°,-sin35°)`, `D2=clamp(.30dx,180,360)`, `P2=P3-D2u3`. The shaft tail is `C(t)` and its 42pt tip is `C(t)+42×normalize(C'(t))`; orientation is `atan2(C'(t))`. Thus the final held shaft and first flight shaft share both P0 and tangent. Quadratic/H/midpoint/sine/circular/linear flight paths are rejected.
- Stickman poses are Ready, Aiming arm-back/body lean, Release forward arm/body shift, Flying, and recovery. Aiming derives its visible 25°↔65° sweep from the current game aim through one deterministic presentation geometry value; Reduced Motion keeps the 300 ms discrete/no-translation contract.
- Reduced Motion creates no flight layer and performs no translation, Bézier, rotation, scale, body shift, or fade trajectory. It preserves the 300 ms aim step then shows a static black hit check/+1 or miss X for 500 ms before Ready.
- Pending separately: M-01/M-02 motion lifecycle reconciliation (reset interpolation, timing curve, and flight-layer removal timing) is intentionally unchanged by this cubic tangent correction and awaits later Rive character integration.

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
2. Confirm only one black stickman/held spear at left (`+48 pt` body/release-hand inset) and one black target centered at right (`−48 pt`); no card, text/status, angle/track, or persistent score. Check normal, aiming, hit, miss, and Reduced Motion frames for black-only ink, no tint/shadow/gradient, and specified 3–3.5 pt weights.
3. Standard hit and miss: hold/release at visible min (raw 20°→25°), midpoint (45°), and visible max (raw 70°→65°). At each release, verify the last held shaft tail/direction and first flight shaft tail/tangent are one continuous spear—no 70–80°→30–40° kink. For high/low hit and miss, verify the cubic high arc, exact target/miss P3 endpoint, 35° descending rightward approach, 820 ms observable flight, impact at about 980 ms, and Ready at about 1,480 ms; no bounce/shake/spin/flash/target scale.
4. Focus: type a sentinel into another app, press/hold/release, then keep typing. TTALGAK must never become key/main.
5. During the visible flight layer, click an underlying button/text field and start an underlying drag. All must route beneath the layer; right anchor must never start a throw.
6. Confirm each layer appears only for standard flight, has `ignoresMouseEvents = true`, is non-key/non-main, remains through impact/result hold, then disappears before next Ready without duplicate spear.
7. Enable Reduce Motion and repeat hit/miss. Observe a 300 ms discrete aim step and a 500 ms static black result with no flight layer, translation, Bézier, rotation, scale, body shift, or fade trajectory.
8. Check Privacy & Security and launch dialogs: no Screen Recording, Accessibility, or Input Monitoring prompt/request. Record font behavior if relevant.
9. Confirm app-owned safe inset and two `180×110 pt` structural anchors remain unchanged. Do not report multi-display, Spaces, or full-screen support without separate Mac QA.

## Linux static validation boundary

```bash
python3 Tests/verify_project.py
python3 -m py_compile Tests/verify_project.py
swift test  # only when Swift is installed
```

A Linux static pass is not a macOS runtime pass. It does not certify Swift/AppKit compilation, rendering, pose timing, real cross-screen flight, focus retention, click/drag/input pass-through, layer lifecycle, reduced-motion behavior, or permission behavior.
