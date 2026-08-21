# TTALGAK internal stickman motion asset provenance

- Origin: Maggie’s original internal artwork at `/home/littleduck/.hermes/company/ttalgak/assets/stickman-motion-v0.1/`.
- License: Copyright 2026 Littleducks's Company; internal TTALGAK use only.
- External assets/accounts/downloads/installations: none.

## Tracked chain

1. `source/*.svg` are byte copies of the canonical 17 SVG frames; `asset-manifest.json` is the canonical frame/tangent/continuity manifest.
2. `source/contact-sheet.png` (8 base frames at 2× grid) and `source/contact-sheet-release-sweep.png` (3×4 sweep grid at 1×) are original internal transparent renders supplied with the asset set.
3. `Tools/regenerate_motion_pngs.py` crops those exact source renders into `runtime/*.png`, each transparent RGBA `180×110` at 1:1. It does not download, install, or invoke an external renderer.
4. SwiftPM `.copy("Resources/StickmanMotion")` bundles this directory. Runtime validates manifest continuity and PNG presence before using a `CALayer`; failure selects the code-drawn fallback.

## Frame mapping

- Base sheet row-major: `ready`, `aim-low-25`, `aim-mid-45`, `aim-high-65`, `release-entry-low-25`, `release-entry-mid-45`, `release-entry-high-65`, `recovery`.
- Sweep sheet row-major: `low25`, `mid45`, `high65`; each row is entry, 053ms, 107ms, 160ms. Entry PNGs are the paired base-sheet release entries; sweep PNGs are cropped from columns 1–3.
- Release final snapshot is manifest `ballisticP0`; tangent converts from SVG y-down `(x,y)` to ballistic y-up `(x,-y)`.

Run `python3 Tools/regenerate_motion_pngs.py` followed by `python3 Tests/verify_project.py` to verify the tracked runtime asset set.
