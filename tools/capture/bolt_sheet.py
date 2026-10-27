#!/usr/bin/env python3
"""bolt_sheet.py: the director's halo-colour options (R 17.6) side by side, labelled, same frame.

capture_bolt.gd renders one frame three times (--halo=amber|eye|violet, same run and bolt seed).
This joins them into one sheet (panels from the full stills or their 2x crops) with a label strip
over each: A hot amber, B species-eye tint, C white with a violet fringe.

  python tools/capture/bolt_sheet.py --out sheet.png A.png B.png C.png [--width 3840]
"""
import argparse
import sys

from PIL import Image, ImageDraw, ImageFont

LABELS = ["A  hot amber", "B  species-eye tint", "C  white, violet fringe"]
STRIP = 90


def font(size):
    for name in ("arial.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--width", type=int, default=3840, help="width of the whole sheet")
    ap.add_argument("panels", nargs=3)
    args = ap.parse_args()
    panel_w = args.width // 3
    panels = []
    for path in args.panels:
        im = Image.open(path).convert("RGB")
        panels.append(im.resize((panel_w, round(im.height * panel_w / im.width)), Image.LANCZOS))
    height = max(p.height for p in panels) + STRIP
    sheet = Image.new("RGB", (panel_w * 3, height), (12, 12, 14))
    draw = ImageDraw.Draw(sheet)
    for i, (label, panel) in enumerate(zip(LABELS, panels)):
        sheet.paste(panel, (i * panel_w, STRIP))
        draw.text((i * panel_w + 30, 18), label, font=font(54), fill=(240, 240, 240))
    sheet.save(args.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
