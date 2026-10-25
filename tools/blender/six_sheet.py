"""One labelled six-view sheet from six_view.py's renders: textured views on the top two rows, clay
on the bottom two, the stats line (stats.json) under the title.

    python tools/blender/six_sheet.py <render_dir> <out.png> "<title>"

Pure Python + Pillow.
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

VIEWS = ["front", "back", "left", "right", "three_quarter", "top"]
TILE = 360
HEAD = 84


def main():
    src, out, title = sys.argv[1], sys.argv[2], sys.argv[3]
    stats = {}
    path = os.path.join(src, "stats.json")
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            stats = json.load(f)
    sheet = Image.new("RGB", (3 * TILE, HEAD + 4 * TILE), (24, 24, 28))
    draw = ImageDraw.Draw(sheet)
    try:
        big = ImageFont.truetype("arialbd.ttf", 30)
        small = ImageFont.truetype("arial.ttf", 20)
    except OSError:
        big = small = ImageFont.load_default()
    draw.text((12, 6), title, fill=(240, 240, 240), font=big)
    line = ", ".join(f"{k} {v}" for k, v in stats.items())
    draw.text((12, 48), line, fill=(200, 200, 200), font=small)
    for m, mode in enumerate(("textured", "clay")):
        for v, view in enumerate(VIEWS):
            p = os.path.join(src, f"{view}_{mode}.png")
            if not os.path.exists(p):
                continue
            img = Image.open(p).convert("RGB").resize((TILE, TILE))
            x, y = (v % 3) * TILE, HEAD + (m * 2 + v // 3) * TILE
            sheet.paste(img, (x, y))
            draw.text((x + 8, y + 6), f"{view} {mode}", fill=(255, 255, 0), font=small)
    sheet.save(out)


if __name__ == "__main__":
    main()
