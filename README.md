# TTALGAK 창던지기 v3

Native macOS 13+ menu-bar mini game. `I_L` is the only pointer input: a transparent `180 × 110 pt` nonactivating panel. Pointer down must begin in its visible actor/held-spear `44 × 44 pt` local zone. `I_R` remains a transparent `180 × 110 pt` display-only structural panel. The actor, target, ground, result, and flight render on a separate full-primary-display transparent display panel; it ignores mouse events and is never key/main.

## v3 contract

- Local vertical drag maps exactly to `angle=clamp(45 + 20×dy/48, 25, 65)` in y-up points. Reverse tangent projection maps power with a 6pt dead zone and 72pt maximum: `r=max(0,-dot(D,t))`, `power=clamp((r-6)/66,0,1)`.
- Down/move/up are local NSView events only. Leaving `I_L` cancels; the next local down resets stale aim. There are no event monitors, taps, global pointer/key/cursor APIs, capture, network, clipboard, or permission APIs.
- Pure launch input is frozen `(P0, angle, power, groundY)`. `g=2400 pt/s²`, `v0=900+1000×power`, `L=42`; target seed/result never participate in velocity or trajectory calculation.
- Hit is only physical `R=16` shaft-segment/ring collision. Miss is the first physical ground-plane crossing, or an honest off-display miss. No target steering, canonical target calibration, endpoint blend, prediction arc, numeric gauge, card, or angle label exists.
- Standard mode uses common-run-loop monotonic elapsed time and ≤4pt collision substeps. Reduced Motion evaluates the same frozen physics immediately, shows a static truthful result, and creates no flight trajectory layer.

Existing internal PNG/SVG assets are not v3 final character-quality acceptance; the code-drawn actor is an intentionally safe fallback.

## Linux static validation

```bash
python3 Tests/verify_project.py
python3 -m py_compile Tests/verify_project.py Tools/regenerate_motion_pngs.py
```

Linux has no Swift toolchain in this environment, so these checks do not claim Swift/AppKit compilation or runtime success.

## Mandatory Mac QA handoff

```bash
cd /Users/littleduck/Documents/GitHub/TTALGAK
git pull --ff-only origin main
swift package describe
swift test
swift build
swift run TTALGAK
```

Run the M-V3 matrix after the four commands pass: same 45° short/mid/long reverse pulls must have strictly rising landing distance; 25°/45°/65° at equal power must differ; actual ground misses, non-clipping actor/target, focus/pass-through/non-key behavior, reduced-motion truth, timer cleanup, and zero permission prompts must be recorded PASS/FAIL. v3 is a candidate implementation until real Mac QA passes.
