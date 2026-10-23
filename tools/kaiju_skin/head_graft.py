"""Grafts another voxelised creature's head onto the croc's neck (D-164 heads, test asset only).

    python tools/kaiju_skin/head_graft.py <croc.kvox> <head.kvox> <out.kvox> [options]

The croc's head set (head0, head1, jaw) in front of the cut plane is replaced by the donor's head, scaled
and placed so the donor's jaw corner (gape) sits on the croc's jaw hinge; the donor's cells are tagged
head0 (behind the hinge), head1 (in front of it, above the mouth line) or jaw (in front, below it), so the
game's bite and roar open it like the croc's. Every other cell is untouched. The matching rig.json is
written beside the output (jaw/head1 tails moved to the donor's snout; the hinge stays put).

Donor frame: the voxelised GLB (tools/blender/voxelize.py), nose toward -z, y up, x centred.
Options (donor coordinates, before scale): --cut-z, --min-y, --gape Z,Y, --tip Z,Y, --scale S
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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("croc")
    ap.add_argument("donor")
    ap.add_argument("out")
    ap.add_argument("--cut-z", type=float, default=-330.0)
    ap.add_argument("--min-y", type=float, default=268.0)
    ap.add_argument("--gape", default="-352,356")
    ap.add_argument("--tip", default="-434,362")
    ap.add_argument("--scale", type=float, default=0.7)
    ap.add_argument("--gamma", type=float, default=2.2, help="undo voxelize.py's extra sRGB encode on the donor colours (1 = keep)")
    a = ap.parse_args()
    croc_path = Path(a.croc)
    rig = json.loads(croc_path.with_suffix(".rig.json").read_text(encoding="utf-8"))
    names = [b["name"] for b in rig["bones"]]
    h0, h1, jw = (names.index(n) for n in ("head0", "head1", "jaw"))
    cp, cc, cf = bake.read_kvox(croc_path)
    dp, dc, _ = bake.read_kvox(Path(a.donor))
    jaw_bone = rig["bones"][jw]
    hinge = np.array([jaw_bone["head"][2], jaw_bone["head"][1]])  # (z, y) of the croc jaw hinge
    gape = np.array([float(v) for v in a.gape.split(",")])  # (z, y) donor
    tip = np.array([float(v) for v in a.tip.split(",")])
    s = a.scale
    # Donor head: forward of the cut, above the throat floor (leaves its arms and chest behind).
    keep = (dp[:, 2] < a.cut_z) & (dp[:, 1] > a.min_y)
    q, col = dp[keep].astype(float), dc[keep]
    col = np.clip(255.0 * (col / 255.0) ** a.gamma, 0, 255).round().astype(np.uint8)
    zy = (q[:, [2, 1]] - gape) * s + hinge
    new = np.round(np.c_[q[:, 0] * s, zy[:, 1], zy[:, 0]]).astype(int)
    new, first = np.unique(new, axis=0, return_index=True)
    col = col[first]
    # bones: behind the hinge head0; in front, below the mouth line jaw else head1
    tip_n = (tip - gape) * s + hinge
    z0, y0, z1, y1 = tip_n[0], tip_n[1], hinge[0], hinge[1]
    line_y = y0 + (y1 - y0) * (new[:, 2] - z0) / (z1 - z0)
    bone = np.where(new[:, 2] >= hinge[0], h0, np.where(new[:, 1] < line_y, jw, h1)).astype(np.uint8)
    # Croc cells that stay: everything except the head set forward of the cut.
    is_head = np.isin(cf, (h0, h1, jw))
    croc_cut = (a.cut_z - gape[0]) * s + hinge[0]  # where the donor's back plane lands
    drop = is_head & (cp[:, 2] < croc_cut)
    keep_c = ~drop
    all_cells = np.vstack([cp[keep_c], new])
    all_rgb = np.vstack([cc[keep_c], col])
    all_bone = np.concatenate([cf[keep_c], bone])
    # one cell per place; the donor's win (they come last, so take the last occurrence)
    _, last = np.unique(all_cells[::-1], axis=0, return_index=True)
    sel = np.sort(len(all_cells) - 1 - last)
    out = Path(a.out)
    height = rig["height"]
    write_kvox(out, all_cells[sel], all_rgb[sel], all_bone[sel], height)
    # rig.json: same bones; the snout tails follow the donor's nose, hinge unchanged.
    nose_z = float(new[:, 2].min())
    rig2 = json.loads(json.dumps(rig))
    for b in rig2["bones"]:
        if b["name"] == "jaw":
            b["tail"] = [0.0, round(float(y1 - 6), 2), round(nose_z + 2, 2)]
        if b["name"] == "head1":
            b["tail"] = [0.0, round(float(y1), 2), round(nose_z, 2)]
    out.with_suffix(".rig.json").write_text(json.dumps(rig2, indent=1), encoding="utf-8", newline="\n")
    counts = {n: int((all_bone[sel] == i).sum()) for i, n in ((h0, "head0"), (h1, "head1"), (jw, "jaw"))}
    print(json.dumps({
        "cells": int(len(sel)), "donor_head_cells": int(len(new)), "croc_cells_dropped": int(drop.sum()), **counts,
        "hinge_zy": hinge.tolist(), "nose_z": nose_z, "croc_nose_z": float(cp[:, 2].min()),
        "snout_length_hinge_to_nose": round(float(hinge[0] - nose_z), 1),
        "croc_snout_length_hinge_to_nose": round(float(hinge[0] - cp[:, 2].min()), 1),
        "scale": s, "croc_cut_z": round(float(croc_cut), 1), "mouth_line": [round(float(v), 1) for v in (z0, y0, z1, y1)],
    }))


if __name__ == "__main__":
    main()
