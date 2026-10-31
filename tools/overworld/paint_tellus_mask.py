"""Paints the Tellus Nova landmass mask (Overworld plan row G1) from outlines traced off the director's
reference map (2026-11-01, a fantasy parchment map: 1408x768 image, map interior x 130..1270, y 40..720).
Coastlines are roughened by seeded midpoint displacement, so the same seed gives the same mask.

The mask is 2:1 equirectangular, one byte per pixel: 0 sea, 1..7 the continents in the globe's order
(D-420, data/continents.json). The globe texture and the continent hit-areas both read it.

    python tools/overworld/paint_tellus_mask.py                      # rewrites assets/overworld/tellus_nova_mask.png
    python tools/overworld/paint_tellus_mask.py <mask.png> <preview.png>   # elsewhere, plus a labelled preview

Pillow at build time only; nothing of it ships."""
import math
import random
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 2048, 1024
X0, X1, Y0, Y1 = 130.0, 1270.0, 40.0, 720.0
SEED = 418

# D-420 order; the mask stores index 1..7 (0 = sea).
IDS = ["ostia_minor", "carthago", "thule", "silvania", "mons_ferrata", "neptunia", "aurelia"]
NAMES = ["Ostia Minor", "Carthago", "Thule", "Silvania", "Mons Ferrata", "Neptunia", "Aurelia"]

SHAPES = {
    "ostia_minor": [
        [(255, 70), (330, 55), (400, 90), (410, 130), (370, 175), (330, 190), (300, 180),
         (270, 200), (250, 165), (260, 120)],
        [(385, 205), (420, 200), (445, 230), (430, 255), (395, 250)],
    ],
    "carthago": [
        [(230, 240), (280, 250), (330, 280), (380, 270), (420, 290), (440, 330), (418, 375),
         (405, 410), (412, 470), (400, 530), (380, 580), (330, 582), (290, 540), (270, 480),
         (258, 420), (240, 360), (220, 300)],
        [(420, 598), (470, 592), (520, 612), (505, 632), (450, 630)],
    ],
    "thule": [
        [(900, 70), (980, 50), (1100, 60), (1200, 80), (1260, 120), (1255, 210), (1230, 250),
         (1190, 300), (1160, 280), (1120, 200), (1060, 150), (1000, 130), (940, 140),
         (910, 110)],
    ],
    "silvania": [
        [(520, 90), (580, 60), (650, 55), (720, 80), (780, 70), (840, 110), (850, 170),
         (830, 220), (800, 260), (830, 300), (820, 350), (760, 355), (700, 330), (640, 320),
         (600, 290), (560, 320), (540, 300), (570, 250), (530, 210), (510, 160)],
    ],
    "mons_ferrata": [
        [(428, 380), (470, 372), (540, 390), (600, 400), (650, 420), (700, 450), (710, 500),
         (690, 550), (640, 580), (580, 560), (520, 560), (470, 530), (436, 500), (424, 460)],
    ],
    "aurelia": [
        [(395, 790), (400, 700), (460, 672), (600, 662), (800, 652), (950, 640), (1050, 602),
         (1150, 562), (1210, 530), (1245, 560), (1238, 640), (1250, 790)],
    ],
}

# Neptunia: the island chain, (centre x, centre y, half width, half height) in reference pixels.
ISLES = [
    (925, 285, 14, 10), (950, 270, 10, 8), (968, 292, 16, 11), (990, 278, 9, 7),
    (945, 310, 11, 8), (985, 312, 12, 8), (1010, 300, 8, 6),
    (770, 430, 12, 9), (795, 445, 10, 7), (815, 425, 9, 7), (830, 460, 11, 8),
    (770, 528, 32, 20), (850, 560, 26, 16), (680, 590, 22, 10), (715, 480, 8, 6),
]


# Latitude band the reference's rows map to: the ink map is not equirectangular, and land at its
# very top or bottom would pinch to nothing at the globe's poles. Below the map edge = past the pole.
V_TOP, V_SPAN = 0.08, 0.84


