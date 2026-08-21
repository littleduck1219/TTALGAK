#!/usr/bin/env python3
"""Rebuild tracked 180x110 runtime PNGs from internal transparent source contact sheets."""
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1] / "Sources/TTALGAK/Resources/StickmanMotion"
source, runtime = root / "source", root / "runtime"
runtime.mkdir(exist_ok=True)
standard = ["ready.svg", "aim-low-25.svg", "aim-mid-45.svg", "aim-high-65.svg", "release-entry-low-25.svg", "release-entry-mid-45.svg", "release-entry-high-65.svg", "recovery.svg"]
sheet = Image.open(source / "contact-sheet.png")
assert sheet.size == (1440, 440) and sheet.mode == "RGBA"
for index, name in enumerate(standard):
    x, y = index % 4 * 360, index // 4 * 220
    sheet.crop((x, y, x + 360, y + 220)).resize((180, 110), Image.Resampling.LANCZOS).save(runtime / (Path(name).stem + ".png"))
sweep = Image.open(source / "contact-sheet-release-sweep.png")
assert sweep.size == (720, 330) and sweep.mode == "RGBA"
for row, band in enumerate(("low-25", "mid-45", "high-65")):
    for col, offset in enumerate(("053", "107", "160")):
        sweep.crop(((col + 1) * 180, row * 110, (col + 2) * 180, (row + 1) * 110)).save(runtime / f"release-sweep-{band}-{offset}.png")
for png in runtime.glob("*.png"):
    image = Image.open(png)
    assert image.size == (180, 110) and image.mode == "RGBA", png
print(f"regenerated {len(list(runtime.glob('*.png')))} 180x110 RGBA runtime frames")
