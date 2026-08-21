# TTALGAK 창던지기 v2

Native macOS 13+ menu-bar mini game. The primary display keeps exactly two transparent `180 × 110 pt` AppKit anchors: left is the only local press/hold/release surface, right is display-only. Windows, Rive and SVG/Core Animation asset integration are out of scope.

## Ballistic contract

- Black-only `#000000`, transparent/no-box scene, 48pt inward subject/target placement, existing 3–3.5pt rounded strokes, app-owned bottom inset, nonactivating/non-key/non-main panels, no permissions/capture/network/file/clipboard/global monitor remain unchanged.
- `BallisticFlightPath` is y-up and freezes only final release `P0`, clamped visible `θ`, and target X. `g=2400pt/s²`; `h25=-.022`, `h45=0`, `h65=.022`; angle-only piecewise `k(θ)` uses canonical `k25/k45/k65` values. `vx=k√(gdx)`, `vy=vx tanθ`, `Tphysics=dx/vx`.
- Standard flight is exactly 820ms without easing: `q=elapsed/.820`, `τ=qTphysics`, `x=x0+vxτ`, `y=y0+vyτ-.5gτ²`, velocity `(vx, vy-gτ)`. The 42pt shaft tail is `(x,y)` and tip is velocity-normalized. No cubic/quadratic/sine path, endpoint forcing, endpoint approach, target/result trajectory input, or velocity smoothing exists.
- Ready setup maps bottom/middle/top to canonical 25°/45°/65° ballistic target centers (`y=y0+h·dx`). Target sequence may seed placement only. Every score/cue is decided solely by sampled actual shaft segment-circle collision against the visible `R=16pt` ring, with maximum 4pt tip substeps. Miss X is drawn only at actual final tip.
- Aim hand is release entry hand. During the 160ms launch it interpolates continuously forward without crossing the body centerline; first flight tail is the final release-hand snapshot. Reduced Motion has no FlightPanel or ballistic translation/rotation and retains the 300ms discrete aim/500ms static result contract.

## Mac commands and required QA

```bash
cd /Users/littleduck/Documents/GitHub/TTALGAK
git pull --ff-only origin main
swift package describe
swift test
swift build
swift run TTALGAK
```

Record PASS/FAIL for low/mid/high launch tangent, apex and descent, actual ring collision and off-angle miss, hand/body continuity, flight pass-through/focus/non-key behavior, black/48pt/strokes/no-box, Reduced Motion no-flight, and no privacy prompts. Linux static validation below does not prove macOS/AppKit runtime behavior.

```bash
python3 Tests/verify_project.py
python3 -m py_compile Tests/verify_project.py
```
