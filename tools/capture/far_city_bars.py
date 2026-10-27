#!/usr/bin/env python3
"""far_city_bars.py: the far-city fog bars (director comment #37) from capture_far_city.gd's files.

For one time of day, before and after (--dir holds far_city_<time>_<tag>_4k.png and <time>_<tag>_*):
  - masks by hiding (from the BEFORE files; the camera and the geometry are the same after): the far
    skyline = pixels that change when it is hidden, minus pixels that change between two plain frames
    (animation); the bay = pixels that change when the water is hidden, minus the far skyline.
  - the far shore line: every image column where the far skyline's lowest pixel sits at most GAP_PX
    above the bay's highest (the far shore's strip between). In each, the far city's FOOT band
    (FOOT_PX rows up from its lowest pixel) and the bay's FAR band (FOOT_PX rows down from its
    highest). Their median sRGB colours, before and after: the far city's foot against the bay at the
    same distance (bar: within 10%, as the largest channel difference over the bay's largest channel,
    over 255, and as the luma difference over the bay's luma) and the median per-column luma step
    across the line (the crisp base line).
  - the bay: mean abs difference of its still pixels before vs after (bar: ~0, the bay reads as it did).
  - near crop (the bottom NEAR_SHARE of the frame: the play city and the kaiju): mean abs difference
    of the still pixels before vs after and the share off by more than 3 (bar: ~0).
  - the fog line from each JSON: the share of fog along the camera's line, play city edge to the far
    back row; whether it ever falls (bar: never) and the far city's foot hazier than its crown.
  - any <time>_after_sweep_*.png (capture_far_city.gd --sweep): the same shore-line numbers each.
Usage: python tools/capture/far_city_bars.py --dir <out> --time night
"""
import argparse
import glob
import json
import os

import numpy as np
from PIL import Image

ANIM_TOL = 3  # 0-255: a pixel that moves this much between two plain frames is animation
HIDE_TOL = 6  # ...and one that moves more than this when a layer is hidden belongs to it
FOOT_PX = 10  # rows each side of the far shore line (4K)
GAP_PX = 24  # the far city's lowest pixel and the bay's highest are this close (the shore's strip)
NEAR_SHARE = 0.3
NEAR_TOL = 3
MIN_COLUMNS = 40


def load(path):
    return np.asarray(Image.open(path).convert("RGB")).astype(np.int16)


def luma(c):
    return 0.2126 * c[..., 0] + 0.7152 * c[..., 1] + 0.0722 * c[..., 2]


def frames(d, time, tag):
    shot = load(os.path.join(d, f"far_city_{time}_{tag}_4k.png"))
    again = load(os.path.join(d, f"{time}_{tag}_again.png"))
    still = np.abs(shot - again).max(axis=2) <= ANIM_TOL
    return shot, still


def masks(d, time):
    shot, still = frames(d, time, "before")
    nofar = load(os.path.join(d, f"{time}_before_nofar.png"))
    nobay = load(os.path.join(d, f"{time}_before_nobay.png"))
    far = (np.abs(shot - nofar).max(axis=2) > HIDE_TOL) & still
    bay = (np.abs(shot - nobay).max(axis=2) > HIDE_TOL) & ~far
    return far, bay


def shore_columns(far, bay):
    cols = []
    for x in range(far.shape[1]):
        fr = np.flatnonzero(far[:, x])
        br = np.flatnonzero(bay[:, x])
        if fr.size == 0 or br.size == 0:
            continue
        low, top = fr.max(), br.min()
        if not 0 <= top - low <= GAP_PX or low < FOOT_PX or top + FOOT_PX > far.shape[0]:
            continue
        cols.append((x, fr[fr > low - FOOT_PX], br[br < top + FOOT_PX]))
    return cols


def shore(img, cols):
    foot = np.array([np.median(img[rf, x], axis=0) for x, rf, _ in cols])
    water = np.array([np.median(img[rb, x], axis=0) for x, _, rb in cols])
    f, w = np.median(foot, axis=0), np.median(water, axis=0)
    diff = float(np.max(np.abs(f - w)))
    return {
        "foot_rgb": [round(float(v), 1) for v in f],
        "bay_rgb": [round(float(v), 1) for v in w],
        "foot_vs_bay_rel": round(diff / max(1.0, float(np.max(w))), 3),
        "foot_vs_bay_of_255": round(diff / 255.0, 3),
        "foot_vs_bay_luma_rel": round(abs(float(luma(f) - luma(w))) / max(1.0, float(luma(w))), 3),
        "column_luma_step": round(float(np.median(np.abs(luma(foot) - luma(water)))), 2),
    }


def fog_line(d, time, tag):
    with open(os.path.join(d, f"{time}_{tag}.json"), encoding="utf-8") as fh:
        data = json.load(fh)
    line = data["line"]
    along = [r["fog"] for r in sorted(line, key=lambda r: r["metres"]) if "crown" not in r["where"]]
    crown = next(r["fog"] for r in line if "crown" in r["where"])
    foot = next(r["fog"] for r in line if "front row foot" in r["where"])
    return {
        "far_takes_engine_fog": data["far_takes_engine_fog"],
        "line": [(r["where"], r["metres"], r["fog"]) for r in line],
        "never_falls": all(b >= a - 1e-4 for a, b in zip(along, along[1:])),
        "foot_minus_crown": round(foot - crown, 3),
    }


def still_diff(a, b, mask):
    diff = np.abs(a - b).max(axis=2)[mask]
    return {
        "mean_abs": round(float(diff.mean()), 3),
        f"share_over_{NEAR_TOL}": round(float((diff > NEAR_TOL).mean()), 5),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", required=True)
    ap.add_argument("--time", required=True)
    a = ap.parse_args()
    far, bay = masks(a.dir, a.time)
    cols = shore_columns(far, bay)
    before, still_b = frames(a.dir, a.time, "before")
    after, still_a = frames(a.dir, a.time, "after")
    still = still_b & still_a
    near = np.zeros_like(still)
    near[int(still.shape[0] * (1.0 - NEAR_SHARE)):] = True
    report = {
        "time": a.time,
        "far_px": int(far.sum()),
        "bay_px": int(bay.sum()),
        "shore_columns": len(cols),
        "fog_before": fog_line(a.dir, a.time, "before"),
        "fog_after": fog_line(a.dir, a.time, "after"),
        "bay_before_vs_after": still_diff(before, after, bay & still),
        "near_crop_before_vs_after": still_diff(before, after, near & still & ~far),
    }
    if len(cols) >= MIN_COLUMNS:
        report["shore_before"] = shore(before, cols)
        report["shore_after"] = shore(after, cols)
        for path in sorted(glob.glob(os.path.join(a.dir, f"{a.time}_after_sweep_*.png"))):
            name = os.path.basename(path)[len(f"{a.time}_after_sweep_"):-4]
            report[f"sweep {name}"] = shore(load(path), cols)
    print(json.dumps(report, indent=1))


if __name__ == "__main__":
    main()
