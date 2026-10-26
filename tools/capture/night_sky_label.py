#!/usr/bin/env python3
"""night_sky_label.py: burn a big A/B/C/D label top-left into each night_<L>_t12.png of a folder
(writes labelled_<L>.png, originals untouched) and print sky and facade-band luminance per still.
Run: py -3 -I tools/capture/night_sky_label.py <folder> [--sky=0.04,0.20] [--facade=0.55,0.75]
Bands are row shares of the height (sky: rows between the two; facade: rows between the two);
luma is Rec.709 on the 8-bit sRGB values (0-255), mean over the band, label area skipped."""
import glob
import os
import sys

from PIL import Image, ImageDraw, ImageFont


def band(img, lo, hi):
    w, h = img.size
    px = img.load()
    tot = n = 0.0
    sr = sg = sb = 0
    for y in range(int(h * lo), int(h * hi), 4):
        for x in range(0, w, 4):
            if x < 400 and y < 400:
                continue
            r, g, b = px[x, y]
            tot += 0.2126 * r + 0.7152 * g + 0.0722 * b
            sr += r
            sg += g
            sb += b
            n += 1
    return tot / n, (sr / n, sg / n, sb / n)


def main():
    opts = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--"))
    sky = [float(v) for v in opts.get("sky", "0.04,0.20").split(",")]
    fac = [float(v) for v in opts.get("facade", "0.55,0.75").split(",")]
    folder = [a for a in sys.argv[1:] if not a.startswith("--")][0]
    print("still  sky_luma  sky_rgb          facade_luma  facade_rgb")
    for p in sorted(glob.glob(os.path.join(folder, "night_?_t*.png"))):
        letter = os.path.basename(p).split("_")[1]
        img = Image.open(p).convert("RGB")
        sl, srgb = band(img, *sky)
        fl, frgb = band(img, *fac)
        d = ImageDraw.Draw(img)
        font = ImageFont.truetype("arialbd.ttf", 280)
        d.text((40, 0), letter, font=font, fill=(255, 255, 255), stroke_width=10, stroke_fill=(0, 0, 0))
        img.save(os.path.join(folder, f"labelled_{letter}.png"))
        print(f"{letter}      {sl:7.1f}   {tuple(round(c) for c in srgb)}  {fl:9.1f}    {tuple(round(c) for c in frgb)}")


if __name__ == "__main__":
    main()
