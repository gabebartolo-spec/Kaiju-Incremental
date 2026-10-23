"""D-164 skins: a small PNG palette per skin (Aseprite-editable), one colour table per body region.

    python tools/kaiju_skin/skins/skin_tool.py palettes          # (re)write palettes/*.png from PALETTES below
    python tools/kaiju_skin/skins/skin_tool.py board OUT.png      # the croc in each skin, 2 views + 2x head crop

Palette PNG: 4 columns x 6 rows, one pixel per swatch (zoom it in Aseprite). Rows are the regions
(back, belly, spines, claws, eyes, teeth). Columns: 0 shadow, 1 mid, 2 light, 3 glow. A cell keeps its own
light/dark (the original luminance, ranked inside its region) and picks its colour along shadow -> mid -> light,
so scales, stripes and the sculpt's detail survive; the glow column is for emissive cells (alpha 0 in the
game's palette dict, like the accent glow): chosen per skin by `glow` below ("crevice": the darkest cells of
the hide, "spots": scale-sized clusters on the flanks, None).
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import regions as R  # noqa: E402
import vox_view as V  # noqa: E402

HERE = Path(__file__).resolve().parent
PAL_DIR = HERE / "palettes"
H = lambda s: tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))

# region -> (shadow, mid, light, glow)
PALETTES = {
    "obsidian": {
        "glow": "crevice", "glow_share": {"back": 0.06, "belly": 0.05, "spines": 0.015}, "glow_regions": ["back", "belly", "spines"],
        "back": ("0a0b0e", "1e1f26", "3a3b45", "ff5a1a"), "belly": ("121318", "272932", "474954", "ff5a1a"),
        "spines": ("050506", "0f0f12", "25252d", "ff7a28"), "claws": ("0b0b0d", "26262c", "5e5e68", "ff5a1a"),
        "eyes": ("8c2a00", "ff6a1a", "ffc060", "ffd080"), "teeth": ("7d776a", "c9c2b0", "f0ead8", "f0ead8"),
    },
    "abyssal": {
        "glow": "spots", "glow_share": 0.035, "glow_regions": ["back"],
        "back": ("04201d", "0b4a44", "1a8274", "9fe0c8"), "belly": ("0c3a3c", "1d6a68", "4aa89e", "9fe0c8"),
        "spines": ("062a2b", "124d4f", "2f8a86", "9fe0c8"), "claws": ("07191a", "1b3a3c", "4c7c7a", "9fe0c8"),
        "eyes": ("1fa88a", "7ff5d0", "e2fff4", "e2fff4"), "teeth": ("bcd8cc", "e0efe6", "f8fffb", "f8fffb"),
    },
    "albino": {
        "glow": None, "glow_share": 0.0, "glow_regions": [],
        "back": ("dcd0b8", "f4ecda", "fffaf0", "fffaf0"), "belly": ("f0d6cb", "fae8de", "fffaf4", "fffaf4"),
        "spines": ("cabda3", "e6dac3", "f8f0de", "f8f0de"), "claws": ("cdbfa5", "e9ddc6", "faf2e0", "faf2e0"),
        "eyes": ("9a1428", "e83a56", "ff9db0", "ffc0cc"), "teeth": ("ece4d2", "fff8ea", "ffffff", "ffffff"),
    },
}


def write_palettes():
    PAL_DIR.mkdir(exist_ok=True)
    for name, p in PALETTES.items():
        img = Image.new("RGB", (4, len(R.REGIONS)))
        for y, reg in enumerate(R.REGIONS):
            for x, hexc in enumerate(p[reg]):
                img.putpixel((x, y), H(hexc))
        img.save(PAL_DIR / f"{name}.png")
        (PAL_DIR / f"{name}.json").write_text(json.dumps(
            {k: p[k] for k in ("glow", "glow_share", "glow_regions")}, indent=1), encoding="utf-8")


def today_palette(col, reg, lum):
    """The croc's own colours as a 4x6 table: the 8th, 50th and 92nd luminance percentile colour per region."""
    out = np.zeros((len(R.REGIONS), 4, 3), np.uint8)
    for r in range(len(R.REGIONS)):
        m = reg == r
        if m.sum() < 5:
            continue
        order = np.argsort(lum[m])
        cols = col[m][order]
        for x, q in enumerate((0.08, 0.5, 0.92, 0.92)):
            out[r, x] = cols[int(q * (len(cols) - 1))]
    return out


