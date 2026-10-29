"""Paints a croc's orange irises black in its .kvox (director, 2026-10-29: "i think i prefer the black eyes").

The sculpt's eye is a dark ball with a warm iris that only reads face-on, so a roar that lifts the head into the
light flashes orange eyes. Every warm cell within EYE_RADIUS of an eye centre (the lid bones' pivot) takes the eye's
own dark colour. Re-run tools/kaiju_skin/bake_all.sh (or bake.py) afterwards: the .vskin stamp covers the .kvox.

    python tools/kaiju_skin/black_eyes.py assets/kaiju/reptilian_baby
"""
import json
import sys
from pathlib import Path

import numpy as np

from bake import read_kvox

EYE_RADIUS = 10.0  # rig units: the iris ends by 10 (warm cells per eye at radius 8 / 10 / 12: 305 / 318 / 318)
EYE_BONES = ("lid_up_l", "lid_up_r")


def warm(c):
    return (c[:, 0] > c[:, 1] + 15) & (c[:, 0] > c[:, 2] + 30)


def main():
    base = Path(sys.argv[1])
    kvox = base.with_suffix(".kvox")
    rig = json.loads(base.with_suffix(".rig.json").read_text(encoding="utf-8"))
    pos, col, _ = read_kvox(kvox)
    col = col.astype(int)
    data = bytearray(kvox.read_bytes())
    version = int.from_bytes(data[4:8], "little")
    off = 18 if version >= 2 else 14
    painted = 0
    for bone in rig["bones"]:
        if bone["name"] not in EYE_BONES:
            continue
        near = np.linalg.norm(pos - np.array(bone["head"]), axis=1) < EYE_RADIUS
        iris = near & warm(col)
        dark = near & (col.max(axis=1) < 40)
        black = np.median(col[dark], axis=0).astype(int) if dark.any() else np.array([20, 20, 20])
        for i in np.flatnonzero(iris):
            data[off + i * 10 + 6:off + i * 10 + 9] = bytes(black.tolist())
        painted += int(iris.sum())
        print(f"{bone['name']}: {int(iris.sum())} iris cells -> {tuple(black.tolist())}")
    kvox.write_bytes(bytes(data))
    print(f"{kvox.name}: {painted} cells painted")


if __name__ == "__main__":
    main()
