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
        "glow": "seams", "fold": 0.30, "fold_color": "000000", "patch": 0.12, "tint": None, "jaw_tint": None,
        "tail_belly_blend": 0.0, "min_run": 60, "t_max": 1.0, "smooth_t": 0.0, "gamma_t": 1.0, "belly_rows": 0.0,
        "eye_core": None, "eye_ring": None, "eye_emissive": True, "extremity_tint": None,
        "back": ("0b0c11", "272a34", "5a5e70", "ff5a1a"), "belly": ("171923", "3a3d4c", "62667a", "ff5a1a"),
        "spines": ("06060a", "16161c", "34343f", "ff7a28"), "claws": ("0a0a0c", "26262c", "62626e", "ff5a1a"),
        "eyes": ("c84a10", "ff7a20", "ffc060", "ffd080"), "teeth": ("302f2b", "5e5b50", "8e8a78", "8e8a78"),
    },
    "abyssal": {
        "glow": "abyssal", "fold": 0.30, "fold_color": "000d0c", "patch": 0.12, "tint": None, "jaw_tint": "2fb8aa",
        "tail_belly_blend": 0.7, "min_run": 10, "t_max": 1.0, "smooth_t": 0.0, "gamma_t": 1.0, "belly_rows": 0.14,
        "eye_core": None, "eye_ring": None, "eye_emissive": True, "extremity_tint": None,
        "back": ("010605", "052a25", "0f5a50", "2fb8aa"), "belly": ("0f4643", "2c847c", "62b8aa", "2fb8aa"),
        "spines": ("031314", "0c3638", "1f6464", "2fb8aa"), "claws": ("040d0f", "10292b", "2a5654", "2fb8aa"),
        "eyes": ("5fe0c8", "bffff0", "e8fffa", "e8fffa"), "teeth": ("2c7a72", "62b6ab", "a6e2d6", "a6e2d6"),
    },
    "albino": {
        "glow": None, "fold": 0.32, "fold_color": "b09a74", "patch": 0.10, "tint": "e8b4a8", "jaw_tint": None,
        "tail_belly_blend": 0.0, "min_run": 10, "t_max": 0.80, "smooth_t": 0.7, "gamma_t": 0.55, "belly_rows": 0.0,
        "eye_core": "ffe8ee", "eye_ring": "6e5448", "eye_emissive": False, "extremity_tint": "e8b4a8",
        "back": ("cdb99a", "efe3c8", "f8f0de", "f8f0de"), "belly": ("e6c9b8", "f6ddd0", "fdeee4", "fdeee4"),
        "spines": ("c2ad8a", "dccdaa", "efe4c8", "efe4c8"), "claws": ("d8a698", "e8b4a8", "f4cfc4", "f4cfc4"),
        "eyes": ("d896a8", "f5b8c6", "ffd8e0", "ffd8e0"), "teeth": ("dccfa8", "f4ecd0", "fffcf0", "fffcf0"),
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
            {k: p[k] for k in ("glow", "fold", "fold_color", "patch", "tint", "jaw_tint", "tail_belly_blend", "min_run", "t_max", "smooth_t", "gamma_t", "belly_rows", "eye_core", "eye_ring", "eye_emissive", "extremity_tint")}, indent=1), encoding="utf-8", newline="\n")


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

    def neighbours(self):
        """(n, 6) index of the face neighbours (-1 where empty), built once."""
        if getattr(self, "_nbr", None) is None:
            where = {tuple(p): i for i, p in enumerate(self.pos)}
            dirs = ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))
            self._nbr = np.array([[where.get((x + d[0], y + d[1], z + d[2]), -1) for d in dirs] for x, y, z in self.pos])
        return self._nbr

    def smoothed(self, values, strength):
        """values blended with the mean of their same-region face neighbours (strength 0..1): kills single-cell specks."""
        nbr = self.neighbours()
        acc = values.copy()
        cnt = np.ones(len(values), np.float32)
        for k in range(6):
            ok = nbr[:, k] >= 0
            ok[ok] = self.reg[nbr[ok, k]] == self.reg[ok]
            acc[ok] += values[nbr[ok, k]]
            cnt[ok] += 1
        return values * (1 - strength) + (acc / cnt) * strength

    def bone_ids(self, *ns):
        return [self.names.index(n) for n in ns if n in self.names]


