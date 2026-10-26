#!/usr/bin/env python3
"""p1c_metrics.py: the numbers for render-plan batch P1c, from the stills of p1c_stills.sh.

For every PNG in a folder (or the files named):
  clip0_2   share of pixels whose brightest channel is 0-2 of 255 (item 4's clipped share)
  low8      share at 8 or below
  mid_luma  mean luma (0-255) of the pixels whose luma is 64-192 (item 4: must move under 3%)
  steps     distinct 8-bit luma values down the sky column (item 3: rises with debanding dither)
  sky_rows  how many sky rows were read
Also writes <name>_sky2x.png beside each still: the sky strip cropped and doubled (nearest), for the 2x look.

Run: py -3 -I tools/capture/p1c_metrics.py <folder or pngs> [--column=0.5] [--sky=0.30]
  --column  the sky column as a share of the width (default 0.5)
  --sky     the top share of the image treated as sky (default 0.30)
Pairs (..._cur/_new, _off/_deband/_sharp/_both) are listed together with the change against the first.
"""
import glob
import os
import sys

from PIL import Image


def luma(r, g, b):
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def measure(path, column, sky):
    img = Image.open(path).convert("RGB")
    w, h = img.size
    px = img.load()
    n = clip = low = mid_n = 0
    mid_sum = 0.0
    step = 4  # every 4th pixel each way: 0.5 M samples at 4K
    for y in range(0, h, step):
        for x in range(0, w, step):
            r, g, b = px[x, y]
            top = max(r, g, b)
            n += 1
            if top <= 2:
                clip += 1
            if top <= 8:
                low += 1
            lu = luma(r, g, b)
            if 64 <= lu <= 192:
                mid_n += 1
                mid_sum += lu
    x = min(w - 1, int(w * column))
    rows = max(1, int(h * sky))
    steps = len({round(luma(*px[x, y])) for y in range(rows)})
    box = (max(0, x - w // 8), 0, min(w, x + w // 8), rows)
    img.crop(box).resize(((box[2] - box[0]) * 2, rows * 2), Image.NEAREST).save(
        os.path.splitext(path)[0] + "_sky2x.png"
    )
    return {
        "clip0_2": clip / n,
        "low8": low / n,
        "mid_luma": mid_sum / mid_n if mid_n else 0.0,
        "steps": steps,
        "sky_rows": rows,
    }


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
    column = float(opts.get("column", 0.5))
    sky = float(opts.get("sky", 0.30))
    files = []
    for a in args or ["."]:
        files += sorted(glob.glob(os.path.join(a, "*.png"))) if os.path.isdir(a) else [a]
    files = [f for f in files if not f.endswith("_sky2x.png")]
    first = {}
    print(f"{'still':44} {'clip0_2':>8} {'low8':>7} {'mid_luma':>9} {'steps':>6}  vs first of set")
    for f in files:
        m = measure(f, column, sky)
        name = os.path.basename(f)[:-4]
        key = name.rsplit("_", 2)[0]
        base = first.setdefault(key, m)
        note = ""
        if base is not m:
            d = (m["mid_luma"] - base["mid_luma"]) / base["mid_luma"] * 100 if base["mid_luma"] else 0.0
            note = f"mid {d:+.1f}%  clip {m['clip0_2'] - base['clip0_2']:+.3f}  steps {m['steps'] - base['steps']:+d}"
        print(f"{name:44} {m['clip0_2']:8.3f} {m['low8']:7.3f} {m['mid_luma']:9.1f} {m['steps']:6d}  {note}")


if __name__ == "__main__":
    main()
