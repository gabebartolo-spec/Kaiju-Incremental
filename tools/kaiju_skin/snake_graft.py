"""Grafts a snake head (viper or cobra, a Tripo model voxelised with tools/blender/voxelize.py) onto the croc's
neck, keeping the croc's body, rig and neck (D-164/D-171 heads, test assets only, nothing wired).

    python tools/kaiju_skin/snake_graft.py <croc.kvox> <head.kvox> <out.kvox> --gape Z,Y --tip Z,Y [options]

Steps: cut the donor's head (cells forward of --cut-z and above --min-y), straighten its axis (a shear that
cancels any yaw of the voxelised model), place it so its gape corner sits on the croc's jaw hinge, tag the
cells head0 / head1 / jaw like head_graft.py, then the optional shape work in donor space:
  --bulge B     widen the lower cheeks behind the eye (a jaw-angle bulge, triangular head)
  --flatten F   squash the crown above the eye line (0..1)
  --fangs       delete the ivory fang cells (fangs fold behind the lip)
  --blend M     pull the head colours toward the croc's hide (keeping their light and dark), strongest at the neck
  --eye R       a bigger gold eye with a slit pupil (radius R cells) on each side
  --hood        add a flat sideways-flared cobra hood behind the head (cells on head0), spectacle mark on its back
"""
import argparse
import json
import struct
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake  # noqa: E402


def write_kvox(path, cells, rgb, bone, height):
    rec = np.zeros(len(cells), dtype=[("p", "<i2", 3), ("c", "u1", 3), ("f", "u1")])
    rec["p"], rec["c"], rec["f"] = cells, rgb, bone
    path.write_bytes(b"KVOX" + struct.pack("<IIH", 2, 1, height) + struct.pack("<I", len(cells)) + rec.tobytes())


def lum_of(c):
    c = c.astype(np.float32) / 255
    return 0.2126 * c[..., 0] + 0.7152 * c[..., 1] + 0.0722 * c[..., 2]


def smooth(x):
    x = np.clip(x, 0, 1)
    return x * x * (3 - 2 * x)


