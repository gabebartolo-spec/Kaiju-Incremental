"""D-164 skins: a small PNG palette per skin (Aseprite-editable), one colour table per body region.

    python tools/kaiju_skin/skins/skin_tool.py palettes          # (re)write palettes/*.png + .json from PALETTES below
    python tools/kaiju_skin/skins/skin_tool.py board OUT.png      # today + the skins, 2 views + 2x head crop

Palette PNG: 4 columns x 6 rows, one pixel per swatch (zoom it in Aseprite). Rows are the regions
(back, belly, spines, claws, eyes, teeth). Columns: 0 shadow, 1 mid, 2 light, 3 glow. A cell keeps its own
light and dark (its original luminance, ranked inside its region) and takes its colour along shadow -> mid ->
light, so the sculpt's scutes and bands survive. Then a fold term darkens cells in creases (cells with many
neighbours around them: a cheap ambient occlusion), tinted by the skin's `fold_color`.
The glow column is for emissive cells (alpha 0 in the game's palette dict, like the accent glow). Which cells
glow is a skin rule in `<skin>.json` (`glow`): "seams" = connected runs along the scute seams, between spine
bases and along the lip line; "flank_row" = a row of dots along the flank at the dark stripe bands; null.
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
        "glow": "seams", "fold": 0.30, "fold_color": "000000", "eye_glow": False,
        "back": ("0a0b0f", "20222a", "484b59", "ff5a1a"), "belly": ("10121a", "2a2d38", "555969", "ff5a1a"),
        "spines": ("06060a", "14141a", "30303c", "ff7a28"), "claws": ("0a0a0c", "26262c", "62626e", "ff5a1a"),
        "eyes": ("8c2a00", "ff6a1a", "ffc060", "ffd080"), "teeth": ("7d776a", "c9c2b0", "f0ead8", "f0ead8"),
    },
    "abyssal": {
        "glow": "flank_row", "fold": 0.30, "fold_color": "000d0c", "eye_glow": False,
        "back": ("020c0b", "083a34", "1a7468", "2fb8aa"), "belly": ("0f4646", "2a8a84", "6cc4b8", "2fb8aa"),
        "spines": ("041c1d", "0f4a4c", "27807e", "2fb8aa"), "claws": ("040d0f", "10292b", "2a5654", "2fb8aa"),
        "eyes": ("1fa88a", "7ff5d0", "d8fff2", "d8fff2"), "teeth": ("84a49b", "adc9bf", "d0e2da", "d0e2da"),
    },
    "albino": {
        "glow": None, "fold": 0.42, "fold_color": "8a5a50", "eye_glow": False,
        "back": ("b0a086", "ecdcbe", "fff6e0", "fff6e0"), "belly": ("c48a82", "efc4b8", "ffe6dc", "ffe6dc"),
        "spines": ("8c7e66", "c8b898", "eadcbc", "eadcbc"), "claws": ("988868", "cbba9a", "eee0c2", "eee0c2"),
        "eyes": ("7a0f1c", "d6283e", "ff7088", "ff7088"), "teeth": ("d4c8ac", "f2e8d0", "fffaf0", "fffaf0"),
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
            {k: p[k] for k in ("glow", "fold", "fold_color", "eye_glow")}, indent=1), encoding="utf-8", newline="\n")


def load_skin(name):
    img = Image.open(PAL_DIR / f"{name}.png").convert("RGB")
    table = np.array(img, np.uint8).reshape(len(R.REGIONS), 4, 3)
    return table, json.loads((PAL_DIR / f"{name}.json").read_text(encoding="utf-8"))


# ---- analysis shared by every skin ------------------------------------------------------------------------------

def concavity(pos, r=3):
    """Occupied cells in the (2r+1)^3 box round each cell: high in creases and seams, low on bulges."""
    mn = pos.min(0) - r - 1
    idx = pos - mn
    occ = np.zeros(idx.max(0) + r + 2, np.uint8)
    occ[idx[:, 0], idx[:, 1], idx[:, 2]] = 1
    cnt = np.zeros(len(pos), np.uint16)
    for dx in range(-r, r + 1):
        for dy in range(-r, r + 1):
            for dz in range(-r, r + 1):
                cnt += occ[idx[:, 0] + dx, idx[:, 1] + dy, idx[:, 2] + dz]
    return cnt.astype(np.float32)


def components(mask, pos, min_size):
    """Connected runs (26-neighbour) of the masked cells, biggest first, smaller than min_size dropped."""
    ids = np.nonzero(mask)[0]
    where = {tuple(p): k for k, p in enumerate(pos[ids])}
    label = np.full(len(ids), -1, np.int32)
    offs = [(a, b, c) for a in (-1, 0, 1) for b in (-1, 0, 1) for c in (-1, 0, 1) if (a, b, c) != (0, 0, 0)]
    out = []
    for s in range(len(ids)):
        if label[s] >= 0:
            continue
        label[s] = len(out)
        stack, run = [s], [s]
        while stack:
            k = stack.pop()
            x, y, z = pos[ids[k]]
            for a, b, c in offs:
                n = where.get((x + a, y + b, z + c))
                if n is not None and label[n] < 0:
                    label[n] = len(out)
                    stack.append(n)
                    run.append(n)
        out.append(ids[run])
    out = [c for c in out if len(c) >= min_size]
    out.sort(key=len, reverse=True)
    return out


class Analysis:
    def __init__(self):
        self.pos, self.col, self.bone = V.load()
        self.names = V.bone_names()
        self.nrm = V.normals(self.pos)
        self.reg = R.classify(self.pos, self.col, self.bone, self.nrm, self.names)
        self.lum, self.sat, _ = R.features(self.col)
        self.conc = concavity(self.pos)
        # region-ranked light (0..1) and fold amount (0..1, creases)
        self.t = np.zeros(len(self.pos), np.float32)
        self.fold = np.zeros(len(self.pos), np.float32)
        for r in range(len(R.REGIONS)):
            m = self.reg == r
            if m.sum() < 5:
                continue
            lo, hi = np.percentile(self.lum[m], (5, 95))
            self.t[m] = np.clip((self.lum[m] - lo) / max(hi - lo, 1e-6), 0, 1)
            clo, chi = np.percentile(self.conc[m], (30, 97))
            self.fold[m] = np.clip((self.conc[m] - clo) / max(chi - clo, 1e-6), 0, 1)

    def bone_ids(self, *ns):
        return [self.names.index(n) for n in ns if n in self.names]


def glow_seams(an):
    """Obsidian: ember in connected runs. Scute seams (dark and creased hide), the gaps between spine bases,
    and the lip line (where the upper head bone meets the jaw bone); everything else stays dark."""
    reg, t, fold, pos = an.reg, an.t, an.fold, an.pos
    cand = np.isin(reg, (R.BACK, R.BELLY)) & (fold > 0.55) & (t < 0.15)
    cand |= (reg == R.SPINES) & (fold > 0.62)
    runs = components(cand, pos, min_size=40)
    budget = int(0.03 * len(pos))
    mask = np.zeros(len(pos), bool)
    for c in runs:  # biggest runs first, until the budget is spent
        if mask.sum() + len(c) > budget:
            continue
        mask[c] = True
    # the lip line: head1 cells touching a jaw cell (a connected seam all along the mouth)
    h1, jw = an.bone_ids("head1")[0], an.bone_ids("jaw")[0]
    sel = np.nonzero(np.isin(an.bone, (h1, jw)))[0]
    where = {tuple(p): i for i, p in zip(sel, pos[sel])}
    lip = []
    for i in sel:
        x, y, z = pos[i]
        for d in ((0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)):
            n = where.get((x + d[0], y + d[1], z + d[2]))
            if n is not None and an.bone[n] != an.bone[i]:
                lip.append(i)
                break
    mask[np.array(lip, dtype=int)] = True
    return mask


def glow_flank_row(an):
    """Abyssal: a row of faint cyan dots along each flank, one on every dark stripe band of the body and tail
    (the bands are where the original luminance dips along the animal's length)."""
    pos, nrm, lum = an.pos, an.nrm, an.lum
    body = np.isin(an.bone, an.bone_ids("spine1", "spine2", *[f"tail{i}" for i in range(9)]))
    mask = np.zeros(len(pos), bool)
    for side in (-1, 1):
        flank = body & (np.sign(pos[:, 0]) == side) & (np.abs(nrm[:, 0]) > 0.6) & (an.reg == R.BACK)
        zs = np.unique(pos[flank, 2])
        zl = np.array([lum[flank & (pos[:, 2] == z)].mean() for z in zs])
        k = 31
        pad = np.pad(zl, k // 2, mode="edge")
        avg = np.convolve(pad, np.ones(k) / k, mode="valid")
        dark = zl < avg * 0.88
        # contiguous dark runs -> band centres
        centres, run = [], []
        for z, d in zip(zs, dark):
            if d:
                run.append(z)
            elif run:
                if len(run) >= 3:
                    centres.append(int(np.mean(run)))
                run = []
        for zc in centres:
            sl = flank & (np.abs(pos[:, 2] - zc) <= 2)
            if sl.sum() < 6:
                continue
            yc = np.percentile(pos[sl, 1], 50)
            mask |= flank & (((pos[:, 2] - zc) ** 2 + (pos[:, 1] - yc) ** 2) <= 3.2 ** 2)
    return mask


def eye_blob(an, radius=2.6):
    """Cells within `radius` of an eye cell (the species eye glow, grown so it reads at the 2x crop)."""
    eyes = np.nonzero(an.reg == R.EYES)[0]
    head = np.nonzero(np.isin(an.bone, an.bone_ids("head0", "head1", "jaw")))[0]
    out = np.zeros(len(an.pos), bool)
    hp = an.pos[head].astype(np.float32)
    for e in eyes:
        d = np.linalg.norm(hp - an.pos[e].astype(np.float32), axis=1)
        out[head[d <= radius]] = True
    return out


def recolour(an, table, meta, eye_glow_red=None):
    """New per-cell colours and the emissive mask for one skin (table: 6 x 4 x 3 swatches)."""
    new = an.col.astype(np.float32).copy()
    for r in range(len(R.REGIONS)):
        m = an.reg == r
        if m.sum() < 5:
            continue
        t = an.t[m][:, None]
        sh, mid, li = (table[r, i].astype(np.float32) for i in range(3))
        new[m] = np.where(t < 0.5, sh + (mid - sh) * (t / 0.5), mid + (li - mid) * ((t - 0.5) / 0.5))
    # folds: darker (and tinted) in creases
    k = (meta["fold"] * an.fold)[:, None]
    fc = np.array(H(meta["fold_color"]), np.float32)
    new = new * (1 - k) + fc * k
    emissive = np.zeros(len(an.pos), bool)
    if meta["glow"] == "seams":
        emissive = glow_seams(an)
    elif meta["glow"] == "flank_row":
        emissive = glow_flank_row(an)
    for r in np.unique(an.reg[emissive]):
        sel = emissive & (an.reg == r)
        new[sel] = table[r, 3].astype(np.float32)
    # lip-line cells carry the back swatch's glow even when classed as teeth/belly
    if meta["glow"] == "seams":
        new[emissive & np.isin(an.reg, (R.TEETH, R.EYES, R.CLAWS))] = table[R.BACK, 3].astype(np.float32)
    if eye_glow_red is not None:
        blob = eye_blob(an)
        new[blob] = np.array(H(eye_glow_red), np.float32)
        emissive |= blob
    return np.clip(new, 0, 255).astype(np.uint8), emissive


# ---- board ------------------------------------------------------------------------------------------------------------

def board(out_path):
    an = Analysis()
    pos, nrm, bone = an.pos, an.nrm, an.bone
    head = np.isin(bone, an.bone_ids("head0", "head1", "jaw"))
    skins = [("Today", None, None, None, "")]
    for n in PALETTES:
        table, meta = load_skin(n)
        skins.append((n.capitalize(), table, meta, None, ""))
    table, meta = load_skin("albino")
    skins.append(("Albino, eye glow red (needs the director's yes)", table, meta, "ff2a3c", ""))
    pw, ph = 760, 640
    sw, label_h = 46, 34
    font = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 34)
    lab = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 26)
    small = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 22)
    row_h = 90 + label_h + 10 + ph
    sheet = Image.new("RGB", (pw * 3 + 80, 90 + len(skins) * row_h), (22, 23, 27))
    d = ImageDraw.Draw(sheet)
    d.text((20, 18), "Croc titan skins as colour tables per region (game voxels, same camera and light)", font=font, fill=(235, 235, 235))
    y = 80
    heads = ["Behind, 3/4 from above", "Front 3/4", "Head, 2x crop"]
    stats = {}
    for label, table, meta, eyered, _ in skins:
        if table is None:
            newcol, emi = an.col, np.zeros(len(an.col), bool)
        else:
            newcol, emi = recolour(an, table, meta, eyered)
        stats[label] = round(float(emi.mean() * 100), 2)
        d.text((20, y), label, font=font, fill=(255, 214, 51))
        if table is not None:  # the palette: six regions, four swatches each, names big enough to read at 1x
            for r, rn in enumerate(R.REGIONS):
                gx = 20 + r * 205 if len(label) < 12 else 20 + r * 205
                gx += 0
                x0 = 20 + r * 245 + (0 if len(label) < 12 else 0)
                for x in range(4):
                    d.rectangle((x0 + x * (sw - 8), y + 46, x0 + x * (sw - 8) + sw - 10, y + 46 + 40), fill=tuple(int(v) for v in table[r, x]))
                d.text((x0, y + 90), rn, font=lab, fill=(255, 255, 255))
            py = y + 128
        else:
            py = y + 60
        row = []
        for yaw, pitch in ((205, 28), (35, 14)):
            img, sc, ctr = V.render(pos, newcol, nrm, yaw, pitch, size=(pw, ph), glow=emi, gain=1.35)
            row.append(img)
        m = V.camera(35, 14)
        hc = (pos[head].astype(np.float32) @ m.T).mean(0)
        img, _, _ = V.render(pos, newcol, nrm, 35, 14, size=(pw, ph), scale=sc * 2.6, center=hc, glow=emi, gain=1.35)
        row.append(img)
        for i, im in enumerate(row):
            sheet.paste(im, (20 + i * (pw + 20), py))
            if table is None:
                d.text((30 + i * (pw + 20), py + ph - 30), heads[i], font=small, fill=(30, 30, 30))
        y = py + ph + 20
    sheet.crop((0, 0, sheet.width, y)).save(out_path)
    return {"region cells": {r: int((an.reg == i).sum()) for i, r in enumerate(R.REGIONS)}, "glow percent": stats}


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "palettes":
        write_palettes()
    elif cmd == "board":
        print(board(sys.argv[2]))
