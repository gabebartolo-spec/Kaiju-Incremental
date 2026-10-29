"""The port's three pool models, authored in code (D-381, the director's port board picks
2026-10-29: A2 Seaforth ship-to-shore cranes, B1 Rotterdam container stacks, C1 Teignmouth quay
sheds; no Tripo spend). Writes each as a raw KVOX v2 (bake.py's input) and bakes it into
data/city_buildings.json and assets/city_buildings/ with the pool bake (district "port": mix 0,
so the colours stay as written here).

    python tools/port/build_port.py <scratch dir>

Voxel axes: x along the quay, y up, z across it, z 0 on the sea side (facing 0 puts it north,
seaward). 8 voxels to a floor (bake.RES)."""

import os
import random
import struct
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
BAKE = os.path.join(HERE, "..", "landmarks", "bake.py")

RED = (200, 48, 42)
WHITE = (232, 230, 224)
GREY = (106, 110, 114)
DARK = (58, 60, 62)
GLASS = (42, 53, 64)
# B1: rust red, orange, blue, grey, green, maroon, white, teal
BOXES = [(138, 58, 42), (216, 116, 42), (42, 90, 154), (138, 142, 144),
         (58, 122, 74), (106, 42, 42), (224, 221, 212), (42, 122, 122)]
CREAM = (216, 207, 184)
CLAD = (111, 132, 148)
DOOR = (42, 90, 168)
ROOF = (168, 173, 176)


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)


class Model:
    def __init__(self):
        self.cells = {}

    def box(self, x0, x1, y0, y1, z0, z1, col):
        """Fills the inclusive box with one colour (or col(x, y, z) when callable)."""
        for x in range(x0, x1 + 1):
            for y in range(y0, y1 + 1):
                for z in range(z0, z1 + 1):
                    self.cells[(x, y, z)] = col(x, y, z) if callable(col) else col

    def line(self, a, b, r, col):
        """A beam of half-width r (voxels) from a to b (x, y, z)."""
        n = max(abs(b[k] - a[k]) for k in range(3))
        for i in range(n + 1):
            t = i / n if n else 0.0
            c = [round(a[k] + (b[k] - a[k]) * t) for k in range(3)]
            self.box(c[0] - r, c[0] + r - 1 + (r == 0), c[1] - r, c[1] + r - 1 + (r == 0),
                     c[2] - r, c[2] + r - 1 + (r == 0), col)

    def write(self, path):
        with open(path, "wb") as f:
            f.write(b"KVOX")
            f.write(struct.pack("<IIHI", 2, 1, max(k[1] for k in self.cells) + 1, len(self.cells)))
            for (x, y, z), (r, g, b) in sorted(self.cells.items()):
                f.write(struct.pack("<hhhBBBB", x, y, z, r, g, b, 0))


