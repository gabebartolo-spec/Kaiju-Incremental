"""Top-down picture of a baked district (data/cities/<district>.json), to check a bake by eye.

Dev tool (needs Pillow). Water blue, parks green, rail brown, streets grey at their width,
buildings shaded by height (outer ones dimmer), the playable rect red, the kaiju start yellow.

    python tools/osm/preview_district.py melbourne_cbd out.png [pixels_per_unit]
"""

import json
import pathlib
import sys

from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    d = json.loads((ROOT / "data" / "cities" / f"{sys.argv[1]}.json").read_text(encoding="utf-8"))
    ppu = float(sys.argv[3]) if len(sys.argv) > 3 else 4.0
    bx, bz, bw, bd = d["bounds"]
    img = Image.new("RGB", (int(bw * ppu), int(bd * ppu)), (205, 200, 190))
    draw = ImageDraw.Draw(img)

    def px(x: float, z: float) -> tuple:
        return ((x - bx) * ppu, (z - bz) * ppu)

    colours = {"water": (120, 160, 210), "park": (150, 190, 120), "rail": (170, 150, 130),
               "plaza": (220, 215, 200)}
    for use in ("park", "plaza", "rail", "water"):
        for a in d["areas"]:
            if a["use"] == use:
                f = a["poly"]
                draw.polygon([px(f[i], f[i + 1]) for i in range(0, len(f), 2)], fill=colours[use])
    for r in d["rails"]:
        draw.line([px(r[i], r[i + 1]) for i in range(0, len(r), 2)], fill=(110, 90, 80), width=2)
    nodes = d["nodes"]
    walk = d["sidewalk"]
    for s in d["streets"]:
        a, b = nodes[s["from"]], nodes[s["to"]]
        width = max(1, int((s["width"]) * ppu))
        draw.line([px(*a), px(*b)], fill=(150, 150, 150), width=width)
    top = max(b["h"] for b in d["buildings"])
    for group, dim in ((d["outer"], 0.7), (d["buildings"], 1.0)):
        for b in group:
            t = b["h"] / top
            g = int((210 - 170 * t) * dim)
            x0, z0 = px(b["x"] - b["w"] * 0.5, b["z"] - b["d"] * 0.5)
            x1, z1 = px(b["x"] + b["w"] * 0.5, b["z"] + b["d"] * 0.5)
            draw.rectangle([x0, z0, x1 - 1, z1 - 1], fill=(g, g, int(g * 1.05)))
    p = d["play"]
    draw.rectangle([px(p[0], p[1]), px(p[0] + p[2], p[1] + p[3])], outline=(220, 40, 40), width=2)
    sx, sz = px(*d["start"])
    draw.ellipse([sx - 5, sz - 5, sx + 5, sz + 5], fill=(250, 210, 30))
    draw.text((6, 6), f"{d['name']} (baked, rotated {d['grid_deg']} deg)  {d['credit']}",
              fill=(20, 20, 20))
    img.save(sys.argv[2])
    print(sys.argv[2], img.size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
