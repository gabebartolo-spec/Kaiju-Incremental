"""Counts dark horizontal bars at lit windows in the frames capture_window_bars.gd saves.

A lit window is a bright warm patch on a dark facade. Two counts per frame, from
<dir>/f*.png (one building's rectangle per frame):
  between : a run of dark pixels, at most --max-band rows tall, with lit pixels directly above and
            below it in the same column, --min-width columns wide side by side (a bar cutting a
            lit window in two).
  strips  : a connected patch of black pixels (every channel <= --black on 0..255) at least --min-strip
            wide and at most --max-strip tall, wider than twice its height (a horizontal strip),
            and strips_lit of those within --near px of a lit window (a bar at a window).
Prints one line per directory (totals, frames with any, per-frame counts).

  python tools/capture/window_bars_count.py <frames dir>... [--black 3] [--save-overlay x.png]
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


def between(lit: np.ndarray, max_band: int, min_width: int) -> tuple[np.ndarray, int]:
    """(mask of band pixels, number of bands): dark runs of <= max_band rows between lit pixels."""
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
    return components(mask, min_width, 1.0e9, 0.0)


def components(
    mask: np.ndarray, min_width: int, max_height: float, min_aspect: float
) -> tuple[np.ndarray, int]:
    """The 8-connected patches of `mask` at least min_width wide, at most max_height tall and
    min_aspect times wider than tall: (their pixels, how many)."""
    labels, _ = ndimage.label(mask, structure=np.ones((3, 3)))
    keep = np.zeros_like(mask)
    count = 0
    for k, sl in enumerate(ndimage.find_objects(labels), start=1):
        width = sl[1].stop - sl[1].start
        height = sl[0].stop - sl[0].start
        if width >= min_width and height <= max_height and width >= min_aspect * height:
            keep[sl][labels[sl] == k] = True
            count += 1
    return keep, count


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("dirs", nargs="+")
    ap.add_argument("--max-band", type=int, default=5)
    ap.add_argument("--min-width", type=int, default=4)
    ap.add_argument("--lit", type=float, default=0.55)
    ap.add_argument("--black", type=float, default=2.0)
    ap.add_argument("--min-strip", type=int, default=8)
    ap.add_argument("--max-strip", type=int, default=16)
    ap.add_argument("--near", type=int, default=3)
    ap.add_argument("--save-overlay", default="")
    a = ap.parse_args()
    for d in a.dirs:
        files = sorted(glob.glob(os.path.join(d, "f[0-9][0-9][0-9].png")))
        if not files:
            print(f"{d}: no frames", file=sys.stderr)
            continue
        rows = []
        worst = (-1, None)
        ref = None
        for path in files:
            rgb = np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)
            if ref is None:  # the lit level of the first frame: its 99.7th luma percentile
                ref = float(np.percentile(luma(rgb), 99.7))
            lit = lit_mask(rgb, ref, a.lit)
            gap_mask, gaps = between(lit, a.max_band, a.min_width)
            strips_mask, strips = components(rgb.max(axis=-1) <= a.black, a.min_strip, a.max_strip, 2.0)
            near = ndimage.binary_dilation(lit, iterations=a.near)
            labels, n = ndimage.label(strips_mask, structure=np.ones((3, 3)))
            touching = 0
            if n:
                touching = int(
                    sum(1 for k in np.unique(labels[near & strips_mask]) if k > 0)
                )
            rows.append((gaps, strips, touching, int(strips_mask.sum()), int(lit.sum())))
            if strips > worst[0]:
                out = rgb.copy()
                out[strips_mask] = [255, 0, 255]
                out[gap_mask] = [0, 255, 255]
                worst = (strips, out)
        total = [sum(r[i] for r in rows) for i in range(5)]
        print(
            f"{d}: frames {len(rows)} lit_ref {ref:.0f} between {total[0]} "
            f"(frames with {sum(1 for r in rows if r[0])}) strips {total[1]} "
            f"(frames with {sum(1 for r in rows if r[1])}, max {max(r[1] for r in rows)}) "
            f"strips_at_lit {total[2]} (frames with {sum(1 for r in rows if r[2])}) "
            f"strip_px {total[3]}"
        )
        print("  strips per frame:", " ".join(str(r[1]) for r in rows))
        print("  strips_at_lit per frame:", " ".join(str(r[2]) for r in rows))
        if a.save_overlay and worst[1] is not None:
            Image.fromarray(worst[1].astype(np.uint8)).save(a.save_overlay)
    return 0


if __name__ == "__main__":
    sys.exit(main())