def keep_runs(mask, pos, min_size):
    """Drop connected runs smaller than min_size: a glow is a run, never a single cell."""
    out = np.zeros(len(mask), bool)
    for c in components(mask, pos, min_size):
        out[c] = True
    return out


def lip_line(an):
    """Cells of head1 that touch a jaw cell (and the jaw cells they touch): a connected seam all along the mouth."""
    pos = an.pos
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
    out = np.zeros(len(pos), bool)
    out[np.array(lip, dtype=int)] = True
    return out


def spine_base_runs(an, fold_min, min_size, budget, exclude=()):
    """Short connected runs in the creases between spine bases (not on the neck/head: those read as specks)."""
    cand = (an.reg == R.SPINES) & (an.fold > fold_min) & ~np.isin(an.bone, an.bone_ids(*exclude))
    mask = np.zeros(len(an.pos), bool)
    for c in components(cand, an.pos, min_size):
        if mask.sum() + len(c) <= budget:
            mask[c] = True
    return mask


def glow_seams(an, min_run):
    """Obsidian: ember in connected runs. Dark creased hide (scute and joint seams, runs of at least min_run), a
    continuous glow in the gaps between the dorsal spines along the whole back and tail, and the lip line."""
    reg, t, fold, pos = an.reg, an.t, an.fold, an.pos
    cand = np.isin(reg, (R.BACK, R.BELLY)) & (fold > 0.55) & (t < 0.15) & ~np.isin(an.bone, an.bone_ids("head0", "head1"))
    budget = int(0.02 * len(pos))
    seams = np.zeros(len(pos), bool)
    for c in components(cand, pos, min_run):  # biggest runs first, until the budget is spent
        if seams.sum() + len(c) <= budget:
            seams[c] = True
    spines = spine_base_runs(an, 0.28, 14, int(0.03 * len(pos)), exclude=("head0", "head1"))
    return seams | spines | lip_line(an)


