# TTALGAK 창던지기 v3

Native macOS 13+ menu-bar mini game. `I_L` is the only pointer input: a transparent `180 × 110 pt` nonactivating panel, placed `96pt` inward from the physical left edge. Pointer down must begin in its visible actor/held-spear `44 × 44 pt` local zone, centered on the launch hand at local `(66,58)`; longer reverse pulls intentionally leave `I_L` and stay valid because local drag/up containment is ignored after a valid down. `I_R` remains a transparent `180 × 110 pt` display-only structural panel. The actor, target, result, persisted ground spears, and flight render on a separate full-primary-display transparent display panel; it ignores mouse events and is never key/main. The physical `groundY` plane is intentionally invisible: it is used only for first-crossing miss resolution, never as a rendered ground line.

## v3 contract

- Local vertical drag maps exactly to `angle=clamp(45 + 20×dy/48, 25, 65)` in y-up points. Reverse tangent projection maps power with a 6pt dead zone and 320pt maximum: `r=max(0,-dot(D,t))`, `power=clamp((r-6)/314,0,1)`.
- Power latch: the moment a valid drag first crosses the 6pt reverse dead zone, the current angle's tangent is frozen. From then on power reads only the displacement component along that frozen axis (`r=-dx/tangent.x`, same `clamp((r-6)/314,0,1)`): vertical angle-only moves change the launch angle but leave power exactly unchanged; only continued pull along the frozen reverse axis raises (or relaxes) power, reaching max at a 320pt pull. Before the dead zone is crossed, angle changes never latch power. `mouseUp` launches the latest angle with the latched power.
- Down/move/up are local NSView events only. A down must begin in the actor zone; after that valid down, the same NSView's `mouseDragged` coordinates update tension outside `I_L` and its actual `mouseUp` launches the final frozen value once, regardless of containment. The next valid down discards stale aim. There are no event monitors, taps, global pointer/key/cursor APIs, capture, network, clipboard, or permission APIs.
- Pure launch input is frozen `(P0, angle, power, groundY)`. `g=2400 pt/s²`, `v0=900+1000×power`, `L=42`; target seed/result never participate in velocity or trajectory calculation.
- Hit is only physical `R=16` shaft-segment/ring collision. Miss is the first physical ground-plane crossing, or an honest off-display miss. No target steering, canonical target calibration, endpoint blend, prediction arc, numeric gauge, card, or angle label exists.
- Ground-miss spears persist where they crossed the hidden ground plane, drawn with the same black stroke language. The inventory is an in-memory FIFO capped at 50: the 51st miss evicts the oldest. Hit spears are transient and never enter the inventory. Nothing is persisted to disk or network.
- Target spawns only at show/new-game and after an actual hit, at `x = screen.maxX − inset` with inset uniformly in `280…520pt` (clamped to visible bounds by a 22pt edge margin), vertical seed heights `ground+64/132/200` cycling deterministically via an injectable provider. Misses, resets, and flight never move the target, and the target never influences launch velocity or physics.
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

Run the M-V3 matrix after the four commands pass: same 45° short/mid/long reverse pulls must have strictly rising landing distance; 25°/45°/65° at equal power must differ; actual ground misses, non-clipping actor/target, focus/pass-through/non-key behavior, reduced-motion truth, timer cleanup, and zero permission prompts must be recorded PASS/FAIL. Additionally: fire 51 ground misses and confirm only 50 spears remain with the oldest removed; confirm the target stays exactly still across misses/resets and moves only after an actual hit; confirm every spawned target x sits within `280…520pt` inset from the right screen edge; confirm maximum power now requires a full `320pt` reverse pull (a `160pt` pull reads ≈0.49 — about half power — and a `72pt` pull ≈0.21). Power-latch check: pull back past the dead zone to establish visible tension, then move only vertically — tension/power must not shrink or grow while the aim angle changes; only further backward pull along the latched direction may change it, and release must launch with the latest angle plus the latched power. v3 is a candidate implementation until real Mac QA passes.
