"""Builds the rampage HUD's ability icons (assets/ui/icons/*.png): white shapes with a dark edge on
a transparent ground, 128x128, so the HUD can tint them (white when ready, grey while charging).
Original shapes drawn here (a bolt, two chevrons, a burst), nothing traced. Pillow at build time
only. Run from the repo root:  python tools/ui/build_icons.py
Paths the game loads them from: data/tuning.json "ui" hud icons. Replace a PNG (same size, white
on transparent) to change an icon; no code reads the shapes."""

import math
import os

from PIL import Image, ImageDraw

SIZE = 128
SCALE = 4
# Shapes in units of the icon's half size (y down), centred on the image; 0.86 keeps the dark edge on the image.
FIT = 0.86
EDGE_PX = 5
BOLT = [(0.2, -1.0), (-0.45, 0.15), (-0.05, 0.15), (-0.25, 1.0), (0.45, -0.25), (0.05, -0.25), (0.35, -1.0)]
CHEVRON = [(-0.35, -0.75), (0.15, 0.0), (-0.35, 0.75), (-0.05, 0.75), (0.45, 0.0), (-0.05, -0.75)]
CHEVRON_STEP = 0.5
BURST_POINTS = 8
BURST_INNER = 0.45


def burst():
    out = []
    for i in range(BURST_POINTS * 2):
        r = 1.0 if i % 2 == 0 else BURST_INNER
        a = -math.pi / 2 + math.pi * i / BURST_POINTS
        out.append((math.cos(a) * r, math.sin(a) * r))
    return out


def shifted(points, dx):
    return [(x + dx, y) for x, y in points]


ICONS = {
    "breath": [BOLT],
    "dash": [shifted(CHEVRON, -CHEVRON_STEP / 2), shifted(CHEVRON, CHEVRON_STEP / 2)],
    "ultimate": [burst()],
}


def draw(shapes):
    big = SIZE * SCALE
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    half = big / 2 * FIT
    edge = EDGE_PX * SCALE
    for shape in shapes:
        pts = [(big / 2 + x * half, big / 2 + y * half) for x, y in shape]
        d.polygon(pts, fill=(11, 11, 13, 235))
        d.line(pts + [pts[0]], fill=(11, 11, 13, 235), width=edge * 2, joint="curve")
    for shape in shapes:
        pts = [(big / 2 + x * half, big / 2 + y * half) for x, y in shape]
        d.polygon(pts, fill=(255, 255, 255, 255))
    return img.resize((SIZE, SIZE), Image.LANCZOS)


if __name__ == "__main__":
    out = os.path.join("assets", "ui", "icons")
    os.makedirs(out, exist_ok=True)
    for name, shapes in ICONS.items():
        draw(shapes).save(os.path.join(out, name + ".png"))
        print("wrote", name)
