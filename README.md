# TTALGAK 창던지기 v3

Native macOS 13+ menu-bar mini game. `I_L` is the only pointer input: a transparent `180 × 110 pt` nonactivating panel, placed `96pt` inward from the physical left edge. Pointer down must begin in its visible actor/held-spear `44 × 44 pt` local zone, centered on the launch hand at local `(66,58)`; longer reverse pulls intentionally leave `I_L` and stay valid because local drag/up containment is ignored after a valid down. `I_R` remains a transparent `180 × 110 pt` display-only structural panel. The actor, target, result, persisted ground spears, and flight render on a separate full-primary-display transparent display panel; it ignores mouse events and is never key/main. The physical `groundY` plane is intentionally invisible: it is used only for first-crossing miss resolution, never as a rendered ground line.

## v3 contract

- Local vertical drag maps exactly to an asymmetric `10…65°` range around the `45°` center in y-up points: `angle=clamp(45 + 35×dy/48, 10, 65)` for `dy<0` and `angle=clamp(45 + 20×dy/48, 10, 65)` for `dy≥0`, so `dy=-48 → 10°`, `dy=0 → 45°`, `dy=+48 → 65°`.
- Physical full power is a compact fixed `64pt` reverse pull. With the `6pt` dead zone, `r=max(0,-dot(D,t))` and `power=clamp((r-6)/58,0,1)`. Power needs no display geometry or edge data and never requires a screen edge.
- Power latch: the moment a valid drag first crosses the 6pt reverse dead zone, the current angle's tangent freezes. From then on power reads only the displacement component along that frozen axis (`r=-dx/tangent.x`): vertical angle-only moves change the launch angle but leave power and raw pull exactly unchanged; only continued movement on the frozen reverse axis changes them. `mouseUp` launches the latest angle with the latched power.
- Visible pull uses `tension=clamp(rawPull/64×64,0,64)pt`, hidden at or below the 6pt dead zone. A `32pt` raw pull shows `32pt` tension and approximately half power (`26/58`); a `64pt` raw pull shows the full `64pt` tension and full power. Vertical angle-only moves preserve raw pull, visible tension, and power together. The hand/launch `P0` never moves during aiming.
- Down/move/up are local NSView events only. A down must begin in the actor zone; the original press-held local event stream may continue delivering drag/up outside that panel, and the first actual `mouseUp` launches once. No display-edge capture is required or supported; ordinary desktop areas remain pass-through. The next valid down discards stale aim. There are no event monitors, taps, global pointer/key/cursor APIs, capture, network, clipboard, or permission APIs.
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

Run the M-V3 matrix after the four commands pass: same 45° short/mid/long reverse pulls must have strictly rising landing distance; 10°/45°/65° at equal power must differ; drag fully down must reach 10° (no drag = 45°, fully up = 65°), and a 10° full-power throw must produce a fast, flat, honestly landing low trajectory with its ground-miss spear persisting in the scene. Record actual ground misses, non-clipping actor/target, focus/pass-through/non-key behavior, reduced-motion truth, timer cleanup, and zero permission prompts as PASS/FAIL. Fire 51 ground misses and confirm only 50 remain with the oldest removed; confirm the target stays still across misses/resets and moves only after a hit; confirm target x remains within `280…520pt` of the right edge. Confirm full power and `64pt` tension at a physical `64pt` pull within the local interaction area, and approximately half power with `32pt` tension at a `32pt` pull. Move only vertically after latching and confirm angle changes while raw pull, power, and tension remain stable; continue along the frozen reverse axis and confirm they increase. Confirm there is no edge drag or capture and no extra capture/input window, ordinary desktop locations pass through normally, and no Accessibility/Input Monitoring/Screen Recording prompt appears. v3 remains a candidate until real Mac QA passes.
