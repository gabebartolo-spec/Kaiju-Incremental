"""Lays the VFX look sheet's stills (capture_vfx_sheet.gd) out as one labelled contact sheet.

    python tools/capture/vfx_sheet.py <out.png> <night_dir> <noon_dir> [--crop=WxH]

Each dir holds one capture run (stills + points.json). Every effect gets a night and a noon panel
side by side, cropped round its screen point at 1x (the game's own zoom at 1080p), one row per
effect family (docs/VFX_STYLE.md). A shot in FLAGS gets a red label: its family has a second look.
"""

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

FAMILIES = [
    ("FIRE", ["fire_ground", "fire_far_smoke", "explosion_wreck"]),
    ("SMOKE, DUST, DEBRIS", ["dust_cloud", "dust_topple", "dust_footfall", "dust_tree_puff", "debris"]),
    ("RINGS", ["ring_stomp", "ring_tail_sweep"]),
    ("SPARKS, FLASH", ["sparks_shell_hit", "sparks_deflect"]),
    ("ABILITY MARKS", ["ability_claw", "ability_stomp_cracks", "ability_leap_crater", "breath_aim"]),
    ("BREATH, BEAM", ["breath_10", "breath_24", "breath_side_10", "ultimate_beam_side_20", "ultimate_beam_20"]),
]
# Shots whose family has more than one look today (docs/VFX_STYLE.md, "Two looks today").
FLAGS = {
    "ultimate_beam_side_20": "2nd beam look (solid box)",
    "ultimate_beam_20": "beam hidden at game camera",
    "breath_10": "orange flame wall, not lightning",
    "breath_24": "orange flame wall, not lightning",
    "breath_side_10": "orange plasma, not lightning",
}
# Crop centre offsets (px) where the effect's point is not the middle of what it draws.
OFFSET = {"fire_far_smoke": (60, -170), "ultimate_beam_side_20": (0, 0), "breath_side_10": (60, -40)}
LABEL_H = 26
GAP = 4


def panel(run: Path, name: str, cw: int, ch: int, font: ImageFont.FreeTypeFont) -> Image.Image:
    points = json.loads((run / "points.json").read_text())
    shot = Image.open(run / f"{name}.png").convert("RGB")
    dx, dy = OFFSET.get(name, (0, 0))
    x, y = points[name][0] + dx, points[name][1] + dy
    left = int(min(max(x - cw / 2, 0), shot.width - cw))
    top = int(min(max(y - ch / 2, 0), shot.height - ch))
    out = Image.new("RGB", (cw, ch + LABEL_H), (18, 18, 18))
    out.paste(shot.crop((left, top, left + cw, top + ch)), (0, LABEL_H))
    flag = FLAGS.get(name)
    text = f"{name} ({run.name})" + (f"  {flag}" if flag else "")
    ImageDraw.Draw(out).text((6, 4), text, fill=(255, 90, 70) if flag else (230, 230, 230), font=font)
    return out


def main(argv: list[str]) -> None:
    opts = {a.split("=")[0]: a.split("=")[1] for a in argv if a.startswith("--")}
    out, night, noon = (Path(a) for a in argv if not a.startswith("--"))
    cw, ch = (int(v) for v in opts.get("--crop", "400x250").split("x"))
    font = ImageFont.truetype("arial.ttf", 16)
    head = ImageFont.truetype("arialbd.ttf", 22)
    per_row = max(len(shots) for _, shots in FAMILIES)
    pair_w = cw * 2 + GAP
    row_h = ch + LABEL_H + 34
    sheet = Image.new("RGB", (per_row * (pair_w + 14), len(FAMILIES) * row_h), (0, 0, 0))
    draw = ImageDraw.Draw(sheet)
    for r, (family, shots) in enumerate(FAMILIES):
        y = r * row_h
        draw.text((6, y + 4), family, fill=(255, 210, 60), font=head)
        for c, name in enumerate(shots):
            x = c * (pair_w + 14)
            sheet.paste(panel(night, name, cw, ch, font), (x, y + 34))
            sheet.paste(panel(noon, name, cw, ch, font), (x + cw + GAP, y + 34))
    sheet.save(out)
    print(f"{out}: {sheet.width}x{sheet.height}")


if __name__ == "__main__":
    main(sys.argv[1:])
