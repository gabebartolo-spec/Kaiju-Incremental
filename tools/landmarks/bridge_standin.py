"""Writes the bridge landmark's STAND-IN raw voxel shell (D-254): a plain two-tower suspension
bridge in grey, until the lead's Tripo model (the D-133 suspension bridge tower) replaces it
through tools/blender/voxelize.py. Our own geometry, no third-party asset.

    python tools/landmarks/bridge_standin.py <out_raw.kvox>
    python tools/landmarks/bake.py <out_raw.kvox> bridge
    python tools/landmarks/bake.py --connect bridge

Sizes in sim units (8 voxels each, BuildingVoxels.RES): LENGTH along x (the span, landings
included: city landmark "bridge" "landing"), WIDTH along z, towers TOWER floors tall. The deck is
the bottom floor, at street level, so it meets the land at both ends (#12).
Pure Python + numpy.
"""
import struct
import sys

import numpy as np

RES = 8
LENGTH = 56
WIDTH = 6
TOWER = 24
DECK = 6  # deck thickness in voxels
STEEL = (138, 141, 144)
ROAD = (58, 58, 60)
KERB = (150, 148, 140)


def build():
    nx, nz, ny = LENGTH * RES, WIDTH * RES, TOWER * RES
    grid = np.zeros((nx, ny, nz), dtype=np.uint8)  # 0 air, 1 steel, 2 road, 3 kerb
    grid[:, 0:DECK, :] = 3
    grid[:, DECK - 1, 4:nz - 4] = 2
    grid[:, DECK:DECK + 3, 0:2] = 3  # parapets
    grid[:, DECK:DECK + 3, nz - 2:nz] = 3
    towers = [nx // 4, nx - nx // 4]
    legs = [(1, 7), (nz - 7, nz - 1)]
    for tx in towers:
        for z0, z1 in legs:
            grid[tx - 4:tx + 4, DECK:ny, z0:z1] = 1
        for y in (ny // 2, ny - 10, ny // 4 + 8):
            grid[tx - 3:tx + 3, y:y + 6, 1:nz - 1] = 1  # portal beams
    top = ny - 4
    sag = DECK + 14
    for z0, z1 in legs:
        cz = (z0 + z1) // 2
        prev = None
        for x in range(nx):
            if x < towers[0]:  # side span: tower top down to the deck at the end
                y = int(DECK + (top - DECK) * (x / towers[0]) ** 2)
            elif x > towers[1]:
                y = int(DECK + (top - DECK) * ((nx - 1 - x) / (nx - 1 - towers[1])) ** 2)
            else:  # main span: a parabola from top to sag mid-span
                t = (x - towers[0]) / (towers[1] - towers[0]) * 2.0 - 1.0
                y = int(sag + (top - sag) * t * t)
            lo, hi = (y, y) if prev is None else (min(y, prev), max(y, prev))
            grid[x, lo:hi + 2, cz - 1:cz + 1] = 1  # 6-connected: steps filled
            if x % 16 == 0 and towers[0] < x < towers[1]:
                grid[x, DECK:y, cz] = 1  # suspenders
            prev = y
    return grid


def write(path, grid):
    colours = {1: STEEL, 2: ROAD, 3: KERB}
    xs, ys, zs = np.nonzero(grid)
    with open(path, "wb") as f:
        f.write(b"KVOX")
        f.write(struct.pack("<IIH", 2, 1, grid.shape[1] + 1))
        f.write(struct.pack("<I", len(xs)))
        for x, y, z in zip(xs.tolist(), ys.tolist(), zs.tolist()):
            r, g, b = colours[int(grid[x, y, z])]
            f.write(struct.pack("<hhhBBBB", x, y, z, r, g, b, 0))


if __name__ == "__main__":
    write(sys.argv[1], build())