def hood_cells(centre, body_rgb, belly_rgb, half_w=46.0, base_w=20.0, height=116.0, curve=12.0, thick=3, tilt=0.45):
    """A flat bell-shaped shield flaring sideways from the neck: narrow at its base, widest about half way up,
    curving forward at the edges. Returns cells (n,3), rgb (n,3)."""
    cx, cy, cz = centre
    cells, rgb = [], []
    y0, y1 = cy - height * 0.45, cy + height * 0.55
    for y in range(int(y0), int(y1) + 1):
        u = (y - y0) / (y1 - y0)
        w = base_w + (half_w - base_w) * np.sin(np.pi * np.clip(u, 0, 1) ** 1.5) ** 0.75
        if u > 0.93:  # a rounded top
            w *= np.sqrt(max(0.0, 1 - ((u - 0.93) / 0.07) ** 2))
        for x in range(-int(w), int(w) + 1):
            e = abs(x) / max(w, 1.0)
            zc = cz - curve * e * e + tilt * (y - y0)  # the edges curve forward; the shield leans back
            for layer in range(thick):
                z = int(round(zc + layer))
                cells.append((cx + x, y, z))
                rgb.append((layer, x, y))  # placeholder, coloured below
    cells = np.array(cells)
    tag = np.array(rgb)
    cols = np.zeros((len(cells), 3), np.uint8)
    dark = np.array((34, 38, 30), float)
    mid = np.array((74, 80, 58), float)
    for i, (layer, x, y) in enumerate(tag):
        yy = y - cy
        if layer == 0:  # the front face: cream scutes with fine rows
            row = 0.5 + 0.5 * np.sin(yy * 1.3)
            cols[i] = np.clip(np.array((226, 212, 172), float) * (0.82 + 0.18 * row), 0, 255)
            continue
        # the back face: narrow dark bands, with one symmetric spectacle mark centred on the back
        band = 0.5 + 0.5 * np.sin(yy * 0.9)
        c = dark + (mid - dark) * (0.25 + 0.5 * band)
        r = np.hypot(x, yy - 26)
        ring = 9.0 <= r <= 13.5
        centre_dark = r < 6.5
        bar = (abs(abs(x) - 8) <= 1.8) and (-8 <= yy <= 8)
        if ring or bar:
            c = np.array((232, 214, 160), float)
        elif centre_dark:
            c = np.array((18, 16, 12), float)
        cols[i] = np.clip(c, 0, 255)
    return cells, cols


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("croc")
    ap.add_argument("donor")
    ap.add_argument("out")
    ap.add_argument("--cut-z", type=float, default=-330.0)
    ap.add_argument("--min-y", type=float, default=330.0)
    ap.add_argument("--gape", required=True)
    ap.add_argument("--tip", required=True)
    ap.add_argument("--scale", type=float, default=0.8)
    ap.add_argument("--gamma", type=float, default=2.2)
    ap.add_argument("--crown", default=None, help="z0,y0,z1,y1: drop donor cells above this line (a hood fin)")
    ap.add_argument("--axis-z", default="-430,-340", help="z range used to straighten the head axis")
    ap.add_argument("--bulge", type=float, default=0.0)
    ap.add_argument("--flatten", type=float, default=0.0)
    ap.add_argument("--fangs", action="store_true")
    ap.add_argument("--blend", type=float, default=0.0)
    ap.add_argument("--eye", type=float, default=0.0)
    ap.add_argument("--hood", action="store_true")
    a = ap.parse_args()
    croc_path = Path(a.croc)
    rig = json.loads(croc_path.with_suffix(".rig.json").read_text(encoding="utf-8"))
    names = [b["name"] for b in rig["bones"]]
    h0, h1, jw = (names.index(n) for n in ("head0", "head1", "jaw"))
    cp, cc, cf = bake.read_kvox(croc_path)
    dp, dc, _ = bake.read_kvox(Path(a.donor))
    hinge = np.array([rig["bones"][jw]["head"][2], rig["bones"][jw]["head"][1]])
    gape = np.array([float(v) for v in a.gape.split(",")])
    tip = np.array([float(v) for v in a.tip.split(",")])
    s = a.scale
    keep = (dp[:, 2] < a.cut_z) & (dp[:, 1] > a.min_y)
    if a.crown:
        z0, y0, z1, y1 = (float(v) for v in a.crown.split(","))
        line = y0 + (y1 - y0) * (dp[:, 2] - z0) / (z1 - z0)
        keep &= dp[:, 1] <= line
    q = dp[keep].astype(float)
    col = np.clip(255.0 * (dc[keep] / 255.0) ** a.gamma, 0, 255)
    # straighten the head axis: its centre line x(z) is fitted over the snout and skull and rotated onto z
    za, zb = (float(v) for v in a.axis_z.split(","))
    zs = np.arange(int(za), int(zb), 4)
    cen = []
    for z in zs:
        m = (np.abs(q[:, 2] - z) < 2) & (q[:, 1] > a.min_y + 10)
        cen.append((q[m, 0].min() + q[m, 0].max()) / 2 if m.sum() > 20 else np.nan)
    ok = ~np.isnan(cen)
    cz = np.polyfit(zs[ok], np.array(cen)[ok], 1)
    phi = np.arctan(cz[0])  # the head's yaw: rotate about the vertical through the gape so its axis runs along z
    px, pz = np.polyval(cz, gape[0]), gape[0]
    dx, dz = q[:, 0] - px, q[:, 2] - pz
    q[:, 0] = dx * np.cos(phi) - dz * np.sin(phi)
    q[:, 2] = pz + dx * np.sin(phi) + dz * np.cos(phi)
    snout = (q[:, 2] < gape[0] + 10) & (q[:, 1] > a.min_y + 10)
    q[:, 0] -= (q[snout, 0].min() + q[snout, 0].max()) / 2  # centre the head on x = 0
    # eye cells (amber, saturated, high on the head), found before any reshaping
    mx, mn = col.max(1), col.min(1)
    sat = (mx - mn) / np.maximum(mx, 1)
    amber = (sat > 0.6) & (col[:, 0] > col[:, 1]) & (col[:, 1] > col[:, 2]) & (q[:, 1] > gape[1] + 8) & (col[:, 0] > 90)
    eye_ctrs = []
    for side in (-1, 1):
        sel = np.nonzero(amber & (np.sign(q[:, 0]) == side))[0]
        if len(sel):
            score = col[sel, 0] - 0.5 * (col[sel, 1] + col[sel, 2])
            eye_ctrs.append(q[sel[np.argmax(score)]].copy())
    # shape work in donor space
    if a.bulge > 0:  # a jaw-angle bulge: lower cheeks widen toward the back of the jaw, taper to a blunt nose
        u = smooth((q[:, 2] - tip[0]) / max(gape[0] - tip[0] + 20.0, 1.0))
        low = smooth((gape[1] + 26 - q[:, 1]) / 40.0 + 0.35)
        q[:, 0] *= 1 + a.bulge * u * low
    if a.flatten > 0 and eye_ctrs:
        top = np.mean([e[1] for e in eye_ctrs])
        above = np.maximum(q[:, 1] - top, 0)
        q[:, 1] = q[:, 1] - a.flatten * above
    if a.fangs:
        ivory = (lum_of(col) > 0.5) & (sat < 0.40)
        line_y = gape[1] + (tip[1] - gape[1]) * np.clip((q[:, 2] - gape[0]) / (tip[0] - gape[0]), 0, 1)
        fang = ivory & (q[:, 2] < tip[0] + 22) & (q[:, 1] < line_y + 2)
        q, col = q[~fang], col[~fang]
    # place: gape corner onto the croc's jaw hinge
    zy = (q[:, [2, 1]] - gape) * s + hinge
    new = np.round(np.c_[q[:, 0] * s, zy[:, 1], zy[:, 0]]).astype(int)
    croc_cut = (a.cut_z - gape[0]) * s + hinge[0]
    # bones
    tip_n = (tip - gape) * s + hinge
    z0, y0, z1, y1 = tip_n[0], tip_n[1], hinge[0], hinge[1]
    line_y = y0 + (y1 - y0) * (new[:, 2] - z0) / (z1 - z0)
    bone = np.where(new[:, 2] >= hinge[0], h0, np.where(new[:, 1] < line_y, jw, h1)).astype(np.uint8)
    # colours: toward the croc's hide, keeping the head's own light and dark; strongest at the neck, softer at the nose
    body_sel = (cf == names.index("spine2")) & (np.abs(cp[:, 0]) < 30) & (cp[:, 1] > 270)
    body_rgb = cc[body_sel].astype(float).mean(0) if body_sel.sum() else np.array((60, 70, 40.0))
    belly_rgb = cc[(cf == names.index("spine2")) & (cp[:, 1] < 262)].astype(float).mean(0)
    if a.blend > 0:
        l_body = lum_of(body_rgb)
        gain = (lum_of(col) / max(float(lum_of(col).mean()), 1e-3))[:, None]
        target = np.clip(body_rgb[None, :] * gain, 0, 255)
        fade = (0.55 + 0.45 * smooth((new[:, 2] - (croc_cut - 70)) / 70.0))[:, None]
        m = np.clip(a.blend * fade, 0, 1)
        col = col * (1 - m) + target * m
    # a bigger gold eye with a slit pupil on each side
    if a.eye > 0:
        for e in eye_ctrs:
            en = np.array([e[0] * s, (e[1] - gape[1]) * s + hinge[1], (e[2] - gape[0]) * s + hinge[0]])
            d = np.linalg.norm(new - en, axis=1)
            iris = d <= a.eye
            col[iris] = (214, 168, 48)
            slit = iris & (np.abs(new[:, 2] - en[2]) <= 0.7)
            col[slit] = (14, 12, 8)
    col = np.clip(col, 0, 255).round().astype(np.uint8)
    # the croc cells that stay
    is_head = np.isin(cf, (h0, h1, jw))
    drop = is_head & (cp[:, 2] < croc_cut)
    keep_c = ~drop
    all_cells = [cp[keep_c], new]
    all_rgb = [cc[keep_c], col]
    all_bone = [cf[keep_c], bone]
    hood_n = 0
    if a.hood:
        # the neck's centre just behind the cut
        nk = (cf == h0) & (cp[:, 2] > croc_cut) & (cp[:, 2] < croc_cut + 14)
        centre = (0, int(cp[nk, 1].mean()) + 38, int(croc_cut) + 2) if nk.sum() else (0, 305, int(croc_cut) + 2)
        hc, hr = hood_cells(centre, body_rgb, belly_rgb)
        all_cells.append(hc)
        all_rgb.append(hr)
        all_bone.append(np.full(len(hc), h0, np.uint8))
        hood_n = len(hc)
    cells = np.vstack(all_cells)
    rgb = np.vstack(all_rgb)
    bones = np.concatenate(all_bone)
    _, last = np.unique(cells[::-1], axis=0, return_index=True)
    sel = np.sort(len(cells) - 1 - last)
    out = Path(a.out)
    write_kvox(out, cells[sel], rgb[sel], bones[sel], rig["height"])
    nose_z = float(new[:, 2].min())
    rig2 = json.loads(json.dumps(rig))
    for b in rig2["bones"]:
        if b["name"] == "jaw":
            b["tail"] = [0.0, round(float(y1 - 6), 2), round(nose_z + 2, 2)]
        if b["name"] == "head1":
            b["tail"] = [0.0, round(float(y1), 2), round(nose_z, 2)]
    out.with_suffix(".rig.json").write_text(json.dumps(rig2, indent=1), encoding="utf-8", newline="\n")
    print(json.dumps({
        "cells": int(len(sel)), "donor_head_cells": int(len(new)), "hood_cells": hood_n, "croc_cells_dropped": int(drop.sum()),
        "croc_cut_z": round(float(croc_cut), 1), "hinge_zy": hinge.tolist(), "nose_z": nose_z,
        "snout_hinge_to_nose": round(float(hinge[0] - nose_z), 1), "croc_snout_hinge_to_nose": round(float(hinge[0] - cp[:, 2].min()), 1),
        "head_width": int(new[:, 0].max() - new[:, 0].min()), "eye_centres": [e.round(1).tolist() for e in eye_ctrs],
    }))


if __name__ == "__main__":
    main()
