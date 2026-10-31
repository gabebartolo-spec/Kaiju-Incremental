"""Solid mouth for a rigged .kvox whose jaw is a hollow shell (the baby croc, director 2026-10-31: the re-rigged jaw
opened see-through, with a black block where its empty inside showed). Every jaw column (x, z) is filled from its
lowest to its highest jaw voxel, owned by the jaw; columns at least ERODE cells in from the lip edge get a THROAT top
cell and a PALATE-deep palate just above it, owned by head1, so the open mouth shows a solid floor and roof while a
shut mouth hides both inside the lips. Mouth colours are the jaw's own pale throat, never red: bake.py turns red
head1/jaw voxels into mouth voxels that BipedHead shows black when the jaw shuts (the director disliked both the pink
and the flip to black), so those are recoloured too. Running it twice adds nothing (filled cells are skipped).

    python tools/kaiju_skin/mouth_fill.py <name.kvox> <name.rig.json>
"""
import json
import sys
from pathlib import Path

import numpy as np

import bake
import lid_flaps

THROAT = np.array([169, 161, 132])  # the jaw's pale throat, sampled from the sculpt
GUM = np.array([120, 114, 94])  # the jaw's darker fill under the throat
ERODE = 2  # cells in from the lip edge before the throat colour and palate start
PALATE = 2  # palate depth above the jaw top
RED = 1.35  # bake.py's mouth-red ratio (red over green and over blue)


def jaw_columns(cells: np.ndarray, own: np.ndarray, jaw: int) -> dict:
    cols = {}
    for x, y, z in cells[own == jaw]:
        lo, hi = cols.get((x, z), (y, y))
        cols[(x, z)] = (min(lo, y), max(hi, y))
    return cols


def erode(cols: set, n: int) -> set:
    for _ in range(n):
        cols = {(x, z) for x, z in cols
                if all(c in cols for c in ((x + 1, z), (x - 1, z), (x, z + 1), (x, z - 1)))}
    return cols


def fill(kvox: Path, rig: Path) -> None:
    data = kvox.read_bytes()
    cells, rgb, own = bake.read_kvox(kvox)
    names = [b["name"] for b in json.loads(rig.read_text())["bones"]]
    jaw, head = names.index("jaw"), names.index("head1")
    occ = {tuple(c) for c in cells}
    cols = jaw_columns(cells, own, jaw)
    inner = erode(set(cols), ERODE)
    add_c, add_r, add_o = [], [], []

    def put(c: tuple, col: np.ndarray, o: int) -> None:
        if c not in occ:
            occ.add(c)
            add_c.append(c)
            add_r.append(col)
            add_o.append(o)

    for (x, z), (lo, hi) in cols.items():
        for y in range(lo, hi + 1):
            put((x, y, z), THROAT if (x, z) in inner and y == hi else GUM, jaw)
        if (x, z) in inner:
            for y in range(hi + 1, hi + 1 + PALATE):
                put((x, y, z), THROAT, head)
    rgb = rgb.copy()
    r, g, b = (rgb[:, i].astype(int) for i in range(3))
    red = np.isin(own, [jaw, head]) & (r > g * RED) & (r > b * RED)
    rgb[red] = THROAT
    for i in np.where(own == jaw)[0]:
        x, y, z = cells[i]
        if (x, z) in inner and y == cols[(x, z)][1]:
            rgb[i] = THROAT
    print(f"{kvox.name}: jaw columns {len(cols)}, inner {len(inner)}, added {len(add_c)}, "
          f"mouth-red recoloured {int(red.sum())}")
    if not add_c:
        add = np.zeros((0, 3), int), np.zeros((0, 3), np.uint8), np.zeros(0, int)
    else:
        add = np.array(add_c, int), np.array(add_r, np.uint8), np.array(add_o, int)
    lid_flaps.write_kvox(kvox, data, np.r_[cells, add[0]], np.r_[rgb, add[1]], np.r_[own, add[2]])


if __name__ == "__main__":
    fill(Path(sys.argv[1]), Path(sys.argv[2]))
