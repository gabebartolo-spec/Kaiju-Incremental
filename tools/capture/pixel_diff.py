"""Pixel diff of two stills (render plan Phase 0, for the zero-pixel items).

    py -3 -I tools/capture/pixel_diff.py before.png after.png [--out diff.png] [--tolerance 0]
        [--mask mask.png [--grow 16]]

Prints "pixel_diff: N of M pixels differ (P%), max channel delta D, mean delta X" and exits 0
when no pixel differs by more than --tolerance (per channel, 0..255), 1 otherwise, 2 on a size
mismatch. --out writes the difference, amplified 8x, for looking at where it lands.
--mask leaves out the mask's white pixels (capture_river.gd --mask: the water), grown by --grow
px so the glow and blur at the water's edge are left out too; the counts are then of the rest.
Needs Pillow.
"""

import argparse
import sys

from PIL import Image, ImageChops, ImageFilter


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("before")
    ap.add_argument("after")
    ap.add_argument("--out", default="")
    ap.add_argument("--tolerance", type=int, default=0)
    ap.add_argument("--mask", default="")
    ap.add_argument("--grow", type=int, default=16)
    args = ap.parse_args()
    a = Image.open(args.before).convert("RGB")
    b = Image.open(args.after).convert("RGB")
    if a.size != b.size:
        print(f"pixel_diff: size mismatch {a.size} vs {b.size}")
        return 2
    diff = ImageChops.difference(a, b)
    total = a.size[0] * a.size[1]
    # Per-channel max of each pixel, then count the pixels above the tolerance.
    r, g, bl = diff.split()
    peak = ImageChops.lighter(ImageChops.lighter(r, g), bl)
    keep = None
    if args.mask:
        m = Image.open(args.mask).convert("L").point(lambda v: 255 if v >= 128 else 0)
        for _ in range(args.grow // 2):  # MaxFilter(5) grows by two pixels each pass
            m = m.filter(ImageFilter.MaxFilter(5))
        keep = ImageChops.invert(m)
        total = keep.histogram()[255]
    hist = peak.histogram(mask=keep)
    over = sum(hist[args.tolerance + 1 :])
    worst = max((i for i, n in enumerate(hist) if n), default=0)
    mean = sum(i * n for i, n in enumerate(hist)) / total
    print(
        f"pixel_diff: {over} of {total} pixels differ ({100.0 * over / total:.4f}%), "
        f"max channel delta {worst}, mean delta {mean:.4f}"
    )
    if args.out:
        diff.point(lambda v: min(255, v * 8)).save(args.out)
    return 0 if over == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
