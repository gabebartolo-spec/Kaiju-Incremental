"""Pixel diff of two stills (render plan Phase 0, for the zero-pixel items).

    py -3 -I tools/capture/pixel_diff.py before.png after.png [--out diff.png] [--tolerance 0]

Prints "pixel_diff: N of M pixels differ (P%), max channel delta D, mean delta X" and exits 0
when no pixel differs by more than --tolerance (per channel, 0..255), 1 otherwise, 2 on a size
mismatch. --out writes the difference, amplified 8x, for looking at where it lands.
Needs Pillow.
"""

import argparse
import sys

from PIL import Image, ImageChops


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("before")
    ap.add_argument("after")
    ap.add_argument("--out", default="")
    ap.add_argument("--tolerance", type=int, default=0)
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
    hist = peak.histogram()
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
