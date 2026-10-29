"""Water surface measurements (D-325 step 1, the surface) on 4K stills from capture_river.gd.

    python tools/capture/water_metrics.py <still.png> <mask.png> [--other <still.png>]
        [--box W,H] [--erode 12] [--sigma 12] [--min-offset 64] [--crop <out.png>]

The mask is capture_river's --mask frame: the water sheets white, everything else black.
  - crop: a box of --box pixels lying wholly in the mask eroded by
    --erode px (water only: no kaiju, quay or splash in it), the one nearest the image's centre;
    --other measures the same box in a second still (main's), so the pair compares like for like.
  - std: the luminance (Rec. 709, 0..255) standard deviation over the box, per still.
  - autocorrelation: the box's luminance, high-passed (minus a Gaussian blur of --sigma px, so the
    sky's gradient across the box is not read as a repeat), zero-padded, normalised to 1 at no
    offset; the peak at any offset longer than --min-offset px. A tiling texture shows a peak
    near 1 at its period; the bar is under 0.3.
Prints one "water_metrics:" line per still. Needs numpy and Pillow.
"""

import argparse
import sys

import numpy as np
from PIL import Image, ImageFilter


def luma(path: str) -> np.ndarray:
    rgb = np.asarray(Image.open(path).convert("RGB"), dtype=np.float64)
    return rgb[..., 0] * 0.2126 + rgb[..., 1] * 0.7152 + rgb[..., 2] * 0.0722


def water(path: str, erode: int) -> np.ndarray:
    m = Image.open(path).convert("L").point(lambda v: 255 if v >= 128 else 0)
    for _ in range(erode // 2):  # MinFilter(5) erodes by two pixels each pass
        m = m.filter(ImageFilter.MinFilter(5))
    return np.asarray(m) > 0


def find_box(mask: np.ndarray, w: int, h: int):
    """The w x h box wholly in the mask nearest the image centre, or None."""
    integral = np.pad(mask.astype(np.int64).cumsum(0).cumsum(1), ((1, 0), (1, 0)))
    full = w * h
    rows, cols = mask.shape
    sums = integral[h:, w:] - integral[:-h, w:] - integral[h:, :-w] + integral[:-h, :-w]
    ys, xs = np.nonzero(sums == full)
    if ys.size == 0:
        return None
    cy, cx = rows / 2.0, cols / 2.0
    k = np.argmin((ys + h / 2.0 - cy) ** 2 + (xs + w / 2.0 - cx) ** 2)
    return int(xs[k]), int(ys[k])


def blur(a: np.ndarray, sigma: float) -> np.ndarray:
    r = int(3 * sigma)
    x = np.arange(-r, r + 1)
    k = np.exp(-(x**2) / (2 * sigma * sigma))
    k /= k.sum()
    pad = np.pad(a, r, mode="reflect")
    a = np.apply_along_axis(lambda v: np.convolve(v, k, mode="valid"), 1, pad)
    return np.apply_along_axis(lambda v: np.convolve(v, k, mode="valid"), 0, a)


def autocorr_peak(a: np.ndarray, sigma: float, min_offset: int) -> tuple:
    hp = a - blur(a, sigma)
    hp -= hp.mean()
    h, w = hp.shape
    f = np.fft.rfft2(hp, s=(2 * h, 2 * w))
    ac = np.fft.irfft2(f * np.conj(f), s=(2 * h, 2 * w))
    ac = np.fft.fftshift(ac)
    # normalise per offset by the overlap, and to 1 at no offset
    ones = np.fft.rfft2(np.ones_like(hp), s=(2 * h, 2 * w))
    overlap = np.fft.fftshift(np.fft.irfft2(ones * np.conj(ones), s=(2 * h, 2 * w)))
    zero = ac[h, w] / overlap[h, w]
    if zero <= 0:
        return 0.0, (0, 0)
    dy, dx = np.mgrid[-h : h, -w : w]
    keep = (np.hypot(dy, dx) > min_offset) & (overlap > 0.25 * h * w)  # at least a quarter overlaps
    norm = np.where(keep, ac / np.maximum(overlap, 1) / zero, -np.inf)
    k = np.unravel_index(np.argmax(norm), norm.shape)
    return float(norm[k]), (int(dx[k]), int(dy[k]))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("still")
    ap.add_argument("mask")
    ap.add_argument("--other", default="")
    ap.add_argument("--box", default="1024,512")
    ap.add_argument("--erode", type=int, default=12)
    ap.add_argument("--sigma", type=float, default=12.0)
    ap.add_argument("--min-offset", type=int, default=64)
    ap.add_argument("--crop", default="")
    args = ap.parse_args()
    w, h = (int(v) for v in args.box.split(","))
    mask = water(args.mask, args.erode)
    at = find_box(mask, w, h)
    if at is None:
        print(f"water_metrics: no {w}x{h} box of water in {args.mask} (eroded {args.erode} px)")
        return 2
    x, y = at
    for path in [args.still] + ([args.other] if args.other else []):
        box = luma(path)[y : y + h, x : x + w]
        peak, off = autocorr_peak(box, args.sigma, args.min_offset)
        print(
            f"water_metrics: {path} box {w}x{h} at {x},{y}: luminance std {box.std():.2f}, "
            f"mean {box.mean():.1f}; autocorrelation peak past {args.min_offset} px {peak:.3f} "
            f"at offset {off}"
        )
    if args.crop:
        Image.open(args.still).convert("RGB").crop((x, y, x + w, y + h)).save(args.crop)
    return 0


if __name__ == "__main__":
    sys.exit(main())
