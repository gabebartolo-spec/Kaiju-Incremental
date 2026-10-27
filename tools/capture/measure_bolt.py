#!/usr/bin/env python3
"""measure_bolt.py: pass-bar numbers for the lightning bolt, measured from the rendered stills.

  python tools/capture/measure_bolt.py <capture dir> <godot log> [--onset <first> <last>]

The capture (capture_bolt.gd) prints POINTS (mouth and struck point in pixels) and POLY (the drawn
polylines in pixels) lines to its log, one set per still; this reads the still PNGs and measures:
  core width: along the main channel, the run of near-white pixels across it (share of the visible
              samples that are >= 8 px wide at 4K, median width);
  brightest 1%: where the brightest 1% of the frame's pixels lie (share near the strike / the mouth);
  noon contrast: mean luma of the core pixels over the ground ring beside the channel;
  onset (--onset): total luma of bolt-coloured pixels per frame, and each frame's rise.
"""
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image

NEAR = 350  # px: "at the strike" / "at the mouth"
WIDE = 8  # px at 4K
STEP = 5  # px between width samples


def luma(a):
    return 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]


def masks(a):
    core = a.min(axis=2) >= 235
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    orange = (r >= 250) & (g >= 110) & (g <= 235) & (b <= 150)
    return core, core | orange


def parse(log):
    pts, polys = {}, {}
    for line in Path(log).read_text(errors="ignore").splitlines():
        m = re.match(r"POINTS (\S+) mouth=(-?\d+),(-?\d+) hit=(-?\d+),(-?\d+)", line)
        if m:
            n = m.group(1)
            pts[n] = [np.array([int(m.group(2)), int(m.group(3))]), np.array([int(m.group(4)), int(m.group(5))])]
            continue
        m = re.match(r"POLY (\S+) (main|branch)(.*)", line)
        if m:
            p = [tuple(int(v) for v in t.split(",")) for t in m.group(3).split()]
            polys.setdefault(m.group(1), []).append((m.group(2), np.array(p, float)))
    return pts, polys


def samples(poly):
    out = []
    for i in range(len(poly) - 1):
        a, b = poly[i], poly[i + 1]
        n = max(int(np.linalg.norm(b - a) / STEP), 1)
        d = (b - a) / max(np.linalg.norm(b - a), 1e-6)
        for k in range(n):
            out.append((a + (b - a) * k / n, d))
    return out


def widths(core, poly):
    h, w = core.shape
    out, seen, total = [], 0, 0
    for p, d in samples(poly):
        n = np.array([-d[1], d[0]])
        total += 1
        run = []
        for t in range(-60, 61):
            x, y = (p + n * t).round().astype(int)
            run.append(core[y, x] if 0 <= x < w and 0 <= y < h else False)
        run = np.array(run)
        if not run[56:65].any():
            continue
        seen += 1
        i = 60 + int(np.argmax(run[56:65])) - 4
        lo = hi = i
        while lo > 0 and run[lo - 1]:
            lo -= 1
        while hi < 120 and run[hi + 1]:
            hi += 1
        out.append(hi - lo + 1)
    return out, seen, total


def ring_contrast(a, core, bolt, poly):
    h, w = core.shape
    lum = luma(a)
    cl, gl = [], []
    for p, d in samples(poly):
        n = np.array([-d[1], d[0]])
        for t in range(-60, 61):
            x, y = (p + n * t).round().astype(int)
            if not (0 <= x < w and 0 <= y < h):
                continue
            if core[y, x]:
                cl.append(lum[y, x])
            elif abs(t) >= 20 and not bolt[y, x]:
                gl.append(lum[y, x])
    if not cl or not gl:
        return 0.0, 0.0, 0.0
    return float(np.mean(cl)), float(np.mean(gl)), float(np.mean(cl) / np.mean(gl))


def share_near(pix, hit, mouth):
    """Shares of `pix` within NEAR px of the strike / of the mouth, each pixel counted for whichever is nearer."""
    dh = np.linalg.norm(pix - hit, axis=1)
    dm = np.linalg.norm(pix - mouth, axis=1)
    return ((dh < NEAR) & (dh <= dm)).mean(), ((dm < NEAR) & (dm < dh)).mean()


def still(dirp, name, pts, polys):
    a = np.asarray(Image.open(Path(dirp) / f"{name}.png").convert("RGB"))
    core, bolt = masks(a)
    lum = luma(a)
    mouth, hit = pts[name]
    thr = np.percentile(lum, 99)
    ys, xs = np.nonzero(lum >= thr)
    pix = np.stack([xs, ys], 1)
    nh, nm = share_near(pix, hit, mouth)
    # the same on bolt-coloured pixels only (city windows excluded)
    bys, bxs = np.nonzero(bolt)
    bp = np.stack([bxs, bys], 1)
    bt = np.percentile(lum[bolt], 99) if bolt.any() else 0
    sel = bp[lum[bys, bxs] >= bt] if bolt.any() else bp
    bh, bm = share_near(sel, hit, mouth) if len(sel) else (0, 0)
    main = [p for k, p in polys.get(name, []) if k == "main"]
    ws, seen, total = [], 0, 0
    mws = []
    for kind, poly in polys.get(name, []):  # the main channel and every fork
        w2, s2, t2 = widths(core, poly)
        if kind == "main":
            mws = w2
        ws, seen, total = ws + w2, seen + s2, total + t2
    wide = np.mean([x >= WIDE for x in ws]) if ws else 0
    cm, gm, ratio = ring_contrast(a, core, bolt, main[0]) if main else (0, 0, 0)
    print(
        f"{name}: top1% luma>={thr:.0f}: near_hit={nh:.2f} near_mouth={nm:.2f} | bolt-colour top1%: "
        f"near_hit={bh:.2f} near_mouth={bm:.2f} | bolt core visible {seen}/{total} samples, "
        f">=8px {wide:.2f}, median {np.median(ws) if ws else 0:.0f}px (main channel alone: median {np.median(mws) if mws else 0:.0f}px, {len(mws)} samples) | core luma {cm:.0f} ground {gm:.0f} ratio {ratio:.2f}"
    )


def onset(dirp, prefix, first, last):
    totals, base = [], None
    for f in range(first, last + 1):
        a = np.asarray(Image.open(Path(dirp) / f"{prefix}_f{f:03d}.png").convert("RGB"))
        lum = luma(a)
        base = lum if base is None else base
        # light the frame gained over the first frame (the leader, the stroke, the lights it throws)
        totals.append(float(np.clip(lum - base, 0, None).sum()))
    peak = max(totals) or 1.0
    print("onset: light gained over the first frame, by frame:", " ".join(f"f{first + i}:{t / 1e6:.2f}M" for i, t in enumerate(totals)))
    print("jumps (share of peak):", " ".join(f"{(totals[i] - totals[i - 1]) / peak:+.2f}" for i in range(1, len(totals))))


if __name__ == "__main__":
    dirp, log = sys.argv[1], sys.argv[2]
    pts, polys = parse(log)
    if "--onset" in sys.argv:
        i = sys.argv.index("--onset")
        prefix = sorted(pts)[0].rsplit("_f", 1)[0]
        onset(dirp, prefix, int(sys.argv[i + 1]), int(sys.argv[i + 2]))
    else:
        for name in sorted(pts):
            still(dirp, name, pts, polys)
