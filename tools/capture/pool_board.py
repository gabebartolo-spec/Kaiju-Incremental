"""Labels a capture_pool.gd board: each pool building's model id (and palette shift) at its roof,
plus a title strip naming the district. Usage: python pool_board.py <dir> <district> [...]
Writes <dir>/<district>_board.png beside the raw still."""

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

FONT_PX = 44
TITLE_PX = 64


def _font(px: int) -> ImageFont.ImageFont:
    for name in ("arialbd.ttf", "DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(name, px)
        except OSError:
            continue
    return ImageFont.load_default()


def label(folder: Path, district: str) -> Path:
    img = Image.open(folder / f"{district}.png").convert("RGB")
    marks = json.loads((folder / f"{district}.json").read_text())
    draw = ImageDraw.Draw(img)
    font = _font(FONT_PX)
    for m in marks:
        text = f"{m['id']} p{m['palette']}"
        x, y = float(m["x"]), float(m["y"])
        box = draw.textbbox((x, y), text, font=font, anchor="mb")
        draw.rectangle(box, fill=(0, 0, 0))
        draw.text((x, y), text, font=font, fill=(255, 230, 80), anchor="mb")
        draw.line((x, y, x, y + 18), fill=(255, 230, 80), width=4)
    ids = sorted({m["id"] for m in marks})
    title = f"{district}: {len(marks)} Tripo buildings in frame ({', '.join(ids)})"
    draw.rectangle((0, 0, img.width, TITLE_PX + 24), fill=(0, 0, 0))
    draw.text((20, 12), title, font=_font(TITLE_PX), fill=(255, 255, 255))
    out = folder / f"{district}_board.png"
    img.save(out)
    return out


if __name__ == "__main__":
    for name in sys.argv[2:]:
        print(label(Path(sys.argv[1]), name))
