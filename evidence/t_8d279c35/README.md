# TTALGAK v3 fixed-pull correction evidence

Kanban: `t_8d279c35`

Baseline: `main` at `3f4114b933f11d3ad0c674a097a9cf4091f665ed`

## Accepted behavior

- Full physical reverse pull is fixed at 160pt with a 6pt dead zone and `power=clamp((rawPull-6)/154,0,1)`.
- Tension is `clamp(rawPull/160*160,0,160)pt`; 80pt raw pull gives 80pt tension and about half power, while 160pt gives full power and 160pt tension.
- The frozen tangent latch keeps raw pull, power, and tension stable during vertical-only angle changes. Continued movement on the frozen reverse axis increases them.
- Gesture calculation needs local points only. The rejected display-bound geometry, edge-dependent scaling, extra input-window recovery, and pull screen-coordinate conversion are absent.
- Existing asymmetric 10…65° angles, hit-only target lifecycle, 50-item ground-miss FIFO, scene flight visibility, and safety boundaries remain guarded.

## TDD and Linux verification

- RED: a baseline-source assertion confirmed `3f4114b` lacks the accepted fixed-160 implementation and contains the rejected geometry/recovery feature.
- GREEN: `python3 Tests/verify_project.py` passes.
- Python compile: `python3 -m py_compile Tests/verify_project.py Tools/regenerate_motion_pngs.py` passes.
- Patch hygiene: `git diff --check` passes.
- Repository integrity: `git fsck --full` passes.
- Forbidden-term scan across source, Swift tests, and README is clean (the verifier itself necessarily names forbidden constructs in its rejection list).

Linux has no Swift toolchain in this environment. These results do not prove Swift/AppKit compilation or macOS runtime behavior.

## Mandatory Mac acceptance handoff

```bash
cd /Users/littleduck/Documents/GitHub/TTALGAK
git pull --ff-only origin main
swift package describe
swift test
swift build
swift run TTALGAK
```

Record PASS/FAIL for:

1. A 160pt physical reverse pull reaches full power and shows 160pt tension without touching or depending on a screen edge; an 80pt pull shows 80pt tension and approximately half power.
2. After latching, vertical-only movement changes angle without changing raw pull, power, or tension; further frozen-axis reverse movement increases them.
3. Press-held local drag/up remains valid outside the input panel while the AppKit event stream remains held.
4. No extra capture/input window appears, no display-edge capture is required or supported, and ordinary desktop points pass through normally.
5. Build/test/run succeeds with no Accessibility, Input Monitoring, or Screen Recording prompt.
6. The full M-V3 matrix in the company README passes, including 10…65° mapping, flight visibility, hit-only target movement, and the 50-miss FIFO.
