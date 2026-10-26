"""Counts dark horizontal bands across lit windows in the frames capture_window_bars.gd saves.

A lit window is a bright warm patch on a dark facade. A band is a run of dark pixels, at most
--max-band rows tall, with lit pixels directly above and below it in the same column, at least
--min-width columns wide side by side. Per frame: the bands, their pixels, and the lit pixels. Reads
<dir>/f*.png (one building's rectangle per frame) and prints one line per frame and a total.

  python -I tools/capture/window_bars_count.py <frames dir>... [--max-band 5] [--min-width 4]
      [--lit 0.55] [--save-overlay <png of the worst frame>]
"""

import argparse
import glob
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage


def luma(rgb: np.ndarray) -> np.ndarray:
    return rgb[..., 0] * 0.299 + rgb[..., 1] * 0.587 + rgb[..., 2] * 0.114


def lit_mask(rgb: np.ndarray, ref: float, share: float) -> np.ndarray:
    """Bright and warm: luma over `share` of the reference lit level, red over blue."""
    y = luma(rgb)
    warm = rgb[..., 0] > rgb[..., 2] + 8.0
    return (y > ref * share) & warm


def bands(lit: np.ndarray, max_band: int, min_width: int) -> tuple[np.ndarray, int]:
    """(mask of band pixels, number of bands): dark runs of <= max_band rows between lit pixels."""
    h, w = lit.shape
    down = np.diff(lit.astype(np.int8), axis=0)  # -1: lit then dark, +1: dark then lit
    s_y, s_x = np.nonzero(down == -1)
    e_y, e_x = np.nonzero(down == 1)
    mask = np.zeros_like(lit)
    if len(s_y) == 0 or len(e_y) == 0:
        return mask, 0
    ev_x = np.concatenate([s_x, e_x])
    ev_y = np.concatenate([s_y, e_y])
    ev_k = np.concatenate([np.zeros(len(s_x), np.int8), np.ones(len(e_x), np.int8)])
    order = np.lexsort((ev_y, ev_x))
    ev_x, ev_y, ev_k = ev_x[order], ev_y[order], ev_k[order]
    for i in range(len(ev_x) - 1):
        if ev_k[i] == 0 and ev_k[i + 1] == 1 and ev_x[i] == ev_x[i + 1]:
            top, bottom = ev_y[i] + 1, ev_y[i + 1]  # dark rows top..bottom inclusive
            if bottom - top + 1 <= max_band:
                mask[top : bottom + 1, ev_x[i]] = True
    labels, n = ndimage.label(mask, structure=np.ones((3, 3)))
    keep = np.zeros_like(mask)
    count = 0
    for k, sl in enumerate(ndimage.find_objects(labels), start=1):
        width = sl[1].stop - sl[1].start
        if width >= min_width:
            keep[labels == k] = True
            count += 1
    return keep, count


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("dirs", nargs="+")
    ap.add_argument("--max-band", type=int, default=5)
    ap.add_argument("--min-width", type=int, default=4)
    ap.add_argument("--lit", type=float, default=0.55)
    ap.add_argument("--save-overlay", default="")
    a = ap.parse_args()
    for d in a.dirs:
        files = sorted(glob.glob(os.path.join(d, "f*.png")))
        if not files:
            print(f"{d}: no frames", file=sys.stderr)
            continue
        counts = []
        worst = (-1, None, None)
        ref = None
        for path in files:
            rgb = np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)
            if ref is None:  # the lit level of the first frame: its 99.7th luma percentile
                ref = float(np.percentile(luma(rgb), 99.7))
            lit = lit_mask(rgb, ref, a.lit)
            mask, n = bands(lit, a.max_band, a.min_width)
            counts.append((n, int(mask.sum()), int(lit.sum())))
            if n > worst[0]:
                worst = (n, path, (rgb, lit, mask))
        total = sum(c[0] for c in counts)
        frames_with = sum(1 for c in counts if c[0] > 0)
        per = " ".join(str(c[0]) for c in counts)
        print(
            f"{d}: frames {len(counts)} lit_ref {ref:.0f} bands total {total} "
            f"frames_with_bands {frames_with} max {max(c[0] for c in counts)} "
            f"band_px {sum(c[1] for c in counts)} lit_px {sum(c[2] for c in counts)}"
        )
        print(f"  per frame: {per}")
        if a.save_overlay and worst[2] is not None:
            rgb, lit, mask = worst[2]
            out = rgb.copy()
            out[mask] = [255, 0, 255]
            Image.fromarray(out.astype(np.uint8)).save(a.save_overlay)
    return 0


if __name__ == "__main__":
    sys.exit(main())