def crane():
    """A2: a ship-to-shore crane parked with its boom raised. Red portal legs on bogies, white
    trolley girders running back over the land legs to the machinery house, a red A-frame, the
    raised lattice boom leaning out over the sea, grey stays from the A-frame's apex."""
    m = Model()
    sea, land = (10, 13), (50, 53)
    for x0 in (3, 33):
        for z0, z1 in (sea, land):
            m.box(x0 - 2, x0 + 5, 0, 3, z0 - 1, z1 + 1, DARK)  # bogie, along the quay
            m.box(x0, x0 + 3, 4, 51, z0, z1, RED)  # leg
        m.box(x0, x0 + 3, 44, 51, sea[0], land[1], RED)  # portal beam, sea to land legs
        m.box(x0 + 1, x0 + 3, 52, 57, sea[0], 63, WHITE)  # trolley girder
    for z0, z1 in (sea, land):
        m.box(3, 36, 44, 51, z0, z1, RED)  # cross beam
    m.box(7, 32, 52, 55, 12, 20, GREY)  # parked trolley
    m.box(15, 24, 44, 51, 14, 20, lambda x, y, z: GLASS if 46 <= y <= 49 else WHITE)  # cab
    m.box(5, 34, 56, 71, 52, 63,
          lambda x, y, z: RED if 64 <= y <= 66 else (ROOF if y >= 70 else WHITE))  # house
    apex = 112
    for x in (4, 34):
        m.line((x, 56, 13), (x, apex, 27), 2, RED)  # A-frame, sea post
        m.line((x, 56, 47), (x, apex, 29), 2, RED)  # A-frame, land post
        m.line((x + 1, apex, 28), (x + 1, 58, 63), 0, GREY)  # backstay
        m.line((x + 1, apex, 28), (x + 1, 124, 4), 0, GREY)  # forestay
    m.box(3, 36, apex - 2, apex + 1, 25, 31, RED)  # apex beam
    foot, tip = (54, 12), (130, 2)  # boom: (y, z) at the hinge and at the head
    for x in (3, 34):
        for off in (0, 5):
            m.line((x, foot[0], foot[1] + off), (x, tip[0], tip[1] + off), 1, RED)
            m.line((x + 1, foot[0], foot[1] + off), (x + 1, tip[0], tip[1] + off), 1, RED)
    steps = 8
    for i in range(steps):
        t0, t1 = i / steps, (i + 1) / steps
        y0, z0 = round(foot[0] + (tip[0] - foot[0]) * t0), round(foot[1] + (tip[1] - foot[1]) * t0)
        y1, z1 = round(foot[0] + (tip[0] - foot[0]) * t1), round(foot[1] + (tip[1] - foot[1]) * t1)
        for x in (3, 4, 34, 35):
            m.line((x, y0, z0), (x, y1, z1 + 5), 0, RED)  # side lacing
        for off in (0, 5):
            m.line((5, y1, z1 + off), (33, y1, z1 + off), 0, WHITE)  # cross member
        m.line((5, y0, z0), (33, y1, z1), 0, WHITE)  # face diagonal
    m.box(1, 38, tip[0], tip[0] + 5, tip[1] - 1, tip[1] + 6, WHITE)  # boom head
    return m


def container(m, x0, y0, z0, length, col, rng):
    """One box, length along x, 4 wide and 4 tall: corrugated sides, darker end frames with
    door bars, a lighter roof."""
    dark, light = shade(col, 0.72), shade(col, 1.15)

    def paint(x, y, z):
        lx = x - x0
        if lx in (0, length - 1):
            return dark if (z - z0) in (0, 3) or (y - y0) in (0, 3) or rng.random() < 0.4 else col
        if y == y0 + 3:
            return light
        return shade(col, 0.86) if lx % 2 else col

    m.box(x0, x0 + length - 1, y0, y0 + 3, z0, z0 + 3, paint)


def stack():
    """B1: a block of 40 ft containers, two along by ten across, up to four high, the colours
    mixed and a few top boxes gone."""
    m = Model()
    rng = random.Random(381)
    for row in range(10):
        for col in range(2):
            high = 4 if rng.random() < 0.7 else 3
            for tier in range(high):
                container(m, col * 21, tier * 4, row * 4, 19, rng.choice(BOXES), rng)
    return m


def shed():
    """C1: a long low quay shed: a cream concrete base wall, ribbed blue-grey cladding, three
    big blue roller doors on the front (z 0) and a shallow grey gable roof."""
    m = Model()
    w, d = 88, 40
    doors = [(10, 23), (38, 51), (66, 79)]

    def wall(x, y, z):
        front = z == 0
        if front and y <= 9 and any(a <= x <= b for a, b in doors):
            return shade(DOOR, 0.82) if y % 2 else DOOR
        if front and y == 10 and any(a - 1 <= x <= b + 1 for a, b in doors):
            return DARK
        if y <= 3:
            return CREAM
        rib = x if z in (0, d - 1) else z
        return shade(CLAD, 0.85) if rib % 3 == 0 else CLAD

    m.box(0, w - 1, 0, 11, 0, d - 1, wall)
    for z in range(d):
        top = 12 + int((d / 2 - abs(z + 0.5 - d / 2)) // 5)
        m.box(0, w - 1, 12, min(top, 15), z, z,
              lambda x, y, zz: shade(ROOF, 0.9) if x % 4 == 0 else ROOF)
    return m


MODELS = {"P01": crane, "P02": stack, "P03": shed}


def main(out):
    os.makedirs(out, exist_ok=True)
    for ident, make in MODELS.items():
        raw = os.path.join(out, ident + ".raw.kvox")
        make().write(raw)
        subprocess.run([sys.executable, BAKE, "--pool", raw, ident], check=True)


if __name__ == "__main__":
    main(sys.argv[1])