def glow_abyssal(an, min_run):
    """Abyssal: faint cyan dashes along each flank on the dark stripe bands of the body and tail, plus short runs
    in the creases between spine bases. No single cells."""
    pos, nrm, lum = an.pos, an.nrm, an.lum
    body = np.isin(an.bone, an.bone_ids("spine1", "spine2", *[f"tail{i}" for i in range(9)]))
    mask = np.zeros(len(pos), bool)
    for side in (-1, 1):
        flank = body & (np.sign(pos[:, 0]) == side) & (np.abs(nrm[:, 0]) > 0.6) & (an.reg == R.BACK)
        zs = np.unique(pos[flank, 2])
        zl = np.array([lum[flank & (pos[:, 2] == z)].mean() for z in zs])
        k = 31
        avg = np.convolve(np.pad(zl, k // 2, mode="edge"), np.ones(k) / k, mode="valid")
        dark = zl < avg * 0.88
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
            mask |= flank & ((((pos[:, 2] - zc) / 2.4) ** 2 + ((pos[:, 1] - yc) / 6.5) ** 2) <= 1.0)
    mask |= spine_base_runs(an, 0.5, 14, int(0.008 * len(pos)), exclude=("head0", "head1"))
    return keep_runs(mask, pos, min_run)


def eye_blob(an, radius=1.3):
    """The species eye glow, grown at most one cell round the eye cells so it reads at the 2x crop."""
    eyes = np.nonzero(an.reg == R.EYES)[0]
    head = np.nonzero(np.isin(an.bone, an.bone_ids("head0", "head1", "jaw")))[0]
    out = np.zeros(len(an.pos), bool)
    out[eyes] = True
    hp = an.pos[head].astype(np.float32)
    for e in eyes:
        d = np.linalg.norm(hp - an.pos[e].astype(np.float32), axis=1)
        out[head[d <= radius]] = True
    return out


def patch_noise(pos, spacing=7, seed=11):
    """Smooth value noise (-1..1) on a coarse lattice: clustered patches, never single cells."""
    f = pos.astype(np.float64) / spacing
    i = np.floor(f).astype(np.int64)
    u = f - i
    u = u * u * (3 - 2 * u)

    def h(ix, iy, iz):
        v = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ (seed * 2654435761)
        v = (v ^ (v >> 13)) * 1274126177
        return ((v ^ (v >> 16)) & 0xFFFF) / 32767.5 - 1.0

    out = 0.0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (u[:, 0] if dx else 1 - u[:, 0]) * (u[:, 1] if dy else 1 - u[:, 1]) * (u[:, 2] if dz else 1 - u[:, 2])
                out = out + w * h(i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz)
    return out.astype(np.float32)


def joint_and_throat_weight(an):
    """Smooth 0..1 blood-tint field: round the limb joints and under the throat."""
    pos = an.pos.astype(np.float32)
    rig = json.loads((V.REPO / "assets" / "kaiju" / "reptilian_adult.rig.json").read_text(encoding="utf-8"))
    heads = {b["name"]: np.array(b["head"], np.float32) for b in rig["bones"]}
    w = np.zeros(len(pos), np.float32)
    for n in ("arm_l1", "arm_l2", "arm_r1", "arm_r2", "leg_l1", "leg_l2", "leg_r1", "leg_r2"):
        d = np.linalg.norm(pos - heads[n], axis=1)
        w = np.maximum(w, np.exp(-(d / 11.0) ** 2))
    head = np.isin(an.bone, an.bone_ids("head0", "head1", "jaw"))
    throat = np.clip((-an.nrm[:, 1] - 0.15) / 0.5, 0, 1) * head
    return np.maximum(w, 0.8 * throat)


def eye_centres(an):
    """One centre per side: the middle of that side's eye cells."""
    out = []
    for side in (-1, 1):
        e = np.nonzero((an.reg == R.EYES) & (np.sign(an.pos[:, 0]) == side))[0]
        if len(e):
            out.append(an.pos[e].astype(np.float32).mean(0))
    return out


def extremity_weight(an):
    """Smooth 0..1 weight on hands, feet, claws and the snout tip (where blood shows through thin hide)."""
    w = np.zeros(len(an.pos), np.float32)
    for n in ("arm_l2", "arm_r2", "leg_l2", "leg_r2"):
        w[an.bone == an.bone_ids(n)[0]] = 0.85
    w[an.reg == R.CLAWS] = 1.0
    head1 = an.bone == an.bone_ids("head1")[0]
    nose = an.pos[head1, 2].min()
    w = np.maximum(w, np.where(head1, np.clip(1 - (an.pos[:, 2] - nose) / 22.0, 0, 1), 0).astype(np.float32))
    return w


def recolour(an, table, meta, eye_glow_red=None):
    """New per-cell colours and the emissive mask for one skin (table: 6 x 4 x 3 swatches)."""
    new = an.col.astype(np.float32).copy()
    noise = patch_noise(an.pos)
    t_src = an.smoothed(an.t, meta["smooth_t"]) if meta["smooth_t"] > 0 else an.t
    t_all = np.clip(t_src + meta["patch"] * noise, 0, 1) ** meta["gamma_t"]
    t_all = np.minimum(t_all, meta["t_max"])
    if meta["belly_rows"] > 0:  # varied scute rows: a random value per row (z slice) on the belly
        rows = np.array([((int(z) * 2654435761) >> 7) & 0xFF for z in an.pos[:, 2]], np.float32) / 255.0 - 0.5
        t_all = np.where(an.reg == R.BELLY, np.clip(t_all + meta["belly_rows"] * rows * 2, 0, 1), t_all)
    for r in range(len(R.REGIONS)):
        m = an.reg == r
        if m.sum() < 5:
            continue
        t = (t_all if r in (R.BACK, R.BELLY, R.SPINES) else an.t)[m][:, None]
        sh, mid, li = (table[r, i].astype(np.float32) for i in range(3))
        new[m] = np.where(t < 0.5, sh + (mid - sh) * (t / 0.5), mid + (li - mid) * ((t - 0.5) / 0.5))
    # the tail's underside fades toward the back colour so it never reads as a lit strip
    if meta["tail_belly_blend"] > 0:
        for i in range(9):
            sel = (an.reg == R.BELLY) & (an.bone == an.bone_ids(f"tail{i}")[0])
            k = min(0.9, meta["tail_belly_blend"] * (0.3 + 0.1 * i))
            new[sel] = new[sel] * (1 - k) + table[R.BACK, 1].astype(np.float32) * k
    # a faint tint along the jaw
    if meta["jaw_tint"]:
        jaw = an.bone == an.bone_ids("jaw")[0]
        z0, z1 = an.pos[jaw, 2].max(), an.pos[jaw, 2].min()
        u = np.clip((z0 - an.pos[:, 2]) / (z0 - z1), 0, 1)
        k = (0.38 * u * jaw)[:, None]
        new = new * (1 - k) + np.array(H(meta["jaw_tint"]), np.float32) * k
    # folds: darker (and tinted) in creases
    k = (meta["fold"] * an.fold)[:, None]
    new = new * (1 - k) + np.array(H(meta["fold_color"]), np.float32) * k
    # a smooth blood tint (low saturation) round joints and under the throat, stronger at the extremities
    if meta["tint"]:
        k = (0.30 * joint_and_throat_weight(an))[:, None]
        new = new * (1 - k) + np.array(H(meta["tint"]), np.float32) * k
    if meta["extremity_tint"]:
        k = (0.34 * extremity_weight(an))[:, None]
        new = new * (1 - k) + np.array(H(meta["extremity_tint"]), np.float32) * k
    emissive = np.zeros(len(an.pos), bool)
    if meta["glow"] == "seams":
        emissive = glow_seams(an, meta["min_run"])
    elif meta["glow"] == "abyssal":
        emissive = glow_abyssal(an, meta["min_run"])
    for r in np.unique(an.reg[emissive]):
        sel = emissive & (an.reg == r)
        new[sel] = table[r, 3].astype(np.float32)
    if meta["glow"]:
        new[emissive & ~np.isin(an.reg, (R.BACK, R.BELLY, R.SPINES))] = table[R.BACK, 3].astype(np.float32)
    # eyes: the eye cells in the table colour, a pale core on the middle ones and a dark ring round them
    eye = an.reg == R.EYES
    head = np.isin(an.bone, an.bone_ids("head0", "head1", "jaw"))
    for c in eye_centres(an):
        d = np.linalg.norm(an.pos.astype(np.float32) - c, axis=1)
        if meta["eye_ring"]:
            ring = head & ~eye & (d <= 3.0)
            new[ring] = np.array(H(meta["eye_ring"]), np.float32)
        if meta["eye_core"]:
            core = eye & (d <= 0.9)
            new[core] = np.array(H(meta["eye_core"]), np.float32)
    if eye_glow_red is not None:
        new[eye] = np.array(H(eye_glow_red), np.float32)
        for c in eye_centres(an):
            d = np.linalg.norm(an.pos.astype(np.float32) - c, axis=1)
            new[eye & (d <= 0.9)] = np.array((255, 208, 208), np.float32)
        emissive |= eye
    elif meta["eye_emissive"]:
        emissive |= eye
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
    heads = ["Behind, 3/4 from above", "Front 3/4 (from the left)", "Head, 2x crop"]
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
        for yaw, pitch in ((205, 28), (-35, 14)):
            img, sc, ctr = V.render(pos, newcol, nrm, yaw, pitch, size=(pw, ph), glow=emi, gain=1.3, ambient=0.58)
            row.append(img)
        m = V.camera(-35, 14)  # the croc's clearer eye is on its left (-x), so the 2x crop looks from that side
        hc = (pos[head].astype(np.float32) @ m.T).mean(0)
        img, _, _ = V.render(pos, newcol, nrm, -35, 14, size=(pw, ph), scale=sc * 2.6, center=hc, glow=emi, gain=1.3, ambient=0.58)
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
