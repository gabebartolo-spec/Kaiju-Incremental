"""Measures and sheets the escalation stills (capture_escalation.gd).
  python tools/capture/escalation_sheet.py <dir> [--baseline <dir>] [--sheet out.png]
Per time and level: sky colour (top rows), the kaiju's contrast against its surroundings (Michelson
luma contrast of the pixels that differ from the kaiju-less frame, against a ring round them) as a
share of the level-0 frame's, and (with --baseline) the pixel difference of the level-0 frame from
the pre-change frame."""
import sys, glob, os, re
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

TIMES = ["dusk", "night", "morning", "noon"]
RING = 12
THUMB = 640


def luma(a):
    return a[..., 0] * 0.2126 + a[..., 1] * 0.7152 + a[..., 2] * 0.0722


def load(path):
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.float32) / 255.0


def kaiju_mask(with_k, without):
    """The kaiju's pixels: what differs when it is hidden, inside a box round it (animated
    street life elsewhere would otherwise count)."""
    h, w = with_k.shape[:2]
    mask = np.abs(with_k - without).sum(axis=2) > 0.08
    box = np.zeros_like(mask)
    box[int(h * 0.30) : int(h * 0.92), int(w * 0.38) : int(w * 0.62)] = True
    return mask & box


def contrast(with_k, without, mask):
    """How far the kaiju stands out from what is behind him: the mean luma difference, over his
    level-0 pixels, between this frame and the same frame with him hidden."""
    if mask is None or mask.sum() < 200:
        return None
    return float(np.abs(luma(with_k) - luma(without))[mask].mean())


def val(s):
    return 0.0 if s == "0" else float(s[0] + "." + s[1:])


def main():
    args = sys.argv[1:]
    d = args[0]
    base = args[args.index("--baseline") + 1] if "--baseline" in args else None
    sheet = args[args.index("--sheet") + 1] if "--sheet" in args else os.path.join(d, "sheet.png")
    found = set()
    for f in glob.glob(os.path.join(d, "*_d*.png")):
        if "nokaiju" not in f:
            found.add(re.search(r"_d(\d+)\.png", f).group(1))
    levels = sorted(found, key=val)
    rows = []
    for t in TIMES:
        c0 = None
        row = []
        for lv in levels:
            f = os.path.join(d, f"{t}_d{lv}.png")
            if not os.path.exists(f):
                continue
            img = load(f)
            h, w = img.shape[:2]
            sky = img[: int(h * 0.06), w // 4 : 3 * w // 4].reshape(-1, 3).mean(0)
            if c0 is None:  # the first (level 0) frame fixes the kaiju's pixels
                mask0 = kaiju_mask(img, load(os.path.join(d, f"{t}_d{lv}_nokaiju.png")))
            c = contrast(img, load(os.path.join(d, f"{t}_d{lv}_nokaiju.png")), mask0)
            if c0 is None:
                c0 = c
            ratio = None if (c is None or not c0) else c / c0
            hexsky = "".join("%02x" % int(x * 255) for x in sky)
            line = f"{t} d={val(lv):.1f} sky=#{hexsky} kaiju_contrast={c} ratio_vs_d0={ratio}"
            if base and val(lv) == 0.0:
                b = load(os.path.join(base, f"{t}_d{lv}.png"))
                line += f" diff_vs_baseline max={np.abs(b - img).max():.4f} mean={np.abs(b - img).mean():.6f}"
            print(line)
            label = f"{t} destruction {val(lv):.1f}" + (f"   kaiju contrast {ratio:.2f}x of d0" if ratio else "")
            row.append((label, Image.open(f).convert("RGB")))
        rows.append(row)
    cols = max(len(r) for r in rows)
    w = THUMB
    h = int(w * 9 / 16)
    out = Image.new("RGB", (cols * w, len(rows) * (h + 24)), (20, 20, 20))
    dr = ImageDraw.Draw(out)
    for ri, row in enumerate(rows):
        for ci, (label, im) in enumerate(row):
            out.paste(im.resize((w, h), Image.LANCZOS), (ci * w, ri * (h + 24) + 24))
            dr.text((ci * w + 6, ri * (h + 24) + 6), label, fill=(240, 240, 240))
    out.save(sheet)
    print("sheet", sheet)


main()
