# TTALGAK 창던지기 v2

Native macOS 13+ menu-bar mini game. The primary display keeps exactly two transparent `180 × 110 pt` AppKit anchors: left is the only local press/hold/release surface, right is display-only. Windows, Rive, external runtimes, downloads, accounts, and third-party assets are out of scope.

## Internal motion assets

- `Sources/TTALGAK/Resources/StickmanMotion/source/` tracks Maggie’s 17 original transparent black-only SVG frames and `asset-manifest.json`; `runtime/` contains their tracked `180×110` RGBA PNG frame assets.
- `Tools/regenerate_motion_pngs.py` reproduces runtime PNGs from the tracked internal transparent contact sheets using installed Python/Pillow. Exact provenance is in `Sources/TTALGAK/Resources/StickmanMotion/PROVENANCE.md`.
- SwiftPM copies `Resources/StickmanMotion`; `StickmanMotionAssets` validates artboard, ordered release frames, hand/tail/final `ballisticP0`, tangents, and every PNG before use. Missing/bad assets select the explicit code-drawn fallback; the actor is never blank.
- Ready and Aim use a discrete selected band: raw `20…35→low25`, `>35…55→mid45`, `>55…70→high65`. No continuous asset interpolation is claimed. Release freezes the selected band/manifest snapshot and Core Animation switches `entry → 053 → 107 → 160` over 160ms.
- On the next compositor boundary, the held preview is hidden with `recovery.png` and exactly one code-flight spear starts at the selected manifest final `P0`; SVG y-down tangent becomes y-up velocity tangent. The ballistic path consumes this frozen snapshot, not the old code hand geometry.

## Ballistic and lifecycle contract

- Black-only `#000000`, transparent/no-box scene, 48pt inward subject/target placement, existing 3–3.5pt rounded strokes, app-owned bottom inset, nonactivating/non-key/non-main panels, no permissions/capture/network/file/clipboard/global monitor remain unchanged.
- `BallisticFlightPath` is y-up and freezes selected asset `P0`, tangent-derived `θ`, and target X. `g=2400pt/s²`; `h25=-.022`, `h45=0`, `h65=.022`; angle-only piecewise `k(θ)` uses canonical `k25/k45/k65` values. `vx=k√(gdx)`, `vy=vx tanθ`, `Tphysics=dx/vx`.
- Standard flight is exactly 820ms without easing: `q=elapsed/.820`, `τ=qTphysics`, `x=x0+vxτ`, `y=y0+vyτ-.5gτ²`, velocity `(vx, vy-gτ)`. The 42pt shaft tail is `(x,y)` and tip is velocity-normalized. No cubic/quadratic/sine path, endpoint forcing, endpoint approach, target/result trajectory input, or velocity smoothing exists.
- Ready setup uses the canonical asset snapshot for ballistic target placement. Every score/cue is sampled actual shaft segment-circle collision against the visible `R=16pt` ring, with maximum 4pt tip substeps. Miss X is at the actual final tip.
- Accepted M-01/M-02 contract: remove the visibility-only FlightPanel at impact; TargetView retains Hit/Miss. Recovery asset remains through impact/result hold, then the existing 220ms reset phase ends in discrete Ready (no unclaimed tween/fade).
- Reduced Motion has no FlightPanel, Core Animation pose tween, ballistic translation/rotation, scale, body shift, or fade; it retains the 300ms discrete aim / 500ms static result policy.

## Mac commands and required QA

```bash
cd /Users/littleduck/Documents/GitHub/TTALGAK
git pull --ff-only origin main
swift package describe
swift test
swift build
swift run TTALGAK
```

Record PASS/FAIL and observations for asset loading/fallback, low/mid/high discrete band and release frames, final P0/tangent launch continuity, ballistic apex/descent/actual collision, recovery→Ready timing, underlying button/text/drag pass-through and focus, right/flight non-key behavior, black/no-box/180×110 bounds, Reduced Motion, and no Screen Recording/Accessibility/Input Monitoring prompt. Linux static validation below is not macOS/AppKit runtime proof.

```bash
python3 Tools/regenerate_motion_pngs.py
python3 Tests/verify_project.py
python3 -m py_compile Tests/verify_project.py Tools/regenerate_motion_pngs.py
```