def recolour(col, reg, lum, normals, pos, table, glow_mode, glow_share, glow_regions):
    """table: (6, 4, 3) uint8 swatches. Returns (new colours, emissive mask)."""
    new = col.copy().astype(np.float32)
    t_all = np.zeros(len(col), np.float32)
    for r in range(len(R.REGIONS)):
        m = reg == r
        if m.sum() < 5:
            continue
        lo, hi = np.percentile(lum[m], (5, 95))
        t = np.clip((lum[m] - lo) / max(hi - lo, 1e-6), 0, 1)
        t_all[m] = t
        sh, mid, li = (table[r, i].astype(np.float32) for i in range(3))
        lo_half = t < 0.5
        c = np.where(lo_half[:, None], sh + (mid - sh) * (t / 0.5)[:, None], mid + (li - mid) * ((t - 0.5) / 0.5)[:, None])
        new[m] = c
    emissive = np.zeros(len(col), bool)
    if glow_mode:
        in_reg = np.isin(reg, [R.REGIONS.index(g) for g in glow_regions])
        if glow_mode == "crevice":
            for gr in glow_regions:  # the darkest share of each region's own cells
                m = reg == R.REGIONS.index(gr)
                emissive |= m & (t_all <= np.percentile(t_all[m], (glow_share.get(gr, 0.05) if isinstance(glow_share, dict) else glow_share) * 100))
        elif glow_mode == "spots":
            # scale-sized clusters: a hash of the cell on a coarse 4-cell grid, flanks only (normal mostly sideways)
            g = (pos // 4).astype(np.int64)
            h = (g[:, 0] * 73856093 ^ g[:, 1] * 19349663 ^ g[:, 2] * 83492791) & 0xFFFF
            spot = (h / 65535.0) < glow_share * 4
            fine = ((pos[:, 0] * 31 + pos[:, 1] * 17 + pos[:, 2] * 13) & 3) == 0
            emissive = in_reg & spot & fine & (np.abs(normals[:, 1]) < 0.55)
        for r in np.unique(reg[emissive]):
            new[emissive & (reg == r)] = table[r, 3].astype(np.float32)
    return np.clip(new, 0, 255).astype(np.uint8), emissive


def load_skin(name):
    img = Image.open(PAL_DIR / f"{name}.png").convert("RGB")
    table = np.array(img, np.uint8).reshape(len(R.REGIONS), 4, 3)
    meta = json.loads((PAL_DIR / f"{name}.json").read_text(encoding="utf-8"))
    return table, meta


def board(out_path):
    pos, col, bone = V.load()
    nrm = V.normals(pos)
    names = V.bone_names()
    reg = R.classify(pos, col, bone, nrm, names)
    lum, sat, _ = R.features(col)
    skins = [("today", "Today", None, None)] + [(n, n.capitalize(), *load_skin(n)) for n in PALETTES]
    head = np.isin(bone, [names.index("head0"), names.index("head1"), names.index("jaw")])
    panels = []
    for key, label, table, meta in skins:
        if table is None:
            newcol, emi = col, np.zeros(len(col), bool)
        else:
            newcol, emi = recolour(col, reg, lum, nrm, pos, table, meta["glow"], meta["glow_share"], meta["glow_regions"])
        row = []
        for yaw, pitch in ((205, 28), (35, 14)):
            img, sc, ctr = V.render(pos, newcol, nrm, yaw, pitch, size=(760, 640), glow=emi, gain=1.35)
            row.append(img)
        # 2x crop on the head from the front 3/4 view
        m = V.camera(35, 14)
        hc = (pos[head].astype(np.float32) @ m.T).mean(0)
        img, _, _ = V.render(pos, newcol, nrm, 35, 14, size=(760, 640), scale=sc * 2.6, center=hc, glow=emi, gain=1.35)
        row.append(img)
        panels.append((label, row, table))
    pw, ph = 760, 640
    font = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 34)
    small = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 22)
    sheet = Image.new("RGB", (pw * 3 + 80, 90 + len(panels) * (ph + 70) + 80), (22, 23, 27))
    d = ImageDraw.Draw(sheet)
    d.text((20, 18), "Croc titan skins as colour tables per region (game voxels, same camera and light)", font=font, fill=(235, 235, 235))
    y = 80
    heads = ["Behind, 3/4 from above", "Front 3/4", "Head, 2x crop"]
    for label, row, table in panels:
        d.text((20, y), label, font=font, fill=(255, 214, 51))
        for i, im in enumerate(row):
            sheet.paste(im, (20 + i * (pw + 20), y + 44))
            if label == "Today":
                d.text((30 + i * (pw + 20), y + 44 + ph - 30), heads[i], font=small, fill=(30, 30, 30))
        if table is not None:  # the swatches, 6 regions x 4 columns, beside the title
            for r in range(6):
                for x in range(4):
                    d.rectangle((300 + x * 30 + r * 140, y + 6, 328 + x * 30 + r * 140, y + 30), fill=tuple(int(v) for v in table[r, x]))
                d.text((300 + r * 140, y + 34), R.REGIONS[r], font=small, fill=(210, 210, 210))
        y += ph + 70
    sheet.crop((0, 0, sheet.width, y)).save(out_path)
    return {r: int((reg == i).sum()) for i, r in enumerate(R.REGIONS)}


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "palettes":
        write_palettes()
    elif cmd == "board":
        print(board(sys.argv[2]))
