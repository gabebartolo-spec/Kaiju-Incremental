"""Measures capture_facade_carve.gd's shots (D-289): how much a step changes the UNTOUCHED upper
half of a building.

    python tools/capture/facade_diff.py <dir with the PNGs and <tag>.json files> [step ...]

Per building (<tag>.json): the building's pixels are those that differ from the `hidden` shot by
more than 2/255 in any channel, on the rows above the building's mid-height inside its screen
rectangle. Pixels that already differ by more than 1/255 between the two identical shots a0 and a1
(smoke, fire, anything animated behind the frozen city) are left out and counted. Per step
(slabs, hit, promote: whichever shots exist) it prints the per-channel mean step and the 99th
percentile and share over 4/255 of the largest channel step. The pass bar (lead, 2026-10-27): mean
<= 1/255 per channel and 99th percentile <= 4/255.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

STEPS = ("slabs", "hit", "promote")


def load(path: Path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGB")).astype(np.int16)


def stats(a: np.ndarray, b: np.ndarray, keep: np.ndarray) -> str:
    d = np.abs(a - b)[keep]
    worst = d.max(axis=1)
    mean = d.mean(axis=0)
    return "mean R %.2f G %.2f B %.2f /255, p99 %d /255, %.1f%% of px step > 4" % (
        mean[0], mean[1], mean[2], np.percentile(worst, 99), 100.0 * (worst > 4).mean())


def building(folder: Path, tag: str, steps: tuple) -> None:
    meta = json.loads((folder / (tag + ".json")).read_text())
    x, y, w, h = meta["rect"]
    rows = slice(y, max(y, min(meta["mid_row"], y + h)))
    cols = slice(x, x + w)
    a0, a1, hidden = (load(folder / ("%s_%s.png" % (tag, n))) for n in ("a0", "a1", "hidden"))
    region = np.zeros(a0.shape[:2], dtype=bool)
    region[rows, cols] = True
    mine = region & (np.abs(a0 - hidden).max(axis=2) > 2)
    stable = np.abs(a0 - a1).max(axis=2) <= 1
    keep = mine & stable
    print("%s: %d building px in the upper half, %d left out as unstable between two identical shots"
          % (tag, mine.sum(), (mine & ~stable).sum()))
    if keep.sum() == 0:
        return
    print("  noise floor a0 vs a1 (stable px only): " + stats(a0, a1, keep))
    for step in steps:
        path = folder / ("%s_%s.png" % (tag, step))
        if path.exists():
            print("  %-7s " % step + stats(a0, load(path), keep))


def main() -> None:
    folder = Path(sys.argv[1])
    steps = tuple(sys.argv[2:]) or STEPS
    for meta in sorted(folder.glob("*.json")):
        building(folder, meta.stem, steps)


if __name__ == "__main__":
    main()