def to_mask(p):
    v = (p[1] - Y0) / (Y1 - Y0)
    return ((p[0] - X0) / (X1 - X0) * W, (V_TOP + V_SPAN * v) * H if v <= 1.0 else H + 40.0)


def roughen(points, rng, depth=5, amp=0.18):
    out = list(points)
    for _ in range(depth):
        nxt = []
        for i, a in enumerate(out):
            b = out[(i + 1) % len(out)]
            mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
            dx, dy = b[0] - a[0], b[1] - a[1]
            k = rng.uniform(-amp, amp)
            nxt += [a, (mx - dy * k, my + dx * k)]
        out = nxt
    return out


def ellipse(cx, cy, rx, ry, n=10):
    return [(cx + rx * math.cos(t * 2 * math.pi / n), cy + ry * math.sin(t * 2 * math.pi / n))
            for t in range(n)]


# Aurelia is the reference's southern polar continent: below this coast it covers the whole pole, so
# the bottom row is one value and nothing pinches to a wedge where the map's rows meet at the pole.
CAP_V, CAP_AMP, CAP_KNOTS = 0.875, 0.012, 16


def polar_cap(mask, rng):
    """Fills every column from a seeded, x-periodic coast down to the bottom row with Aurelia."""
    coast = [CAP_V + rng.uniform(-CAP_AMP, CAP_AMP) for _ in range(CAP_KNOTS)]
    for _ in range(4):
        nxt = []
        for i, a in enumerate(coast):
            b = coast[(i + 1) % len(coast)]
            nxt += [a, (a + b) / 2 + rng.uniform(-CAP_AMP, CAP_AMP) / 2]
        coast = nxt
    px = mask.load()
    fill = IDS.index("aurelia") + 1
    for x in range(W):
        t = x / W * len(coast)
        i = int(t)
        v = coast[i] + (coast[(i + 1) % len(coast)] - coast[i]) * (t - i)
        for y in range(int(v * H), H):
            px[x, y] = fill


def paint():
    rng = random.Random(SEED)
    mask = Image.new("L", (W, H), 0)
    draw = ImageDraw.Draw(mask)
    for cid, polys in SHAPES.items():
        for poly in polys:
            draw.polygon(roughen([to_mask(p) for p in poly], rng), fill=IDS.index(cid) + 1)
    for isle in ISLES:
        draw.polygon(roughen([to_mask(p) for p in ellipse(*isle)], rng, depth=3, amp=0.12),
                     fill=IDS.index("neptunia") + 1)
    polar_cap(mask, random.Random(SEED + 1))
    return mask


def preview(mask, out):
    """Hazard yellow on near-black (D-061), each continent its own shade, names on top."""
    shades = [(255, 214, 0), (255, 170, 0), (200, 230, 60), (255, 240, 120), (230, 140, 30),
              (90, 200, 220), (255, 90, 40)]
    pal = [12, 12, 14] + [c for s in shades for c in s] + [0] * (256 - 8) * 3
    img = mask.copy()
    img.putpalette(pal)
    img = img.convert("RGB")
    edge = mask.filter(ImageFilter.FIND_EDGES).point(lambda v: 255 if v else 0)
    img.paste((255, 255, 255), mask=edge)
    d = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("arialbd.ttf", 34)
    except OSError:
        font = ImageFont.load_default()
    px = mask.load()
    for n, name in enumerate(NAMES):
        xs, ys, c = 0, 0, 0
        for y in range(0, H, 4):
            for x in range(0, W, 4):
                if px[x, y] == n + 1:
                    xs, ys, c = xs + x, ys + y, c + 1
        if c:
            d.text((xs / c, ys / c), name, fill=(255, 255, 255), font=font, anchor="mm",
                   stroke_width=3, stroke_fill=(0, 0, 0))
    img.save(out)


if __name__ == "__main__":
    m = paint()
    m.save(sys.argv[1] if len(sys.argv) > 1 else "assets/overworld/tellus_nova_mask.png")
    if len(sys.argv) > 2:
        preview(m, sys.argv[2])
    counts = m.histogram()
    for n, cid in enumerate(IDS):
        print(f"{cid:13s} {counts[n + 1] / (W * H) * 100:5.2f}% of the map")
