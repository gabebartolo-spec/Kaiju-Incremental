#!/usr/bin/env python3
"""label_stills.py: burn each still's file name (set, variant) top-left into <folder>/labelled/.
Run: py -3 -I tools/capture/label_stills.py <folder>"""
import glob
import os
import sys

from PIL import Image, ImageDraw, ImageFont

folder = sys.argv[1]
os.makedirs(os.path.join(folder, "labelled"), exist_ok=True)
font = ImageFont.truetype("arialbd.ttf", 110)
for p in sorted(glob.glob(os.path.join(folder, "*_t[0-9][0-9].png"))):
    img = Image.open(p).convert("RGB")
    name = os.path.basename(p)[:-4].rsplit("_t", 1)[0]
    ImageDraw.Draw(img).text((40, 10), name, font=font, fill=(255, 255, 255), stroke_width=6, stroke_fill=(0, 0, 0))
    img.save(os.path.join(folder, "labelled", os.path.basename(p)))
print("labelled", len(glob.glob(os.path.join(folder, "labelled", "*.png"))))
