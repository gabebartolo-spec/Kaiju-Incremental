"""The pool's big and biggest landmarks, authored in code (D-375 tiers; director 2026-10-30:
"Spire + megatower", "Author in code (free)", no Tripo spend). Writes each as a raw KVOX v2
(bake.py's input) and bakes it into data/landmarks.json and assets/landmarks/.

    python tools/landmarks/build_towers.py <scratch dir>

Voxel axes: x, z across the footprint, y up; 8 voxels to a floor and to a sim unit (bake.RES).
Each tier is a hollow shell (bake.py keeps only the faces open to outside air and marks sealed
air structural, so the inside costs nothing)."""

import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "port"))
from build_port import Model, shade  # noqa: E402

BAKE = os.path.join(HERE, "bake.py")
R = 8  # voxels a floor / a sim unit

STONE = (196, 188, 170)
STONE_DARK = (150, 142, 126)
GLASS = (52, 74, 96)
GLASS_LIT = (70, 98, 124)
STEEL = (150, 156, 162)
GOLD = (196, 160, 72)
RED = (200, 48, 42)


def shell(m, cx, cz, half, y0, y1, col):
    """A square tier's walls and roof: half-width `half` voxels round (cx, cz), from y0 to y1."""
    x0, x1, z0, z1 = cx - half, cx + half - 1, cz - half, cz + half - 1
    m.box(x0, x1, y0, y1, z0, z0, col)
    m.box(x0, x1, y0, y1, z1, z1, col)
    m.box(x0, x0, y0, y1, z0, z1, col)
    m.box(x1, x1, y0, y1, z0, z1, col)
    m.box(x0, x1, y1, y1, z0, z1, col)


def windows(frame, glass, lit, every=4):
    """Facade colour: a frame band each floor and each `every` voxels across, glass between."""
    def col(x, y, z):
        if y % R in (0, 1) or x % every == 0 or z % every == 0:
            return frame
        return lit if (x * 7 + y // R * 3 + z * 5) % 11 == 0 else glass
    return col


def spire():
    """Big tier: a stone tower in four setbacks to a steel needle, 10 x 10 units, 52 floors."""
    m = Model()
    c = 5 * R
    tiers = [(5 * R, 0, 6), (4 * R, 6, 30), (3 * R, 30, 40), (2 * R, 40, 45), (R, 45, 48)]
    for half, f0, f1 in tiers:
        col = windows(STONE, shade(GLASS, 1.1), GLASS_LIT, every=6) if f1 > 6 else STONE_DARK
        shell(m, c, c, half, f0 * R, f1 * R - 1, col)
        m.box(c - half, c + half - 1, f1 * R - 2, f1 * R - 1, c - half, c + half - 1, STONE_DARK)
    m.box(c - 2, c + 1, 48 * R, 52 * R - 1, c - 2, c + 1, STEEL)
    m.box(c - 1, c, 52 * R - 6, 52 * R - 1, c - 1, c, RED)
    return m


def megatower():
    """Biggest tier: a glass megatower, 16 x 16 units, setbacks to a gold crown and a mast, 80 floors."""
    m = Model()
    c = 8 * R
    shell(m, c, c, 8 * R, 0, 4 * R - 1, STONE_DARK)  # podium
    tiers = [(7 * R, 4, 40), (6 * R, 40, 60), (5 * R, 60, 70), (4 * R, 70, 74)]
    for half, f0, f1 in tiers:
        shell(m, c, c, half, f0 * R, f1 * R - 1, windows(STEEL, GLASS, GLASS_LIT))
        m.box(c - half, c + half - 1, f1 * R - 2, f1 * R - 1, c - half, c + half - 1, STEEL)
    shell(m, c, c, 3 * R, 74 * R, 76 * R - 1, GOLD)  # crown
    m.box(c - 3, c + 2, 76 * R, 80 * R - 1, c - 3, c + 2, STEEL)  # mast
    m.box(c - 1, c, 80 * R - 6, 80 * R - 1, c - 1, c, RED)
    return m


MODELS = {"spire": spire, "megatower": megatower}


def main(out):
    os.makedirs(out, exist_ok=True)
    for ident, make in MODELS.items():
        raw = os.path.join(out, ident + ".raw.kvox")
        make().write(raw)
        subprocess.run([sys.executable, BAKE, raw, ident], check=True)
        subprocess.run([sys.executable, BAKE, "--connect", ident], check=True)


if __name__ == "__main__":
    main(sys.argv[1])
